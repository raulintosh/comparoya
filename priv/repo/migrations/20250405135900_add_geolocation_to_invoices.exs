defmodule Comparoya.Repo.Migrations.AddGeolocationToInvoices do
  use Ecto.Migration

  def change do
    # Add latitude and longitude columns
    alter table(:invoices) do
      add :latitude, :float
      add :longitude, :float
      add :geocoding_status, :string
      add :geocoding_error, :string
    end

    # Create indexes for the new columns
    create index(:invoices, [:latitude, :longitude])
    create index(:invoices, [:geocoding_status])
  end
end
