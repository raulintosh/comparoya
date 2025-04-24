defmodule Mix.Tasks.Comparoya.ImportCatalog do
  @moduledoc """
  Mix task to import catalog data from JSON files.

  ## Examples

      # Import from the default file (catalogo_superseis.json)
      mix comparoya.import_catalog

      # Import from a specific file
      mix comparoya.import_catalog path/to/catalog.json

      # Clear the catalog before importing
      mix comparoya.import_catalog --clear

  """
  use Mix.Task

  alias Comparoya.Catalog.Import

  @shortdoc "Import catalog data from JSON files"
  def run(args) do
    # Start the application to ensure Repo is available
    Mix.Task.run("app.start")

    {opts, args, _} = OptionParser.parse(args, strict: [clear: :boolean])

    # Clear the catalog if requested
    if opts[:clear] do
      IO.puts("Clearing existing catalog data...")
      Import.clear_catalog()
    end

    # Get the file path from args or use default
    file_path = List.first(args) || "catalogo_superseis.json"

    IO.puts("Importing catalog data from #{file_path}...")

    case Import.import_superseis_catalog(file_path) do
      {:ok, _} ->
        IO.puts("Catalog data imported successfully!")

      {:error, reason} ->
        IO.puts("Error importing catalog data: #{inspect(reason)}")
    end
  end
end
