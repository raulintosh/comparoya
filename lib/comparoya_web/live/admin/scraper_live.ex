defmodule ComparoyaWeb.Admin.ScraperLive do
  use ComparoyaWeb, :live_view

  alias Phoenix.PubSub
  require Logger

  @topic "scraper:updates"

  # Add on_mount callback to ensure admin authentication
  on_mount {ComparoyaWeb.Live.AuthOrAdminLive, :require_authenticated_user_or_admin}

  # Helper functions for the template
  def status_color("idle"), do: "bg-gray-400"
  def status_color("running"), do: "bg-blue-500 animate-pulse"
  def status_color("completed"), do: "bg-green-500"
  def status_color("error"), do: "bg-red-500"
  def status_color(_), do: "bg-gray-400"

  def status_text("idle"), do: "Idle"
  def status_text("running"), do: "Running"
  def status_text("completed"), do: "Completed"
  def status_text("error"), do: "Error"
  def status_text(_), do: "Unknown"

  def entry_color(:info), do: "text-blue-800 bg-blue-50"
  def entry_color(:success), do: "text-green-800 bg-green-50"
  def entry_color(:error), do: "text-red-800 bg-red-50"
  def entry_color(_), do: "text-gray-800 bg-gray-50"

  alias Comparoya.Catalog
  alias Comparoya.Catalog.{Category, Subcategory}
  alias Comparoya.Invoices.BusinessEntity
  alias Comparoya.Repo
  import Ecto.Query, only: [from: 2]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Comparoya.PubSub, @topic)
    end

    # Load business entities for the dropdown
    business_entities = get_business_entities()

    socket =
      socket
      |> assign(:page_title, "Scraper Status")
      |> assign(:scraping_status, [])
      |> assign(:current_subcategory, nil)
      |> assign(:current_business_entity, nil)
      |> assign(:total_products, 0)
      |> assign(:successful_products, 0)
      |> assign(:failed_products, 0)
      |> assign(:progress_message, "Waiting to start scraping...")
      # idle, running, completed, error
      |> assign(:status, "idle")
      # Controls-related assigns
      |> assign(:business_entities, business_entities)
      |> assign(:selected_business_entity_id, nil)
      |> assign(:categories, [])
      |> assign(:selected_category_id, nil)
      |> assign(:subcategories, [])
      |> assign(:selected_subcategory_id, nil)

    # Ensure current_user and current_admin are assigned to avoid KeyError
    socket =
      socket
      |> then(fn s ->
        if !Map.has_key?(s.assigns, :current_user), do: assign(s, :current_user, nil), else: s
      end)
      |> then(fn s ->
        if !Map.has_key?(s.assigns, :current_admin), do: assign(s, :current_admin, nil), else: s
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("form_change", params, socket) do
    # Extract values from the form
    business_entity_id = parse_id(params["business_entity"])
    category_id = parse_id(params["category"])
    subcategory_id = parse_id(params["subcategory"])

    # Process business entity selection
    socket =
      if business_entity_id != socket.assigns.selected_business_entity_id do
        categories =
          if business_entity_id do
            query =
              from c in Category,
                where: c.business_entities_id == ^business_entity_id,
                order_by: [asc: c.description]

            Repo.all(query)
          else
            []
          end

        socket
        |> assign(:selected_business_entity_id, business_entity_id)
        |> assign(:categories, categories)
        |> assign(:selected_category_id, nil)
        |> assign(:subcategories, [])
        |> assign(:selected_subcategory_id, nil)
      else
        socket
      end

    # Process category selection
    socket =
      if category_id != socket.assigns.selected_category_id do
        subcategories =
          if category_id do
            query =
              from s in Subcategory,
                where: s.category_id == ^category_id,
                order_by: [asc: s.description]

            Repo.all(query)
          else
            []
          end

        socket
        |> assign(:selected_category_id, category_id)
        |> assign(:subcategories, subcategories)
        |> assign(:selected_subcategory_id, nil)
      else
        socket
      end

    # Process subcategory selection
    socket =
      if subcategory_id != socket.assigns.selected_subcategory_id do
        assign(socket, :selected_subcategory_id, subcategory_id)
      else
        socket
      end

    {:noreply, socket}
  end

  # Helper function to parse IDs from form values
  defp parse_id(value) when is_binary(value) do
    case value do
      "" ->
        nil

      id ->
        case Integer.parse(id) do
          {int_id, ""} -> int_id
          _ -> nil
        end
    end
  end

  defp parse_id(_), do: nil

  @impl true
  def handle_event("scrape_subcategory", _params, socket) do
    subcategory_id = socket.assigns.selected_subcategory_id

    if subcategory_id do
      # Start the scraping process in a Task to not block the LiveView
      Task.start(fn ->
        Catalog.Scraper.scrape_subcategory(subcategory_id)
      end)

      socket =
        socket
        |> assign(:status, "running")
        |> assign(:progress_message, "Starting subcategory scraping...")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("scrape_category", _params, socket) do
    category_id = socket.assigns.selected_category_id

    if category_id do
      # Get all subcategories for the category
      subcategories = Repo.all(from s in Subcategory, where: s.category_id == ^category_id)

      # Start the scraping process in a Task to not block the LiveView
      Task.start(fn ->
        Enum.each(subcategories, fn subcategory ->
          Catalog.Scraper.scrape_subcategory(subcategory.id)
        end)
      end)

      socket =
        socket
        |> assign(:status, "running")
        |> assign(:progress_message, "Starting category scraping...")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("scrape_all", _params, socket) do
    business_entity_id = socket.assigns.selected_business_entity_id

    if business_entity_id do
      # Start the scraping process in a Task to not block the LiveView
      Task.start(fn ->
        Catalog.Scraper.scrape_all_subcategories(business_entity_id)
      end)

      socket =
        socket
        |> assign(:status, "running")
        |> assign(:progress_message, "Starting full scraping process...")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:start, payload}, socket) do
    Logger.info("ScraperLive received start event: #{inspect(payload)}")

    socket =
      socket
      |> assign(:current_subcategory, %{
        id: payload.subcategory_id,
        name: payload.subcategory_name
      })
      |> assign(:current_business_entity, payload.business_entity)
      |> assign(:progress_message, "Started scraping #{payload.subcategory_name}")
      |> assign(:status, "running")
      |> update_scraping_status(fn status ->
        [
          %{
            timestamp: DateTime.utc_now(),
            type: :info,
            message: "Started scraping #{payload.subcategory_name} from #{payload.url}"
          }
          | status
        ]
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:progress, payload}, socket) do
    Logger.info("ScraperLive received progress event: #{inspect(payload)}")

    socket =
      socket
      |> assign(:progress_message, payload.message)
      |> update_scraping_status(fn status ->
        [
          %{
            timestamp: DateTime.utc_now(),
            type: :info,
            message: payload.message,
            products_count: Map.get(payload, :products_count)
          }
          | status
        ]
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:complete, payload}, socket) do
    Logger.info("ScraperLive received complete event: #{inspect(payload)}")

    socket =
      socket
      |> assign(:progress_message, "Completed scraping #{payload.subcategory_name}")
      |> assign(:status, "completed")
      |> assign(:total_products, (socket.assigns.total_products || 0) + payload.products_count)
      |> assign(
        :successful_products,
        (socket.assigns.successful_products || 0) + payload.successful
      )
      |> assign(:failed_products, (socket.assigns.failed_products || 0) + payload.failed)
      |> update_scraping_status(fn status ->
        [
          %{
            timestamp: DateTime.utc_now(),
            type: :success,
            message:
              "Completed scraping #{payload.subcategory_name}. " <>
                "Products: #{payload.products_count}, " <>
                "Successful: #{payload.successful}, " <>
                "Failed: #{payload.failed}"
          }
          | status
        ]
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:error, payload}, socket) do
    Logger.error("ScraperLive received error event: #{inspect(payload)}")

    socket =
      socket
      |> assign(:progress_message, "Error: #{payload.message}")
      |> assign(:status, "error")
      |> update_scraping_status(fn status ->
        [
          %{
            timestamp: DateTime.utc_now(),
            type: :error,
            message: payload.message
          }
          | status
        ]
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:start_all, payload}, socket) do
    Logger.info("ScraperLive received start_all event: #{inspect(payload)}")

    socket =
      socket
      |> assign(:current_business_entity, payload.business_entity_name)
      |> assign(
        :progress_message,
        "Started scraping all subcategories for #{payload.business_entity_name}"
      )
      |> assign(:status, "running")
      |> assign(:total_products, 0)
      |> assign(:successful_products, 0)
      |> assign(:failed_products, 0)
      |> assign(:scraping_status, [
        %{
          timestamp: DateTime.utc_now(),
          type: :info,
          message: "Started scraping all subcategories for #{payload.business_entity_name}"
        }
      ])

    {:noreply, socket}
  end

  @impl true
  def handle_info({:progress_all, payload}, socket) do
    Logger.info("ScraperLive received progress_all event: #{inspect(payload)}")

    socket =
      socket
      |> assign(:progress_message, payload.message)
      |> update_scraping_status(fn status ->
        [
          %{
            timestamp: DateTime.utc_now(),
            type: :info,
            message: "#{payload.message} (#{payload.subcategories_count} subcategories)"
          }
          | status
        ]
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:complete_all, payload}, socket) do
    Logger.info("ScraperLive received complete_all event: #{inspect(payload)}")

    socket =
      socket
      |> assign(:progress_message, "Completed scraping all subcategories")
      |> assign(:status, "completed")
      |> assign(:total_products, payload.total_products)
      |> update_scraping_status(fn status ->
        [
          %{
            timestamp: DateTime.utc_now(),
            type: :success,
            message:
              "Completed scraping all subcategories. " <>
                "Total subcategories: #{payload.subcategories_count}, " <>
                "Successful: #{payload.successful_count}, " <>
                "Total products: #{payload.total_products}"
          }
          | status
        ]
      end)

    {:noreply, socket}
  end

  # Helper function to update the scraping status
  defp update_scraping_status(socket, fun) do
    Phoenix.Component.update(socket, :scraping_status, fun)
  end

  defp get_business_entities() do
    query =
      from be in BusinessEntity,
        where: be.economic_activity_code in ["47111", "56101", "46699", "46900"],
        order_by: [asc: be.name]

    Repo.all(query)
  end
end
