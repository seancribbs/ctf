defmodule Ctf.GameLog do
  @modes [:read, :write]
  defstruct [:file, :mode]

  def read(%__MODULE__{file: file, mode: :read}) do
    with <<length::size(4)>> <- IO.binread(file, 4),
         <<term::binary-size(length)>> <- IO.binread(file, length) do
      :erlang.binary_to_term(term)
    else
      :eof -> nil
      other -> raise "Unexpected result from reading #{__MODULE__}: #{inspect(other)}"
    end
  end

  def write(%__MODULE__{file: file, mode: :write}, term) do
    serialized = :erlang.term_to_binary(term, [:compressed])
    length = byte_size(serialized)
    IO.binwrite(file, <<length::size(4), serialized::binary>>)
  end

  def open(file, mode) when mode in @modes do
    with {:ok, port} <- File.open(file, [mode]) do
      %__MODULE__{file: port, mode: mode}
    end
  end

  def close(%__MODULE__{file: f} = log) do
    with :ok <- File.close(f) do
      %{log | mode: :closed}
    end
  end

  defimpl Enumerable do
    def reduce(_, {:halt, acc}, _f) do
      {:halted, acc}
    end

    def reduce(log, {:suspend, acc}, f) do
      {:suspended, acc, &reduce(log, &1, f)}
    end

    def reduce(%@for{mode: :read} = log, {:cont, acc}, f) do
      case @for.read(log) do
        nil -> {:done, acc}
        item -> reduce(log, f.(item, acc), f)
      end
    end

    def reduce(_, {:cont, acc}, _f) do
      # Must be in read mode, otherwise return the accumulator
      {:done, acc}
    end

    def count(_) do
      {:error, __MODULE__}
    end

    def member?(_, _) do
      {:error, __MODULE__}
    end

    def slice(_) do
      {:error, __MODULE__}
    end
  end

  defimpl Collectable do
    def into(%@for{file: _file, mode: :write} = log) do
      {log, &collect/2}
    end

    def into(_) do
      raise "Can only collect into #{@for} in write mode"
    end

    defp collect(log, :halt) do
      @for.close(log)
      :ok
    end

    defp collect(log, :done) do
      @for.close(log)
    end

    defp collect(log, {:cont, item}) do
      case @for.write(log, item) do
        :ok -> log
        {:error, reason} -> raise "Error writing to #{@for}: #{inspect(reason)}"
      end
    end
  end
end
