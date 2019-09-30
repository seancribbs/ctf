defmodule Ctf.UI.Objects.Flag do
  import Scenic.Primitives, only: [rectangle: 3, update_opts: 2]
  alias Ctf.UI.Sprites

  @size 70

  def add_to_graph(graph, {color, square_size, x, y}, opts) do
    defaults =
      Keyword.merge(transforms(square_size, x, y),
        fill: {:image, Sprites.sprite(sprite_name(color))}
      )

    rectangle(graph, {@size, @size}, Keyword.merge(defaults, opts))
  end

  def adjust_position(rect, square_size, x, y) do
    update_opts(rect, transforms(square_size, x, y))
  end

  defp transforms(square_size, x, y) do
    scale = square_size / @size
    offset = (@size - square_size) / 2

    [
      translate: {square_size * x - offset, square_size * y - offset},
      scale: scale
    ]
  end

  defp sprite_name(:blue), do: "flagBlue"
  defp sprite_name(:red), do: "flagRed"
end
