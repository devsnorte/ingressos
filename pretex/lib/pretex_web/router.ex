defmodule PretexWeb.Router do
  use PretexWeb, :router

  import PretexWeb.CustomerAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {PretexWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_customer)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", PretexWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
  end

  scope "/admin", PretexWeb.Admin do
    pipe_through(:browser)

    live("/organizations", OrganizationLive.Index, :index)
    live("/organizations/new", OrganizationLive.Index, :new)
    live("/organizations/:id/edit", OrganizationLive.Index, :edit)
    live("/organizations/:id", OrganizationLive.Show, :show)
    live("/organizations/:id/show/edit", OrganizationLive.Show, :edit)

    live("/organizations/:org_id/team", TeamLive.Index, :index)
    live("/organizations/:org_id/team/invite", TeamLive.Index, :invite)
    live("/organizations/:org_id/team/:id/permissions", TeamLive.Index, :permissions)
  end

  if Application.compile_env(:pretex, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: PretexWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  ## Authentication routes

  scope "/", PretexWeb do
    pipe_through([:browser, :require_authenticated_customer])

    live_session :require_authenticated_customer,
      on_mount: [{PretexWeb.CustomerAuth, :require_authenticated}] do
      live("/customers/settings", CustomerLive.Settings, :edit)
      live("/customers/settings/confirm-email/:token", CustomerLive.Settings, :confirm_email)
      live("/account/orders", CustomerLive.Orders, :index)
      live("/account/privacy", CustomerLive.Privacy, :index)
    end

    post("/customers/update-password", CustomerSessionController, :update_password)
  end

  scope "/", PretexWeb do
    pipe_through([:browser])

    live_session :current_customer,
      on_mount: [{PretexWeb.CustomerAuth, :mount_current_scope}] do
      live("/customers/register", CustomerLive.Registration, :new)
      live("/customers/log-in", CustomerLive.Login, :new)
      live("/customers/log-in/:token", CustomerLive.Confirmation, :new)
    end

    post("/customers/log-in", CustomerSessionController, :create)
    delete("/customers/log-out", CustomerSessionController, :delete)
  end
end
