defmodule Comparoya.Invoices.Invoice do
  use Ecto.Schema
  import Ecto.Changeset
  alias Comparoya.Accounts.User
  alias Comparoya.Invoices.{BusinessEntity, InvoiceItem, InvoiceMetadata}

  schema "invoices" do
    field :invoice_number, :string
    field :invoice_type, :string
    field :invoice_type_description, :string
    field :emission_date, :utc_datetime
    field :signature_date, :utc_datetime
    field :security_code, :string

    field :recipient_ruc, :string
    field :recipient_name, :string
    field :recipient_email, :string

    field :total_amount, :decimal
    field :total_discount, :decimal
    field :total_vat, :decimal

    field :raw_xml, :string
    field :storage_key, :string

    # Geolocation fields
    field :latitude, :float
    field :longitude, :float
    field :geocoding_status, :string
    field :geocoding_error, :string

    belongs_to :user, User
    belongs_to :business_entity, BusinessEntity
    has_many :items, InvoiceItem
    has_one :metadata, InvoiceMetadata

    timestamps()
  end

  @doc """
  Changeset for creating or updating an invoice.
  """
  def changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [
      :invoice_number,
      :invoice_type,
      :invoice_type_description,
      :emission_date,
      :signature_date,
      :security_code,
      :recipient_ruc,
      :recipient_name,
      :recipient_email,
      :total_amount,
      :total_discount,
      :total_vat,
      :raw_xml,
      :storage_key,
      :user_id,
      :business_entity_id,
      :latitude,
      :longitude,
      :geocoding_status,
      :geocoding_error
    ])
    |> validate_required([
      :invoice_number,
      :emission_date,
      :total_amount,
      :total_vat,
      :business_entity_id
    ])
    |> unique_constraint([:invoice_number, :business_entity_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:business_entity_id)
  end

  @doc """
  Finds an invoice by invoice number and business entity ID.
  """
  def find_by_number_and_entity(invoice_number, business_entity_id) do
    Comparoya.Repo.get_by(__MODULE__,
      invoice_number: invoice_number,
      business_entity_id: business_entity_id
    )
  end

  @doc """
  Preloads associated data for an invoice.
  """
  def preload_all(invoice) do
    Comparoya.Repo.preload(invoice, [
      :user,
      :business_entity,
      :metadata,
      items: [:product_reference]
    ])
  end
end
