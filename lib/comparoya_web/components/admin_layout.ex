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
      {render_slot(@inner_block)}
    </div>
    """
  end
end
