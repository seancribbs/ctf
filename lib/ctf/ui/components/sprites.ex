defmodule Ctf.Sprites do
  use Ctf.FileResource,
    manifest: "priv/static/sprites.manifest",
    resources: [sprite: {".png", Scenic.Cache.Static.Texture, []}]
end
