defmodule Ctf.UI.Scenes.Game do
  use Scenic.Scene
  alias Scenic.Graph

  alias Ctf.UI.Components, as: C
  alias Ctf.{Board, Flag, Player}

  @graph Graph.build()

  @grid_count 20

  def next_frame(board) do
    GenServer.cast(__MODULE__, {:next, board})
  end

  def demo() do
    game = Ctf.Game.new([%{health_points: 5, module: Ctf.Players.Random}, %{health_points: 5, module: Ctf.Players.Random}])
    result = {_status, frames} = Ctf.Game.play(game)
    for frame <- frames do
      next_frame(frame.board)
      Process.sleep(1000)
    end
    result
  end

  def init(_, opts) do
    # TODO: There's a better way to do this but it's a bit harder
    Process.register(self(), __MODULE__)

    viewport = opts[:viewport]
    board = dummy_board()

    graph =
      @graph
      |> C.Board.add_to_graph(board, id: :board)
      |> C.Scores.add_to_graph(board, width: 601, height: 50, translate: {0, 600})

    {:ok, %{graph: graph, viewport: viewport}, push: graph}
  end

  def handle_cast({:next, %Board{} = board}, %{graph: graph} = state) do
    next_graph =
      graph
      |> C.Board.modify(board)
      |> C.Scores.modify(board)

    {:noreply, %{state| graph: next_graph}, push: next_graph}
  end

  defp dummy_board do
    # Create a dummy board for prototyping
    f1 = %Flag{number: 1, x: 0, y: 0}
    f2 = %Flag{number: 2, x: 0, y: 0}

    p1 =
      Player.new(
        number: 1,
        flag: f1,
        x: 0,
        y: 0,
        health_points: 5,
        module: Ctf.Players.Random,
        direction: :e
      )

    p2 =
      Player.new(
        number: 2,
        flag: f2,
        x: 0,
        y: 0,
        health_points: 5,
        module: Ctf.Players.Random,
        direction: :w
      )

    Board.new(height: @grid_count, width: @grid_count, players: [p1, p2], obstacle_count: 10)
  end
end
