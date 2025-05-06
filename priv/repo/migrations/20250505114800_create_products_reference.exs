defmodule Comparoya.Repo.Migrations.CreateProductsReference do
  use Ecto.Migration

  def change do
    create table(:products_reference) do
      add :name, :string, null: false
      add :barcode, :string
      add :internal_code, :string
      add :subcategory_id, references(:subcategories, on_delete: :nilify_all)
      add :business_entity_id, references(:business_entities, on_delete: :nilify_all)

      timestamps()
    end

    create index(:products_reference, [:subcategory_id])
    create index(:products_reference, [:business_entity_id])
    # Create a unique constraint to avoid duplicates for each business entity
    create unique_index(:products_reference, [:barcode, :business_entity_id],
             name: :products_reference_barcode_business_entity_index
           )
  end
end
