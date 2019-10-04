defmodule Ctf.Players.Skunk do
  @behaviour Ctf.Player
  alias Ctf.{Board, Game, Player}

  # moves [:fire, :clockwise, :counterclockwise, :move]

  def name do
    "Skunk"
  end

  @impl Ctf.Player
  def turn(game = %Game{}, player = %Player{}, nil) do
    turn(game, player, 0)
  end

  def turn(%Game{board: board}, player = %Player{}, state) when state >= 3 do
    case find_location_of(:empty, board, player) do
      {:ok, distance} ->
        {[move: distance], 0}

      _ ->
        {[clockwise: 1], state}
    end
  end

  def turn(%Game{board: board}, player = %Player{}, state) do
    case find_location_of(:player, board, player) do
      {:ok, distance} ->
        {[fire: distance], 0}

      _ ->
        {[clockwise: 1], state + Enum.random(1..2)}
    end
  end

  # @spec find_oponent_location(term, term) :: {:ok, direction, distance} | :none
  defp find_location_of(thing, board, %{x: my_x, y: my_y, direction: direction}) do
    check(board, my_x, my_y, direction, 3, thing)
  end

  defp check(_, _, _, _, 0, _) do
    :none
  end

  defp check(board, x, y, direction, distance, :player) do
    case check_spot(board, x, y, direction, distance) do
      [%Player{}] ->
        {:ok, distance}

      _ ->
        check(board, x, y, direction, distance - 1, :player)
    end
  end

  defp check(board, x, y, direction, distance, :empty) do
    case check_spot(board, x, y, direction, 4 - distance) do
      [] ->
        {:ok, distance}

      _ ->
        check(board, x, y, direction, distance - 1, :empty)
    end
  end

  defp check_spot(board, x, y, :n, distance) do
    Board.get_cell_contents(board, x, y - distance)
  end

  defp check_spot(board, x, y, :s, distance) do
    Board.get_cell_contents(board, x, y + distance)
  end

  defp check_spot(board, x, y, :e, distance) do
    Board.get_cell_contents(board, x + distance, y)
  end

  defp check_spot(board, x, y, :w, distance) do
    Board.get_cell_contents(board, x - distance, y)
  end
end
