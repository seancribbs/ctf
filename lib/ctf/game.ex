defmodule Ctf.Game do
  @enforce_keys [:board]
  defstruct board: nil

  @type t() :: %__MODULE__{
          board: Board.t
  }

  alias Ctf.{Board, Player}

  def new(players, board_height \\ 20, board_width \\ 20, obstacle_count \\ 25) do
    %__MODULE__{
      board: Board.new(
        height: board_height,
        width: board_width,
        players: players,
        obstacle_count: obstacle_count
      )
    }
  end

  def play(%__MODULE__{} = game) do
    perform_game_loop(:ok, game, [])
  end

  defp perform_game_loop({:win, player_number}, _, boards), do: {player_number, boards}
  defp perform_game_loop(:ok, game, boards) do
    {move_lists, players} =
      Enum.reduce(game.board.players, {[], []}, fn player, {move_lists, players} ->
        {move_list, new_state} = apply(player.module, :turn, [game, player.state])
        {move_lists ++ [move_list], players ++ [%Player{player | state: new_state}]}
      end)

    {status, game, new_boards} =
      lockstep(move_lists, 3)
      |> advance_steps(%__MODULE__{game | board: %{game.board | players: players}}, [])

    perform_game_loop(status, game, boards ++ new_boards)
  end

  defp advance_steps([], game, new_boards), do: {:ok, game, new_boards}
  defp advance_steps([{p1_move, p2_move} | rest], game, new_boards) do



    have to perform fires first in same lockstep
    have to perform moves in order to prevent timing problems
    -> ^, has to be performed in opposite order in same lockstep
    clear collisions
    not only need to detect collision on move, but also record if someone else landed in the space in the
      same frame as the one being collided in


    Enum.zip([p1_move, p2_move], game.board.players)
    |> create_frame(game, :ok, [game])
    |> validate_board()
  end

  defp create_frame(:ok, [], _, new_game), do: {:ok, new_game}
  defp create_frame(:error, [], original_game, _), do: {:error, original_game}
  defp create_frame({:win, player}, [], _, new_game), do: {:win, player, new_game}
  defp create_frame(:draw, [], _, new_game), do: {:draw, new_game}
  defp create_frame(:ok, [{{:fire, count}, %Player{direction: direction, x: x, y: y} = player} | rest], original_game, status, new_games) do
    [newest_game | rest_games] = new_games

    case detect_collsion(player, newest_game, {x, y}, count) do
      {:player, %Player{x: hit_x, y: hit_y, health_points: health_points, number: number} = hit_player} ->
        new_hit_player = %Player{hit_player | health_points: health_points - 1}
        updated_game =
          %Game{newest_game |
            board: %Board{board |
              players: List.replace_at(
                newest_game.board.players,
                number - 1,
                new_hit_player
              ),
              collisions: [{:fire, {hit_x, hit_y}} | (newest_game.board.collisions || [])],
              cells: update_in(newest_game.board.cells, [hit_x, hit_y], new_hit_player)
            }
          }

        updated_games =
          cond do
            # no other fires in this frame, as we order fires first
            is_nil(newest_game.board.collisions) ->
              [updated_game | new_games]
            # other fires in this frame, so just update the same fire frame
            true ->
              [updated_game | rest_games]
          end

        case {new_hit_player.health_points, status} do
          {0, :ok} -> create_frame(rest, original_game, {:win, player}, updated_games)
          {0, {:win, _}} -> create_frame(rest, original_game, :draw, updated_games)
          _ -> create_frame(rest, original_game, status, updated_games)
        end
      _ ->
        # no new frames
        create_frame(rest, original_game, status, new_games)
    end
  end
  defp create_frame([{{direction, 1}, %Player{number: number, x: x, y: y} = player} | rest], original_game, status, new_games) when direction in [:clockwise, :counterclockwise] do
    [newest_game | rest_games] = new_games
    new_rotated_player = Player.rotate(player, direction)

    updated_game =
      %Game{newest_game |
        board: %Board{board |
          players: List.replace_at(
            newest_game.board.players,
            number - 1,
            new_rotated_player
          ),
          cells: update_in(game.board.cells, [x, y], new_rotated_player)
        }
      }

    updated_games =
      if !is_nil(newest_game.board.collisions) && elem(Enum.at(newest_game.board.collisions, 0), 0) == :fire do
        [updated_game | new_games]
      else
        [updated_game | rest_games]
      end

    create_frame(rest, original_game, status, updated_games)
  end
  defp create_frame([{{:move, 1}, %Player{number: number, x: x, y: y, health_points: health_points} = player} | rest], original_game, status, new_games) do 
    [newest_game | _] = new_games

    case detect_collsion(player, newest_game, {x, y}, 1) do
      {:player, %Player{x: hit_x, y: hit_y, health_points: health_points, number: number} = hit_player} ->
        reduce both players
        need to make sure this only happens once
      obstacle when obstacle in [{:edge, _}, {:obstacle, _}] ->
        {type, _} = obstacle
        {obstacle_x, obstacle_y} = case obstacle do
          {:edge, {edge_x, edge_y}} -> {edge_x, edge_y}
          {:obstacle, %Obstacle{x: obstacle_x, y: obstacle_y}} -> {obstacle_x, obstacle_y}
        end

        new_player = %Player{player | health_points: health_points - 1}
        updated_game =
          %Game{newest_game |
            board: %Board{board |
              players: List.replace_at(
                newest_game.board.players,
                number - 1,
                new_player
              ),
              collisions: [{type, {obstacle_x, obstacle_y}} | (newest_game.board.collisions || [])],
              cells: update_in(newest_game.board.cells, [hit_x, hit_y], new_player)
            }
          }

        updated_games =
          if !is_nil(newest_game.board.collisions) && elem(Enum.at(newest_game.board.collisions, 0), 0) == :fire do
            [updated_game | new_games]
          else
            [updated_game | rest_games]
          end

        other_player = Enum.filter(newest_game.board.players, fn prospect -> prospect != new_player end)

        case {new_player.health_points, status} do
          {0, :ok} -> create_frame(rest, original_game, {:win, prospect}, updated_games)
          {0, {:win, _}} -> create_frame(rest, original_game, :draw, updated_games)
          _ -> create_frame(rest, original_game, status, updated_games)
        end
      {:flag  %Flag{x: flag_x, y: flag_y, number: flag_number}} ->
        new_player = %Player{player | x: flag_x, y: flag_y}
        updated_game =
          %Game{newest_game |
            board: %Board{board |
              players: List.replace_at(
                newest_game.board.players,
                number - 1,
                new_player
              ),
              collisions: [{type, {obstacle_x, obstacle_y}} | (newest_game.board.collisions || [])],
              cells: update_in(newest_game.board.cells, [hit_x, hit_y], new_player)
            }
          }

      _ -> nil
    else
           if not other player's flag, no collision

      case get_in(game.board.cells, [new_cell_x, new_cell_y]) do
        %Player{} = p -> {:player, p}
        %Obstacle{} = o -> {:obstacle, o}
        %Flag{} = f -> {:flag, f}
        nil -> detect_collsion(player, game, {new_cell_x, new_cell_y}, count - 1)

        new_hit_player = %Player{hit_player | health_points: health_points - 1}
        updated_game =
          %Game{newest_game |
            board: %Board{board |
              players: List.replace_at(
                newest_game.board.players,
                number - 1,
                new_hit_player
              ),
              collisions: [{:fire, {hit_x, hit_y}} | (newest_game.board.collisions || [])],
              cells: update_in(newest_game.board.cells, [hit_x, hit_y], new_hit_player)
            }
          }

        updated_games =
          cond do
            # no other fires in this frame, as we order fires first
            is_nil(newest_game.board.collisions) ->
              [updated_game | new_games]
            # other fires in this frame, so just update the same fire frame
            true ->
              [updated_game | rest_games]
          end

        case {new_hit_player.health_points, status} do
          {0, :ok} -> create_frame(rest, original_game, {:win, player}, updated_games)
          {0, {:win, _}} -> create_frame(rest, original_game, :draw, updated_games)
          _ -> create_frame(rest, original_game, status, updated_games)
        end
      _ ->
        # no new frames
        create_frame(rest, original_game, status, new_games)

  end


  defp get_newest_game(original_game, new_games) do
    cond do
      [] == new_games -> original_game
      [newest_game | _] = new_games -> newest_game 
    end
  end

  defp detect_collsion(_, _, _, 0), do: nil
  defp detect_collsion(player, game, {x, y}, count) do
    {displace_x, displace_y} = get_displacement(player)
    new_cell_x = displace_x * count + x 
    new_cell_y = displace_y * count + y

    cond do
      new_cell_x >= game.board.width ->
        {:edge, {game.board.width, new_cell_y}}
      new_cell_y >= game.board.height ->
        {:edge, {new_cell_x, game.board.height}}
      new_cell_x < 0 ->
        {:edge, {-1, new_cell_y}}
      new_cell_y < 0 ->
        {:edge, {new_cell_x, -1}}
      true ->
        case get_in(game.board.cells, [new_cell_x, new_cell_y]) do
          %Player{} = p -> {:player, p}
          %Obstacle{} = o -> {:obstacle, o}
          %Flag{} = f -> {:flag, f}
          nil -> detect_collsion(player, game, {new_cell_x, new_cell_y}, count - 1)
        end
    end
  end

  defp lockstep(move_lists, count) do
    [p1_moves, p2_moves] =
      Enum.map(move_lists, fn moves -> first(moves, [], count) end)

    Enum.zip([p1_moves, p2_moves]) ++
      cond do
        length(p1_moves) > length(p2_moves) ->
          p1_moves
          |> Enum.drop(length(p2_moves))
          |> Enum.map(fn move -> {move, nil} end)
        length(p1_moves) < length(p2_moves) ->
          p2_moves
          |> Enum.drop(length(p1_moves))
          |> Enum.map(fn move -> {nil, move} end)
        true -> []
      end
  end

  defp first([], acc, _), do: Enum.reverse(acc)
  defp first(_, acc, 0), do: Enum.reverse(acc)

  defp first([{:fire, count} | rest], acc, remaining) do
    # slurp all the fires into one immediate firing turn
    first(rest, [{:fire, min(remaining, count)} | acc], max(0, remaining - count))
  end
  defp first([{_, 1} = move | rest], acc, remaining) do
    first(rest, [move | acc], remaining - 1)
  end
  defp first([{action, count} | rest], acc, remaining) do
    first([{action, count - 1}] ++ rest, [{action, 1} | acc], remaining - 1)
  end
end
