defmodule Comparoya.Invoices.InvoiceItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Comparoya.Invoices.{Invoice, ProductReference}

  schema "invoice_items" do
    field :description, :string
    field :quantity, :decimal
    field :unit_price, :decimal
    field :discount_amount, :decimal
    field :discount_percentage, :decimal
    field :total_amount, :decimal
    field :vat_rate, :decimal
    field :vat_base, :decimal
    field :vat_amount, :decimal

    belongs_to :invoice, Invoice
    belongs_to :product_reference, ProductReference

    timestamps()
  end

  @doc """
  Changeset for creating or updating an invoice item.
  """
  def changeset(invoice_item, attrs) do
    invoice_item
    |> cast(attrs, [
      :description,
      :quantity,
      :unit_price,
      :discount_amount,
      :discount_percentage,
      :total_amount,
      :vat_rate,
      :vat_base,
      :vat_amount,
      :invoice_id,
      :product_reference_id
    ])
    |> validate_required([
      :description,
      :quantity,
      :unit_price,
      :total_amount,
      :vat_rate,
      :vat_base,
      :vat_amount,
      :invoice_id
    ])
    |> foreign_key_constraint(:invoice_id)
    |> foreign_key_constraint(:product_reference_id)
  end
end
