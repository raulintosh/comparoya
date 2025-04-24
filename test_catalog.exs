# Test script for the Catalog context
# Run with: mix run test_catalog.exs

alias Comparoya.Catalog

IO.puts("Testing Catalog context...")

# List all categories
IO.puts("\n=== Categories ===")
categories = Catalog.list_categories()

Enum.each(categories, fn category ->
  IO.puts("#{category.id}: #{category.description}")
end)

# Get a specific category with subcategories
if length(categories) > 0 do
  first_category = List.first(categories)
  IO.puts("\n=== Subcategories for '#{first_category.description}' ===")

  category_with_subs = Catalog.get_category_with_subcategories!(first_category.id)

  Enum.each(category_with_subs.subcategories, fn subcategory ->
    IO.puts("  #{subcategory.id}: #{subcategory.description} (#{subcategory.path})")
  end)
end

# List all subcategories
IO.puts("\n=== All Subcategories ===")
# Just show first 10 for brevity
subcategories = Catalog.list_subcategories() |> Enum.take(10)

Enum.each(subcategories, fn subcategory ->
  IO.puts(
    "#{subcategory.id}: #{subcategory.description} (Category ID: #{subcategory.category_id})"
  )
end)

# Search for categories
IO.puts("\n=== Search Categories for 'Almacén' ===")
search_results = Catalog.search_categories("Almacén")

Enum.each(search_results, fn category ->
  IO.puts("#{category.id}: #{category.description}")
end)

# Search for subcategories
IO.puts("\n=== Search Subcategories for 'Aceites' ===")
search_results = Catalog.search_subcategories("Aceites")

Enum.each(search_results, fn subcategory ->
  IO.puts(
    "#{subcategory.id}: #{subcategory.description} (Category ID: #{subcategory.category_id})"
  )
end)

IO.puts("\nCatalog context testing completed.")
