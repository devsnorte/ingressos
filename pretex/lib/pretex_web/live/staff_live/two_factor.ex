defmodule PretexWeb.StaffLive.TwoFactor do
  use PretexWeb, :live_view

  on_mount({PretexWeb.UserAuth, :require_authenticated_no_2fa})

  alias Pretex.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-md mx-auto py-12">
        <div class="text-center mb-8">
          <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-indigo-100 mb-4">
            <.icon name="hero-shield-check" class="w-8 h-8 text-indigo-600" />
          </div>
          <h1 class="text-2xl font-bold text-gray-900">Two-Factor Authentication</h1>
          <p class="mt-2 text-sm text-gray-600">
            Please verify your identity to continue.
          </p>
        </div>

        <%= if @totp_enabled do %>
          <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-4">
            <h2 class="text-base font-semibold text-gray-900 mb-1">Authenticator App</h2>
            <p class="text-sm text-gray-500 mb-4">
              Enter the 6-digit code from your authenticator app.
            </p>
            <.form
              for={@totp_form}
              id="totp-form"
              action={~p"/staff/two-factor/complete"}
              method="post"
              phx-submit="verify_totp"
              phx-trigger-action={@trigger_totp}
            >
              <input type="hidden" name="method" value="totp" />
              <.input
                field={@totp_form[:code]}
                type="text"
                label="Authentication Code"
                placeholder="000000"
                autocomplete="one-time-code"
                inputmode="numeric"
                maxlength="6"
                required
              />
              <.button variant="primary" class="w-full mt-4" phx-disable-with="Verifying...">
                Verify Code
              </.button>
            </.form>
          </div>
        <% end %>

        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <h2 class="text-base font-semibold text-gray-900 mb-1">Recovery Code</h2>
          <p class="text-sm text-gray-500 mb-4">
            Use one of your saved recovery codes if you can't access your authenticator.
          </p>
          <.form
            for={@recovery_form}
            id="recovery-form"
            action={~p"/staff/two-factor/complete"}
            method="post"
            phx-submit="verify_recovery"
            phx-trigger-action={@trigger_recovery}
          >
            <input type="hidden" name="method" value="recovery" />
            <.input
              field={@recovery_form[:code]}
              type="text"
              label="Recovery Code"
              placeholder="XXXX-XXXX"
              autocomplete="off"
              required
            />
            <.button variant="primary" class="w-full mt-4" phx-disable-with="Verifying...">
              Use Recovery Code
            </.button>
          </.form>
        </div>

        <div class="mt-6 text-center">
          <.link navigate={~p"/staff/log-out"} class="text-sm text-gray-500 hover:text-gray-700">
            Sign out and use a different account
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    totp_enabled = Accounts.User.totp_enabled?(user)

    totp_form = to_form(%{"code" => ""}, as: :totp)
    recovery_form = to_form(%{"code" => ""}, as: :recovery)

    socket =
      socket
      |> assign(:totp_enabled, totp_enabled)
      |> assign(:totp_form, totp_form)
      |> assign(:recovery_form, recovery_form)
      |> assign(:trigger_totp, false)
      |> assign(:trigger_recovery, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("verify_totp", %{"totp" => %{"code" => code}}, socket) do
    user = socket.assigns.current_user

    if Accounts.valid_totp_code?(user.totp_secret, code) do
      {:noreply, assign(socket, :trigger_totp, true)}
    else
      totp_form = to_form(%{"code" => code}, as: :totp)

      socket =
        socket
        |> put_flash(:error, "Invalid authentication code. Please try again.")
        |> assign(:totp_form, totp_form)

      {:noreply, socket}
    end
  end

  def handle_event("verify_recovery", %{"recovery" => %{"code" => code}}, socket) do
    user = socket.assigns.current_user

    case Accounts.use_recovery_code(user, code) do
      :ok ->
        {:noreply, assign(socket, :trigger_recovery, true)}

      :error ->
        recovery_form = to_form(%{"code" => code}, as: :recovery)

        socket =
          socket
          |> put_flash(:error, "Invalid or already-used recovery code.")
          |> assign(:recovery_form, recovery_form)

        {:noreply, socket}
    end
  end
end
