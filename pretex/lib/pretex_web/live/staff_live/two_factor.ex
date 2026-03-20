defmodule PretexWeb.StaffLive.TwoFactor do
  use PretexWeb, :live_view

  on_mount({PretexWeb.UserAuth, :require_authenticated_no_2fa})

  alias Pretex.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex">
      <%!-- Left panel (hidden on mobile) --%>
      <div class="hidden lg:flex lg:w-1/2 bg-neutral text-neutral-content flex-col justify-between p-12 relative overflow-hidden">
        <%!-- Decorative circles --%>
        <div class="absolute top-20 right-10 w-32 h-32 rounded-full bg-primary/10"></div>
        <div class="absolute bottom-32 left-8 w-20 h-20 rounded-full bg-primary/10"></div>
        <div class="absolute top-1/2 right-1/3 w-12 h-12 rounded-full bg-primary/5"></div>

        <div>
          <a href="/" class="flex items-center gap-2 mb-2">
            <.icon name="hero-ticket" class="size-7 text-primary" />
            <span class="text-xl font-bold">Pretex</span>
          </a>
          <p class="text-sm text-neutral-content/50">Painel Administrativo</p>
        </div>

        <div class="relative z-10">
          <blockquote class="text-2xl font-semibold leading-relaxed mb-6">
            Gerencie eventos, equipes e configurações da sua organização.
          </blockquote>
        </div>

        <div></div>
      </div>

      <%!-- Right panel --%>
      <div class="w-full lg:w-1/2 flex items-center justify-center p-6 sm:p-12 bg-base-100">
        <div class="w-full max-w-sm space-y-6">
          <%!-- Mobile logo --%>
          <div class="lg:hidden flex items-center gap-2 mb-4">
            <a href="/" class="flex items-center gap-2">
              <.icon name="hero-ticket" class="size-6 text-primary" />
              <span class="text-lg font-bold">Pretex</span>
            </a>
          </div>

          <div class="text-center">
            <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary/10 mb-4">
              <.icon name="hero-shield-check" class="w-8 h-8 text-primary" />
            </div>
            <h1 class="text-2xl font-bold">Verificação em duas etapas</h1>
            <p class="mt-2 text-sm text-base-content/60">
              Verifique sua identidade para continuar.
            </p>
          </div>

          <%= if @totp_enabled do %>
            <div>
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
                  label="Código do autenticador"
                  placeholder="000000"
                  autocomplete="one-time-code"
                  inputmode="numeric"
                  maxlength="6"
                  required
                />
                <.button variant="primary" class="w-full mt-4" phx-disable-with="Verificando...">
                  Verificar
                </.button>
              </.form>
            </div>

            <div class="divider text-sm text-base-content/40">ou</div>
          <% end %>

          <div>
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
                label="Código de recuperação"
                placeholder="XXXX-XXXX"
                autocomplete="off"
                required
              />
              <.button variant="primary" class="w-full mt-4" phx-disable-with="Verificando...">
                Verificar com código de recuperação
              </.button>
            </.form>
          </div>

          <div class="text-center">
            <.link
              navigate={~p"/staff/log-out"}
              class="text-sm text-base-content/60 hover:text-base-content"
            >
              Sair
            </.link>
          </div>

          <Layouts.flash_group flash={@flash} />
        </div>
      </div>
    </div>
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
