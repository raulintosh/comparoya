defmodule Comparoya.Catalog.ProductReference do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Comparoya.Repo
  alias Comparoya.Catalog.Subcategory
  alias Comparoya.Invoices.BusinessEntity

  schema "products_reference" do
    field :name, :string
    field :barcode, :string
    field :internal_code, :string

    belongs_to :subcategory, Subcategory
    belongs_to :business_entity, BusinessEntity

    timestamps()
  end

  def changeset(product_reference, attrs) do
    product_reference
    |> cast(attrs, [:name, :barcode, :internal_code, :subcategory_id, :business_entity_id])
    |> validate_required([:name, :subcategory_id, :business_entity_id])
    |> foreign_key_constraint(:subcategory_id)
    |> foreign_key_constraint(:business_entity_id)
    |> unique_constraint([:barcode, :business_entity_id],
      name: :products_reference_barcode_business_entity_index
    )
  end

  @doc """
  Finds or creates a product reference by barcode and business entity.
  """
  def find_or_create(attrs) do
    query =
      from p in __MODULE__,
        where: p.barcode == ^attrs.barcode,
        where: p.business_entity_id == ^attrs.business_entity_id

    case Repo.one(query) do
      nil ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()

      product_reference ->
        # Update if needed
        changes = Map.take(attrs, [:name, :internal_code, :subcategory_id])

        product_reference
        |> changeset(changes)
        |> Repo.update()
    end
  end

  @doc """
  Lists all products for a specific subcategory.
  """
  def list_by_subcategory(subcategory_id) do
    from(p in __MODULE__, where: p.subcategory_id == ^subcategory_id)
    |> Repo.all()
  end

  @doc """
  Lists all products for a specific business entity.
  """
  def list_by_business_entity(business_entity_id) do
    from(p in __MODULE__, where: p.business_entity_id == ^business_entity_id)
    |> Repo.all()
  end
end
