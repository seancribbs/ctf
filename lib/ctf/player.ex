defmodule Ctf.Player do
  @enforce_keys [:number, :flag, :x, :y, :health_points, :module, :name, :state, :direction]
  defstruct number: nil,
            flag: nil,
            x: nil,
            y: nil,
            health_points: nil,
            module: nil,
            name: nil,
            state: nil,
            direction: nil

  @type state() :: any()
  @type actions() :: [move: 1..3, rotate: 1..3, fire: 1..3]

  @callback turn(Ctf.Game.t(), state()) :: {actions(), state()}

  @type t() :: %__MODULE__{
          number: Integer.t(),
          flag: Flag.t(),
          x: Integer.t(),
          y: Integer.t(),
          health_points: Integer.t(),
          module: Atom.t(),
          name: String.t(),
          state: any(),
          direction: Atom.t()
        }

  @direction_move_displacement [
    n: {0, -1},
    s: {0, 1},
    w: {-1, 0},
    e: {1, 0}
  ]

  def new(
        number: number,
        flag: flag,
        x: x,
        y: y,
        health_points: health_points,
        module: module,
        direction: direction
      )
      when direction in [:n, :s, :e, :w] do
    %__MODULE__{
      number: number,
      flag: flag,
      x: x,
      y: y,
      health_points: health_points,
      module: module,
      name: get_name(module),
      state: nil,
      direction: direction
    }
  end

  defp get_name(module) do
    apply(module, :name, [])
  rescue
    _e in UndefinedFunctionError -> "#{module}"
  end

  def rotate(%__MODULE__{} = player, :clockwise) do
    %__MODULE__{
      player
      | direction:
          case player.direction do
            :n -> :e
            :e -> :s
            :s -> :w
            :w -> :n
          end
    }
  end

  def rotate(%__MODULE__{} = player, :counterclockwise) do
    %__MODULE__{
      player
      | direction:
          case player.direction do
            :n -> :w
            :e -> :n
            :s -> :e
            :w -> :s
          end
    }
  end

  # no validation is done here: it is expected the caller will
  # determine if this is a valid move (we don't know how big the board is)
  def move(%__MODULE__{} = player) do
    {x_change, y_change} = @direction_move_displacement[player.direction]
    %__MODULE__{player | x: player.x + x_change, y: player.y + y_change}
  end

  def decrement_health(%__MODULE__{health_points: health_points} = player) do
    status =
      cond do
        health_points <= 1 -> :dead
        true -> :ok
      end

    {status, %__MODULE__{player | health_points: health_points - 1}}
  end
end
