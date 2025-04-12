defmodule ComparoyaWeb.Live.AuthOrAdminLive do
  @moduledoc """
  LiveView hook to check if a user is either authenticated or an admin.
  """
  use ComparoyaWeb, :live_view

  alias Comparoya.Repo
  alias Comparoya.Accounts
  alias Comparoya.Accounts.User

  def on_mount(:require_authenticated_user_or_admin, _params, session, socket) do
    user_id = session["current_user_id"] || Map.get(session, :current_user_id)
    admin_id = session["admin_user_id"] || Map.get(session, :admin_user_id)

    cond do
      user_id && user_id != "" ->
        user = Repo.get(User, user_id)

        if user != nil do
          socket =
            socket
            |> assign(:current_user, user)

          {:cont, socket}
        else
          redirect_with_error(socket)
        end

      admin_id && admin_id != "" ->
        admin = Repo.get(User, admin_id)

        if admin != nil && Accounts.is_admin?(admin) do
          socket =
            socket
            |> assign(:current_user, admin)
            |> assign(:current_admin, admin)

          {:cont, socket}
        else
          redirect_with_error(socket)
        end

      true ->
        redirect_with_error(socket)
    end
  end

  defp redirect_with_error(socket) do
    socket =
      socket
      |> put_flash(:error, "You must log in to access this page.")
      |> push_navigate(to: "/")

    {:halt, socket}
  end
end
