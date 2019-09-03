defmodule Ctf.Components.Flag do
  import Scenic.Primitives, only: [rectangle: 3, update_opts: 2]
  alias Ctf.Sprites

  @size 70

  def add_to_graph(graph, {color, square_size, x, y}, opts) do
    defaults =
      Keyword.merge(transforms(square_size, x, y),
        fill: {:image, Sprites.sprite(sprite_name(color))}
      )

    rectangle(graph, {70, 70}, Keyword.merge(defaults, opts))
  end

  def adjust_position(rect, square_size, x, y) do
    update_opts(rect, transforms(square_size, x, y))
  end

  defp transforms(square_size, x, y) do
    [
      translate: {square_size * x, square_size * y},
      scale: square_size / @size
    ]
  end

  defp sprite_name(:blue), do: "flagBlue"
  defp sprite_name(:red), do: "flagRed"
end
