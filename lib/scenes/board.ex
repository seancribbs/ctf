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

  @obstacle_scale @square_size / 107
  @obstacle_size 98 * @obstacle_scale
  @obstacle_pad (@square_size - @obstacle_size) / 2
  @obstacle_x_offset (98 - @obstacle_size) / 2 - @obstacle_pad
  @obstacle_y_offset (107 - @square_size) / 2

  @stats %{
    count: @grid_count,
    size: @square_size,
    obstacle_scale: @obstacle_scale,
    obstacle_width: @obstacle_size,
    obstacle_offset: @obstacle_pad
  }

  @obstacles (for o <- 1..10 do
                fn graph ->
                  x = :rand.uniform(@grid_count - 1)
                  y = :rand.uniform(@grid_count - 1)

                  translate = {
                    x * @square_size - @obstacle_x_offset,
                    y * @square_size - @obstacle_y_offset
                  }

                  rectangle(graph, {98, 107},
                    fill: {:image, Sprites.sprite("treeLarge")},
                    id: {:obstacle, o},
                    translate: translate,
                    scale: @obstacle_scale,
                    rotate: :math.pi() * 2 * :rand.uniform()
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

  @tanks (for {color, idx} <- Enum.with_index(~w(blue red)a, 1) do
            fn graph ->
              {xoff, yoff} = Ctf.Tank.offsets(@square_size)

              Ctf.Tank.add_to_graph(graph, {color, @square_size},
                translate: {(@square_size * idx) + xoff, (@square_size * idx) + yoff},
                rotate: :math.pi() * 0.5 * Enum.random(0..3),
                id: color
              )
            end
          end)

  @objects @dirt_squares ++ @h_grid_lines ++ @v_grid_lines ++ @obstacles ++ @tanks
  @graph Enum.reduce(@objects, Graph.build(), fn f, g -> f.(g) end)

  def init(_arg, opts) do
    viewport = opts[:viewport]
    IO.inspect(@stats)
    {:ok, %{graph: @graph, viewport: viewport}, push: @graph}
  end

  # def handle_input({:key, {" ", :release, _}}, _context, state) do
  #   IO.puts("SWITCHING BACK")
  #   ViewPort.set_root(state.viewport, Ctf.Scene.Home, nil)
  #   {:noreply, state}
  # end

  # def handle_input(_, _, state) do
  #   {:noreply, state}
  # end
end
