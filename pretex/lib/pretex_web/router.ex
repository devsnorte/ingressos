defmodule PretexWeb.Router do
  use PretexWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PretexWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PretexWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", PretexWeb do
  #   pipe_through :api
  # end

  scope "/admin", PretexWeb.Admin do
    pipe_through :browser

    live "/organizations", OrganizationLive.Index, :index
    live "/organizations/new", OrganizationLive.Index, :new
    live "/organizations/:id/edit", OrganizationLive.Index, :edit
    live "/organizations/:id", OrganizationLive.Show, :show
    live "/organizations/:id/show/edit", OrganizationLive.Show, :edit
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:pretex, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PretexWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
