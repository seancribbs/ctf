defmodule Ctf.UI do
  def start(games) do
    Scenic.ViewPort.set_root(:main_viewport, {Ctf.UI.Scenes.Game, games})
  end
end
