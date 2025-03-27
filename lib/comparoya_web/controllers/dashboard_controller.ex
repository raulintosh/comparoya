defmodule ComparoyaWeb.DashboardController do
  use ComparoyaWeb, :controller

  import ComparoyaWeb.Plugs.Auth

  plug :require_authenticated_user

  def index(conn, _params) do
    render(conn, :index)
  end
end
