defmodule PretexWeb.Router do
  use PretexWeb, :router

  import PretexWeb.CustomerAuth
  import PretexWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {PretexWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_customer)
    plug(:fetch_current_user)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :require_customer_no_2fa do
    plug(:require_authenticated_customer_no_2fa)
  end

  pipeline :require_user_no_2fa do
    plug(:require_authenticated_user_no_2fa)
  end

  scope "/", PretexWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
  end

  # -- Staff auth (magic link) -----------------------------------------------

  scope "/staff", PretexWeb do
    pipe_through(:browser)

    live_session :staff_unauthenticated,
      on_mount: [{PretexWeb.UserAuth, :mount_current_user}] do
      live("/log-in", StaffLive.Login, :new)
      live("/log-in/:token", StaffLive.MagicLink, :new)
    end

    post("/log-in/confirm", UserSessionController, :create)
    delete("/log-out", UserSessionController, :delete)
  end

  # -- Staff 2FA challenge (authenticated but 2FA not yet verified) ----------
  # Uses plain :browser pipeline so the 2FA check in require_authenticated_user
  # does not loop. The on_mount callback handles authentication without 2FA check.

  scope "/staff", PretexWeb do
    pipe_through([:browser, :require_user_no_2fa])

    live_session :staff_two_factor,
      on_mount: [{PretexWeb.UserAuth, :require_authenticated_no_2fa}] do
      live("/two-factor", StaffLive.TwoFactor, :new)
    end

    post("/two-factor/complete", StaffTwoFactorController, :complete)
  end

  # -- Staff security settings (requires authenticated + 2FA) ----------------

  scope "/staff", PretexWeb do
    pipe_through([:browser, :require_authenticated_user])

    live_session :staff_security,
      on_mount: [{PretexWeb.UserAuth, :require_authenticated_user}] do
      live("/security", StaffLive.Security, :index)
    end
  end

  # -- Admin (requires staff login) ------------------------------------------

  scope "/admin", PretexWeb.Admin do
    pipe_through([:browser, :require_authenticated_user])

    live_session :require_authenticated_user,
      on_mount: [{PretexWeb.UserAuth, :require_authenticated_user}] do
      live("/organizations", OrganizationLive.Index, :index)
      live("/organizations/new", OrganizationLive.Index, :new)
      live("/organizations/:id/edit", OrganizationLive.Index, :edit)
      live("/organizations/:id", OrganizationLive.Show, :show)
      live("/organizations/:id/show/edit", OrganizationLive.Show, :edit)

      live("/organizations/:org_id/team", TeamLive.Index, :index)
      live("/organizations/:org_id/team/invite", TeamLive.Index, :invite)
      live("/organizations/:org_id/team/:id/permissions", TeamLive.Index, :permissions)

      live("/organizations/:org_id/payments", PaymentLive.Index, :index)
      live("/organizations/:org_id/payments/new", PaymentLive.Index, :select)
      live("/organizations/:org_id/payments/new/:type", PaymentLive.Index, :new)
      live("/organizations/:org_id/payments/:id/edit", PaymentLive.Index, :edit)

      live("/organizations/:org_id/events", EventLive.Index, :index)
      live("/organizations/:org_id/events/new", EventLive.New, :new)
      live("/organizations/:org_id/events/:id/edit", EventLive.Edit, :edit)
      live("/organizations/:org_id/events/:id", EventLive.Show, :show)

      live("/organizations/:org_id/events/:event_id/sub-events", SubEventLive.Index, :index)
      live("/organizations/:org_id/events/:event_id/sub-events/new", SubEventLive.Index, :new)

      live(
        "/organizations/:org_id/events/:event_id/sub-events/:id/edit",
        SubEventLive.Index,
        :edit
      )

      live("/organizations/:org_id/events/:event_id/catalog", CatalogLive.Index, :index)
      live("/organizations/:org_id/events/:event_id/catalog/new", CatalogLive.Index, :new)
      live("/organizations/:org_id/events/:event_id/catalog/:id/edit", CatalogLive.Index, :edit)

      live("/organizations/:org_id/events/:event_id/quotas", QuotaLive.Index, :index)
      live("/organizations/:org_id/events/:event_id/quotas/new", QuotaLive.Index, :new)
      live("/organizations/:org_id/events/:event_id/quotas/:id/edit", QuotaLive.Index, :edit)

      live(
        "/organizations/:org_id/events/:event_id/questions",
        QuestionLive.Index,
        :index
      )

      live(
        "/organizations/:org_id/events/:event_id/questions/new",
        QuestionLive.Index,
        :new
      )

      live(
        "/organizations/:org_id/events/:event_id/questions/:id/edit",
        QuestionLive.Index,
        :edit
      )

      live(
        "/organizations/:org_id/events/:event_id/questions/attendee-fields",
        QuestionLive.AttendeeFields,
        :index
      )

      live(
        "/organizations/:org_id/events/:event_id/catalog/items/new",
        CatalogLive.ItemForm,
        :new
      )

      live(
        "/organizations/:org_id/events/:event_id/catalog/items/:id",
        CatalogLive.ItemForm,
        :edit
      )
    end
  end

  # -- Customer 2FA challenge (authenticated but 2FA not yet verified) --------
  # Uses plain :browser pipeline so the 2FA check in require_authenticated_customer
  # does not loop. The on_mount callback handles authentication without 2FA check.

  scope "/", PretexWeb do
    pipe_through([:browser, :require_customer_no_2fa])

    live_session :customer_two_factor,
      on_mount: [{PretexWeb.CustomerAuth, :require_authenticated_no_2fa}] do
      live("/customers/two-factor", CustomerLive.TwoFactor, :new)
    end

    post("/customers/two-factor/complete", CustomerTwoFactorController, :complete)
  end

  # -- Customer auth ---------------------------------------------------------

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
    pipe_through(:browser)

    live_session :current_customer,
      on_mount: [{PretexWeb.CustomerAuth, :mount_current_scope}] do
      live("/customers/register", CustomerLive.Registration, :new)
      live("/customers/log-in", CustomerLive.Login, :new)
      live("/customers/log-in/:token", CustomerLive.Confirmation, :new)

      live("/events", EventsLive.Index, :index)
      live("/events/:slug", EventsLive.Show, :index)
      live("/events/:slug/checkout", EventsLive.Checkout, :info)
      live("/events/:slug/checkout/summary", EventsLive.Checkout, :summary)
      live("/events/:slug/orders/:code", EventsLive.Confirmation, :index)
    end

    post("/customers/log-in", CustomerSessionController, :create)
    delete("/customers/log-out", CustomerSessionController, :delete)
  end

  if Application.compile_env(:pretex, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: PretexWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
