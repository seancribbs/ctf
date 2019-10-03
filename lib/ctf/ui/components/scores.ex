defmodule Ctf.UI.Components.Scores do
  import Scenic.Primitives
  alias Ctf.UI.Fonts

  def add_to_graph(graph, board, opts) do
    graph
    |> background(opts)
    |> player(board, 1, opts)
    |> player(board, 2, opts)
  end

  defp background(graph, opts) do
    bgopts =
      Keyword.merge(
        [fill: :black, id: {:scores, :background}],
        Keyword.take(opts, [:translate])
      )

    rectangle(graph, {opts[:width], opts[:height]}, bgopts)
  end

  defp player(graph, board, number, opts) do
    player = Enum.find(board.players, &(&1.number == number))

    translate = Scenic.Math.Vector2.add(opts[:translate], {(number - 1) * (opts[:width] / 2) + 20, 0})

    color =
      if number == 1 do
        :orange_red
      else
        :light_sky_blue
      end

    graph
    |> text("#{player.name}       #{player.health_points}",
      fill: color,
      font: :roboto_mono,
      font_size: 20,
      id: {:scores, number},
    translate: translate,
    text_align: :left_top
    )
  end
end
