defmodule Comparoya.Workers.GmailXmlAttachmentWorker do
  @moduledoc """
  Worker for processing Gmail XML attachments.
  """

  use Oban.Worker, queue: :gmail, max_attempts: 3

  require Logger
  alias Comparoya.Accounts
  alias Comparoya.Jobs
  alias Comparoya.Gmail.XmlAttachmentProcessor

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"job_configuration_id" => job_configuration_id}}) do
    with {:ok, job_config} <- get_job_configuration(job_configuration_id),
         {:ok, user} <- get_user(job_config.user_id) do
      Logger.info("Processing Gmail XML attachments for user #{user.email}")

      # Get options from job configuration
      query =
        get_in(job_config.config, ["query"]) ||
          "has:attachment filename:xml {factura OR Factura OR FACTURA}"

      max_results = get_in(job_config.config, ["max_results"]) || 10
      IO.inspect(query, label: "Query")
      IO.inspect(max_results, label: "Max Results")
      # Process the attachments
      case XmlAttachmentProcessor.process_xml_attachments(user,
             query: query,
             max_results: max_results,
             callback: &handle_xml_data/4
           ) do
        {:ok, results} ->
          # Update the last run timestamp
          Jobs.update_last_run_at(job_configuration_id)

          processed_count = Enum.count(results, & &1.processed)
          error_count = Enum.count(results, & &1.error)

          Logger.info("Processed #{processed_count} XML attachments with #{error_count} errors")

          # Return success
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
