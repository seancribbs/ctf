defmodule Ctf.Players.Random do
  @behaviour Ctf.Player
  alias Ctf.Game

  @moves [:fire, :clockwise, :counterclockwise, :move]

  @impl Ctf.Player
  def turn(_game = %Game{}, _state) do
    {accumulate_turns([], 3), Enum.random(1..10000)}
  end

  def name() do
    # yes, collsions will happen.  deal with it.
    "Random #{trunc(:rand.uniform() * 100_000)}"
  end

  defp accumulate_turns(acc, 0) do
    Enum.reverse(acc)
  end
  defp accumulate_turns(acc, remaining) do
    move = Enum.at(@moves, trunc(:rand.uniform() * length(@moves)))
    # need to return at least 1 to be valid
    count = trunc(:rand.uniform() * (remaining - 1)) + 1
    accumulate_turns([{move, count} | acc], remaining - count)
  end
end
