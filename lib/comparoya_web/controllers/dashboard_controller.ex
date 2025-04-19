defmodule ComparoyaWeb.DashboardController do
  use ComparoyaWeb, :controller

  import ComparoyaWeb.Plugs.AuthOrAdmin
  import Ecto.Query, warn: false

  alias Comparoya.Repo
  alias Comparoya.Invoices
  alias Comparoya.Invoices.{Invoice, InvoiceItem, ProductReference}

  plug :require_authenticated_user_or_admin

  def index(conn, params) do
    # Use either the current_user or current_admin
    user = conn.assigns[:current_user] || conn.assigns[:current_admin]

    # Get invoices for the user
    invoices = Invoices.list_user_invoices(user)
    invoice_count = length(invoices)

    # Extract search, pagination and sorting parameters
    search_term = params["search"] || ""
    page = String.to_integer(params["page"] || "1")
    per_page = 25
    sort_by = params["sort_by"] || "emission_date"
    sort_order = params["sort_order"] || "desc"

    # Get products with latest prices
    {products_with_prices, total_count} =
      get_products_with_latest_prices(
        user.id,
        search_term,
        page,
        per_page,
        sort_by,
        sort_order
      )

    # Calculate pagination data
    total_pages = ceil(total_count / per_page)

    render(conn, :index,
      current_user: user,
      invoice_count: invoice_count,
      products_with_prices: products_with_prices,
      search_term: search_term,
      current_page: page,
      total_pages: total_pages,
      sort_by: sort_by,
      sort_order: sort_order
    )
  end

  # Get products with their latest prices from invoices
  defp get_products_with_latest_prices(user_id, search_term, page, per_page, sort_by, sort_order) do
    # Base query for products with latest prices
    # Only from business entities with economic activity codes 47111 and 56101
    base_query =
      from pr in ProductReference,
        join: ii in InvoiceItem,
        on: ii.product_reference_id == pr.id,
        join: i in Invoice,
        on: i.id == ii.invoice_id,
        join: be in Comparoya.Invoices.BusinessEntity,
        on: i.business_entity_id == be.id,
        where: i.user_id == ^user_id,
        where: be.economic_activity_code in ["47111", "56101", "46699"]

    # Add search filter if search term is provided
    search_query =
      if search_term && search_term != "" do
        search_pattern = "%#{search_term}%"

        from q in base_query,
          where: ilike(q.description, ^search_pattern)
      else
        base_query
      end

    # Count total results for pagination
    count_query =
      from q in search_query,
        select: count(q.id, :distinct)

    total_count = Repo.one(count_query)

    # Add group by, select, order by, and pagination
    result_query =
      from pr in search_query,
        join: ii in InvoiceItem,
        on: ii.product_reference_id == pr.id,
        join: i in Invoice,
        on: i.id == ii.invoice_id,
        group_by: [pr.id, pr.internal_code, pr.description],
        select: %{
          id: pr.id,
          internal_code: pr.internal_code,
          description: pr.description,
          latest_price: fragment("MAX(?)", ii.unit_price),
          latest_invoice_date: fragment("MAX(?)", i.emission_date),
          business_info:
            fragment(
              "(SELECT CONCAT(slug, ' - ', city_description) FROM business_entities WHERE id = (SELECT business_entity_id FROM invoices WHERE id = (SELECT invoice_id FROM invoice_items WHERE id = (SELECT MAX(id) FROM invoice_items WHERE product_reference_id = ? AND invoice_id IN (SELECT id FROM invoices WHERE user_id = ?)))))",
              pr.id,
              ^user_id
            )
        },
        limit: ^per_page,
        offset: ^((page - 1) * per_page)

    # Apply ordering based on sort parameters
    result_query =
      case {sort_by, sort_order} do
        {"description", "asc"} ->
          from [pr, ii, i] in result_query, order_by: [asc: pr.description]

        {"description", _} ->
          from [pr, ii, i] in result_query, order_by: [desc: pr.description]

        {"price", "asc"} ->
          from [pr, ii, i] in result_query, order_by: [asc: fragment("MAX(?)", ii.unit_price)]

        {"price", _} ->
          from [pr, ii, i] in result_query, order_by: [desc: fragment("MAX(?)", ii.unit_price)]

        {_, "asc"} ->
          from [pr, ii, i] in result_query, order_by: [asc: fragment("MAX(?)", i.emission_date)]

        {_, _} ->
          from [pr, ii, i] in result_query, order_by: [desc: fragment("MAX(?)", i.emission_date)]
      end

    {Repo.all(result_query), total_count}
  end
end
