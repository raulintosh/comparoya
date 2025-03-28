defmodule ComparoyaWeb.DashboardController do
  use ComparoyaWeb, :controller

  import ComparoyaWeb.Plugs.AuthOrAdmin
  import Ecto.Query, warn: false

  alias Comparoya.Repo
  alias Comparoya.Invoices
  alias Comparoya.Invoices.{Invoice, InvoiceItem, ProductReference}

  plug :require_authenticated_user_or_admin

  def index(conn, _params) do
    # Use either the current_user or current_admin
    user = conn.assigns[:current_user] || conn.assigns[:current_admin]

    # Get invoices for the user
    invoices = Invoices.list_user_invoices(user)
    invoice_count = length(invoices)

    # Get products with latest prices
    products_with_prices = get_products_with_latest_prices(user.id)

    render(conn, :index,
      current_user: user,
      invoice_count: invoice_count,
      products_with_prices: products_with_prices
    )
  end

  # Get products with their latest prices from invoices
  defp get_products_with_latest_prices(user_id) do
    # This query gets the latest invoice item for each product reference
    query =
      from pr in ProductReference,
        join: ii in InvoiceItem,
        on: ii.product_reference_id == pr.id,
        join: i in Invoice,
        on: i.id == ii.invoice_id,
        where: i.user_id == ^user_id,
        group_by: [pr.id, pr.internal_code, pr.description],
        select: %{
          id: pr.id,
          internal_code: pr.internal_code,
          description: pr.description,
          latest_price: fragment("MAX(?)", ii.unit_price),
          latest_invoice_date: fragment("MAX(?)", i.emission_date)
        },
        order_by: [desc: fragment("MAX(?)", i.emission_date)]

    Repo.all(query)
  end
end
