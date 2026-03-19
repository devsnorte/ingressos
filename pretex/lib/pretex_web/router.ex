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

  scope "/admin", PretexWeb.Admin do
    pipe_through :browser

    live "/organizations", OrganizationLive.Index, :index
    live "/organizations/new", OrganizationLive.Index, :new
    live "/organizations/:id/edit", OrganizationLive.Index, :edit
    live "/organizations/:id", OrganizationLive.Show, :show
    live "/organizations/:id/show/edit", OrganizationLive.Show, :edit

    live "/organizations/:org_id/team", TeamLive.Index, :index
    live "/organizations/:org_id/team/invite", TeamLive.Index, :invite
    live "/organizations/:org_id/team/:id/permissions", TeamLive.Index, :permissions
  end

  if Application.compile_env(:pretex, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PretexWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
