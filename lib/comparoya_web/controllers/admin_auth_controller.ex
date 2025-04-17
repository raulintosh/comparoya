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

  def change_password_form(conn, _params) do
    render(conn, :change_password_form, error_message: nil)
  end

  def change_password(conn, %{
        "user" => %{
          "current_password" => current_password,
          "new_password" => new_password,
          "confirm_password" => confirm_password
        }
      }) do
    user = conn.assigns.current_admin

    cond do
      new_password != confirm_password ->
        conn
        |> put_flash(:error, "New password and confirmation do not match")
        |> render(:change_password_form,
          error_message: "New password and confirmation do not match"
        )

      String.length(new_password) < 6 ->
        conn
        |> put_flash(:error, "Password must be at least 6 characters long")
        |> render(:change_password_form,
          error_message: "Password must be at least 6 characters long"
        )

      true ->
        case Accounts.change_user_password(user, current_password, new_password) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, "Password changed successfully")
            |> redirect(to: ~p"/dashboard")

          {:error, :invalid_current_password} ->
            conn
            |> put_flash(:error, "Current password is incorrect")
            |> render(:change_password_form, error_message: "Current password is incorrect")

          {:error, changeset} ->
            conn
            |> put_flash(:error, "Failed to change password")
            |> render(:change_password_form,
              error_message: "Failed to change password: #{inspect(changeset.errors)}"
            )
        end
    end
  end
end
