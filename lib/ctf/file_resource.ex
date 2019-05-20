defmodule Ctf.FileResource do
  @callback load() :: :ok

  defmacro __using__([{name, {dir, extension}}]) do
    res_dir = Path.join([:code.priv_dir(:ctf), "static", dir])

    resources =
      for res <- File.ls!(res_dir), String.ends_with?(res, extension) do
        path = Path.join(res_dir, res)
        Module.put_attribute(__CALLER__.module, :external_resource, path)
        {path, Path.basename(path, extension), Scenic.Cache.Hash.file!(path, :sha)}
      end

    Module.put_attribute(__CALLER__.module, :resources, resources)

    clauses =
      for {_, base, sha} <- resources do
        quote do
          def unquote(name)(unquote(base)) do
            unquote(sha)
          end
        end
      end

    quote do
      @behaviour Ctf.FileResource
      unquote_splicing(clauses)
      def unquote(name)(_), do: nil

      def load do
        Enum.each(@resources, fn {path, _, sha} ->
          Scenic.Cache.File.load(path, sha)
        end)
      end
    end
  end

  def load_all do
    :ctf
    |> Application.spec(:modules)
    |> Enum.filter(fn mod ->
      b = mod.__info__(:attributes)[:behaviour]
      is_list(b) && Enum.member?(b, __MODULE__)
    end)
    |> Enum.each(&apply(&1, :load, []))
  end
end
