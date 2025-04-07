defmodule Comparoya.Invoices do
  @moduledoc """
  The Invoices context.
  This module provides functions for working with invoices and related data.
  """

  import Ecto.Query, warn: false
  alias Comparoya.Repo
  alias Comparoya.Accounts.User

  alias Comparoya.Invoices.{
    Invoice,
    InvoiceItem,
    InvoiceMetadata,
    BusinessEntity,
    ProductReference,
    UnitOfMeasurement
  }

  @doc """
  Returns the list of invoices for a user.

  ## Examples

      iex> list_user_invoices(user)
      [%Invoice{}, ...]

  """
  def list_user_invoices(%User{} = user) do
    Invoice
    |> where([i], i.user_id == ^user.id)
    |> order_by([i], desc: i.emission_date)
    |> Repo.all()
    |> Repo.preload([:business_entity])
  end

  @doc """
  Gets a single invoice.

  Raises `Ecto.NoResultsError` if the Invoice does not exist.

  ## Examples

      iex> get_invoice!(123)
      %Invoice{}

      iex> get_invoice!(456)
      ** (Ecto.NoResultsError)

  """
  def get_invoice!(id) do
    Invoice
    |> Repo.get!(id)
    |> Invoice.preload_all()
  end

  @doc """
  Gets a single invoice with preloaded associations.

  Returns nil if the Invoice does not exist.

  ## Examples

      iex> get_invoice(123)
      %Invoice{}

      iex> get_invoice(456)
      nil

  """
  def get_invoice(id) do
    case Repo.get(Invoice, id) do
      nil -> nil
      invoice -> Invoice.preload_all(invoice)
    end
  end

  @doc """
  Creates an invoice with its items and metadata.

  ## Examples

      iex> create_invoice(%{field: value})
      {:ok, %{invoice: %Invoice{}, items: [%InvoiceItem{}], metadata: %InvoiceMetadata{}}}

      iex> create_invoice(%{field: bad_value})
      {:error, failed_operation, failed_value, changes_so_far}

  """
  def create_invoice(attrs) do
    result =
      Repo.transaction(fn ->
        # Create or get business entity
        {:ok, business_entity} = create_or_get_business_entity(attrs.business_entity)

        # Create invoice
        invoice_attrs =
          Map.merge(attrs.invoice, %{
            business_entity_id: business_entity.id,
            user_id: attrs.user_id,
            geocoding_status: "pending"
          })

        {:ok, invoice} =
          %Invoice{}
          |> Invoice.changeset(invoice_attrs)
          |> Repo.insert()

        # Create invoice items
        items =
          Enum.map(attrs.items, fn item_attrs ->
            # Create or get product reference
            {:ok, product_reference} =
              create_or_get_product_reference(item_attrs.product_reference)

            # Create invoice item
            {:ok, item} =
              %InvoiceItem{}
              |> InvoiceItem.changeset(
                Map.merge(item_attrs, %{
                  invoice_id: invoice.id,
                  product_reference_id: product_reference.id
                })
              )
              |> Repo.insert()

            item
          end)

        # Create invoice metadata
        {:ok, metadata} =
          %InvoiceMetadata{}
          |> InvoiceMetadata.changeset(Map.merge(attrs.metadata, %{invoice_id: invoice.id}))
          |> Repo.insert()

        %{
          invoice: invoice,
          items: items,
          metadata: metadata
        }
      end)

    case result do
      {:ok, %{invoice: invoice} = result} ->
        # Enqueue geocoding job
        Comparoya.Geocoding.enqueue_geocoding_job(invoice)

        {:ok, result}

      error ->
        error
    end
  end

  @doc """
  Creates or gets a business entity.

  ## Examples

      iex> create_or_get_business_entity(%{ruc: "123", name: "Company"})
      {:ok, %BusinessEntity{}}

  """
  def create_or_get_business_entity(attrs) do
    BusinessEntity.find_or_create(attrs)
  end

  @doc """
  Creates or gets a product reference.

  ## Examples

      iex> create_or_get_product_reference(%{internal_code: "123", description: "Product"})
      {:ok, %ProductReference{}}

  """
  def create_or_get_product_reference(attrs) do
    # First, create or get the unit of measurement
    {:ok, unit_of_measurement} = create_or_get_unit_of_measurement(attrs.unit_of_measurement)

    # Then, create or get the product reference
    ProductReference.find_or_create(
      Map.merge(attrs, %{unit_of_measurement_id: unit_of_measurement.id})
    )
  end

  @doc """
  Creates or gets a unit of measurement.

  ## Examples

      iex> create_or_get_unit_of_measurement(%{code: "123", description: "Unit"})
      {:ok, %UnitOfMeasurement{}}

  """
  def create_or_get_unit_of_measurement(attrs) do
    UnitOfMeasurement.find_or_create(attrs)
  end

  @doc """
  Finds an invoice by invoice number and business entity RUC.

  ## Examples

      iex> find_invoice_by_number_and_entity_ruc("001-001-0000123", "80123456")
      %Invoice{}

      iex> find_invoice_by_number_and_entity_ruc("001-001-0000456", "80123456")
      nil

  """
  def find_invoice_by_number_and_entity_ruc(invoice_number, entity_ruc) do
    business_entity = Repo.get_by(BusinessEntity, ruc: entity_ruc)

    if business_entity do
      Invoice
      |> where(
        [i],
        i.invoice_number == ^invoice_number and i.business_entity_id == ^business_entity.id
      )
      |> Repo.one()
      |> Invoice.preload_all()
    else
      nil
    end
  end

  @doc """
  Finds a user by email.
  Performs a case-insensitive comparison to handle emails in different cases.

  ## Examples

      iex> find_user_by_email("user@example.com")
      %User{}

      iex> find_user_by_email("USER@EXAMPLE.COM")
      %User{}

      iex> find_user_by_email("nonexistent@example.com")
      nil

  """
  def find_user_by_email(email) when is_binary(email) do
    # Convert email to lowercase for case-insensitive comparison
    downcased_email = String.downcase(email)

    # Use a query with a case-insensitive comparison
    User
    |> where([u], fragment("lower(?)", u.email) == ^downcased_email)
    |> Repo.one()
  end

  def find_user_by_email(_), do: nil

  @doc """
  Updates the storage key for an invoice.

  ## Examples

      iex> update_invoice_storage_key(invoice, "new_storage_key")
      {:ok, %Invoice{}}

      iex> update_invoice_storage_key(invoice, nil)
      {:error, %Ecto.Changeset{}}

  """
  def update_invoice_storage_key(%Invoice{} = invoice, storage_key) when is_binary(storage_key) do
    invoice
    |> Invoice.changeset(%{storage_key: storage_key})
    |> Repo.update()
  end
end
