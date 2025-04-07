defmodule Comparoya.Repo.Migrations.CreateGeocodingAttempts do
  use Ecto.Migration

  def change do
    create table(:geocoding_attempts) do
      add :invoice_id, references(:invoices, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :error_reason, :string
      add :attempted_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:geocoding_attempts, [:invoice_id])
    create index(:geocoding_attempts, [:status])
    create index(:geocoding_attempts, [:attempted_at])
  end
end
