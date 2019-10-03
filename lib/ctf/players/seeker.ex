defmodule Ctf.Players.Seeker do
  @moduledoc """
  A CTF Player that only seeks the flag, attempting to get there as fast as
  possible.
  """

  @behaviour Ctf.Player
  alias Ctf.{Game, Board, Flag, Player}

  def turn(_game = %Game{board: board}, %Player{number: num, x: x, y: y, direction: d}, state) do
    start = {x, y}
    enemy_flag = Enum.find(board.flags, &(&1.number != num))
    goal = {enemy_flag.x, enemy_flag.y}

    case search(start, goal, board) do
      {:max, path, ^goal} ->

        IO.inspect(path, label: "path")
        steps = take_steps(path, d, [])
        IO.inspect(steps, label: "actions")

        {steps, state}

      _ ->
        IO.puts("Maaaaan, this is too hard. I give up. :(")
        {[], state}
    end
  end

  def name() do
    "Seeker #{:rand.uniform(100_000)}"
  end

  defp take_steps(_, _, steps) when length(steps) >= 3 do
    # We've accumulated enough actions
    steps
    |> Enum.reverse()
    |> Enum.take(3)
  end

  defp take_steps([], _direction, steps) do
    Enum.reverse(steps)
  end

  defp take_steps([neighbor|rest], direction, steps) do
    take_steps(rest, dir(neighbor),
      # We should always want to move to the neighbor spot
      [{:move, 1}] ++
        # But we first need to make sure we're pointing in the right direction
        do_rotate(direction, dir(neighbor)) ++
        steps)
  end

  defp dir({ 1,  0}), do: :e
  defp dir({-1,  0}), do: :w
  defp dir({ 0,  1}), do: :s
  defp dir({ 0, -1}), do: :n

  defp do_rotate(direction, direction), do: []
  defp do_rotate(:n, :e), do: [clockwise: 1]
  defp do_rotate(:e, :s), do: [clockwise: 1]
  defp do_rotate(:s, :w), do: [clockwise: 1]
  defp do_rotate(:w, :n), do: [clockwise: 1]
  defp do_rotate(:e, :n), do: [counterclockwise: 1]
  defp do_rotate(:s, :e), do: [counterclockwise: 1]
  defp do_rotate(:w, :s), do: [counterclockwise: 1]
  defp do_rotate(:n, :w), do: [counterclockwise: 1]
  defp do_rotate(:n, :s), do: [clockwise: 1, clockwise: 1]
  defp do_rotate(:s, :n), do: [clockwise: 1, clockwise: 1]
  defp do_rotate(:w, :e), do: [clockwise: 1, clockwise: 1]
  defp do_rotate(:e, :w), do: [clockwise: 1, clockwise: 1]

  defp search(start, goal, board) do
    search_state = %{
      open: MapSet.new([{score([], start, goal), [], start}]),
      closed: MapSet.new()
    }

    continue(search_state, &neighbors(&1, board), &score(&1, &2, goal))
  end

  defp continue(state, neighbors, score) do
    case pop_best(state) do
      nil ->
        nil

      {{:max, path, pos}, _new_state} ->
        {:max, path, pos}

      {{_fscore, path, pos}, new_state} ->
        pos
        |> neighbors.()
        |> Enum.reject(fn {_, npos} ->
          is_closed?(npos, new_state) || is_open?(npos, new_state)
        end)
        |> Enum.reduce(new_state, &push(&1, &2, path, score))
        |> continue(neighbors, score)
    end
  end

  defp push({step, pos}, %{open: open} = state, path, score) do
    new_path = [step | path]
    %{state | open: MapSet.put(open, {score.(new_path, pos), new_path, pos})}
  end

  defp pop_best(%{open: open, closed: closed}) do
    with t = {_, _, bpos} <- Enum.max(open, fn -> nil end) do
      {t, %{open: MapSet.delete(open, t), closed: MapSet.put(closed, bpos)}}
    end
  end

  defp is_open?(pos, %{open: open}) do
    Enum.any?(open, &match?({_, _, ^pos}, &1))
  end

  defp is_closed?(pos, %{closed: closed}) do
    Enum.member?(closed, pos)
  end

  defp neighbors({x, y}, board) do
    [
      {{1, 0}, {x + 1, y}},
      {{-1, 0}, {x - 1, y}},
      {{0, 1}, {x, y + 1}},
      {{0, -1}, {x, y - 1}}
    ]
    |> Enum.filter(fn {_, {x2, y2}} ->
      in_bounds?(board, x2, y2) && is_movable?(board, x2, y2)
    end)
  end

  defp score(_p, flag, flag), do: :max

  defp score(p, pos, flag) do
    -length(p) - Scenic.Math.Vector2.distance(flag, pos)
  end

  defp in_bounds?(board, x, y) do
    x >= 0 && x < board.width - 1 && y >= 0 && y < board.height - 1
  end

  defp is_movable?(board, x, y) do
    case Board.get_cell_contents(board, x, y) do
      [] ->
        true

      [%Flag{}] ->
        true

      _ ->
        false
    end
  end
end
