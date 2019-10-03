# CTF

Program your robot tank to capture the flag and destroy other tanks in this
turn-based strategy game in Elixir! You have only a few milliseconds to make a
decision, so don't spend too much time computing your move.

## Requirements

* Elixir >= 1.8 and OTP >= 21
* [Scenic prerequisites](https://github.com/boydm/scenic/blob/master/guides/install_dependencies.md)

## Game Rules

* Players are automated, no human input is allowed! (aside from the code)
* On each turn, each player has (maximum) three action points and may allocate
  them among three action types:
  * Move forward `n` squares (`move: n`)
  * Rotate clockwise or counterclockwise 90 degrees `n` times (`clockwise: n`, `counterclockwise: n`)
  * Fire forward `n` squares (`fire: n`)
* After actions are decided and validated, player tanks perform the actions
  simultaneously in lock-step. Collisions damage both tanks and nullify the
  movement command.
* Players have 5 health points, which are diminished by enemy fire and
  collisions.
* The first player to reach the enemy flag wins! Even if your player
  incapacitates the other player, you must get to their flag.

Some example turns might be:

```elixir
# Move forward twice, rotate clockwise once
[move: 2, clockwise: 1]

# Fire at opponent 3 squares away
[fire: 3]

# Invalid turn, only first three actions used. 
# Essentially the same as the first turn above.
[move: 2, clockwise: 2]
```

## Defining Your Player

To define your player, you must implement a module with the following behaviour:

```elixir
defmodule Ctf.Player do
  # Some types used in the callback definition
  @type state() :: any()
  @type actions() :: [move: 1..3, rotate: 1..3, fire: 1..3]

  # Implement this function!
  @callback turn(Game.t(), Player.t(), state()) :: {actions(), state()}
  
  # Name your player (optional, defaults to the module name)
  @callback name() :: String.t()
  
  @optional_callbacks [name: 0]
end
```
