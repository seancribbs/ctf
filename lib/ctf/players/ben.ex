defmodule Ctf.Players.Ben do
  @moduledoc """
  A CTF Player that only seeks the flag, attempting to get there as fast as
  possible.
  """

  @behaviour Ctf.Player
  alias Ctf.{Game, Board, Flag, Player}

  def turn(g = %Game{board: board}, p = %Player{x: x, y: y, direction: d}, state) do
    {moves, state} = dumb(g, p, state)

    {left, up, right, down} = {
      Enum.empty?(Ctf.Board.get_cell_contents(board, x - 1, y)),
      Enum.empty?(Ctf.Board.get_cell_contents(board, x, y - 1)),
      Enum.empty?(Ctf.Board.get_cell_contents(board, x + 1, y)),
      Enum.empty?(Ctf.Board.get_cell_contents(board, x, y + 1))
    }

    cond do
      {:vert, :n, false} == {state, d, up} ->
        {[counterclockwise: 1, move: 1, clockwise: 1], state}

      {:vert, :s, false} == {state, d, down} ->
        {[counterclockwise: 1, move: 1, clockwise: 1], state}

      {:horiz, :e, false} == {state, d, right} ->
        {[counterclockwise: 1, move: 1, clockwise: 1], state}

      {:horiz, :w, false} == {state, d, left} ->
        {[counterclockwise: 1, move: 1, clockwise: 1], state}

      true ->
        {moves, state}
    end
  end

  def dumb(g = %Game{board: board}, p = %Player{number: num, x: x}, :horiz) do
    flag = Enum.find(board.flags, &(&1.number != num))
    move_x = flag.x - x

    if abs(move_x) > 0 do
      {[move: abs(move_x)], :horiz}
    else
      turn(g, p, nil)
    end
  end

  def dumb(%Game{board: board}, %Player{number: num, x: x, direction: d}, :rot) do
    flag = Enum.find(board.flags, &(&1.number != num))
    move_x = flag.x - x

    steps =
      if move_x > 0 do
        d2d(d, :e)
      else
        d2d(d, :w)
      end

    {steps ++ [move: abs(move_x)], :horiz}
  end

  def dumb(g = %Game{board: board}, p = %Player{number: num, y: y}, :vert) do
    flag = Enum.find(board.flags, &(&1.number != num))
    move_y = flag.y - y

    if abs(move_y) > 0 do
      {[move: abs(move_y)], :vert}
    else
      turn(g, p, :rot)
    end
  end

  def dumb(%Game{board: board}, %Player{number: num, y: y, direction: d}, _) do
    flag = Enum.find(board.flags, &(&1.number != num))
    move_y = flag.y - y

    steps =
      if move_y > 0 do
        d2d(d, :s)
      else
        d2d(d, :n)
      end

    {steps ++ [move: abs(move_y)], :vert}
  end

  def name() do
    "Ben"
  end

  defp d2d(d, d2) do
    case {d, d2} do
      {:n, :n} -> []
      {:n, :e} -> [clockwise: 1]
      {:n, :s} -> [clockwise: 2]
      {:n, :w} -> [counterclockwise: 1]
      {:e, :e} -> []
      {:e, :s} -> [clockwise: 1]
      {:e, :w} -> [clockwise: 2]
      {:e, :n} -> [counterclockwise: 1]
      {:s, :s} -> []
      {:s, :w} -> [clockwise: 1]
      {:s, :n} -> [clockwise: 2]
      {:s, :e} -> [counterclockwise: 1]
      {:w, :w} -> []
      {:w, :n} -> [clockwise: 1]
      {:w, :e} -> [clockwise: 2]
      {:w, :s} -> [counterclockwise: 1]
    end
  end
end
