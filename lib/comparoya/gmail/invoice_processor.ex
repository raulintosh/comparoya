defmodule Comparoya.Gmail.InvoiceProcessor do
  @moduledoc """
  Module for processing invoice XML attachments from Gmail and saving them to the database.
  """

  require Logger
  alias Comparoya.Gmail.XmlAttachmentProcessor
  alias Comparoya.Invoices
  alias Comparoya.Accounts.User

  @doc """
  Processes invoice XML attachments for a user and saves them to the database.

  ## Parameters

  * `user` - The user to process attachments for
  * `opts` - Options for processing
    * `:query` - Gmail search query (default: "has:attachment filename:xml factura")
    * `:max_results` - Maximum number of messages to process (default: 10)

  ## Returns

  * `{:ok, results}` - Where results is a list of processed invoices
  * `{:error, reason}` - If an error occurs
  """
  def process_invoice_attachments(%User{} = user, opts \\ []) do
    # Define the callback function to save invoices
    callback = fn parsed_xml, _filename, _message_id, storage_key ->
      save_invoice(parsed_xml, user.id, storage_key)
    end

    # Add the callback to the options
    opts = Keyword.put(opts, :callback, callback)

    # Process the XML attachments
    XmlAttachmentProcessor.process_xml_attachments(user, opts)
  end

  @doc """
  Processes a specific message for invoice XML attachments and saves them to the database.

  ## Parameters

  * `message_id` - The ID of the message to process
  * `access_token` - The access token for the Gmail API
  * `user_id` - The ID of the user to associate with the invoices

  ## Returns

  * `{:ok, results}` - Where results is a list of processed invoices
  * `{:error, reason}` - If an error occurs
  """
  def process_invoice_message(message_id, access_token, user_id) do
    # Define the callback function to save invoices
    callback = fn parsed_xml, _filename, _message_id, storage_key ->
      save_invoice(parsed_xml, user_id, storage_key)
    end

    # Process the message
    XmlAttachmentProcessor.process_message(message_id, access_token, callback)
  end

  @doc """
  Saves an invoice to the database.

  ## Parameters

  * `parsed_xml` - The parsed XML data
  * `user_id` - The ID of the user to associate with the invoice (optional)
  * `storage_key` - The storage key for the XML file in DigitalOcean Spaces (optional)

  ## Returns

  * `{:ok, result}` - Where result is the created invoice
  * `{:error, reason}` - If an error occurs
  """
  def save_invoice(parsed_xml, user_id, storage_key \\ nil) do
    # Set the user ID if not already set
    parsed_xml =
      if is_nil(parsed_xml.user_id) do
        Map.put(parsed_xml, :user_id, user_id)
      else
        parsed_xml
      end

    # Add the storage key if provided
    parsed_xml =
      if storage_key do
        Map.put(parsed_xml, :storage_key, storage_key)
      else
        parsed_xml
      end

    # Check if the invoice already exists
    case Invoices.find_invoice_by_number_and_entity_ruc(
           parsed_xml.invoice.invoice_number,
           parsed_xml.business_entity.ruc
         ) do
      nil ->
        # Invoice doesn't exist, create it
        case Invoices.create_invoice(parsed_xml) do
          {:ok, result} ->
            Logger.info("Created invoice #{result.invoice.invoice_number}")
            {:ok, result}

          {:error, operation, value, _changes} ->
            Logger.error("Failed to create invoice: #{operation} - #{inspect(value)}")
            {:error, "Failed to create invoice: #{operation}"}
        end

      invoice ->
        # Invoice already exists
        Logger.info("Invoice #{invoice.invoice_number} already exists")
        {:ok, invoice}
    end
  end
end
