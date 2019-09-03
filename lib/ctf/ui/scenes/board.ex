defmodule Ctf.Scene.Board do
  use Scenic.Scene
  alias Scenic.Graph
  import Scenic.Primitives
  alias Ctf.Sprites

  @grid_count 18
  @square_size 600 / @grid_count

  @dirt_squares (for x <- 0..5, y <- 0..5 do
                   fn graph ->
                     rectangle(graph, {128, 128},
                       fill: {:image, Sprites.sprite("dirt")},
                       translate: {x * 128, y * 128}
                     )
                   end
                 end)

  @flags (for {color, idx} <- Enum.with_index(~w(red blue)a, 1) do
            &Ctf.Components.Flag.add_to_graph(&1, {color, @square_size, 0, 0}, id: {:flag, idx})
          end)

  @obstacles (for o <- 1..10 do
                fn graph ->
                  x = :rand.uniform(@grid_count - 1)
                  y = :rand.uniform(@grid_count - 1)

                  Ctf.Components.Obstacle.add_to_graph(graph, @square_size, x, y,
                    id: {:obstacle, o}
                  )
                end
              end)

  @h_grid_lines (for y <- 1..@grid_count do
                   fn graph ->
                     line(
                       graph,
                       {{0, @square_size * y}, {600, @square_size * y}},
                       id: {:h_grid, y},
                       stroke: {1, {:black, 32}}
                     )
                   end
                 end)

  @v_grid_lines (for x <- 1..@grid_count do
                   fn graph ->
                     line(
                       graph,
                       {{@square_size * x, 0}, {@square_size * x, 600}},
                       id: {:v_grid, x},
                       stroke: {1, {:black, 32}}
                     )
                   end
                 end)

  @tanks (for {color, idx} <- Enum.with_index(~w(red blue)a, 1) do
            fn graph ->
              {xoff, yoff} = Ctf.Tank.offsets(@square_size)

              Ctf.Tank.add_to_graph(graph, {color, @square_size},
                translate: {@square_size * idx + xoff, @square_size * idx + yoff},
                rotate: :math.pi() * 0.5 * Enum.random(0..3),
                id: {:player, idx}
              )
            end
          end)

  @objects @dirt_squares ++ @h_grid_lines ++ @v_grid_lines ++ @obstacles ++ @tanks ++ @flags
  @graph Enum.reduce(@objects, Graph.build(), fn f, g -> f.(g) end)

  alias Ctf.{Board, Player, Flag}
  alias Ctf.Players.Random

  def init(_arg, opts) do
    viewport = opts[:viewport]
    # IO.inspect(@stats)

    # Create a dummy board for prototyping
    f1 = %Flag{number: 1, x: 0, y: 0}
    f2 = %Flag{number: 2, x: 0, y: 0}

    p1 =
      Player.new(number: 1, flag: f1, x: 0, y: 0, health_points: 5, module: Random, direction: :e)

    p2 =
      Player.new(number: 2, flag: f2, x: 0, y: 0, health_points: 5, module: Random, direction: :w)

    board =
      Board.new(height: @grid_count, width: @grid_count, players: [p1, p2], obstacle_count: 10)

    graph = draw_board(@graph, board)

    Board.dump(board)

    {:ok, %{graph: graph, viewport: viewport, board: board}, push: graph}
  end

  defp draw_board(graph, board) do
    # Move players first
    directions = %{
      :n => 0,
      :w => 0.5,
      :s => 1,
      :e => 1.5
    }

    # Position the players
    graph =
      Enum.reduce(board.players, graph, fn player, graph ->
        {xoff, yoff} = Ctf.Tank.offsets(@square_size)

        Graph.modify(
          graph,
          {:player, player.number},
          &update_opts(&1,
            translate: {player.y * @square_size + xoff, player.x * @square_size + yoff},
            rotate: directions[player.direction] * :math.pi()
          )
        )
      end)

    graph =
      board.obstacles
      |> Enum.with_index(1)
      |> Enum.reduce(graph, fn {obstacle, i}, graph ->
        Graph.modify(
          graph,
          {:obstacle, i},
          &Ctf.Components.Obstacle.adjust_position(&1, @square_size, obstacle.y, obstacle.x)
        )
      end)

    board.flags
    |> Enum.with_index(1)
    |> Enum.reduce(graph, fn {flag, i}, graph ->
      Graph.modify(
        graph,
        {:flag, i},
        &Ctf.Components.Flag.adjust_position(&1, @square_size, flag.y, flag.x)
      )
    end)
  end
end
