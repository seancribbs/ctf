defmodule Ctf.Scene.Home do
  use Scenic.Scene

  alias Scenic.{Graph, ViewPort}

  import Scenic.Primitives
  # import Scenic.Components

  @title "* WELCOME TO CTF *"

  @note """
  PROGRAM YOUR ROBOT TANK TO

  1    NAVIGATE THE FIELD
  2   CAPTURE THE ENEMY FLAG
  3   RETURN IT TO YOUR FLAG
  4   DEFEND YOUR FLAG
  5   DESTROY YOUR ENEMY
  """

  @prompt ">> PRESS SPACE TO BEGIN BATTLE <<"

  @graph Graph.build(font: Ctf.Fonts.font("retro-gaming"), font_size: 24)
         |> text(@title, translate: {350, 60}, text_align: :center, fill: :yellow)
         |> text(@note, translate: {175, 150})
         |> text(@prompt, translate: {350, 550}, text_align: :center, fill: :cornflower_blue)

  # ============================================================================
  # setup
  # --------------------------------------------------------
  def init(_arg, opts) do
    viewport = opts[:viewport]

    {:ok, %{graph: @graph, viewport: viewport}, push: @graph}
  end

  def handle_input({:key, {" ", :release, _}}, _context, state) do
    # TODO: Switch scenes
    IO.puts("GAME BEGINS!")
    ViewPort.set_root(state.viewport, Ctf.Scene.Board)
    {:noreply, state}
  end

  def handle_input(_, _, state) do
    {:noreply, state}
  end
end
