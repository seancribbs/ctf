defmodule Ctf.UI.Scenes.Game do
  use Scenic.Scene
  alias Scenic.Graph

  alias Ctf.UI.Components, as: C

  @graph Graph.build()

  def init([], opts) do
    Process.register(self(), __MODULE__)

    viewport = opts[:viewport]

    {:ok, %{viewport: viewport, graph: @graph}, push: @graph}
  end

  def init(games = [_ | _], opts) do
    # TODO: There's a better way to do this but it's a bit harder
    Process.register(self(), __MODULE__)

    viewport = opts[:viewport]

    send(self(), :replay)

    {:ok, %{graph: @graph, viewport: viewport, games: games}}
  end

  def handle_info(:replay, %{graph: graph, games: games} = state) do
    {status, [board | rest]} = hd(games)

    graph =
      graph
      |> C.Board.add_to_graph(board, id: :board)
      |> C.Scores.add_to_graph(board, width: 601, height: 50, translate: {0, 600})

    Process.send_after(self(), :next_frame, 500)

    {:ok, Map.merge(state, %{graph: graph, status: status, frames: rest}), push: graph}
  end

  def handle_info(:next_frame, %{frames: [], games: []} = state) do
    {:ok, state}
  end

  def handle_info(:next_frame, %{graph: graph, frames: [board | rest]} = state) do
    next_graph =
      graph
      |> C.Board.modify(board)
      |> C.Scores.modify(board)

    Process.send_after(self(), :next_frame, 500)

    {:noreply, %{state | graph: next_graph, frames: rest}, push: next_graph}
  end

  def handle_info(:next_frame, %{frames: [], games: [game | rest]} = state) do
    {status, frames} = game
    handle_info(:next_frame, Map.merge(state, %{status: status, frames: frames, games: rest}))
  end
end
