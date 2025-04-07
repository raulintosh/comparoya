defmodule ComparoyaWeb.Router do
  use ComparoyaWeb, :router

  import ComparoyaWeb.Plugs.Auth
  import ComparoyaWeb.Plugs.AdminAuth
  import Oban.Web.Router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ComparoyaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :fetch_current_admin
  end

  pipeline :admin do
    plug :require_admin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ComparoyaWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/privacy-policy", PageController, :privacy_policy
    get "/terms-of-service", PageController, :terms_of_service
    get "/logout", AuthController, :logout
    get "/dashboard", DashboardController, :index
  end

  scope "/auth", ComparoyaWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/admin", ComparoyaWeb do
    pipe_through :browser

    get "/login", AdminAuthController, :login_form
    post "/login", AdminAuthController, :login
    # get "/register", AdminAuthController, :register_form
    # post "/register", AdminAuthController, :register
    get "/logout", AdminAuthController, :logout
  end

  scope "/admin", ComparoyaWeb do
    pipe_through [:browser, :admin]

    # Add admin-only routes here
    resources "/job_configurations", JobConfigurationController
    post "/job_configurations/:id/run_now", JobConfigurationController, :run_now

    # Geocoding routes
    get "/geocoding", AdminGeocodingController, :index
    post "/geocoding/start_batch", AdminGeocodingController, :start_batch
    post "/geocoding/update_coordinates/:id", AdminGeocodingController, :update_coordinates
  end

  # Other scopes may use custom stacks.
  # scope "/api", ComparoyaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:comparoya, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      oban_dashboard("/oban")
      live_dashboard "/dashboard", metrics: ComparoyaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
