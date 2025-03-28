defmodule Comparoya.Invoices.InvoiceMetadata do
  use Ecto.Schema
  import Ecto.Changeset
  alias Comparoya.Invoices.Invoice

  schema "invoice_metadata" do
    field :payment_condition, :string
    field :payment_condition_description, :string
    field :payment_type, :string
    field :payment_type_description, :string
    field :payment_amount, :decimal

    belongs_to :invoice, Invoice

    timestamps()
  end

  @doc """
  Changeset for creating or updating invoice metadata.
  """
  def changeset(invoice_metadata, attrs) do
    invoice_metadata
    |> cast(attrs, [
      :payment_condition,
      :payment_condition_description,
      :payment_type,
      :payment_type_description,
      :payment_amount,
      :invoice_id
    ])
    |> validate_required([:invoice_id])
    |> unique_constraint(:invoice_id)
    |> foreign_key_constraint(:invoice_id)
  end
end
