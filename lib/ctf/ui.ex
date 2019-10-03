defmodule Ctf.UI do
  def start(games) do
    Scenic.ViewPort.stop(:main_viewport)


    Application.get_env(:ctf, :viewport)
    |> Keyword.put(:default_scene, {Ctf.UI.Scenes.Game, games})
    |> Scenic.ViewPort.start()
  end
end
