defmodule Ctf.Components.Tank do
  import Ctf.Sprites
  import Scenic.Primitives

  @height 15 + 83
  @padding 3
  @width 78
  @directions %{n: 0, w: 0.5, s: 1, e: 1.5}

  def add_to_graph(graph, color, size, direction, x, y, opts) do
    defaults = transforms(size, direction, x, y)

    group(
      graph,
      fn group ->
        group
        |> base(color)
        |> turret(color)
      end,
      Keyword.merge(defaults, opts)
    )
  end

  def adjust_position(tank, size, direction, x, y) do
    update_opts(tank, transforms(size, direction, x, y))
  end

  defp transforms(size, direction, x, y) do
    scale_factor = size / @height
    tank_size = @width * scale_factor
    tank_pad = (size - tank_size) / 2
    xoff = (@width - tank_size) / 2 - tank_pad
    yoff = (@height - size) / 2

    [
      pin: {@width / 2.0, @height / 2.0},
      scale: scale_factor,
      translate: {x * size - xoff, y * size - yoff},
      rotate: @directions[direction] * :math.pi()
    ]
  end

  defp base(graph, :red) do
    base(graph, "tankRed_outline")
  end

  defp base(graph, :blue) do
    base(graph, "tankBlue_outline")
  end

  defp base(graph, sprite_name) when is_binary(sprite_name) do
    rect(graph, {83, 78},
      fill: {:image, sprite(sprite_name)},
#      pin: {83 / 2.0, (78 + 15) / 2.0},
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
    rect(graph, {24, 58},
      fill: {:image, sprite(sprite_name)},
#      pin: {12, 58},
      translate: {29, 0}
    )
  end
end
