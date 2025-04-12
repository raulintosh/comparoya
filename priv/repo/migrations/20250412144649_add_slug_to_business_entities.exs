defmodule Comparoya.Repo.Migrations.AddSlugToBusinessEntities do
  use Ecto.Migration

  def change do
    alter table(:business_entities) do
      add :slug, :string, default: nil
    end
  end
end
