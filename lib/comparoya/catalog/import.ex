defmodule Comparoya.Catalog.Import do
  @moduledoc """
  Module for importing catalog data from JSON files.
  """

  alias Comparoya.Repo
  alias Comparoya.Catalog.Category
  alias Comparoya.Catalog.Subcategory

  @doc """
  Imports categories and subcategories from the SuperSeis catalog JSON file.
  """
  def import_superseis_catalog(file_path \\ "catalogo_superseis.json") do
    with {:ok, content} <- File.read(file_path),
         {:ok, data} <- Jason.decode(content) do
      # First, let's create a migration to fix the foreign key constraint
      IO.puts("Fixing database constraints...")
      fix_foreign_key_constraint()

      result =
        Repo.transaction(fn ->
          # Process each department and its categories
          Enum.each(data, fn department_data ->
            department_name = department_data["department"]

            # Process each category in the department
            Enum.each(department_data["categories"], fn category_data ->
              category_name = category_data["name"]
              full_category_name = "#{department_name} - #{category_name}"

              # Create or update the category
              category =
                case Repo.get_by(Category, description: full_category_name) do
                  nil ->
                    %Category{description: full_category_name}
                    |> Repo.insert!()

                  existing ->
                    existing
                end

              # Process each subcategory in the category
              Enum.each(category_data["subcategories"], fn subcategory_data ->
                subcategory_name = subcategory_data["name"]
                subcategory_url = subcategory_data["url"]

                # Create or update the subcategory
                case Repo.get_by(Subcategory,
                       category_id: category.id,
                       description: subcategory_name
                     ) do
                  nil ->
                    %Subcategory{
                      category_id: category.id,
                      description: subcategory_name,
                      path: subcategory_url
                    }
                    |> Repo.insert!()

                  existing ->
                    existing
                    |> Subcategory.changeset(%{path: subcategory_url})
                    |> Repo.update!()
                end
              end)
            end)
          end)
        end)

      case result do
        {:ok, _} -> {:ok, :imported}
        error -> error
      end
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, error}
    end
  end

  @doc """
  Clears all categories and subcategories from the database.
  """
  def clear_catalog do
    Repo.delete_all(Subcategory)
    Repo.delete_all(Category)
  end

  @doc """
  Fixes the foreign key constraint in the database.

  The database has an unusual foreign key constraint where the id column
  of subcategories references the id column of categories. This function
  drops that constraint and creates a new one using the category_id column.
  """
  def fix_foreign_key_constraint do
    # Drop the existing constraint
    Repo.query!("ALTER TABLE subcategories DROP CONSTRAINT IF EXISTS subcategories_categories_fk")

    # Create a new constraint using category_id
    Repo.query!(
      "ALTER TABLE subcategories ADD CONSTRAINT subcategories_categories_fk FOREIGN KEY (category_id) REFERENCES categories(id)"
    )

    IO.puts("Foreign key constraint fixed.")
  end
end
