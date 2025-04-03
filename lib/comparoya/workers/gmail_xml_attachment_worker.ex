defmodule Comparoya.Workers.GmailXmlAttachmentWorker do
  @moduledoc """
  Worker for processing Gmail XML attachments.

  This worker supports two modes:
  1. Historical mode: Processes invoices from the current and previous year (one-time job)
  2. Continuous mode: Processes new invoices since the user's registration (recurring job)
  """

  use Oban.Worker, queue: :gmail, max_attempts: 3

  require Logger
  alias Comparoya.Accounts
  alias Comparoya.Jobs
  alias Comparoya.Gmail.{API, XmlAttachmentProcessor}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"job_configuration_id" => job_configuration_id}}) do
    with {:ok, job_config} <- get_job_configuration(job_configuration_id),
         {:ok, user} <- get_user(job_config.user_id) do
      # Determine which type of job to run based on the job configuration
      job_type = get_in(job_config.config, ["job_type"]) || "regular"

      result =
        case job_type do
          "historical" ->
            process_historical_invoices(user, job_config)

          "continuous" ->
            process_continuous_invoices(user, job_config)

          _ ->
            # Fallback to regular processing for backward compatibility
            process_regular_invoices(user, job_config)
        end

      # Update the last run timestamp regardless of the job type
      Jobs.update_last_run_at(job_configuration_id)

      result
    else
      {:error, reason} ->
        Logger.error("Error in GmailXmlAttachmentWorker: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Processes historical invoices for a user (current and previous year).
  This is intended to be run once when a user registers.
  """
  def process_historical_invoices(user, job_config) do
    Logger.info("Processing historical invoices for user #{user.email}")

    # Build a query for invoices from the current and previous year
    query = API.build_historical_invoice_query()

    # Get max results from job configuration or use a higher default for historical processing
    max_results = get_in(job_config.config, ["max_results"]) || 100

    Logger.info("Historical query: #{query}")
    Logger.info("Max results: #{max_results}")

    # Process the attachments
    case XmlAttachmentProcessor.process_xml_attachments(user,
           query: query,
           max_results: max_results,
           callback: &handle_xml_data/4
         ) do
      {:ok, results} ->
        processed_count = Enum.count(results, & &1.processed)
        error_count = Enum.count(results, & &1.error)

        Logger.info("Processed #{processed_count} historical invoices with #{error_count} errors")

        # Store the current date in the job configuration for future continuous jobs
        # This will be used as the starting point for continuous processing
        today = Date.utc_today()

        # Update the job configuration with the registration date
        update_job_config_with_registration_date(job_config.id, today)

        # Return success
        :ok

      {:error, reason} ->
        Logger.error("Error processing historical invoices: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Processes continuous invoices for a user (since registration or last run).
  This is intended to be run on a recurring schedule.
  """
  def process_continuous_invoices(user, job_config) do
    Logger.info("Processing continuous invoices for user #{user.email}")

    # Get the registration date from the job configuration or use a recent date as fallback
    registration_date = get_registration_date_from_config(job_config)

    # Build a query for invoices since the registration date
    query = API.build_continuous_invoice_query(registration_date)

    # Get max results from job configuration or use a default
    max_results = get_in(job_config.config, ["max_results"]) || 20

    Logger.info("Continuous query: #{query}")
    Logger.info("Max results: #{max_results}")

    # Process the attachments
    case XmlAttachmentProcessor.process_xml_attachments(user,
           query: query,
           max_results: max_results,
           callback: &handle_xml_data/4
         ) do
      {:ok, results} ->
        processed_count = Enum.count(results, & &1.processed)
        error_count = Enum.count(results, & &1.error)

        Logger.info("Processed #{processed_count} new invoices with #{error_count} errors")

        # Return success
        :ok

      {:error, reason} ->
        Logger.error("Error processing continuous invoices: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Processes invoices using the regular method (backward compatibility).
  """
  def process_regular_invoices(user, job_config) do
    Logger.info("Processing Gmail XML attachments for user #{user.email} (regular mode)")

    # Get options from job configuration
    query =
      get_in(job_config.config, ["query"]) ||
        "has:attachment filename:xml {factura OR Factura OR FACTURA}"

    max_results = get_in(job_config.config, ["max_results"]) || 10

    Logger.info("Regular query: #{query}")
    Logger.info("Max results: #{max_results}")

    # Process the attachments
    case XmlAttachmentProcessor.process_xml_attachments(user,
           query: query,
           max_results: max_results,
           callback: &handle_xml_data/4
         ) do
      {:ok, results} ->
        processed_count = Enum.count(results, & &1.processed)
        error_count = Enum.count(results, & &1.error)

        Logger.info("Processed #{processed_count} XML attachments with #{error_count} errors")

        # Return success
        :ok

      {:error, reason} ->
        Logger.error("Error processing Gmail XML attachments: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    with {:ok, user} <- get_user(user_id) do
      Logger.info("Processing Gmail XML attachments for user #{user.email} (direct call)")

      # Use the same case-insensitive query as the job configuration
      query = "has:attachment filename:xml {factura OR Factura OR FACTURA}"

      case XmlAttachmentProcessor.process_xml_attachments(user,
             query: query,
             callback: &handle_xml_data/4
           ) do
        {:ok, results} ->
          processed_count = Enum.count(results, & &1.processed)
          error_count = Enum.count(results, & &1.error)

          Logger.info("Processed #{processed_count} XML attachments with #{error_count} errors")

          :ok

        {:error, reason} ->
          Logger.error("Error processing Gmail XML attachments: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Error in GmailXmlAttachmentWorker: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp get_job_configuration(id) do
    case Jobs.get_job_configuration!(id) do
      nil -> {:error, :job_configuration_not_found}
      job_config -> {:ok, job_config}
    end
  rescue
    Ecto.NoResultsError -> {:error, :job_configuration_not_found}
  end

  defp get_user(user_id) do
    case Accounts.get_user(user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp update_job_config_with_registration_date(job_config_id, date) do
    # Get the job configuration
    with job_config <- Jobs.get_job_configuration!(job_config_id) do
      # Get the current config or initialize an empty map
      config = job_config.config || %{}

      # Add the registration date to the config
      updated_config = Map.put(config, "registration_date", Date.to_iso8601(date))

      # Update the job configuration
      Jobs.update_job_configuration(job_config, %{config: updated_config})
    end
  end

  defp get_registration_date_from_config(job_config) do
    # Get the registration date from the config or use a fallback
    case get_in(job_config.config, ["registration_date"]) do
      nil ->
        # If no registration date is found, use a recent date as fallback
        # This ensures we don't try to process all emails ever
        Date.add(Date.utc_today(), -30)

      date_str when is_binary(date_str) ->
        # Parse the ISO 8601 date string
        case Date.from_iso8601(date_str) do
          {:ok, date} -> date
          # Fallback if parsing fails
          _ -> Date.add(Date.utc_today(), -30)
        end
    end
  end

  defp handle_xml_data(parsed_xml, filename, message_id, storage_key) do
    # Use the InvoiceProcessor to save the invoice data
    alias Comparoya.Gmail.InvoiceProcessor

    Logger.info("Processing invoice data from file #{filename} in message #{message_id}")
    Logger.info("File stored at: #{storage_key}")

    case parsed_xml do
      %{invoice: _, business_entity: _, items: _, metadata: _} = invoice_data ->
        # This is an invoice XML, process it
        case InvoiceProcessor.save_invoice(invoice_data, nil, storage_key) do
          {:ok, result} ->
            Logger.info("Successfully processed invoice #{result.invoice.invoice_number}")
            :ok

          {:error, reason} ->
            Logger.error("Failed to process invoice: #{reason}")
            {:error, reason}
        end

      _ ->
        # This is not an invoice XML, log and continue
        Logger.warning("XML file #{filename} is not a recognized invoice format")
        :ok
    end
  end
end
