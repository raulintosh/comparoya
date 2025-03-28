defmodule ComparoyaWeb.Plugs.AuthOrAdmin do
  @moduledoc """
  Plug to check if a user is either authenticated or an admin.
  """
  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Ensures that a user is either authenticated or an admin.
  If not, redirects to the login page.
  """
  def require_authenticated_user_or_admin(conn, _opts) do
    if conn.assigns[:current_user] || conn.assigns[:current_admin] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
