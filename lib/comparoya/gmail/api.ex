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

  ## Examples

      iex> list_messages(access_token, q: "has:attachment")
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

  # Private functions

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
