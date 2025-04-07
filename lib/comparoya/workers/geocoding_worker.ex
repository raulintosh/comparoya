defmodule Comparoya.Workers.GeocodingWorker do
  @moduledoc """
  Worker for geocoding invoice addresses.
  """

  use Oban.Worker, queue: :geocoding, max_attempts: 10

  require Logger
  alias Comparoya.Repo
  alias Comparoya.Invoices.{Invoice, BusinessEntity}
  alias Comparoya.Geocoding.{Geocoder, GeocodingAttempt}

  # Define which errors are retryable
  @retryable_errors [:over_query_limit, :network_error, :timeout]

  # Define which errors should be marked as permanent failures
  @permanent_errors [:invalid_address, :no_results, :request_denied, :invalid_request]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"invoice_id" => invoice_id}, attempt: attempt}) do
    Logger.info("Geocoding invoice #{invoice_id} (attempt #{attempt})")

    with {:ok, invoice} <- get_invoice(invoice_id),
         {:ok, business_entity} <- get_business_entity(invoice.business_entity_id),
         {:ok, address} <- extract_address(business_entity),
         {:ok, coordinates} <- Geocoder.geocode(address) do
      # Update the invoice with the coordinates
      case update_invoice_coordinates(invoice, coordinates) do
        {:ok, updated_invoice} ->
          # Record successful geocoding attempt
          record_geocoding_attempt(invoice_id, "success")
          {:ok, updated_invoice}

        {:error, _changeset} ->
          record_geocoding_attempt(invoice_id, "failed", "database_error")
          {:error, :database_error}
      end
    else
      {:error, error_type} = error when error_type in @retryable_errors ->
        # For retryable errors, we'll use snooze to retry later
        backoff_duration = calculate_backoff(attempt, error_type)

        Logger.warn(
          "Retryable error for invoice #{invoice_id}: #{error_type}. Retrying in #{backoff_duration}ms"
        )

        record_geocoding_attempt(invoice_id, "pending", to_string(error_type))
        {:snooze, backoff_duration}

      {:error, error_type} when error_type in @permanent_errors ->
        # For permanent errors, we'll mark the job as completed but log the issue
        Logger.info("Permanent error for invoice #{invoice_id}: #{error_type}. Not retrying.")
        record_geocoding_failure(invoice_id, error_type)
        {:ok, :permanent_error}

      {:error, :invoice_not_found} ->
        Logger.error("Invoice not found: #{invoice_id}")
        {:discard, :invoice_not_found}

      {:error, :business_entity_not_found} ->
        Logger.error("Business entity not found for invoice: #{invoice_id}")
        {:discard, :business_entity_not_found}

      {:error, :no_address} ->
        Logger.info("No address found for business entity of invoice: #{invoice_id}")
        record_geocoding_failure(invoice_id, :no_address)
        {:ok, :no_address}

      {:error, reason} ->
        # For unknown errors, we'll retry a few times
        if attempt < 3 do
          Logger.error("Unknown error for invoice #{invoice_id}: #{inspect(reason)}. Will retry.")
          record_geocoding_attempt(invoice_id, "pending", "unknown_error")
          {:snooze, 60_000 * attempt}
        else
          Logger.error(
            "Giving up on invoice #{invoice_id} after #{attempt} attempts: #{inspect(reason)}"
          )

          record_geocoding_failure(invoice_id, :unknown_error)
          {:error, reason}
        end
    end
  end

  # Calculate exponential backoff with jitter
  defp calculate_backoff(attempt, error_type) do
    base_ms =
      case error_type do
        # 1 minute for rate limits
        :over_query_limit -> 60_000
        # 30 seconds for network issues
        :network_error -> 30_000
        # 15 seconds for timeouts
        :timeout -> 15_000
        # Default
        _ -> 30_000
      end

    # Exponential backoff: base * 2^(attempt-1) + random jitter
    trunc(:math.pow(2, attempt - 1) * base_ms + :rand.uniform(5_000))
  end

  # Record geocoding attempt in the database
  defp record_geocoding_attempt(invoice_id, status, error_reason \\ nil) do
    %GeocodingAttempt{}
    |> GeocodingAttempt.changeset(%{
      invoice_id: invoice_id,
      status: status,
      error_reason: error_reason,
      attempted_at: DateTime.utc_now()
    })
    |> Repo.insert()
    |> case do
      {:ok, _attempt} -> :ok
      {:error, _changeset} -> :error
    end
  end

  # Record geocoding failure in the database
  defp record_geocoding_failure(invoice_id, reason) do
    # Record the attempt
    record_geocoding_attempt(invoice_id, "failed", to_string(reason))

    # Update the invoice to mark it as failed
    case get_invoice(invoice_id) do
      {:ok, invoice} ->
        invoice
        |> Ecto.Changeset.change(%{
          geocoding_status: "failed",
          geocoding_error: to_string(reason)
        })
        |> Repo.update()
        |> case do
          {:ok, _updated} -> :ok
          {:error, _changeset} -> :error
        end

      {:error, _} ->
        :error
    end
  end

  # Helper functions

  defp get_invoice(id) do
    case Repo.get(Invoice, id) do
      nil -> {:error, :invoice_not_found}
      invoice -> {:ok, invoice}
    end
  end

  defp get_business_entity(id) do
    case Repo.get(BusinessEntity, id) do
      nil -> {:error, :business_entity_not_found}
      entity -> {:ok, entity}
    end
  end

  defp extract_address(business_entity) do
    address = business_entity.address

    if is_nil(address) or address == "" do
      {:error, :no_address}
    else
      # Construct a full address with available information
      full_address =
        [
          address,
          business_entity.city_description,
          business_entity.district_description,
          business_entity.department_description
        ]
        |> Enum.filter(&(&1 && &1 != ""))
        |> Enum.join(", ")

      if full_address == "" do
        {:error, :no_address}
      else
        {:ok, full_address}
      end
    end
  end

  defp update_invoice_coordinates(invoice, %{latitude: lat, longitude: lng}) do
    invoice
    |> Ecto.Changeset.change(%{
      latitude: lat,
      longitude: lng,
      geocoding_status: "success",
      geocoding_error: nil
    })
    |> Repo.update()
  end
end
