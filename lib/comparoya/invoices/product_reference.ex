defmodule Comparoya.Invoices.ProductReference do
  use Ecto.Schema
  import Ecto.Changeset
  alias Comparoya.Invoices.{UnitOfMeasurement, InvoiceItem}

  schema "product_references" do
    field :internal_code, :string
    field :description, :string

    belongs_to :unit_of_measurement, UnitOfMeasurement
    has_many :invoice_items, InvoiceItem

    timestamps()
  end

  @doc """
  Changeset for creating or updating a product reference.
  """
  def changeset(product_reference, attrs) do
    product_reference
    |> cast(attrs, [:internal_code, :description, :unit_of_measurement_id])
    |> validate_required([:internal_code, :description])
    |> unique_constraint(:internal_code)
    |> foreign_key_constraint(:unit_of_measurement_id)
  end

  @doc """
  Finds or creates a product reference by internal code.
  """
  def find_or_create(attrs) do
    case Comparoya.Repo.get_by(__MODULE__, internal_code: attrs.internal_code) do
      nil ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Comparoya.Repo.insert()

      product_reference ->
        # Update the description if it has changed
        if product_reference.description != attrs.description do
          product_reference
          |> changeset(%{description: attrs.description})
          |> Comparoya.Repo.update()
        else
          {:ok, product_reference}
        end
    end
  end
end
