defmodule ComparoyaWeb.AdminAuthController do
  use ComparoyaWeb, :controller

  alias Comparoya.Accounts
  alias Comparoya.Accounts.User

  def login_form(conn, _params) do
    render(conn, :login_form, error_message: nil)
  end

  def login(conn, %{"user" => %{"username" => username, "password" => password}}) do
    case Accounts.authenticate_user(username, password) do
      {:ok, user} ->
        if Accounts.is_admin?(user) do
          conn
          |> put_session(:admin_user_id, user.id)
          |> configure_session(renew: true)
          |> put_flash(:info, "Welcome back, #{user.name || user.username}!")
          |> redirect(to: ~p"/dashboard")
        else
          conn
          |> put_flash(:error, "You do not have admin privileges.")
          |> render(:login_form, error_message: "You do not have admin privileges.")
        end

      {:error, :invalid_username} ->
        conn
        |> put_flash(:error, "Invalid username or password")
        |> render(:login_form, error_message: "Invalid username or password")

      {:error, :invalid_password} ->
        conn
        |> put_flash(:error, "Invalid username or password")
        |> render(:login_form, error_message: "Invalid username or password")
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:admin_user_id)
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: ~p"/admin/login")
  end

  def register_form(conn, _params) do
    changeset = Accounts.User.registration_changeset(%User{}, %{})
    render(conn, :register_form, changeset: changeset)
  end

  def register(conn, %{"user" => user_params}) do
    case Accounts.register_admin(user_params) do
      {:ok, user} ->
        conn
        |> put_session(:admin_user_id, user.id)
        |> configure_session(renew: true)
        |> put_flash(:info, "Admin account created successfully.")
        |> redirect(to: ~p"/dashboard")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :register_form, changeset: changeset)
    end
  end
end
