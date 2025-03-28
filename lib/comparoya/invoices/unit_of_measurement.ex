defmodule Comparoya.Invoices.UnitOfMeasurement do
  use Ecto.Schema
  import Ecto.Changeset
  alias Comparoya.Invoices.ProductReference

  schema "units_of_measurement" do
    field :code, :string
    field :description, :string

    has_many :product_references, ProductReference

    timestamps()
  end

  @doc """
  Changeset for creating or updating a unit of measurement.
  """
  def changeset(unit_of_measurement, attrs) do
    unit_of_measurement
    |> cast(attrs, [:code, :description])
    |> validate_required([:code, :description])
    |> unique_constraint(:code)
  end

  @doc """
  Finds or creates a unit of measurement by code.
  """
  def find_or_create(attrs) do
    case Comparoya.Repo.get_by(__MODULE__, code: attrs.code) do
      nil ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Comparoya.Repo.insert()

      unit_of_measurement ->
        {:ok, unit_of_measurement}
    end
  end
end
