defmodule Ctf.Components.Obstacle do
  import Scenic.Primitives, only: [rectangle: 3, update_opts: 2]
  alias Ctf.Sprites

  def add_to_graph(graph, square_size, x, y, opts) do
    defaults =
      Keyword.merge(transforms(square_size, x, y),
        fill: {:image, Sprites.sprite("treeLarge")},
        rotate: :math.pi() * 2 * :rand.uniform()
      )

    rectangle(graph, {98, 107}, Keyword.merge(defaults, opts))
  end

  def adjust_position(rect, square_size, x, y) do
    update_opts(rect, transforms(square_size, x, y))
  end

  defp transforms(square_size, x, y) do
    obstacle_scale = square_size / 107
    obstacle_size = 98 * obstacle_scale
    obstacle_pad = (square_size - obstacle_size) / 2
    obstacle_x_offset = (98 - obstacle_size) / 2 - obstacle_pad
    obstacle_y_offset = (107 - square_size) / 2

    translate = {
      x * square_size - obstacle_x_offset,
      y * square_size - obstacle_y_offset
    }

    [scale: obstacle_scale, translate: translate]
  end
end
