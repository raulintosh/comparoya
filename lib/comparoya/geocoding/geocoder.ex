defmodule Comparoya.Geocoding.Geocoder do
  @moduledoc """
  Service for geocoding addresses using Google Maps API.
  """

  require Logger

  @doc """
  Geocodes an address using Google Maps API.

  Returns `{:ok, %{latitude: float, longitude: float}}` on success,
  or `{:error, reason}` on failure.
  """
  def geocode(address) when is_binary(address) and address != "" do
    api_key = Application.get_env(:comparoya, :google_maps)[:api_key]

    if is_nil(api_key) or api_key == "" or api_key == "your_api_key_here" do
      Logger.error("""
      Google Maps API key is not configured.
      Please set the GOOGLE_MAPS_API_KEY environment variable or update the config in config/config.exs.
      You can get an API key from the Google Cloud Console: https://console.cloud.google.com/
      Make sure to enable the Geocoding API for your project.
      """)

      {:error, :api_key_missing}
    else
      url = build_geocoding_url(address, api_key)

      case make_request(url) do
        {:ok, body} ->
          result = parse_geocoding_response(body)

          case result do
            {:error, :request_denied} ->
              Logger.error("""
              Google Maps API request was denied. This could be due to:
              1. Invalid API key
              2. API key restrictions (IP, referrer, etc.)
              3. Geocoding API not enabled for your project
              4. Billing not enabled for your Google Cloud project

              Please check your Google Cloud Console: https://console.cloud.google.com/
              """)

              result

            _ ->
              result
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def geocode(_), do: {:error, :invalid_address}

  # Private functions

  defp build_geocoding_url(address, api_key) do
    encoded_address = URI.encode_www_form(address)
    "https://maps.googleapis.com/maps/api/geocode/json?address=#{encoded_address}&key=#{api_key}"
  end

  defp make_request(url) do
    HTTPoison.get(url, [], timeout: 10_000, recv_timeout: 10_000)
    |> case do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status_code: status_code, body: body}} ->
        Logger.error("Geocoding API error: #{status_code}, #{body}")
        {:error, :api_error}

      {:error, %HTTPoison.Error{reason: :timeout}} ->
        Logger.error("Geocoding request timeout")
        {:error, :timeout}

      {:error, %HTTPoison.Error{reason: :econnrefused}} ->
        Logger.error("Geocoding connection refused")
        {:error, :network_error}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Geocoding request error: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp parse_geocoding_response(body) do
    case Jason.decode(body) do
      {:ok, %{"status" => "OK", "results" => [result | _]}} ->
        location = get_in(result, ["geometry", "location"])

        if location do
          {:ok,
           %{
             latitude: location["lat"],
             longitude: location["lng"]
           }}
        else
          {:error, :no_location}
        end

      {:ok, %{"status" => "ZERO_RESULTS"}} ->
        {:error, :no_results}

      {:ok, %{"status" => "OVER_QUERY_LIMIT"}} ->
        {:error, :over_query_limit}

      {:ok, %{"status" => "REQUEST_DENIED"}} ->
        {:error, :request_denied}

      {:ok, %{"status" => "INVALID_REQUEST"}} ->
        {:error, :invalid_request}

      {:ok, %{"status" => status}} ->
        Logger.error("Geocoding API status: #{status}")
        {:error, :unknown_error}

      {:error, _} ->
        {:error, :parse_error}
    end
  end
end
