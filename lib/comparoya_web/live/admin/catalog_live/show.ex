defmodule ComparoyaWeb.Admin.CatalogLive.Show do
  use ComparoyaWeb, :live_view

  alias Comparoya.Catalog
  alias Comparoya.Repo
  import Ecto.Query

  on_mount {ComparoyaWeb.Live.AuthOrAdminLive, :require_authenticated_user_or_admin}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Ensure current_user is assigned to avoid KeyError
    socket =
      if !Map.has_key?(socket.assigns, :current_user),
        do: assign(socket, :current_user, nil),
        else: socket

    category = get_category(id)

    socket =
      socket
      |> assign(:page_title, "Category Details")
      |> assign(:category, category)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:category, get_category(id))}
  end

  defp get_category(id) do
    Catalog.Category
    |> where([c], c.id == ^id)
    |> preload([:business_entity, :subcategories])
    |> Repo.one()
  end

  defp page_title(:show), do: "Category Details"
end
