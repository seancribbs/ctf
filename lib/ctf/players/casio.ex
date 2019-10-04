defmodule Ctf.Players.CasioJuarez do
  @behaviour Ctf.Player
  alias Ctf.{Game, Player, Board, Flag}

  @moves [:fire, :clockwise, :counterclockwise, :move]

  def name() do
    "Casio Juarez Robot"
  end

  @impl Ctf.Player
  def turn(game = %Game{}, player = %Player{}, _state) do
    # {accumulate_turns([], game, player, 3), Enum.random(1..10000)}

    coords = List.flatten(for w <- (0..(game.board.width - 1)), do: (for h <- (0..(game.board.height - 1)), do: {w, h}))

    items = Enum.map(coords, fn ({xx, yy}) -> {{xx, yy}, Board.get_cell_contents(game.board, xx, yy)} end)

    pn = player.number

    other_flags = Enum.filter(items, fn ({{_, _}, contents}) -> match?([%Flag{}], contents) and not (hd(contents).number == pn) end)

    num_flags = length(other_flags)

    {{ftg_x, ftg_y}, flag_to_get} = hd(other_flags)

    delta_x = player.x - ftg_x
    delta_y = player.y - ftg_y

    np_mv = Player.move(player)
    np_cw = Player.move(Player.rotate(player, :clockwise))
    np_ccw = Player.move(Player.rotate(player, :counterclockwise))

    cond do
      (abs(np_mv.x - ftg_x) < abs(delta_x)) or (abs(np_mv.y - ftg_y) < abs(delta_y)) ->
        {[move: 1, fire: 1, fire: 1], nil}
      (abs(np_cw.x - ftg_x) < abs(delta_x)) or (abs(np_cw.y - ftg_y) < abs(delta_y)) ->
        {[clockwise: 1, move: 1, fire: 1], nil}
      (abs(np_ccw.x - ftg_x) < abs(delta_x)) or (abs(np_ccw.y - ftg_y) < abs(delta_y)) ->
        {[counterclockwise: 1, move: 1, fire: 1], nil}
      true ->
        {[counterclockwise: 1, counterclockwise: 1, move: 1], nil}
    end
  end

  defp accumulate_turns(acc, _game, _player, 0) do
    Enum.reverse(acc)
  end

  defp accumulate_turns(acc, game, %Player{x: x, y: y} = player, remaining) do
    {displace_x, displace_y} = Player.get_displacement(player)
    new_cell_x = displace_x + x
    new_cell_y = displace_y + y

    contents = Board.get_cell_contents(game.board, new_cell_x, new_cell_y)
    cond do
      # go forward if you can
      contents == [] and new_cell_x < game.board.width and new_cell_y < game.board.height and new_cell_x >= 0 and new_cell_y >= 0 ->
        new_player = Player.move(player)
        accumulate_turns([{:move, 1} | acc], game, new_player, remaining - 1)
      # who knows, we might win here
      match?([%Flag{}], contents) ->
        new_player = Player.move(player)
        accumulate_turns([{:move, 1} | acc], game, new_player, remaining - 1)
      # otherwise turn clockwise (until you can eventually move forward)
      true ->
        new_player = Player.rotate(player, :clockwise)
        accumulate_turns([{:clockwise, 1} | acc], game, new_player, remaining - 1)
    end
  end
end
