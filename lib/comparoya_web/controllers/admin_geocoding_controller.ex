defmodule ComparoyaWeb.AdminGeocodingController do
  use ComparoyaWeb, :controller

  alias Comparoya.Geocoding
  alias Comparoya.Invoices.Invoice
  alias Comparoya.Repo

  import Ecto.Query

  def index(conn, _params) do
    # Get statistics about geocoded vs non-geocoded invoices
    stats = get_geocoding_stats()

    # Get recent geocoding attempts
    recent_attempts =
      Geocoding.GeocodingAttempt
      |> order_by([a], desc: a.attempted_at)
      |> limit(10)
      |> Repo.all()
      |> Repo.preload(:invoice)

    render(conn, :index, stats: stats, recent_attempts: recent_attempts)
  end

  def start_batch(conn, params) do
    # Parse parameters
    batch_size = String.to_integer(params["batch_size"] || "100")
    delay_ms = String.to_integer(params["delay_ms"] || "1000")

    max_invoices =
      if params["max_invoices"] && params["max_invoices"] != "",
        do: String.to_integer(params["max_invoices"]),
        else: nil

    # Start the batch process in a separate process
    Task.start(fn ->
      Geocoding.batch_geocode_invoices(
        batch_size: batch_size,
        delay_ms: delay_ms,
        max_invoices: max_invoices
      )
    end)

    conn
    |> put_flash(:info, "Batch geocoding started")
    |> redirect(to: ~p"/admin/geocoding")
  end

  def update_coordinates(conn, %{"id" => id, "invoice" => params}) do
    invoice = Repo.get!(Invoice, id)

    latitude = parse_float(params["latitude"])
    longitude = parse_float(params["longitude"])

    if latitude && longitude do
      invoice
      |> Ecto.Changeset.change(%{
        latitude: latitude,
        longitude: longitude,
        geocoding_status: "manual",
        geocoding_error: nil
      })
      |> Repo.update()
      |> case do
        {:ok, _invoice} ->
          conn
          |> put_flash(:info, "Coordinates updated successfully")
          |> redirect(to: ~p"/admin/geocoding")

        {:error, _changeset} ->
          conn
          |> put_flash(:error, "Failed to update coordinates")
          |> redirect(to: ~p"/admin/geocoding")
      end
    else
      conn
      |> put_flash(:error, "Invalid coordinates")
      |> redirect(to: ~p"/admin/geocoding")
    end
  end

  defp get_geocoding_stats do
    total = Repo.aggregate(Invoice, :count)

    geocoded =
      Invoice
      |> where([i], not is_nil(i.latitude) and not is_nil(i.longitude))
      |> Repo.aggregate(:count)

    failed =
      Invoice
      |> where([i], i.geocoding_status == "failed")
      |> Repo.aggregate(:count)

    pending =
      Invoice
      |> where([i], i.geocoding_status == "pending")
      |> Repo.aggregate(:count)

    %{
      total: total,
      geocoded: geocoded,
      failed: failed,
      pending: pending,
      percent_complete: if(total > 0, do: Float.round(geocoded / total * 100, 1), else: 0)
    }
  end

  defp parse_float(nil), do: nil
  defp parse_float(""), do: nil

  defp parse_float(string) do
    case Float.parse(string) do
      {float, _} -> float
      :error -> nil
    end
  end
end
