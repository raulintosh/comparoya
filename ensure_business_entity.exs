# Script to ensure the business entity "CAFSA S.A." exists in the database

# Ensure the application is started
Application.ensure_all_started(:comparoya)

alias Comparoya.Repo
alias Comparoya.Invoices.BusinessEntity

# Check if the business entity exists
business_entity = Repo.get_by(BusinessEntity, name: "CAFSA S.A.")

if business_entity do
  IO.puts("Business entity 'CAFSA S.A.' already exists with ID: #{business_entity.id}")
else
  # Create the business entity
  attrs = %{
    # Example RUC, replace with actual RUC if known
    ruc: "80012345-6",
    name: "CAFSA S.A.",
    slug: "cafsa-sa",
    # Example address, replace with actual address if known
    address: "Asunción, Paraguay",
    # Example department code, replace with actual code if known
    department_code: "01",
    # Example department, replace with actual department if known
    department_description: "Asunción",
    # Example district code, replace with actual code if known
    district_code: "01",
    # Example district, replace with actual district if known
    district_description: "Asunción",
    # Example city code, replace with actual code if known
    city_code: "01",
    # Example city, replace with actual city if known
    city_description: "Asunción",
    # Example phone, replace with actual phone if known
    phone: "+595 21 123456",
    # Example email, replace with actual email if known
    email: "info@cafsa.com.py",
    # Example activity code, replace with actual code if known
    economic_activity_code: "123",
    # Example activity, replace with actual activity if known
    economic_activity_description: "Retail"
  }

  case BusinessEntity.find_or_create(attrs) do
    {:ok, entity} ->
      IO.puts("Business entity 'CAFSA S.A.' created with ID: #{entity.id}")

    {:error, changeset} ->
      IO.puts("Error creating business entity: #{inspect(changeset.errors)}")
  end
end
