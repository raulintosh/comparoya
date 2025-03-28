defmodule Comparoya.Invoices.BusinessEntity do
  use Ecto.Schema
  import Ecto.Changeset
  alias Comparoya.Invoices.Invoice

  schema "business_entities" do
    field :ruc, :string
    field :name, :string
    field :address, :string
    field :department_code, :string
    field :department_description, :string
    field :district_code, :string
    field :district_description, :string
    field :city_code, :string
    field :city_description, :string
    field :phone, :string
    field :email, :string
    field :economic_activity_code, :string
    field :economic_activity_description, :string

    has_many :invoices, Invoice

    timestamps()
  end

  @doc """
  Changeset for creating or updating a business entity.
  """
  def changeset(business_entity, attrs) do
    business_entity
    |> cast(attrs, [
      :ruc,
      :name,
      :address,
      :department_code,
      :department_description,
      :district_code,
      :district_description,
      :city_code,
      :city_description,
      :phone,
      :email,
      :economic_activity_code,
      :economic_activity_description
    ])
    |> validate_required([:ruc, :name])
    |> unique_constraint(:ruc)
  end

  @doc """
  Finds or creates a business entity by RUC.
  """
  def find_or_create(attrs) do
    case Comparoya.Repo.get_by(__MODULE__, ruc: attrs.ruc) do
      nil ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Comparoya.Repo.insert()

      business_entity ->
        {:ok, business_entity}
    end
  end
end
