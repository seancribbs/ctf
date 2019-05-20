defmodule Ctf.Scene.Board do
  use Scenic.Scene
  alias Scenic.{Graph, ViewPort}
  import Scenic.Primitives
  alias Ctf.Sprites

  @dirt_squares (for x <- 0..5, y <- 0..5 do
                   fn graph ->
                     rectangle(graph, {128, 128},
                       fill: {:image, Sprites.sprite("dirt")},
                       translate: {x * 128, y * 128}
                     )
                   end
                 end)

  @graph Enum.reduce(@dirt_squares, Graph.build(), fn f, g -> f.(g) end)


  def init(_arg, opts) do
    viewport = opts[:viewport]
    push_graph(@graph)
    {:ok, %{graph: @graph, viewport: viewport}}
  end

  def handle_input({:key, {" ", :release, _}}, _context, state) do
    IO.puts("SWITCHING BACK")
    ViewPort.set_root(state.viewport, Ctf.Scene.Home)
    {:noreply, state}
  end

  def handle_input(_, _, state) do
    {:noreply, state}
  end
end
