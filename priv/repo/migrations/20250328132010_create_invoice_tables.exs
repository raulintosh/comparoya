defmodule Comparoya.Repo.Migrations.CreateInvoiceTables do
  use Ecto.Migration

  def change do
    # Referential data tables

    # Units of measurement
    create table(:units_of_measurement) do
      add :code, :string, null: false
      add :description, :string, null: false

      timestamps()
    end

    create unique_index(:units_of_measurement, [:code])

    # Business entities (companies)
    create table(:business_entities) do
      add :ruc, :string, null: false
      add :name, :string, null: false
      add :address, :string
      add :department_code, :string
      add :department_description, :string
      add :district_code, :string
      add :district_description, :string
      add :city_code, :string
      add :city_description, :string
      add :phone, :string
      add :email, :string
      add :economic_activity_code, :string
      add :economic_activity_description, :string

      timestamps()
    end

    create unique_index(:business_entities, [:ruc])

    # Product references
    create table(:product_references) do
      add :internal_code, :string, null: false
      add :description, :string, null: false
      add :unit_of_measurement_id, references(:units_of_measurement, on_delete: :restrict)

      timestamps()
    end

    create unique_index(:product_references, [:internal_code])
    create index(:product_references, [:unit_of_measurement_id])

    # Transactional data tables

    # Invoices
    create table(:invoices) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :business_entity_id, references(:business_entities, on_delete: :restrict)

      # Invoice identification
      add :invoice_number, :string, null: false
      add :invoice_type, :string
      add :invoice_type_description, :string
      add :emission_date, :utc_datetime, null: false
      add :signature_date, :utc_datetime
      add :security_code, :string

      # Customer information
      add :recipient_ruc, :string
      add :recipient_name, :string
      add :recipient_email, :string

      # Invoice totals
      add :total_amount, :decimal, precision: 15, scale: 2, null: false
      add :total_discount, :decimal, precision: 15, scale: 2, default: 0.0
      add :total_vat, :decimal, precision: 15, scale: 2, null: false

      # Raw XML data for reference
      add :raw_xml, :text

      timestamps()
    end

    create unique_index(:invoices, [:invoice_number, :business_entity_id])
    create index(:invoices, [:user_id])
    create index(:invoices, [:emission_date])
    create index(:invoices, [:recipient_ruc])
    create index(:invoices, [:recipient_email])

    # Invoice items
    create table(:invoice_items) do
      add :invoice_id, references(:invoices, on_delete: :delete_all), null: false
      add :product_reference_id, references(:product_references, on_delete: :restrict)

      # Product transaction details
      add :description, :string, null: false
      add :quantity, :decimal, precision: 15, scale: 3, null: false
      add :unit_price, :decimal, precision: 15, scale: 2, null: false
      add :discount_amount, :decimal, precision: 15, scale: 2, default: 0.0
      add :discount_percentage, :decimal, precision: 15, scale: 2, default: 0.0
      add :total_amount, :decimal, precision: 15, scale: 2, null: false

      # Tax information
      add :vat_rate, :decimal, precision: 5, scale: 2, null: false
      add :vat_base, :decimal, precision: 15, scale: 2, null: false
      add :vat_amount, :decimal, precision: 15, scale: 2, null: false

      timestamps()
    end

    create index(:invoice_items, [:invoice_id])
    create index(:invoice_items, [:product_reference_id])

    # Invoice metadata (payment information)
    create table(:invoice_metadata) do
      add :invoice_id, references(:invoices, on_delete: :delete_all), null: false

      # Payment information
      add :payment_condition, :string
      add :payment_condition_description, :string
      add :payment_type, :string
      add :payment_type_description, :string
      add :payment_amount, :decimal, precision: 15, scale: 2

      timestamps()
    end

    create unique_index(:invoice_metadata, [:invoice_id])
  end
end
