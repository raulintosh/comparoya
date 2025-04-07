defmodule Comparoya.Geocoding.GeocodingAttempt do
  @moduledoc """
  Schema for tracking geocoding attempts.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Comparoya.Invoices.Invoice

  schema "geocoding_attempts" do
    belongs_to :invoice, Invoice
    # "success", "failed", "pending"
    field :status, :string
    field :error_reason, :string
    field :attempted_at, :utc_datetime

    timestamps()
  end

  @doc """
  Changeset for creating or updating a geocoding attempt.
  """
  def changeset(geocoding_attempt, attrs) do
    geocoding_attempt
    |> cast(attrs, [:invoice_id, :status, :error_reason, :attempted_at])
    |> validate_required([:invoice_id, :status, :attempted_at])
    |> foreign_key_constraint(:invoice_id)
  end
end
