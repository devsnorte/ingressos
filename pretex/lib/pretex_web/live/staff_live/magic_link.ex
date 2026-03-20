defmodule PretexWeb.StaffLive.MagicLink do
  use PretexWeb, :live_view

  alias Pretex.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.peek_user_magic_link_token(token) do
      {:ok, user} ->
        # Can't write the session from a LiveView — hand off to the controller
        # via a form POST with the raw token so the session is set server-side.
        {:ok,
         assign(socket,
           user: user,
           token: token,
           form: to_form(%{"token" => token, "remember_me" => "false"}, as: "user"),
           trigger_submit: false
         )}

      {:error, :invalid} ->
        {:ok,
         socket
         |> put_flash(:error, "The login link is invalid or has expired.")
         |> push_navigate(to: ~p"/staff/log-in")}
    end
  end

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

          <div>
            <h1 class="text-2xl font-bold">Bem-vindo de volta!</h1>
            <p class="mt-2 text-sm text-base-content/60">{@user.email}</p>
          </div>

          <.form
            for={@form}
            id="magic-link-form"
            action={~p"/staff/log-in/confirm"}
            phx-submit="confirm"
            phx-trigger-action={@trigger_submit}
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <.button
              name={@form[:remember_me].name}
              value="true"
              class="btn btn-primary w-full"
            >
              Entrar e manter conectado
            </.button>
            <.button class="btn btn-outline w-full mt-2">
              Entrar apenas desta vez
            </.button>
          </.form>

          <Layouts.flash_group flash={@flash} />
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("confirm", _params, socket) do
    {:noreply, assign(socket, trigger_submit: true)}
  end
end
