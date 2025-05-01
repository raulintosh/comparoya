# Arete Catalog Import

This README explains how to import the Arete catalog into the Comparoya system.

## Files

- `catalogo_arete.json`: Contains the catalog data for Arete
- `ensure_business_entity.exs`: Script to ensure the business entity "CAFSA S.A." exists in the database
- `test_arete_catalog.exs`: Script to test importing the Arete catalog

## Steps to Import the Catalog

1. First, ensure the business entity "CAFSA S.A." exists in the database:

```bash
mix run ensure_business_entity.exs
```

2. Then, import the Arete catalog:

```bash
mix run test_arete_catalog.exs
```

## Implementation Details

The import functionality is implemented in the `Comparoya.Catalog.Import` module, which has been extended with the `import_arete_catalog` function. This function:

1. Finds the business entity "CAFSA S.A." in the database
2. Reads the catalog data from the `catalogo_arete.json` file
3. Imports the categories and subcategories, setting the `business_entities_id` field to the ID of "CAFSA S.A."

The catalog data structure is similar to the SuperSeis catalog, with departments, categories, and subcategories.

## Customizing the Catalog Data

If you need to modify the catalog data, edit the `catalogo_arete.json` file. The structure should be maintained as follows:

```json
[
  {
    "department": "Department Name",
    "categories": [
      {
        "name": "Category Name",
        "subcategories": [
          {
            "name": "Subcategory Name",
            "url": "https://example.com/subcategory-url"
          }
        ]
      }
    ]
  }
]
```

## Customizing the Business Entity

If you need to modify the business entity details, edit the `ensure_business_entity.exs` file. The current implementation uses example values for most fields, which should be replaced with actual values if known.
