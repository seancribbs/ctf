defmodule Ctf.UI.Objects.Bullet do
  import Scenic.Primitives, only: [rectangle: 3, update_opts: 2]
  alias Ctf.UI.Sprites

  @height 34
  @width 20

  @directions %{n: 0, w: 1.5, s: 1, e: 0.5}

  def add_to_graph(graph, color, size, direction, x, y, opts) do
    defaults =
      Keyword.merge(transforms(size, direction, x, y),
        fill: fill(color)
      )

    rectangle(graph, {@width, @height}, Keyword.merge(defaults, opts))
  end

  def adjust_position(rect, size, direction, x, y) do
    update_opts(rect, transforms(size, direction, x, y))
  end

  defp transforms(size, direction, x, y) do
    scale_factor = 0.35 * size / @height
    bullet_size = @width * scale_factor
    bullet_pad = (size - bullet_size) / 2
    xoff = (@width - bullet_size) / 2 - bullet_pad
    yoff = (@height - 0.35 * size) / 2

    [
      pin: {@width / 2.0, @height / 2.0},
      scale: scale_factor,
      translate: {x * size - xoff, y * size - yoff},
      rotate: @directions[direction] * :math.pi()
    ]
  end

  defp fill(:blue) do
    {:image, Sprites.sprite("bulletBlueSilver_outline")}
  end

  defp fill(:red) do
    {:image, Sprites.sprite("bulletRedSilver_outline")}
  end
end
