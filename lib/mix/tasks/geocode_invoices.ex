defmodule Mix.Tasks.Comparoya.GeocodeInvoices do
  @moduledoc """
  Mix task to geocode existing invoices.

  ## Examples

      # Geocode all invoices
      mix comparoya.geocode_invoices

      # Geocode with custom batch size and delay
      mix comparoya.geocode_invoices --batch-size=50 --delay=2000

      # Geocode a limited number of invoices
      mix comparoya.geocode_invoices --max=1000
  """

  use Mix.Task
  require Logger

  @shortdoc "Geocode existing invoices"

  @impl Mix.Task
  def run(args) do
    # Parse arguments
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          batch_size: :integer,
          delay: :integer,
          max: :integer
        ]
      )

    # Start application
    [:postgrex, :ecto, :oban, :comparoya]
    |> Enum.each(&Application.ensure_all_started/1)

    # Convert options
    options = [
      batch_size: Keyword.get(opts, :batch_size, 100),
      delay_ms: Keyword.get(opts, :delay, 1000),
      max_invoices: Keyword.get(opts, :max)
    ]

    # Run the batch geocoding
    Logger.info("Starting batch geocoding with options: #{inspect(options)}")

    case Comparoya.Geocoding.batch_geocode_invoices(options) do
      {:ok, count} ->
        Logger.info("Batch geocoding completed. Queued #{count} invoices for geocoding.")

      {:error, reason} ->
        Logger.error("Batch geocoding failed: #{inspect(reason)}")
    end
  end
end
