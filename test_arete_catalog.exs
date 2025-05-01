# Script to test importing the Arete catalog

# Ensure the application is started
Application.ensure_all_started(:comparoya)

# Import the catalog
case Comparoya.Catalog.Import.import_arete_catalog() do
  {:ok, :imported} ->
    IO.puts("Arete catalog imported successfully!")

  {:error, reason} ->
    IO.puts("Error importing Arete catalog: #{inspect(reason)}")
end
