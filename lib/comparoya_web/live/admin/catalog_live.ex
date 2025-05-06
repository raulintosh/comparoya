defmodule ComparoyaWeb.Admin.CatalogLive do
  use ComparoyaWeb, :live_view

  alias Comparoya.Catalog
  alias Comparoya.Invoices.BusinessEntity
  alias Comparoya.Repo
  import Ecto.Query

  on_mount {ComparoyaWeb.Live.AuthOrAdminLive, :require_authenticated_user_or_admin}

  @impl true
  def mount(_params, _session, socket) do
    # Ensure current_user is assigned to avoid KeyError
    socket =
      if !Map.has_key?(socket.assigns, :current_user),
        do: assign(socket, :current_user, nil),
        else: socket

    business_entities = list_business_entities()

    socket =
      socket
      |> assign(:page_title, "Catalog Management")
      |> assign(:categories, [])
      |> assign(:business_entities, business_entities)
      |> assign(:selected_business_entity_id, nil)
      |> assign(:search_term, "")
      |> assign(:current_page, 1)
      |> assign(:total_pages, 1)
      |> assign(:per_page, 10)

    {:ok, socket, temporary_assigns: [categories: []]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    search_term = params["search"] || ""
    page = String.to_integer(params["page"] || "1")
    business_entity_id = parse_business_entity_id(params["business_entity_id"])

    categories = list_categories(business_entity_id, search_term, page, socket.assigns.per_page)
    total_count = count_categories(business_entity_id, search_term)
    total_pages = ceil(total_count / socket.assigns.per_page)

    socket =
      socket
      |> assign(:categories, categories)
      |> assign(:search_term, search_term)
      |> assign(:current_page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:selected_business_entity_id, business_entity_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    params = %{
      "search" => search_term,
      "business_entity_id" =>
        if(socket.assigns.selected_business_entity_id,
          do: to_string(socket.assigns.selected_business_entity_id),
          else: nil
        ),
      "page" => "1"
    }

    {:noreply, push_patch(socket, to: ~p"/admin/catalog?#{params}")}
  end

  @impl true
  def handle_event(
        "filter_business_entity",
        %{"business_entity_id" => business_entity_id},
        socket
      ) do
    params = %{
      "search" => socket.assigns.search_term,
      "business_entity_id" => business_entity_id,
      "page" => "1"
    }

    {:noreply, push_patch(socket, to: ~p"/admin/catalog?#{params}")}
  end

  defp list_business_entities do
    Repo.all(BusinessEntity)
  end

  defp list_categories(business_entity_id, search_term, page, per_page) do
    query =
      from c in Catalog.Category,
        preload: [:business_entity, :subcategories]

    query =
      if business_entity_id do
        from c in query, where: c.business_entities_id == ^business_entity_id
      else
        query
      end

    query =
      if search_term && search_term != "" do
        search_pattern = "%#{search_term}%"
        from c in query, where: ilike(c.description, ^search_pattern)
      else
        query
      end

    query =
      from c in query,
        order_by: [asc: c.description],
        limit: ^per_page,
        offset: ^((page - 1) * per_page)

    Repo.all(query)
  end

  defp count_categories(business_entity_id, search_term) do
    query = from(c in Catalog.Category)

    query =
      if business_entity_id do
        from c in query, where: c.business_entities_id == ^business_entity_id
      else
        query
      end

    query =
      if search_term && search_term != "" do
        search_pattern = "%#{search_term}%"
        from c in query, where: ilike(c.description, ^search_pattern)
      else
        query
      end

    query = from c in query, select: count(c.id)

    Repo.one(query)
  end

  defp parse_business_entity_id(nil), do: nil
  defp parse_business_entity_id(""), do: nil

  defp parse_business_entity_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} -> id
      _ -> nil
    end
  end

  defp parse_business_entity_id(id), do: id
end
