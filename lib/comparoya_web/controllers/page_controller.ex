defmodule ComparoyaWeb.PageController do
  use ComparoyaWeb, :controller

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
