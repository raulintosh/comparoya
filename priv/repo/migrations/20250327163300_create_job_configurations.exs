defmodule Comparoya.Repo.Migrations.CreateJobConfigurations do
  use Ecto.Migration

  def change do
    create table(:job_configurations) do
      add :name, :string, null: false
      add :description, :string
      add :job_type, :string, null: false
      add :interval_minutes, :integer, null: false
      add :enabled, :boolean, default: true, null: false
      add :last_run_at, :utc_datetime
      add :config, :map, default: %{}, null: false
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:job_configurations, [:user_id])
    create unique_index(:job_configurations, [:name, :user_id])
  end
end
