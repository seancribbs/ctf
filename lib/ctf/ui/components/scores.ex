defmodule Ctf.UI.Components.Scores do
  import Scenic.Primitives
  alias Scenic.Graph

  def add_to_graph(graph, board, opts) do
    graph
    |> background(opts)
    |> player(board, 1, opts)
    |> player(board, 2, opts)
  end

  def modify(graph, board) do
    graph
    |> Graph.modify({:scores, 1}, &text(&1, player_text(get_player(board, 1))))
    |> Graph.modify({:scores, 2}, &text(&1, player_text(get_player(board, 2))))
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
    player = get_player(board, number)

    translate =
      Scenic.Math.Vector2.add(opts[:translate], {(number - 1) * (opts[:width] / 2) + 20, 0})

    color =
      if number == 1 do
        :orange_red
      else
        :light_sky_blue
      end

    graph
    |> text(player_text(player),
      fill: color,
      font: :roboto_mono,
      font_size: 20,
      id: {:scores, number},
      translate: translate,
      text_align: :left_top
    )
  end

  defp player_text(player) do
    "#{player.name}       #{player.health_points}"
  end

  defp get_player(board, number) do
    Enum.find(board.players, &(&1.number == number))
  end
end
