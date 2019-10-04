defmodule Ctf do
  @moduledoc """
  Starter application using the Scenic framework.
  """

  def start(_type, _args) do
    # load the viewport configuration from config
    main_viewport_config = Application.get_env(:ctf, :viewport)

    # start the application with the viewport
    children = [
      {Scenic, viewports: [main_viewport_config]},
      {Task, &Ctf.FileResource.load_all/0}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def do_this do
    Ctf.Game.new([
      %{health_points: 5, module: Ctf.Players.Skunk},
      %{health_points: 5, module: Ctf.Players.ObstacleAvoider}
    ])
    |> Ctf.Game.play()
    |> List.wrap()
    |> Ctf.UI.start()
  end
end
