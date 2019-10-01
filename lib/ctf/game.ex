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
    |> create_frame(:ok, [game])
    |> validate_board()
  end

  defp create_frame([], status, frames) do
    # reverse and return all but final frame
    [initial_game | rest] = Enum.reverse(frames)
    {:ok, rest}
  end
  defp create_frame(status, [{{:fire, count}, %Player{direction: direction, x: x, y: y} = player} | rest_steps], frames) do
    [newest_frame | rest_frames] = frames

    case detect_collision(player, newest_frame, {x, y}, count) do
      {:player, %Player{health_points: health_points, number: number} = hit_player} ->
        new_hit_player = %Player{hit_player | health_points: health_points - 1}
        updated_frame =
          %Game{newest_frame |
            board: %Board{newest_frame.board|
              players: List.replace_at(
                newest_frame.board.players,
                number - 1,
                new_hit_player
              ),
              events: [{:fire, {x, y}, hit_player} | (newest_frame.board.events || [])]
            }
          }

        updated_frames =
          cond do
            # no other fires in this frame, as we order fires first
            newest_frame.board.events == [] ->
              [updated_frame | frames]
            # other fires in this frame, so just update the same fire frame
            true ->
              [updated_frame | rest_frames]
          end

        case {new_hit_player.health_points, status} do
          {0, :ok} -> create_frame({:win, player}, rest_steps, updated_frames)
          {0, {:win, _}} -> create_frame(:draw, rest_steps, :draw, updated_frames)
          _ -> create_frame(status, rest_steps, updated_frames)
        end
      # Flags, Obstacles, Edges
      {_, barrier} ->
        updated_frame =
          %Game{newest_frame |
            board: %Board{newest_frame.board |
              events: [{:fire, {x, y}, barrier} | (newest_frame.board.events || [])]
            }
          }

        updated_frames =
          cond do
            # no other fires in this frame, as we order fires first
            newest_frame.board.events == [] ->
              [updated_frame | new_frames]
            # other fires in this frame, so just update the same fire frame
            true ->
              [updated_frame | rest_frames]
          end

        create_frame(status, rest_steps, updated_frames)
    end
  end
  defp create_frame(status, [{{direction, 1}, %Player{number: number, x: x, y: y} = player} | rest_steps], frames) when direction in [:clockwise, :counterclockwise] do
    [newest_frame | rest_frames] = frames 
    new_rotated_player = Player.rotate(player, direction)

    updated_frame =
      %Game{newest_frame |
        board: %Board{newest_frame.board|
          players: List.replace_at(
            newest_frame.board.players,
            number - 1,
            new_rotated_player
          ),
        }
      }

    updated_frames =
      if !is_nil(newest_frame.board.events) && elem(Enum.at(newest_frame.board.events, 0), 0) == :fire do
        [updated_frame | frames]
      else
        [updated_frame | rest_frames]
      end

    create_frame(status, rest_steps, updated_frames)
  end
  defp create_frame(status, [{{:move, 1}, %Player{number: number, x: x, y: y, health_points: health_points} = player} | rest_steps], frames) do 
    [newest_frame | rest_frames] = frames

    case detect_collision(player, newest_frame, {x, y}, 1) do
      {:player, %Player{x: hit_x, y: hit_y, health_points: health_points, number: number} = hit_player} ->
        if !is_nil(newest_frame.board.events) do
          case newest_frame.board.events do
            [{:collision, %Person{}}] ->
              # already collided in last frame, so no updates necessary
              create_frame(status, rest_steps, frames)
            [{:move, %{x: ^hit_x, y: ^hit_y}}] ->
              # previous player moved to this square, so rollback to original frame, and subtract health
              [original_frame | _] = Enum.reverse(frames)

              [new_player1, new_player2] = new_players = Enum.map(original_frame.board.players, fn board_player ->
                %Player{board_player | health_points: health_points - 1}
              end)

              updated_frame =
                %Game{original_frame |
                  board: %Board{original_frame.board |
                    players: new_players,
                    events: [
                      {:collision, %{x: hit_x, y: hit_y}},
                      {:collision, new_player1},
                      {:collision, new_player2}
                    ]
                  }
                }

              case new_players do
                [%Player{health_points: 0}, %Player{health_points: 0}] ->
                  create_frame(:draw, rest_steps, [updated_frame])
                [%Player{health_points: 0}, other_player] ->
                  create_frame({:win, other_player}, rest_steps, [updated_frame])
                [%Player{other_player, %Player{health_points: 0}] ->
                  create_frame({:win, other_player}, rest_steps, [updated_frame])
                _ ->
                  create_frame(status, rest_steps, [updated_frame])
              end
            [{:fire, _, _}] ->
              # hit a player, but previous frame was a fire event, so create new frame
              no_move_and_reduce_health(newest_frame, frames, status, rest_steps, hit_player, player)
            _ ->
              # hit a player, but no conflicting events
              no_move_and_reduce_health(newest_frame, rest_frames, status, rest_steps, hit_player, player)
          end
        else
          # hit a player, but no events
          no_move_and_reduce_health(newest_frame, rest_frames, status, rest_steps, hit_player, player)
        end
      {type, _} = barrier when type in [:edge, :obstacle] ->
        new_player = %Player{player | health_points: health_points - 1}
        updated_game =
          %Game{newest_game |
            board: %Board{newest_game.board |
              players: List.replace_at(
                newest_game.board.players,
                number - 1,
                new_player
              ),
              events: [{:collision, barrier} | (newest_game.board.events || [])]
            }
          }

        updated_games =
          if !is_nil(newest_game.board.events) && elem(Enum.at(newest_game.board.events, 0), 0) == :fire do
            [updated_game | new_games]
          else
            [updated_game | rest_games]
          end

        case {new_player.health_points, status} do
          {0, :ok} ->
            other_player = Enum.filter(newest_game.board.players, fn prospect -> prospect != new_player end)
            create_frame({:win, other_player}, rest_steps, updated_games)
          {0, {:win, _}} ->
            create_frame(:draw, rest_steps, updated_games)
          _ ->
            create_frame(status, rest_steps, updated_games)
        end
      {:flag  %Flag{x: flag_x, y: flag_y, number: flag_number}} when flag_number != player.number ->
        new_player = %Player{player | x: flag_x, y: flag_y}
        updated_game =
          %Game{newest_game |
            board: %Board{newest_game.board |
              players: List.replace_at(
                newest_game.board.players,
                number - 1,
                new_player
              ),
              events: [{:move, %{x: flag_x, y: flag_y}} | (newest_game.board.events || [])]
            }
          }

        updated_games =
          if !is_nil(newest_game.board.events) && elem(Enum.at(newest_game.board.events, 0), 0) == :fire do
            [updated_game | new_games]
          else
            [updated_game | rest_games]
          end

        # if not other's player's flag, no collision/win
        case status do
          :ok -> create_frame(rest, original_game, {:win, new_player}, updated_games)
          {:win, _} -> create_frame(rest, original_game, :draw, updated_games)
        end
      {:miss, %{x: new_x, y: new_y}} ->
        # no collision, just advance player
        new_player = %Player{player | x: new_x, y: new_y}
        updated_game =
          %Game{newest_game |
            board: %Board{newest_game.board |
              players: List.replace_at(
                newest_game.board.players,
                number - 1,
                new_player
              ),
              events: [{:move, %{x: new_x, y: new_y}} | (newest_game.board.events || [])]
            }
          }

        updated_games =
          if !is_nil(newest_game.board.events) && elem(Enum.at(newest_game.board.events, 0), 0) == :fire do
            [updated_game | new_games]
          else
            [updated_game | rest_games]
          end

        create_frame(rest, original_game, status, updated_games)
    end
  end

  defp move_and_reduce_health(newest_frame, rest_frames, status, rest_steps, hit_player, player) do
    case status do
      {:win, player} ->
        create_frame(status, rest_steps, rest_frames)
      :draw ->
        create_frame(status, rest_steps, rest_frames)
      :ok ->
        # reduce both players
        new_players = Enum.map(newest_frame.board.players, fn board_player ->
          %Player{board_player | health_points: health_points - 1}
        end)
  
        updated_frame =
          %Game{newest_frame |
            board: %Board{newest_frame.board |
              players: new_players,
              events: [{:collision, hit_player}, {:collision, player}] ++ (newest_frame.board.events || [])
            }
          }
  
        updated_frames = [updated_frame | rest_frames]
  
        case new_players do
          [%Player{health_points: 0}, %Player{health_points: 0}] ->
            create_frame(:draw, rest, updated_frames)
          [%Player{health_points: 0}, other_player] ->
            create_frame({:win, other_player}, rest_steps, updated_frames)
          [%Player{other_player, %Player{health_points: 0}] ->
            create_frame({:win, other_player}, rest_steps, updated_frames)
          _ ->
            create_frame(status, rest_steps, updated_frames)
        end
    end
  end

  defp get_newest_game(original_game, new_games) do
    cond do
      [] == new_games -> original_game
      [newest_game | _] = new_games -> newest_game 
    end
  end

  defp detect_collision(_, _, {x, y}, 0), do: {:miss, %{x: x, y: y}} 
  defp detect_collision(player, game, {x, y}, count) do
    {displace_x, displace_y} = get_displacement(player)
    new_cell_x = displace_x + x 
    new_cell_y = displace_y + y

    cond do
      new_cell_x >= game.board.width ->
        {:edge, %{x: game.board.width - 1, y: new_cell_y}}
      new_cell_y >= game.board.height ->
        {:edge, %{x: new_cell_x, y: game.board.height - 1}}
      new_cell_x < 0 ->
        {:edge, %{x: 0, y: new_cell_y}}
      new_cell_y < 0 ->
        {:edge, %{x: new_cell_x, y: 0}}
      true ->
        case get_in(game.board.cells, [new_cell_x, new_cell_y]) do
          %Player{} = p -> {:player, p}
          %Obstacle{} = o -> {:obstacle, o}
          %Flag{} = f -> {:flag, f}
          nil -> detect_collision(player, game, {new_cell_x, new_cell_y}, count - 1)
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
