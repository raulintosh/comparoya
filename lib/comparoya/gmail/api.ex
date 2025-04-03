defmodule Comparoya.Gmail.API do
  @moduledoc """
  Module for interacting with the Gmail API.
  """

  require Logger
  alias HTTPoison.{Response, Error}

  @gmail_base_url "https://www.googleapis.com/gmail/v1"
  @user_id "me"

  @doc """
  Lists messages in the user's Gmail account.

  ## Options

  * `:q` - Search query (e.g., "has:attachment")
  * `:max_results` - Maximum number of messages to return
  * `:page_token` - Page token for pagination

  ## Date Filtering

  You can use the following Gmail search operators for date filtering:
  * `after:YYYY/MM/DD` - Messages received after the specified date
  * `before:YYYY/MM/DD` - Messages received before the specified date
  * `older:YYYY/MM/DD` - Messages older than the specified date
  * `newer:YYYY/MM/DD` - Messages newer than the specified date

  ## Examples

      iex> list_messages(access_token, q: "has:attachment")
      {:ok, %{"messages" => [%{"id" => "123", ...}, ...], "nextPageToken" => "token"}}

      iex> list_messages(access_token, q: "has:attachment after:2025/01/01 before:2025/12/31")
      {:ok, %{"messages" => [%{"id" => "123", ...}, ...], "nextPageToken" => "token"}}
  """
  def list_messages(access_token, opts \\ []) do
    query_params = build_query_params(opts)

    "#{@gmail_base_url}/users/#{@user_id}/messages#{query_params}"
    |> get(access_token)
  end

  @doc """
  Gets a specific message from the user's Gmail account.

  ## Options

  * `:format` - Format of the message (e.g., "full", "metadata", "minimal", "raw")

  ## Examples

      iex> get_message(access_token, "123", format: "full")
      {:ok, %{"id" => "123", "payload" => %{...}, ...}}

  """
  def get_message(access_token, message_id, opts \\ []) do
    query_params = build_query_params(opts)

    "#{@gmail_base_url}/users/#{@user_id}/messages/#{message_id}#{query_params}"
    |> get(access_token)
  end

  @doc """
  Gets an attachment from a message.

  ## Examples

      iex> get_attachment(access_token, "123", "attachment_id")
      {:ok, %{"data" => "base64_encoded_data", ...}}

  """
  def get_attachment(access_token, message_id, attachment_id) do
    "#{@gmail_base_url}/users/#{@user_id}/messages/#{message_id}/attachments/#{attachment_id}"
    |> get(access_token)
  end

  @doc """
  Refreshes an access token using a refresh token.

  ## Examples

      iex> refresh_access_token(refresh_token, client_id, client_secret)
      {:ok, %{"access_token" => "new_token", "expires_in" => 3600, ...}}

  """
  def refresh_access_token(refresh_token, client_id, client_secret) do
    url = "https://oauth2.googleapis.com/token"

    body =
      URI.encode_query(%{
        refresh_token: refresh_token,
        client_id: client_id,
        client_secret: client_secret,
        grant_type: "refresh_token"
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post(url, body, headers) do
      {:ok, %Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %Response{status_code: status_code, body: body}} ->
        {:error, %{status_code: status_code, body: Jason.decode!(body)}}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Builds a Gmail search query for invoices from the current and previous year.

  ## Parameters

  * `base_query` - The base search query (default: "has:attachment filename:xml {factura OR Factura OR FACTURA}")

  ## Returns

  * A Gmail search query string that includes date filters for the current and previous year
  """
  def build_historical_invoice_query(
        base_query \\ "has:attachment filename:xml {factura OR Factura OR FACTURA}"
      ) do
    current_year = Date.utc_today().year
    previous_year = current_year - 1

    # Format: "base_query after:YYYY/01/01 before:YYYY/12/31"
    "#{base_query} after:#{previous_year}/01/01 before:#{current_year}/12/31"
  end

  @doc """
  Builds a Gmail search query for invoices received since a specific date.

  ## Parameters

  * `start_date` - The start date (Date struct or string in format "YYYY/MM/DD")
  * `base_query` - The base search query (default: "has:attachment filename:xml {factura OR Factura OR FACTURA}")

  ## Returns

  * A Gmail search query string that includes a date filter for messages after the start date
  """
  def build_continuous_invoice_query(
        start_date,
        base_query \\ "has:attachment filename:xml {factura OR Factura OR FACTURA}"
      ) do
    date_str = format_date_for_query(start_date)
    "#{base_query} after:#{date_str}"
  end

  # Private functions

  defp format_date_for_query(date) when is_binary(date), do: date

  defp format_date_for_query(%Date{} = date) do
    "#{date.year}/#{String.pad_leading("#{date.month}", 2, "0")}/#{String.pad_leading("#{date.day}", 2, "0")}"
  end

  defp build_query_params(opts) do
    if Enum.empty?(opts) do
      ""
    else
      "?" <> URI.encode_query(opts)
    end
  end

  defp get(url, access_token) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/json"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %Response{status_code: 401}} ->
        {:error, :unauthorized}

      {:ok, %Response{status_code: status_code, body: body}} ->
        Logger.error("Gmail API error: #{status_code} - #{body}")
        {:error, %{status_code: status_code, body: Jason.decode!(body)}}

      {:error, %Error{reason: reason}} ->
        Logger.error("Gmail API request error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
