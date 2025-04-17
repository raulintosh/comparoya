defmodule ComparoyaWeb.AdminGeocodingHTML do
  use ComparoyaWeb, :html

  import ComparoyaWeb.AdminLayout

  embed_templates "admin_geocoding_html/*"

  @doc """
  Returns the CSS class for a status badge.
  """
  def status_badge_class(status) do
    case status do
      "success" ->
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"

      "failed" ->
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"

      "pending" ->
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800"

      _ ->
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
    end
  end
end
