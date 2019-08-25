defmodule Ctf.Player do
  @enforce_keys [:number, :flag, :x, :y, :health_points, :module, :direction]
  defstruct number: nil, flag: nil, x: nil, y: nil, health_points: nil, module: nil, direction: nil

  @type t() :: %__MODULE__{
         number: Integer.t,
         flag: Flat.t,
         x: Integer.t,
         y: Integer.t,
         health_points: Integer.t,
         module: Atom.t,
         direction: Atom.t
       }

  @directions %{
    "N" => [0, -1],
    "S" => [0,  1],
    "W" => [-1, 0],
    "E" => [1,  0],
  }

  def new(number: number, flag: flag, x: x, y: y, health_points: health_points, module: module, direction: direction) when direction in [:n, :s, :e, :w] do
    %__MODULE__{
      number: number,
      flag: flag,
      x: x,
      y: y,
      health_points: health_points,
      module: module,
      direction: direction
    }
  end

  #def move(%__MODULE__{position: [x, y]} = player, direction, units \\ 1) when units > 0 and units <= 3 do
  #  direction_transform = @directions[direction]
  #  new_player_position =
  #    Enum.reduce(1..units, fn
  #  %__MODULE__{player | position: [x + direction_transform[0] * units, y + direction_transform[1] * units]}}


  #  {:ok, %__MODULE__{player | position: [x + direction_transform[0] * units, y + direction_transform[1] * units]}}
  #end

  def decrement_health(%__MODULE__{health_points: health_points} = player) do
    if health_points == 0 do
      {:error, player, "no health points to decrement"}
    else
      {:ok, %__MODULE__{player | health_points: health_points - 1}}
    end
  end
end
