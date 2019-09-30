defmodule Ctf.UI.Scenes.Game do
  use Scenic.Scene
  alias Scenic.Graph

  alias Ctf.UI.Components, as: C
  alias Ctf.{Board, Flag, Player}

  @graph Graph.build()

  @grid_count 20

  def init(_, opts) do
    viewport = opts[:viewport]
    board = dummy_board()

    graph =
      @graph
      |> C.Board.add_to_graph(board, id: :board)
      |> C.Scores.add_to_graph(board, width: 601, height: 50, translate: {0, 600})

    {:ok, %{graph: graph, viewport: viewport}, push: graph}
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
