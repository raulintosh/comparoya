defmodule ComparoyaWeb.PageController do
  use ComparoyaWeb, :controller

  def terms_of_service(conn, _params) do
    render(conn, :terms_of_service)
  end

  def privacy_policy(conn, _params) do
    render(conn, :privacy_policy)
  end

  def home(conn, _params) do
    # If the user is already logged in, redirect to the dashboard
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/dashboard")
    else
      # Otherwise, render the home page
      # The home page is often custom made,
      # so skip the default app layout.
      render(conn, :home, layout: false)
    end
  end
end
