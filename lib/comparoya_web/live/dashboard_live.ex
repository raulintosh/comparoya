defmodule ComparoyaWeb.DashboardLive do
  use ComparoyaWeb, :live_view

  import Ecto.Query, warn: false

  alias Comparoya.Repo
  alias Comparoya.Invoices
  alias Comparoya.Invoices.{Invoice, InvoiceItem, ProductReference}

  on_mount {ComparoyaWeb.Live.AuthOrAdminLive, :require_authenticated_user_or_admin}

  @per_page 25

  @impl true
  def mount(_params, _session, socket) do
    # Get invoices for the user
    user = socket.assigns.current_user
    invoices = Invoices.list_user_invoices(user)
    invoice_count = length(invoices)

    socket =
      socket
      |> assign(:invoice_count, invoice_count)
      |> assign(:search_term, "")
      |> assign(:current_page, 1)
      |> assign(:total_pages, 1)
      |> assign(:sort_by, "emission_date")
      |> assign(:sort_order, "desc")
      |> assign(:products_with_prices, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Extract search, pagination and sorting parameters
    search_term = params["search"] || ""
    page = String.to_integer(params["page"] || "1")
    sort_by = params["sort_by"] || "emission_date"
    sort_order = params["sort_order"] || "desc"

    user = socket.assigns.current_user

    # Get products with latest prices
    {products_with_prices, total_count} =
      if user do
        get_products_with_latest_prices(
          user.id,
          search_term,
          page,
          @per_page,
          sort_by,
          sort_order
        )
      else
        {[], 0}
      end

    # Calculate pagination data
    total_pages = ceil(total_count / @per_page)

    socket =
      socket
      |> assign(:products_with_prices, products_with_prices)
      |> assign(:search_term, search_term)
      |> assign(:current_page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_order, sort_order)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    params = %{
      "search" => search_term,
      "sort_by" => socket.assigns.sort_by,
      "sort_order" => socket.assigns.sort_order
    }

    {:noreply, push_patch(socket, to: ~p"/dashboard?#{params}")}
  end

  @impl true
  def handle_event("search_debounced", %{"value" => search_term}, socket) do
    params = %{
      "search" => search_term,
      "sort_by" => socket.assigns.sort_by,
      "sort_order" => socket.assigns.sort_order,
      # Reset to first page on new search
      "page" => "1"
    }

    {:noreply, push_patch(socket, to: ~p"/dashboard?#{params}")}
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
        where: be.economic_activity_code in ["47111", "56101"]

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
