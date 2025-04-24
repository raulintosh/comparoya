defmodule Comparoya.Catalog.Subcategory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "subcategories" do
    field :description, :string
    field :path, :string

    # Note: The database has an unusual foreign key constraint where the id column
    # of subcategories references the id column of categories. However, for the Ecto
    # schema, we're using the more conventional category_id field for the association.
    belongs_to :category, Comparoya.Catalog.Category, foreign_key: :category_id
  end

  @doc false
  def changeset(subcategory, attrs) do
    subcategory
    |> cast(attrs, [:category_id, :description, :path])
    |> validate_required([:category_id, :description])
    |> validate_length(:description, max: 200)
    |> validate_length(:path, max: 400)
    |> foreign_key_constraint(:category_id)
  end
end
