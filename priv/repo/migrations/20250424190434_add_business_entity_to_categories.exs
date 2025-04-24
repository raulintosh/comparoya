defmodule Comparoya.Repo.Migrations.AddBusinessEntityToCategories do
  use Ecto.Migration

  def change do
    # Add business_entities_id column to categories table
    alter table(:categories) do
      add :business_entities_id, references(:business_entities, on_delete: :nilify_all)
    end

    # Create an index on the foreign key
    create index(:categories, [:business_entities_id])

    # Execute a function to update the categories table
    execute fn ->
      # Find the business entity with name "RETAIL S.A."
      repo().query!("""
      UPDATE categories
      SET business_entities_id = (
        SELECT id FROM business_entities WHERE name = 'RETAIL S.A.' LIMIT 1
      )
      """)
    end
  end
end
