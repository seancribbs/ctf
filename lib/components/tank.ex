defmodule Ctf.Tank do
  use Scenic.Component, has_children: false
  import Ctf.Sprites
  import Scenic.Primitives
  alias Scenic.Graph

  @height 15 + 83
  @padding 3
  @width 78

  @impl true
  def verify(any = {color, size}) when is_atom(color) and is_number(size) do
    {:ok, any}
  end

  @impl true
  def init({color, size}, _opts) do
    scale_factor = size / (@height + 2 * @padding)

    graph =
      Graph.build(scale: scale_factor)
      |> base(color)
      |> turret(color)

    {:ok, color, push: graph}
  end

  def offsets(size) do
    scale_factor = size / (@height + 2 * @padding)
    {((@height - @width) / 2 + @padding) * scale_factor, @padding * scale_factor}
  end

  defp base(graph, :red) do
    base(graph, "tankRed_outline")
  end

  defp base(graph, :blue) do
    base(graph, "tankBlue_outline")
  end

  defp base(graph, sprite_name) when is_binary(sprite_name) do
    rrect(graph, {83, 78, 5},
      fill: {:image, sprite(sprite_name)},
      pin: {83 / 2.0, (78 + 15) / 2.0},
      translate: {0, 15}
    )
  end

  defp turret(graph, :red) do
    turret(graph, "barrelRed_outline")
  end

  defp turret(graph, :blue) do
    turret(graph, "barrelBlue_outline")
  end

  defp turret(graph, sprite_name) when is_binary(sprite_name) do
    rrect(graph, {24, 58, 5},
      fill: {:image, sprite(sprite_name)},
      pin: {12, 58},
      translate: {29, 0})
  end
end
