defmodule Ctf.Game do
  @enforce_keys [:board]
  defstruct board: nil

  @type t() :: %__MODULE__{
          board: Board.t()
        }

  alias Ctf.{Board, Player, Flag, Obstacle}

  def new(players, board_height \\ 20, board_width \\ 20, obstacle_count \\ 25) do
    %__MODULE__{
      board:
        Board.new(
          height: board_height,
          width: board_width,
          players: players,
          obstacle_count: obstacle_count
        )
    }
  end

  # returns status (:draw, {:win, player})
  def play(%__MODULE__{} = game) do
    perform_game_loop(:ok, game, [], 0)
  end

  # limit to 100000 loops
  defp perform_game_loop(_, _, frames, 100000), do: {:draw, frames}
  defp perform_game_loop(:ok, game, frames, count) do
    {move_lists, players} =
      Enum.reduce(game.board.players, {[], []}, fn player, {move_lists, acc} ->
        {move_list, new_state} = apply(player.module, :turn, [game, player, player.state])
        {move_lists ++ [move_list], acc ++ [%Player{player | state: new_state}]}
      end)

    locksteps = lockstep(move_lists, 3)

    game_with_updated_player_states =
      %__MODULE__{game | board: %Board{game.board | players: players}}

    {status, new_frames} =
      Enum.reduce(
        locksteps,
        {:ok, [game_with_updated_player_states]},
        fn {p1_move, p2_move}, {status, [latest_frame | _] = acc} ->
          if status == :ok do
            # displacement calcs to make sure we do moves in proper order
            # if player 1 were to move to where player 2 is currently, then do
            # moves in the opposite order, as player 2 might move out of the way
            # by the time player 1 moves.  if player 2 moves into player 1, we
            # are okay with that, because we know that player 1 is also going
            # to move into player 2.

            IO.inspect({p1_move, p2_move})

            p1_will_move_into_p2 =
              if !is_nil(p1_move) && elem(p1_move, 0) == :move do
                [%Player{number: 1, x: x, y: y} = player1, player2] = players
                {displace_x, displace_y} = Player.get_displacement(player1)
                new_cell_x = displace_x + x 
                new_cell_y = displace_y + y
                player2 in Board.get_cell_contents(latest_frame.board, new_cell_x, new_cell_y)
              else
                false
              end

            move_players = Enum.zip([p1_move, p2_move], players)
            move_players_maybe_reversed =
              cond do
                !is_nil(p1_move) && !is_nil(p2_move) && elem(p1_move, 0) != :fire && elem(p2_move, 0) == :fire ->
                  # have to perform fires first in same lockstep
                  Enum.reverse(move_players)
                p1_will_move_into_p2 ->
                  # have to perform moves in order to prevent timing problems (see above)
                  Enum.reverse(move_players)
                true ->
                  #no need to reverse
                  move_players
              end
              # locksteps sometimes have nil values for one player (and one player only)
              |> Enum.filter(fn {move, _} -> !is_nil(move) end)

            frame_with_cleared_events = clear_events(latest_frame)

            move_players_with_numbers_only =
              move_players_maybe_reversed
              |> Enum.map(fn {move, %Player{number: number}} -> {move, number} end)

            # move_players_maybe_reversed can't be used for second element -- it will be out of date
            {frame_status, newest_frames} = create_frame(:ok, move_players_with_numbers_only, [frame_with_cleared_events])
            {frame_status, newest_frames ++ acc}
          else
            # TODO: could probably use :halt here, but it's only 3, so I'll look later
            {status, acc}
          end
        end)

    [newest_frame | _] = new_frames
    [_initial_seed_frame | rest_frames] = Enum.reverse(new_frames)
    perform_game_loop(status, newest_frame, frames ++ rest_frames, count+1)
  end
  defp perform_game_loop(status, _, frames, _), do: {status, frames}

  defp clear_events(frame) do
    %__MODULE__{frame | board: %Board{frame.board | events: []}}
  end

  defp create_frame(status, [], frames) do
    # reverse and return all but final frame
    [_initial_game | rest_frames] = Enum.reverse(frames)
    {status, Enum.reverse(rest_frames)}
  end
  defp create_frame(:draw, _, frames), do: create_frame(:draw, [], frames)
  defp create_frame(status, [{{:fire, count}, player_number} | rest_steps], frames) do
    [newest_frame | rest_frames] = frames
    player = %Player{x: x, y: y, number: ^player_number} = Enum.at(newest_frame.board.players, player_number - 1)

    case detect_collision(player, newest_frame, {x, y}, count) do
      {:player, %Player{health_points: health_points, number: number} = hit_player} ->
        new_hit_player = %Player{hit_player | health_points: health_points - 1}
        updated_frame =
          %__MODULE__{newest_frame |
            board: %Board{newest_frame.board |
              players: List.replace_at(
                newest_frame.board.players,
                number - 1,
                new_hit_player
              ),
              events: [{:fire, %{x: x, y: y}, new_hit_player} | (newest_frame.board.events || [])]
            }
          }

        updated_frames =
          cond do
            # no other fires in this frame, as we order fires first
            newest_frame.board.events == [] ->
              [updated_frame | frames]
            # need to keep original in case of rollback necessity
            rest_frames == [] -> 
              [updated_frame | frames]
            # other fires in this frame, so just update the same fire frame
            true ->
              [updated_frame | rest_frames]
          end

        case {new_hit_player.health_points, status} do
          {0, :ok} -> create_frame({:win, player}, rest_steps, updated_frames)
          {0, {:win, _}} -> create_frame(:draw, rest_steps, updated_frames)
          _ -> create_frame(status, rest_steps, updated_frames)
        end
      # Flags, Obstacles, Edges, Misses
      {_, barrier} ->
        updated_frame =
          %__MODULE__{newest_frame |
            board: %Board{newest_frame.board |
              events: [{:fire, %{x: x, y: y}, barrier} | (newest_frame.board.events || [])]
            }
          }

        updated_frames =
          cond do
            # no other fires in this frame, as we order fires first
            newest_frame.board.events == [] ->
              [updated_frame | frames]
            # need to keep original in case of rollback necessity
            rest_frames == [] -> 
              [updated_frame | frames]
            # other fires in this frame, so just update the same fire frame
            true ->
              [updated_frame | rest_frames]
          end

        create_frame(status, rest_steps, updated_frames)
    end
  end
  defp create_frame(status, [{{direction, 1}, player_number} | rest_steps], frames) when direction in [:clockwise, :counterclockwise] do
    [newest_frame | rest_frames] = frames 
    player = %Player{number: ^player_number} = Enum.at(newest_frame.board.players, player_number - 1)

    new_rotated_player = Player.rotate(player, direction)

    updated_frame =
      %__MODULE__{newest_frame |
        board: %Board{newest_frame.board|
          players: List.replace_at(
            newest_frame.board.players,
            player_number - 1,
            new_rotated_player
          ),
        }
      }

    rotation_event = {direction, player, new_rotated_player}
    updated_frame_with_event =
      %__MODULE__{updated_frame |
        board: %Board{updated_frame.board|
          events: [rotation_event]
        }
      }

    updated_frames =
      cond do
        length(newest_frame.board.events) > 0 && elem(Enum.at(newest_frame.board.events, 0), 0) == :fire ->
          [updated_frame_with_event | frames]
        # need to keep original in case of rollback necessity
        rest_frames == [] -> 
          [updated_frame_with_event | frames]
        true ->
          updated_frame_with_prepended_events =
            %__MODULE__{updated_frame |
              board: %Board{updated_frame.board|
                events: [rotation_event | (newest_frame.board.events || [])]
              }
            }

          [updated_frame_with_prepended_events | rest_frames]
      end

    create_frame(status, rest_steps, updated_frames)
  end
  defp create_frame(status, [{{:move, 1}, player_number} | rest_steps], frames) do 
    [newest_frame | rest_frames] = frames
    player = %Player{x: x, y: y, health_points: health_points, number: ^player_number} =
      Enum.at(newest_frame.board.players, player_number - 1)

    case detect_collision(player, newest_frame, {x, y}, 1) do
      {:player, %Player{x: hit_x, y: hit_y} = hit_player} ->
        if length(newest_frame.board.events) > 0 do
          case newest_frame.board.events do
            [{:collision, %Player{}}] ->
              # already collided in last frame, so no updates necessary
              create_frame(status, rest_steps, frames)
            [{:move, %{x: ^hit_x, y: ^hit_y}}] ->
              # previous player moved to this square, so rollback to original frame, and subtract health
              original_frame = List.last(frames)

              [new_player1, new_player2] = new_players = Enum.map(
                original_frame.board.players,
                fn %Player{health_points: this_player_health_points} = board_player ->
                  %Player{board_player | health_points: this_player_health_points - 1}
                end
              )

              updated_frame =
                %__MODULE__{original_frame |
                  board: %Board{original_frame.board |
                    players: new_players,
                    events: [
                      {:collision, %{x: hit_x, y: hit_y}},
                      {:collision, new_player1},
                      {:collision, new_player2}
                    ]
                  }
                }

              new_updated_frames = [updated_frame | original_frame]
              case new_players do
                [%Player{health_points: 0}, %Player{health_points: 0}] ->
                  create_frame(:draw, rest_steps, new_updated_frames)
                [%Player{health_points: 0}, other_player] ->
                  create_frame({:win, other_player}, rest_steps, new_updated_frames)
                [other_player, %Player{health_points: 0}] ->
                  create_frame({:win, other_player}, rest_steps, new_updated_frames)
                _ ->
                  create_frame(status, rest_steps, new_updated_frames)
              end
            [{:fire, _, _}] ->
              # hit a player, but previous frame was a fire event, so create new frame
              no_move_and_reduce_health(newest_frame, frames, status, rest_steps, hit_player, player)
            _ ->
              # hit a player, but no conflicting events, so mutate current frame
              frames_to_append =
                if rest_frames == [] do
                  frames
                else
                  rest_frames
                end
              no_move_and_reduce_health(newest_frame, frames_to_append, status, rest_steps, hit_player, player)
          end
        else
          # hit a player, but no events, so mutate current frame
          frames_to_append =
            if rest_frames == [] do
              frames
            else
              rest_frames
            end
          no_move_and_reduce_health(newest_frame, frames_to_append, status, rest_steps, hit_player, player)
        end
      {type, _} = barrier when type in [:edge, :obstacle] ->
        new_player = %Player{player | health_points: health_points - 1}

        last_event_was_fire = length(newest_frame.board.events) > 0 && elem(Enum.at(newest_frame.board.events, 0), 0) == :fire

        appendable_events =
          if last_event_was_fire do
            []
          else
            newest_frame.board.events
          end

        updated_frame =
          %__MODULE__{newest_frame |
            board: %Board{newest_frame.board |
              players: List.replace_at(
                newest_frame.board.players,
                player_number - 1,
                new_player
              ),
              events: [{:collision, barrier} | appendable_events]
            }
          }

        updated_frames =
          cond do
            last_event_was_fire ->
              [updated_frame | frames]
            # need to keep original in case of rollback necessity
            rest_frames == [] -> 
              [updated_frame | frames]
            true ->
              [updated_frame | rest_frames]
          end

        case {new_player.health_points, status} do
          {0, :ok} ->
            [other_player] = Enum.filter(updated_frame.board.players, fn prospect -> prospect != new_player end)
            create_frame({:win, other_player}, rest_steps, updated_frames)
          {0, {:win, _}} ->
            create_frame(:draw, rest_steps, updated_frames)
          _ ->
            create_frame(status, rest_steps, updated_frames)
        end
      # if not other's player's flag, no collision/win
      {:flag, %Flag{x: flag_x, y: flag_y, number: flag_number}} when flag_number != player_number ->
        new_player = %Player{player | x: flag_x, y: flag_y}

        last_event_was_fire = length(newest_frame.board.events) > 0 && elem(Enum.at(newest_frame.board.events, 0), 0) == :fire

        appendable_events =
          if last_event_was_fire do
            []
          else
            newest_frame.board.events
          end

        updated_frame =
          %__MODULE__{newest_frame |
            board: %Board{newest_frame.board |
              players: List.replace_at(
                newest_frame.board.players,
                player_number - 1,
                new_player
              ),
              events: [{:move, %{x: flag_x, y: flag_y}} | appendable_events]
            }
          }

        updated_frames =
          cond do
            last_event_was_fire ->
              [updated_frame | frames]
            # need to keep original in case of rollback necessity
            rest_frames == [] -> 
              [updated_frame | frames]
            true ->
              [updated_frame | rest_frames]
          end

        case status do
          :ok -> create_frame({:win, new_player}, rest_steps, updated_frames)
          {:win, _} -> create_frame(:draw, rest_steps, updated_frames)
        end
      {own_flag_or_miss, %{x: new_x, y: new_y}} when own_flag_or_miss in [:flag, :miss] ->
        # no collision, just advance player
        new_player = %Player{player | x: new_x, y: new_y}

        last_event_was_fire = length(newest_frame.board.events) > 0 && elem(Enum.at(newest_frame.board.events, 0), 0) == :fire

        appendable_events =
          if last_event_was_fire do
            []
          else
            newest_frame.board.events
          end

        updated_frame =
          %__MODULE__{newest_frame |
            board: %Board{newest_frame.board |
              players: List.replace_at(
                newest_frame.board.players,
                player_number - 1,
                new_player
              ),
              events: [{:move, %{x: new_x, y: new_y}} | appendable_events]
            }
          }

        updated_frames =
          cond do
            last_event_was_fire ->
              [updated_frame | frames]
            # need to keep original in case of rollback necessity
            rest_frames == [] -> 
              [updated_frame | frames]
            true ->
              [updated_frame | rest_frames]
          end

        create_frame(status, rest_steps, updated_frames)
    end
  end

  defp no_move_and_reduce_health(newest_frame, rest_frames, status, rest_steps, hit_player, player) do
    case status do
      :ok ->
        # previous frame had no win or draw calculated
        # reduce both players
        new_players = Enum.map(newest_frame.board.players, fn %Player{health_points: health_points} = board_player ->
          %Player{board_player | health_points: health_points - 1}
        end)

        last_event_was_fire = length(newest_frame.board.events) > 0 && elem(Enum.at(newest_frame.board.events, 0), 0) == :fire

        appendable_events =
          if last_event_was_fire do
            []
          else
            newest_frame.board.events
          end

        updated_frame =
          %__MODULE__{newest_frame |
            board: %Board{newest_frame.board |
              players: new_players,
              events: [{:collision, hit_player}, {:collision, player}] ++ appendable_events
            }
          }

        updated_frames = [updated_frame | rest_frames]
  
        case new_players do
          [%Player{health_points: 0}, %Player{health_points: 0}] ->
            create_frame(:draw, rest_steps, updated_frames)
          [%Player{health_points: 0}, other_player] ->
            create_frame({:win, other_player}, rest_steps, updated_frames)
          [other_player, %Player{health_points: 0}] ->
            create_frame({:win, other_player}, rest_steps, updated_frames)
          _ ->
            create_frame(status, rest_steps, updated_frames)
        end
      other_status ->
        # pass through a previously calculated win or a draw, as reducing both by 1
        # would not cause a :draw situation
        create_frame(other_status, rest_steps, rest_frames)
    end
  end

  defp detect_collision(_, _, {x, y}, 0), do: {:miss, %{x: x, y: y}} 
  defp detect_collision(player, game, {x, y}, count) do
    {displace_x, displace_y} = Player.get_displacement(player)
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
        content =
          # prioritized in Player as obstacle, then player, then flag
          Board.get_cell_contents(game.board, new_cell_x, new_cell_y)
          |> List.first()
        case content do
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

  defp first([{:fire, count} | rest_steps], acc, remaining) do
    # slurp all the fires into one immediate firing turn
    first(rest_steps, [{:fire, min(remaining, count)} | acc], max(0, remaining - count))
  end
  defp first([{_, 1} = move | rest_steps], acc, remaining) do
    first(rest_steps, [move | acc], remaining - 1)
  end
  defp first([{action, count} | rest_steps], acc, remaining) do
    first([{action, count - 1}] ++ rest_steps, [{action, 1} | acc], remaining - 1)
  end
end
