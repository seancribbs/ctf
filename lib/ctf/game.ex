defmodule Ctf.Game do
  @enforce_keys [:board]
  defstruct board: nil

  @type t() :: %__MODULE__{
          board: Board.t
  }

  alias Ctf.{Board, Player, Flag, Obstacle}

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

  # returns status (:draw, {:win, player})
  def play(%__MODULE__{} = game) do
    perform_game_loop(:ok, game, [], 0)
  end

  # limit to 100000 loops
  defp perform_game_loop(_, _, frames, 100000), do: {:draw, frames}
  defp perform_game_loop(:ok, game, frames, count) do
    {move_lists, players} =
      Enum.reduce(game.board.players, {[], []}, fn player, {move_lists, acc} ->
        {move_list, new_state} = apply(player.module, :turn, [game, player.state])
        {move_lists ++ [move_list], acc ++ [%Player{player | state: new_state}]}
      end)

    {status, new_frames} =
      lockstep(move_lists, 3)
      |> Enum.reduce({:ok, [game]}, fn {p1_move, p2_move}, {status, [latest_frame | _] = acc} ->
           if status == :ok do
             # displacement calcs to make sure we do moves in proper order
             # if player 1 were to move to where player 2 is currently, then do
             # moves in the opposite order, as player 2 might move out of the way
             # by the time player 1 moves.  if player 2 moves into player 1, we
             # are okay with that, because we know that player 1 is also going
             # to move into player 2.

             p1_will_move_into_p2 =
               if elem(p1_move, 0) == :move do
                 [%Player{number: 1, x: x, y: y} = player1, player2] = players
                 {displace_x, displace_y} = Player.get_displacement(player1)
                 new_cell_x = displace_x + x 
                 new_cell_y = displace_y + y
                 player2 in(Board.get_cell_contents(latest_frame.board, new_cell_x, new_cell_y))
               else
                 false
               end

             move_players = Enum.zip([p1_move, p2_move], players)
             move_players_maybe_reversed =
               cond do
                 elem(p1_move, 0) != :fire && elem(p2_move, 0) == :fire ->
                   # have to perform fires first in same lockstep
                   Enum.reverse(move_players)
                 p1_will_move_into_p2 ->
                   # have to perform moves in order to prevent timing problems (see above)
                   Enum.reverse(move_players)
                 true ->
                   #no need to reverse
                   move_players
               end

             # clear events on each call to create_frame
             frame_with_cleared_events =
               %__MODULE__{latest_frame | board: %Board{latest_frame.board | events: []}}

             {frame_status, new_frames} = create_frame(move_players_maybe_reversed, :ok, [frame_with_cleared_events])
             {frame_status, new_frames ++ acc}
           else
             # TODO: could probably use :halt here, but it's only 3, so I'll look later
             {status, acc}
           end
         end)

    [_initial_seed_frame | rest_frames] = Enum.reverse(new_frames)
    perform_game_loop(status, game, frames ++ Enum.reverse(rest_frames), count+1)
  end
  defp perform_game_loop(status, _, frames, _), do: {status, frames}

  defp create_frame(status, [], frames) do
    # reverse and return all but final frame
    [_initial_game | rest_frames] = Enum.reverse(frames)
    {status, Enum.reverse(rest_frames)}
  end
  defp create_frame(status, [{{:fire, count}, %Player{x: x, y: y} = player} | rest_steps], frames) do
    [newest_frame | rest_frames] = frames

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
          {0, {:win, _}} -> create_frame(:draw, rest_steps, updated_frames)
          _ -> create_frame(status, rest_steps, updated_frames)
        end
      # Flags, Obstacles, Edges
      {_, barrier} ->
        updated_frame =
          %__MODULE__{newest_frame |
            board: %Board{newest_frame.board |
              events: [{:fire, {x, y}, barrier} | (newest_frame.board.events || [])]
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

        create_frame(status, rest_steps, updated_frames)
    end
  end
  defp create_frame(status, [{{direction, 1}, %Player{number: number} = player} | rest_steps], frames) when direction in [:clockwise, :counterclockwise] do
    [newest_frame | rest_frames] = frames 
    new_rotated_player = Player.rotate(player, direction)

    updated_frame =
      %__MODULE__{newest_frame |
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
      {:player, %Player{x: hit_x, y: hit_y, health_points: health_points} = hit_player} ->
        if !is_nil(newest_frame.board.events) do
          case newest_frame.board.events do
            [{:collision, %Player{}}] ->
              # already collided in last frame, so no updates necessary
              create_frame(status, rest_steps, frames)
            [{:move, %{x: ^hit_x, y: ^hit_y}}] ->
              # previous player moved to this square, so rollback to original frame, and subtract health
              [original_frame | _] = Enum.reverse(frames)

              [new_player1, new_player2] = new_players = Enum.map(original_frame.board.players, fn board_player ->
                %Player{board_player | health_points: health_points - 1}
              end)

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

              case new_players do
                [%Player{health_points: 0}, %Player{health_points: 0}] ->
                  create_frame(:draw, rest_steps, [updated_frame])
                [%Player{health_points: 0}, other_player] ->
                  create_frame({:win, other_player}, rest_steps, [updated_frame])
                [other_player, %Player{health_points: 0}] ->
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
        updated_frame =
          %__MODULE__{newest_frame |
            board: %Board{newest_frame.board |
              players: List.replace_at(
                newest_frame.board.players,
                number - 1,
                new_player
              ),
              events: [{:collision, barrier} | (newest_frame.board.events || [])]
            }
          }

        updated_frames =
          if !is_nil(newest_frame.board.events) && elem(Enum.at(newest_frame.board.events, 0), 0) == :fire do
            [updated_frame | frames]
          else
            [updated_frame | rest_frames]
          end

        case {new_player.health_points, status} do
          {0, :ok} ->
            other_player = Enum.filter(newest_frame.board.players, fn prospect -> prospect != new_player end)
            create_frame({:win, other_player}, rest_steps, updated_frames)
          {0, {:win, _}} ->
            create_frame(:draw, rest_steps, updated_frames)
          _ ->
            create_frame(status, rest_steps, updated_frames)
        end
      {:flag, %Flag{x: flag_x, y: flag_y, number: flag_number}} when flag_number != number ->
        new_player = %Player{player | x: flag_x, y: flag_y}
        updated_frame =
          %__MODULE__{newest_frame |
            board: %Board{newest_frame.board |
              players: List.replace_at(
                newest_frame.board.players,
                number - 1,
                new_player
              ),
              events: [{:move, %{x: flag_x, y: flag_y}} | (newest_frame.board.events || [])]
            }
          }

        updated_frames =
          if !is_nil(newest_frame.board.events) && elem(Enum.at(newest_frame.board.events, 0), 0) == :fire do
            [updated_frame | frames]
          else
            [updated_frame | rest_frames]
          end

        # if not other's player's flag, no collision/win
        case status do
          :ok -> create_frame({:win, new_player}, rest_steps, updated_frames)
          {:win, _} -> create_frame(:draw, rest_steps, updated_frames)
        end
      {:miss, %{x: new_x, y: new_y}} ->
        # no collision, just advance player
        new_player = %Player{player | x: new_x, y: new_y}
        updated_frame =
          %__MODULE__{newest_frame |
            board: %Board{newest_frame.board |
              players: List.replace_at(
                newest_frame.board.players,
                number - 1,
                new_player
              ),
              events: [{:move, %{x: new_x, y: new_y}} | (newest_frame.board.events || [])]
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
  end

  defp no_move_and_reduce_health(newest_frame, rest_frames, status, rest_steps, hit_player, player) do
    case status do
      :ok ->
        # previous frame had no win or draw calculated
        # reduce both players
        new_players = Enum.map(newest_frame.board.players, fn %Player{health_points: health_points} = board_player ->
          %Player{board_player | health_points: health_points - 1}
        end)
  
        updated_frame =
          %__MODULE__{newest_frame |
            board: %Board{newest_frame.board |
              players: new_players,
              events: [{:collision, hit_player}, {:collision, player}] ++ (newest_frame.board.events || [])
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
        # pass through a previously calculated win or a draw
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
