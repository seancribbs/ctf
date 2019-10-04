defmodule Ctf.Players.Jeremy do
  @behaviour Ctf.Player
  alias Ctf.{Player, Game, Board, Flag}

  # all I do is drive around and avoid obstacles randomly

  @moves [:fire, :clockwise, :counterclockwise, :move]

  def name() do
    "Jeremy (Obstacle Avoider) Tank #{trunc(:rand.uniform() * 100)}"
  end

  @impl Ctf.Player

  def turn(game = %Game{}, player = %Player{number: 2}, nil) do
    case player.direction do
      :n ->
        {accumulate_turns([{:counterclockwise, 1}], game, player, 2), :turned}

      :s ->
        {accumulate_turns([{:clockwise, 1}], game, player, 2), :turned}

      :w ->
        {accumulate_turns([], game, player, 3), :turned}

      :e ->
        {accumulate_turns(
           [{:clockwise, 2}],
           game,
           player,
           1
         ), :turned}
    end
  end

  def turn(game = %Game{}, player = %Player{number: 1}, nil) do
    case player.direction do
      :n ->
        {accumulate_turns([{:clockwise, 1}], game, player, 2), :turned}

      :s ->
        {accumulate_turns([{:counterclockwise, 1}], game, player, 2), :turned}

      :e ->
        {accumulate_turns([], game, player, 3), :turned}

      :w ->
        {accumulate_turns(
           [{:clockwise, 2}],
           game,
           player,
           1
         ), :turned}
    end
  end

  def turn(game = %Game{}, player = %Player{}, _) do
    state_token = Enum.random(1..10000)
    {accumulate_turns([], game, player, 3), state_token}
  end

  defp accumulate_turns(acc, game, player, remaining, last \\ nil)

  defp accumulate_turns(acc, _game, _player, 0, last) do
    Enum.reverse(acc)
  end

  defp accumulate_turns(acc, game, %Player{x: x, y: y} = player, remaining, last) do
    %{x: flag_x, y: flag_y} = Enum.find(game.board.flags, &(&1.number != player.number))

    {displace_x, displace_y} = Player.get_displacement(player)
    new_cell_x = displace_x + x
    new_cell_y = displace_y + y

    contents = Board.get_cell_contents(game.board, new_cell_x, new_cell_y)

    cond do
      # go forward if you can
      contents == [] and new_cell_x < game.board.width and new_cell_y < game.board.height and
        new_cell_x >= 0 and new_cell_y >= 0 ->
        if(last == :avoiding) do
          new_player = Player.move(player)
          accumulate_turns([{:move, 1} | acc], game, new_player, remaining - 1)
        else
          {action, new_player} = seek_flag({flag_x, flag_y}, player)
          accumulate_turns([action | acc], game, new_player, remaining - 1)
        end

      # who knows, we might win here
      match?([%Flag{}], contents) ->
        new_player = Player.move(player)
        accumulate_turns([{:move, 1} | acc], game, new_player, remaining - 1)

      # otherwise turn clockwise (until you can eventually move forward)
      true ->
        new_player = Player.rotate(player, Enum.random([:clockwise, :counterclockwise]))
        accumulate_turns([{:clockwise, 1} | acc], game, new_player, remaining - 1, :avoiding)
    end
  end

  defp seek_flag({flag_x, flag_y}, %Player{direction: dir, x: player_x, y: player_y} = player) do
    cond do
      flag_y < player_y && dir == :n ->
        {{:move, 1}, Player.move(player)}

      flag_y == player_y && dir == :n ->
        {{:counterclockwise, 1}, Player.rotate(player, :clockwise)}

      flag_y == player_y && dir == :s ->
        {{:clockwise, 1}, Player.rotate(player, :counterclockwise)}

      flag_x < player_x && dir == :w ->
        {{:move, 1}, Player.move(player)}

      flag_x == player_x && dir == :w ->
        {{:counterclockwise, 1}, Player.rotate(player, :counterclockwise)}

      flag_x == player_x && dir == :e ->
        {{:clockwise, 1}, Player.rotate(player, :clockwise)}

      # flag_x > player_x && dir == :s -> Player.move(player)
      # flag_y > player_y && dir == :e -> Player.move(player)
      # flag_y < player_y && dir == :w -> Player.move(player)
      # flag_x < player_x && dir == :e -> Player.rotate(player, :clockwise)
      # flag_x < player_x && dir == :w -> Player.rotate(player, :counterclockwise)
      # flag_x > player_x && dir == :e -> Player.rotate(player, :counterclockwise)
      # flag_x > player_x && dir == :w -> Player.rotate(player, :clockwise)
      # flag_y > player_y && dir == :n -> Player.rotate(player, :clockwise)
      # flag_y > player_y && dir == :s -> Player.rotate(player, :counterclockwise)
      # flag_y < player_y && dir == :n -> Player.rotate(player, :counterclockwise)
      # flag_y < player_y && dir == :s -> Player.rotate(player, :clockwise)
      true ->
        {{:move, 1}, Player.move(player)}
    end
  end
end
