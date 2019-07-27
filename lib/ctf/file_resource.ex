defmodule Ctf.FileResource do
  @callback load() :: :ok

  defmacro __using__(opts) do
    {opts, _} = Code.eval_quoted(opts, [], __ENV__)
    manifest = Keyword.fetch!(opts, :manifest)
    resources = Keyword.fetch!(opts, :resources)

    resource_kinds = Keyword.keys(resources)
    files_and_hashes = read_manifest(manifest)
    grouped_resources = group_resources(files_and_hashes, resources)
    accessors = generate_accessors(resources, grouped_resources)
    loaders = generate_loaders(resources, grouped_resources)

    quote do
      @external_resource unquote(manifest)
      @behaviour Ctf.FileResource

      unquote_splicing(accessors)
      unquote_splicing(loaders)

      def load do
        for kind <- unquote(resource_kinds) do
          load(kind)
        end
        :ok
      end

      def __manifest__ do
        unquote(files_and_hashes)
      end
    end
  end

  def load_all do
    :ctf
    |> Application.spec(:modules)
    |> Enum.filter(fn mod ->
      b = mod.__info__(:attributes)[:behaviour]
      is_list(b) && Enum.member?(b, __MODULE__)
    end)
    |> Enum.each(&apply(&1, :load, []))
  end

  ##### MACRO SUPPORT FUNCTIONS

  defp read_manifest(manifest) do
    # Reads the precomputed asset manifest into a list of two-tuples of file +
    # hash
    manifest
    |> File.read!()
    |> String.split(~r{\s}, trim: true)
    |> Enum.chunk_every(2)
    |> Enum.map(&List.to_tuple/1)
  end

  defp group_resources(files_and_hashes, resources) do
    # Groups resources from the manifest by their type, matching on the
    # first file pattern.
    Enum.group_by(
      files_and_hashes,
      fn {file, _hash} ->
        Enum.find(resources, {:ignored, :bogus}, fn {_name, {file_pattern, _, _}} ->
          String.contains?(file, file_pattern)
        end)
        |> elem(0)
      end
    )
    |> Map.delete(:ignored)
  end

  defp generate_accessors(resources, grouped_resources) do
    # Generates accessor functions for each resource type, where the single
    # argument is the filename before the matching pattern, and the return value
    # is the hash for that file.
    for {name, {file_pattern, _, _}} <- resources, {file, hash} <- grouped_resources[name] do
      [short_name | _] =
        file
        |> Path.basename()
        |> String.split(file_pattern)

      quote do
        def unquote(name)(unquote(short_name)) do
          unquote(hash)
        end
      end
    end
  end

  defp generate_loaders(resources, grouped_resources) do
    for {kind, {_, loader, opts}} <- resources do
      pairs = grouped_resources[kind]

      if opts[:extension_hash] do
        # For whatever reason, Font uses the directory and the font's filename
        # extension to load the file. Why is this so different?
        quote do
          def load(unquote(kind)) do
            for {file, _} <- unquote(Macro.escape(pairs)) do
              path = Path.dirname(file)
              <<?., hash::binary>> = Path.extname(file)
              unquote(loader).load!(path, hash, scope: :global)
            end
          end
        end
      else
        quote do
          def load(unquote(kind)) do
            for {file, hash} <- unquote(Macro.escape(pairs)) do
              unquote(loader).load!(file, hash, scope: :global)
            end
          end
        end
      end
    end
  end
end
