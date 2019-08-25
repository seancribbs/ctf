defmodule Game do
  @enforce_keys [:board]
  defstruct board: nil

  @type t() :: %__MODULE__{
          board: Board.t
        }

  def new(players, board_height \\ 50, board_width \\ 50, obstacle_count \\ 25) do
    %Game{
      board: Board.new(
        height: board_height,
        width: board_width,
        players: players,
        obstacle_count: obstacle_count
      )
    }
  end

  #def play(%Game{} = game) do
  #end
end
