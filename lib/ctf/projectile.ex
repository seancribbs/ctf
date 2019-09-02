defmodule Ctf.Projectile do
  @enforce_keys [:x, :y]
  defstruct x: nil, y: nil

  @type t() :: %__MODULE__{
          x: Integer.t(),
          y: Integer.t()
        }

  def new(x: x, y: y) do
    %__MODULE__{
      x: x,
      y: y
    }
  end
end
