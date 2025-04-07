defmodule Comparoya.Geocoding do
  @moduledoc """
  Context module for geocoding functionality.
  """

  alias Comparoya.Invoices.Invoice

  @doc """
  Enqueues a geocoding job for an invoice.

  ## Examples

      iex> enqueue_geocoding_job(invoice)
      {:ok, %Oban.Job{}}

  """
  def enqueue_geocoding_job(%Invoice{} = invoice) do
    %{invoice_id: invoice.id}
    |> Comparoya.Workers.GeocodingWorker.new()
    |> Oban.insert()
  end

  @doc """
  Batch geocodes invoices without coordinates.

  ## Options

  * `:batch_size` - Number of invoices to process in each batch (default: 100)
  * `:delay_ms` - Delay between batches in milliseconds (default: 1000)
  * `:max_invoices` - Maximum number of invoices to process (default: nil, meaning all)

  ## Examples

      iex> batch_geocode_invoices()
      {:ok, 42} # 42 invoices queued for geocoding

  """
  def batch_geocode_invoices(opts \\ []) do
    import Ecto.Query
    alias Comparoya.Repo
    alias Comparoya.Invoices.Invoice

    batch_size = Keyword.get(opts, :batch_size, 100)
    delay_ms = Keyword.get(opts, :delay_ms, 1000)
    max_invoices = Keyword.get(opts, :max_invoices)

    # Get total count of invoices without coordinates
    total_count =
      Invoice
      |> where([i], is_nil(i.latitude) or is_nil(i.longitude))
      |> Repo.aggregate(:count)

    # Calculate number of batches
    max_to_process = if max_invoices, do: min(max_invoices, total_count), else: total_count
    num_batches = ceil(max_to_process / batch_size)

    # Process in batches
    processed_count =
      Enum.reduce(0..(num_batches - 1), 0, fn batch_num, processed_so_far ->
        # Check if we've reached the maximum
        if max_invoices && processed_so_far >= max_invoices do
          processed_so_far
        else
          # Calculate how many to process in this batch
          remaining = max_to_process - processed_so_far
          current_batch_size = min(batch_size, remaining)

          # Process batch
          processed_in_batch = process_batch(batch_num, current_batch_size)

          # Sleep between batches to avoid overwhelming the API
          if batch_num < num_batches - 1 do
            :timer.sleep(delay_ms)
          end

          processed_so_far + processed_in_batch
        end
      end)

    {:ok, processed_count}
  end

  # Process a batch of invoices
  defp process_batch(batch_num, batch_size) do
    import Ecto.Query
    alias Comparoya.Repo
    alias Comparoya.Invoices.Invoice

    # Get a batch of invoices without coordinates
    invoices =
      Invoice
      |> where([i], is_nil(i.latitude) or is_nil(i.longitude))
      |> limit(^batch_size)
      |> offset(^(batch_num * batch_size))
      |> Repo.all()

    # Enqueue geocoding jobs for each invoice
    Enum.each(invoices, fn invoice ->
      enqueue_geocoding_job(invoice)
    end)

    length(invoices)
  end
end
