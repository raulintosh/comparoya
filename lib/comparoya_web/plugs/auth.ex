defmodule ComparoyaWeb.Plugs.Auth do
  @moduledoc """
  Authentication plugs for the application.
  """
  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Fetches the current user from the session and assigns it to the connection.
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :current_user_id)

    if user_id do
      user = Comparoya.Repo.get(Comparoya.Accounts.User, user_id)
      assign(conn, :current_user, user)
    else
      assign(conn, :current_user, nil)
    end
  end

  @doc """
  Ensures that a user is authenticated.
  If not, redirects to the login page.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
