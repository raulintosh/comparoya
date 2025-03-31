defmodule Comparoya.Gmail.XmlAttachmentProcessor do
  @moduledoc """
  Module for processing XML attachments from Gmail.
  """

  require Logger
  import SweetXml
  alias Comparoya.Gmail.API
  alias Comparoya.Accounts.User
  alias ExAws.S3

  @doc """
  Processes XML attachments for a user.

  ## Parameters

  * `user` - The user to process attachments for
  * `opts` - Options for processing
    * `:query` - Gmail search query (default: "has:attachment filename:xml factura")
    * `:max_results` - Maximum number of messages to process (default: 10)
    * `:callback` - Function to call with the parsed XML (default: nil)

  ## Returns

  * `{:ok, results}` - Where results is a list of processed attachments
  * `{:error, reason}` - If an error occurs
  """
  def process_xml_attachments(%User{} = user, opts \\ []) do
    query = Keyword.get(opts, :query, "has:attachment filename:xml factura")
    max_results = Keyword.get(opts, :max_results, 10)
    callback = Keyword.get(opts, :callback)

    with {:ok, access_token} <- ensure_valid_token(user),
         {:ok, messages} <- API.list_messages(access_token, q: query, maxResults: max_results) do
      results = process_messages(messages, access_token, callback)
      {:ok, results}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Processes a specific message for XML attachments.

  ## Parameters

  * `message_id` - The ID of the message to process
  * `access_token` - The access token for the Gmail API
  * `callback` - Function to call with the parsed XML (default: nil)

  ## Returns

  * `{:ok, results}` - Where results is a list of processed attachments
  * `{:error, reason}` - If an error occurs
  """
  def process_message(message_id, access_token, callback \\ nil) do
    with {:ok, message} <- API.get_message(access_token, message_id, format: "full") do
      attachments = extract_xml_attachments(message)

      results =
        Enum.map(attachments, fn attachment ->
          process_attachment(message_id, attachment, access_token, callback)
        end)

      {:ok, results}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp ensure_valid_token(
         %User{provider_token: token, provider: "google", provider_id: _provider_id} = user
       ) do
    # First, try to use the token to see if it's still valid
    case API.list_messages(token, maxResults: 1) do
      {:ok, _} ->
        # Token is valid, return it
        {:ok, token}

      {:error, :unauthorized} ->
        # Token is expired, refresh it
        refresh_token(user)

      {:error, reason} ->
        # Some other error occurred
        Logger.error("Error checking token validity: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_valid_token(%User{provider: provider}) do
    {:error, "Provider #{provider} not supported for Gmail API access"}
  end

  defp refresh_token(%User{refresh_token: refresh_token} = user) when not is_nil(refresh_token) do
    # Get Google OAuth credentials from config
    client_id = get_google_client_id()
    client_secret = get_google_client_secret()

    # Use the refresh token from the user record
    # Refresh the token
    case API.refresh_access_token(refresh_token, client_id, client_secret) do
      {:ok, %{"access_token" => new_token}} ->
        # Update the user's token in the database
        case Comparoya.Accounts.update_user(user, %{provider_token: new_token}) do
          {:ok, updated_user} ->
            {:ok, updated_user.provider_token}

          {:error, changeset} ->
            Logger.error("Failed to update user token: #{inspect(changeset)}")
            {:error, "Failed to update user token"}
        end

      {:error, reason} ->
        Logger.error("Failed to refresh token: #{inspect(reason)}")
        {:error, "Failed to refresh token"}
    end
  end

  defp refresh_token(%User{refresh_token: nil} = _user) do
    {:error, "No refresh token available for this user. User needs to re-authenticate."}
  end

  # Helper functions to get Google OAuth credentials
  defp get_google_client_id do
    Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id]
  end

  defp get_google_client_secret do
    Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret]
  end

  # Helper function to add padding to Base64 data if needed
  defp pad_base64(data) do
    case rem(String.length(data), 4) do
      0 -> data
      1 -> data <> "==="
      2 -> data <> "=="
      3 -> data <> "="
    end
  end

  # Upload file to DigitalOcean Spaces
  defp upload_to_spaces(data, filename) do
    # Generate a unique key for the file in the "facturas" folder
    key = "facturas/#{DateTime.utc_now() |> DateTime.to_iso8601()}_#{filename}"

    # Upload the file to DigitalOcean Spaces
    try do
      result =
        S3.put_object("comparoya", key, data)
        |> ExAws.request()

      case result do
        {:ok, _response} ->
          Logger.info("Successfully uploaded #{filename} to DigitalOcean Spaces")
          {:ok, key}

        {:error, error} ->
          Logger.error("Failed to upload #{filename} to DigitalOcean Spaces: #{inspect(error)}")
          {:error, "Failed to upload to DigitalOcean Spaces: #{inspect(error)}"}
      end
    rescue
      e ->
        Logger.error("Error uploading to DigitalOcean Spaces: #{inspect(e)}")
        {:error, "Error uploading to DigitalOcean Spaces: #{inspect(e)}"}
    end
  end

  defp process_messages(%{"messages" => messages}, access_token, callback) do
    Enum.flat_map(messages, fn %{"id" => message_id} ->
      case process_message(message_id, access_token, callback) do
        {:ok, results} -> results
        {:error, _} -> []
      end
    end)
  end

  defp process_messages(_, _, _), do: []

  defp extract_xml_attachments(message) do
    parts = get_in(message, ["payload", "parts"]) || []

    Enum.filter(parts, fn part ->
      filename = get_in(part, ["filename"]) || ""
      mime_type = get_in(part, ["mimeType"]) || ""

      String.ends_with?(filename, ".xml") ||
        mime_type == "application/xml" ||
        mime_type == "text/xml"
    end)
  end

  defp process_attachment(message_id, attachment, access_token, callback) do
    attachment_id = get_in(attachment, ["body", "attachmentId"])
    filename = get_in(attachment, ["filename"])

    result = %{
      message_id: message_id,
      filename: filename,
      processed: false,
      error: nil,
      data: nil,
      storage_key: nil
    }

    if attachment_id do
      case API.get_attachment(access_token, message_id, attachment_id) do
        {:ok, %{"data" => data}} ->
          try do
            # Add debug logging to see what's happening
            Logger.debug(
              "Attempting to decode Base64 data: #{inspect(String.slice(data, 0, 100))}..."
            )

            # Try different Base64 decoding approaches
            decoded_data =
              case Base.decode64(data, ignore: :whitespace) do
                {:ok, decoded} ->
                  decoded

                :error ->
                  # Try with padding
                  padded_data = pad_base64(data)

                  case Base.decode64(padded_data, ignore: :whitespace) do
                    {:ok, decoded} ->
                      decoded

                    :error ->
                      # Try with URL-safe alphabet
                      case Base.url_decode64(data, padding: false) do
                        {:ok, decoded} ->
                          decoded

                        :error ->
                          Logger.error("Error decoding Base64 data after multiple attempts")
                          nil
                      end
                  end
              end

            if decoded_data do
              # Upload the attachment to DigitalOcean Spaces
              upload_result = upload_to_spaces(decoded_data, filename)

              case upload_result do
                {:ok, storage_key} ->
                  # Parse the XML data
                  parsed_xml = parse_xml(decoded_data)

                  if callback, do: callback.(parsed_xml, filename, message_id, storage_key)

                  %{result | processed: true, data: parsed_xml, storage_key: storage_key}

                {:error, upload_error} ->
                  Logger.error("Error uploading attachment: #{upload_error}")
                  %{result | error: "Error uploading attachment: #{upload_error}"}
              end
            else
              %{result | error: "Error decoding Base64 data"}
            end
          rescue
            e ->
              Logger.error("Error processing XML attachment: #{inspect(e)}")
              %{result | error: "Error processing XML: #{inspect(e)}"}
          end

        {:error, reason} ->
          Logger.error("Error fetching attachment: #{inspect(reason)}")
          %{result | error: "Error fetching attachment: #{inspect(reason)}"}
      end
    else
      %{result | error: "No attachment ID found"}
    end
  end

  defp parse_xml(xml_data) do
    try do
      # Parse the XML invoice data with better error handling
      parsed_xml =
        try do
          xml_data |> parse()
        rescue
          e in ArgumentError ->
            # Handle specific error for non-alphabet characters
            if String.contains?(Exception.message(e), "non-alphabet character") do
              # Try to clean the XML data by removing problematic characters
              cleaned_xml = clean_xml_data(xml_data)
              cleaned_xml |> parse()
            else
              reraise e, __STACKTRACE__
            end
        end

      # Extract invoice data
      invoice_data = extract_invoice_data(parsed_xml)

      # Extract business entity data
      business_entity = extract_business_entity(parsed_xml)

      # Extract invoice items
      items = extract_invoice_items(parsed_xml)

      # Extract invoice metadata
      metadata = extract_invoice_metadata(parsed_xml)

      # Find user by email
      user_id = find_user_id_by_email(parsed_xml)

      # Return structured data
      %{
        invoice: invoice_data,
        business_entity: business_entity,
        items: items,
        metadata: metadata,
        user_id: user_id,
        raw_xml: xml_data
      }
    rescue
      e ->
        Logger.error("Error parsing XML: #{inspect(e)}")
        reraise e, __STACKTRACE__
    end
  end

  # Helper function to clean XML data by removing problematic characters
  defp clean_xml_data(xml_data) do
    # Replace problematic characters with their XML entity equivalents
    xml_data
    |> String.replace("-", "&#45;")
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  # Extract invoice data from XML
  defp extract_invoice_data(xml) do
    # Get invoice identification
    invoice_number =
      "#{xpath(xml, ~x"//gTimb/dEst/text()"s)}-#{xpath(xml, ~x"//gTimb/dPunExp/text()"s)}-#{xpath(xml, ~x"//gTimb/dNumDoc/text()"s)}"

    invoice_type = xpath(xml, ~x"//gTimb/iTiDE/text()"s)
    invoice_type_description = xpath(xml, ~x"//gTimb/dDesTiDE/text()"s)

    # Get dates
    emission_date = parse_datetime(xpath(xml, ~x"//gDatGralOpe/dFeEmiDE/text()"s))
    signature_date = parse_datetime(xpath(xml, ~x"//dFecFirma/text()"s))

    # Get security code
    security_code = xpath(xml, ~x"//gOpeDE/dCodSeg/text()"s)

    # Get recipient information
    recipient_ruc = xpath(xml, ~x"//gDatGralOpe/gDatRec/dRucRec/text()"s)
    recipient_name = xpath(xml, ~x"//gDatGralOpe/gDatRec/dNomRec/text()"s)
    recipient_email = xpath(xml, ~x"//gDatGralOpe/gDatRec/dEmailRec/text()"s)

    # Get totals
    total_amount = parse_decimal(xpath(xml, ~x"//gTotSub/dTotGralOpe/text()"s))
    total_discount = parse_decimal(xpath(xml, ~x"//gTotSub/dTotDesc/text()"s))
    total_vat = parse_decimal(xpath(xml, ~x"//gTotSub/dTotIVA/text()"s))

    %{
      invoice_number: invoice_number,
      invoice_type: invoice_type,
      invoice_type_description: invoice_type_description,
      emission_date: emission_date,
      signature_date: signature_date,
      security_code: security_code,
      recipient_ruc: recipient_ruc,
      recipient_name: recipient_name,
      recipient_email: recipient_email,
      total_amount: total_amount,
      total_discount: total_discount,
      total_vat: total_vat
    }
  end

  # Extract business entity data from XML
  defp extract_business_entity(xml) do
    %{
      ruc: xpath(xml, ~x"//gDatGralOpe/gEmis/dRucEm/text()"s),
      name: xpath(xml, ~x"//gDatGralOpe/gEmis/dNomEmi/text()"s),
      address: xpath(xml, ~x"//gDatGralOpe/gEmis/dDirEmi/text()"s),
      department_code: xpath(xml, ~x"//gDatGralOpe/gEmis/cDepEmi/text()"s),
      department_description: xpath(xml, ~x"//gDatGralOpe/gEmis/dDesDepEmi/text()"s),
      district_code: xpath(xml, ~x"//gDatGralOpe/gEmis/cDisEmi/text()"s),
      district_description: xpath(xml, ~x"//gDatGralOpe/gEmis/dDesDisEmi/text()"s),
      city_code: xpath(xml, ~x"//gDatGralOpe/gEmis/cCiuEmi/text()"s),
      city_description: xpath(xml, ~x"//gDatGralOpe/gEmis/dDesCiuEmi/text()"s),
      phone: xpath(xml, ~x"//gDatGralOpe/gEmis/dTelEmi/text()"s),
      email: xpath(xml, ~x"//gDatGralOpe/gEmis/dEmailE/text()"s),
      economic_activity_code: xpath(xml, ~x"//gDatGralOpe/gEmis/gActEco[1]/cActEco/text()"s),
      economic_activity_description:
        xpath(xml, ~x"//gDatGralOpe/gEmis/gActEco[1]/dDesActEco/text()"s)
    }
  end

  # Extract invoice items from XML
  defp extract_invoice_items(xml) do
    xml
    |> xpath(~x"//gDtipDE/gCamItem"l)
    |> Enum.map(fn item ->
      # Extract product reference data
      product_reference = %{
        internal_code: xpath(item, ~x"./dCodInt/text()"s),
        description: xpath(item, ~x"./dDesProSer/text()"s),
        unit_of_measurement: %{
          code: xpath(item, ~x"./cUniMed/text()"s),
          description: xpath(item, ~x"./dDesUniMed/text()"s)
        }
      }

      # Extract item transaction data
      %{
        description: xpath(item, ~x"./dDesProSer/text()"s),
        quantity: parse_decimal(xpath(item, ~x"./dCantProSer/text()"s)),
        unit_price: parse_decimal(xpath(item, ~x"./gValorItem/dPUniProSer/text()"s)),
        discount_amount:
          parse_decimal(xpath(item, ~x"./gValorItem/gValorRestaItem/dDescItem/text()"s)),
        discount_percentage:
          parse_decimal(xpath(item, ~x"./gValorItem/gValorRestaItem/dPorcDesIt/text()"s)),
        total_amount:
          parse_decimal(xpath(item, ~x"./gValorItem/gValorRestaItem/dTotOpeItem/text()"s)),
        vat_rate: parse_decimal(xpath(item, ~x"./gCamIVA/dTasaIVA/text()"s)),
        vat_base: parse_decimal(xpath(item, ~x"./gCamIVA/dBasGravIVA/text()"s)),
        vat_amount: parse_decimal(xpath(item, ~x"./gCamIVA/dLiqIVAItem/text()"s)),
        product_reference: product_reference
      }
    end)
  end

  # Extract invoice metadata from XML
  defp extract_invoice_metadata(xml) do
    payment_condition = xpath(xml, ~x"//gDtipDE/gCamCond/iCondOpe/text()"s)
    payment_condition_description = xpath(xml, ~x"//gDtipDE/gCamCond/dDCondOpe/text()"s)

    # Get payment information
    payment_type = xpath(xml, ~x"//gDtipDE/gCamCond/gPaConEIni/iTiPago/text()"s)
    payment_type_description = xpath(xml, ~x"//gDtipDE/gCamCond/gPaConEIni/dDesTiPag/text()"s)

    payment_amount =
      parse_decimal(xpath(xml, ~x"//gDtipDE/gCamCond/gPaConEIni/dMonTiPag/text()"s))

    %{
      payment_condition: payment_condition,
      payment_condition_description: payment_condition_description,
      payment_type: payment_type,
      payment_type_description: payment_type_description,
      payment_amount: payment_amount
    }
  end

  # Find user ID by email from XML
  defp find_user_id_by_email(xml) do
    recipient_email = xpath(xml, ~x"//gDatGralOpe/gDatRec/dEmailRec/text()"s)

    case Comparoya.Invoices.find_user_by_email(recipient_email) do
      nil -> nil
      user -> user.id
    end
  end

  # Helper function to parse datetime strings
  defp parse_datetime(datetime_str) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  # Helper function to parse decimal strings
  defp parse_decimal(decimal_str) do
    case Decimal.parse(decimal_str) do
      {decimal, ""} -> decimal
      _ -> Decimal.new("0")
    end
  end
end
