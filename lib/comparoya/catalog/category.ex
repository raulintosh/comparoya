defmodule Comparoya.Catalog.Category do
  use Ecto.Schema
  import Ecto.Changeset
  alias Comparoya.Invoices.BusinessEntity

  schema "categories" do
    field :description, :string

    has_many :subcategories, Comparoya.Catalog.Subcategory, foreign_key: :category_id
    belongs_to :business_entity, BusinessEntity, foreign_key: :business_entities_id
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:description, :business_entities_id])
    |> validate_required([:description])
    |> validate_length(:description, max: 100)
    |> foreign_key_constraint(:business_entities_id)
  end
end
