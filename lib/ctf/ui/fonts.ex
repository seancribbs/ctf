defmodule Ctf.UI.Fonts do
  use Ctf.FileResource,
    manifest: "priv/static/fonts.manifest",
    resources: [
      font_metrics: {".ttf.metrics", Scenic.Cache.Static.FontMetrics, []},
      font: {".ttf", Scenic.Cache.Static.Font, [extension_hash: true]}
    ]
end
