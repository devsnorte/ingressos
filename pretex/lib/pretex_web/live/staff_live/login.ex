defmodule PretexWeb.StaffLive.Login do
  use PretexWeb, :live_view

  alias Pretex.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{"email" => ""}, as: "user"), email_sent: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-sm space-y-6">
        <div class="text-center space-y-1">
          <h1 class="text-2xl font-bold">Staff login</h1>
          <p class="text-base-content/60 text-sm">Enter your email to receive a magic link</p>
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info text-sm">
          <.icon name="hero-information-circle" class="size-5 shrink-0" />
          <div>
            Running local mail adapter — <.link href="/dev/mailbox" class="underline font-medium">view emails here</.link>.
          </div>
        </div>

        <div :if={@email_sent} class="alert alert-success">
          <.icon name="hero-envelope" class="size-5 shrink-0" />
          <span>If that email is registered, a login link is on its way.</span>
        </div>

        <.form
          :if={!@email_sent}
          for={@form}
          id="staff-login-form"
          phx-submit="send_link"
        >
          <.input
            field={@form[:email]}
            type="email"
            label="Email address"
            autocomplete="email"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn btn-primary w-full mt-2">
            Send login link
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("send_link", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_login_instructions(
        user,
        &url(~p"/staff/log-in/#{&1}")
      )
    end

    # Always show the same message to avoid user enumeration
    {:noreply, assign(socket, email_sent: true)}
  end

  defp local_mail_adapter? do
    Application.get_env(:pretex, Pretex.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
