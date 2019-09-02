defmodule Ctf.Flag do
  @enforce_keys [:number, :x, :y]
  defstruct number: nil, x: nil, y: nil

  @type t() :: %__MODULE__{
          number: Integer.t(),
          x: Integer.t(),
          y: Integer.t()
        }

  def new(number: number, x: x, y: y) do
    %__MODULE__{
      number: number,
      x: x,
      y: y
    }
  end
end
