defmodule Comparoya.Repo.Migrations.AddStorageKeyToInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :storage_key, :string
    end
  end
end
