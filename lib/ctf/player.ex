defmodule Player do
  @enforce_keys [:number, :flag, :x, :y, :health_points, :module]
  defstruct number: nil, flag: nil, x: nil, y: nil, health_points: nil, module: nil

  @type t() :: %__MODULE__{
         number: Integer.t,
         flag: Flat.t,
         x: Integer.t,
         y: Integer.t,
         health_points: Integer.t,
         module: Atom.t
       }

  @directions %{
    "N" => [0, -1],
    "S" => [0,  1],
    "W" => [-1, 0],
    "E" => [1,  0],
  }

  def new(number: number, flag: flag, x: x, y: y, health_points: health_points, module: module) do
    %Player{
      number: number,
      flag: flag,
      x: x,
      y: y,
      health_points: health_points,
      module: module
    }
  end

  #def move(%Player{position: [x, y]} = player, direction, units \\ 1) when units > 0 and units <= 3 do
  #  direction_transform = @directions[direction]
  #  new_player_position =
  #    Enum.reduce(1..units, fn
  #  %Player{player | position: [x + direction_transform[0] * units, y + direction_transform[1] * units]}}


  #  {:ok, %Player{player | position: [x + direction_transform[0] * units, y + direction_transform[1] * units]}}
  #end

  def decrement_health(%Player{health_points: health_points} = player) do
    if health_points == 0 do
      {:error, player, "no health points to decrement"}
    else
      {:ok, %Player{player | health_points: health_points - 1}}
    end
  end
end
