defmodule ComparoyaWeb.AdminLayout do
  use ComparoyaWeb, :html

  @doc """
  Renders an admin layout with a navigation bar and content.

  ## Examples

      <.admin_layout current_admin={@current_admin}>
        Content goes here
      </.admin_layout>
  """
  attr :current_admin, :map, required: true
  slot :inner_block, required: true

  def admin_layout(assigns) do
    ~H"""
    <div>
      <div class="bg-gray-100 border-b border-gray-200 mb-6">
        <div class="max-w-[85rem] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between py-4">
            <div class="flex items-center space-x-4">
              <span class="text-lg font-semibold text-gray-800">Admin Dashboard</span>
            </div>
            <div class="flex items-center space-x-4">
              <.link
                href={~p"/admin/job_configurations"}
                class="text-gray-600 hover:text-gray-900 font-medium"
              >
                Job Configurations
              </.link>
              <.link href={~p"/admin/geocoding"} class="text-gray-600 hover:text-gray-900 font-medium">
                Geocoding
              </.link>
              <.link
                href={~p"/admin/change_password"}
                class="text-gray-600 hover:text-gray-900 font-medium"
              >
                Change Password
              </.link>
              <.link href={~p"/admin/logout"} class="text-gray-600 hover:text-gray-900 font-medium">
                Logout
              </.link>
            </div>
          </div>
        </div>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
