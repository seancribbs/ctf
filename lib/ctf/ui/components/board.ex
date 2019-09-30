defmodule Ctf.UI.Components.Board do
  use Scenic.Component
  alias Scenic.Graph
  import Scenic.Primitives
  alias Ctf.UI.Sprites
  alias Ctf.UI.Objects, as: O

  @board_px 600

  # assumes 20x20, but is only for initial graph state
  @default_square_size 30

  @dirt_squares (for x <- 0..5, y <- 0..5 do
                   fn graph ->
                     rectangle(graph, {128, 128},
                       fill: {:image, Sprites.sprite("dirt")},
                       translate: {x * 120 - 8, y * 120 - 8},
                       scale: 0.9375
                     )
                   end
                 end)

  @flags (for {color, idx} <- Enum.with_index(~w(red blue)a, 1) do
            &O.Flag.add_to_graph(&1, {color, @default_square_size, 0, 0}, id: {:flag, idx})
          end)

  @tanks (for {color, idx} <- Enum.with_index(~w(red blue)a, 1) do
            &O.Tank.add_to_graph(&1, color, @default_square_size, :n, 0, 0, id: {:player, idx})
          end)

  @init_graph Enum.reduce(@dirt_squares ++ @tanks ++ @flags, Graph.build(), fn f, g -> f.(g) end)

  @impl true
  def verify(%Ctf.Board{} = b) do
    {:ok, b}
  end

  def verify(_other) do
    "must be a Ctf.Board struct"
  end

  @impl true
  def init(board, _opts) do
    graph =
      @init_graph
      |> add_grid(board)
      |> add_obstacles(board)
      |> position_objects(board)

    {:ok, %{graph: graph, board: board}, push: graph}
  end

  defp add_grid(graph, board) do
    ss = square_size(board)

    h_grid_lines =
      for y <- 1..board.height do
        fn graph ->
          line(
            graph,
            {{0, ss * y}, {600, ss * y}},
            id: {:h_grid, y},
            stroke: {1, {:black, 32}}
          )
        end
      end

    v_grid_lines =
      for x <- 1..board.width do
        fn graph ->
          line(
            graph,
            {{ss * x, 0}, {ss * x, 600}},
            id: {:v_grid, x},
            stroke: {1, {:black, 32}}
          )
        end
      end

    Enum.reduce(h_grid_lines ++ v_grid_lines, graph, fn f, g -> f.(g) end)
  end

  defp add_obstacles(graph, board) do
    ss = square_size(board)

    board.obstacles
    |> Enum.with_index(1)
    |> Enum.reduce(graph, fn {o, i}, g ->
      O.Obstacle.add_to_graph(g, ss, o.x, o.y, id: {:obstacle, i})
    end)
  end

  defp square_size(board) do
    # assume board is square for now
    @board_px / board.width
  end

  defp position_objects(graph, board) do
    ss = square_size(board)
    # Move players first
    graph =
      Enum.reduce(board.players, graph, fn player, graph ->
        Graph.modify(
          graph,
          {:player, player.number},
          &O.Tank.adjust_position(
            &1,
            ss,
            player.direction,
            player.x,
            player.y
          )
        )
      end)

    board.flags
    |> Enum.with_index(1)
    |> Enum.reduce(graph, fn {flag, i}, graph ->
      Graph.modify(
        graph,
        {:flag, i},
        &O.Flag.adjust_position(&1, ss, flag.x, flag.y)
      )
    end)
  end
end
