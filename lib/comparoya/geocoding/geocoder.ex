defmodule Comparoya.Geocoding.Geocoder do
  @moduledoc """
  Service for geocoding addresses using Google Maps API.
  """

  require Logger

  @doc """
  Geocodes an address using Google Maps API.e

  Returns `{:ok, %{latitude: float, longitude: float}}` on success,
  or `{:error, reason}` on failure.
  """
  def geocode(address) when is_binary(address) and address != "" do
    api_key = System.get_env("GOOGLE_MAPS_API_KEY")

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
      # IO.inspect(url, label: "Geocoding URL")

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
        Logger.error("""
        Geocoding API HTTP error:
        Status code: #{status_code}
        Response body: #{body}
        This could indicate an issue with the Google Maps API service or your request.
        Check the response body for specific error details from Google.
        """)

        {:error, :api_error}

      {:error, %HTTPoison.Error{reason: :timeout}} ->
        Logger.error("""
        Geocoding request timed out after 10 seconds.
        This could be due to:
        1. Slow internet connection
        2. Google Maps API service experiencing high latency
        3. Complex geocoding request requiring more processing time

        Consider increasing the timeout value if this happens frequently.
        """)

        {:error, :timeout}

      {:error, %HTTPoison.Error{reason: :econnrefused}} ->
        Logger.error("""
        Geocoding connection refused.
        This indicates a network connectivity issue:
        1. No internet connection
        2. DNS resolution failure for maps.googleapis.com
        3. Firewall or proxy blocking outbound connections to Google APIs
        4. Google Maps API endpoint is unreachable

        Check your network configuration and connectivity to Google services.
        """)

        {:error, :network_error}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("""
        Geocoding request network error:
        Error reason: #{inspect(reason)}

        This could be due to:
        1. Intermittent network issues
        2. SSL/TLS certificate validation problems
        3. DNS resolution failures
        4. Proxy configuration issues
        5. Other HTTP client errors

        Check your network configuration and try again later.
        """)

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
        Logger.info("""
        Geocoding returned ZERO_RESULTS for the address.
        This means Google could not find any location matching the provided address.
        Possible reasons:
        1. The address is incomplete or incorrect
        2. The address is in a format Google doesn't recognize
        3. The location doesn't exist or is too new to be in Google's database

        Try providing a more complete or accurate address.
        """)

        {:error, :no_results}

      {:ok, %{"status" => "OVER_QUERY_LIMIT"}} ->
        Logger.error("""
        Geocoding API returned OVER_QUERY_LIMIT.
        This means you've exceeded your Google Maps API usage limits.
        Possible solutions:
        1. Wait and try again later
        2. Increase your Google Maps API quota in the Google Cloud Console
        3. Implement rate limiting in your application
        4. Enable billing for your Google Cloud project if not already enabled

        Check your usage in the Google Cloud Console: https://console.cloud.google.com/
        """)

        {:error, :over_query_limit}

      {:ok, %{"status" => "REQUEST_DENIED"}} ->
        Logger.error("""
        Geocoding API returned REQUEST_DENIED.
        This means your request was rejected by Google.
        Common reasons:
        1. Invalid API key
        2. API key not authorized for Geocoding API
        3. API key has restrictions (IP, referrer, etc.) that are blocking your request
        4. Billing not enabled for your Google Cloud project

        Check your API key configuration in the Google Cloud Console.
        """)

        {:error, :request_denied}

      {:ok, %{"status" => "INVALID_REQUEST"}} ->
        Logger.error("""
        Geocoding API returned INVALID_REQUEST.
        This means your request was malformed.
        Possible issues:
        1. Missing required parameters
        2. Invalid parameter values
        3. Malformed address string

        Check the address format and ensure all required parameters are provided.
        """)

        {:error, :invalid_request}

      {:ok, %{"status" => status}} ->
        Logger.error("""
        Geocoding API returned unknown status: #{status}
        This is an unexpected response from the Google Maps API.
        Please check the Google Maps API documentation for this status code.
        If this persists, contact Google Maps API support.
        """)

        {:error, :unknown_error}

      {:error, error} ->
        Logger.error("""
        Failed to parse Geocoding API response: #{inspect(error)}
        This could be due to:
        1. Invalid JSON in the response
        2. Unexpected response format
        3. Internal error in the JSON parsing library

        Check the raw response and ensure it's valid JSON.
        """)

        {:error, :parse_error}
    end
  end
end
