defmodule Comparoya.Repo.Migrations.AddAdminAuthToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :string
      add :password_hash, :string
      add :is_admin, :boolean, default: false
    end

    create unique_index(:users, [:username])
  end
end
