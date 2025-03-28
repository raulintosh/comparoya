defmodule ComparoyaWeb.Plugs.AdminAuth do
  @moduledoc """
  Authentication plugs for admin users.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias Comparoya.Accounts

  @doc """
  Fetches the current admin user from the session and assigns it to the connection.
  """
  def fetch_current_admin(conn, _opts) do
    admin_id = get_session(conn, :admin_user_id)

    if admin_id do
      user = Comparoya.Repo.get(Comparoya.Accounts.User, admin_id)

      if user && Accounts.is_admin?(user) do
        assign(conn, :current_admin, user)
      else
        assign(conn, :current_admin, nil)
      end
    else
      assign(conn, :current_admin, nil)
    end
  end

  @doc """
  Ensures that a user is authenticated as an admin.
  If not, redirects to the admin login page.
  """
  def require_admin(conn, _opts) do
    if conn.assigns[:current_admin] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in as an admin to access this page.")
      |> redirect(to: "/admin/login")
      |> halt()
    end
  end
end
