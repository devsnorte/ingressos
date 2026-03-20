defmodule PretexWeb.CustomerLive.Login do
  use PretexWeb, :live_view

  alias Pretex.Customers

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
          <p class="text-sm text-neutral-content/50">Plataforma de eventos open source</p>
        </div>

        <div class="relative z-10">
          <blockquote class="text-2xl font-semibold leading-relaxed mb-6">
            Gerencie seus eventos com total controle. Sem taxas, sem intermediários.
          </blockquote>
          <p class="text-neutral-content/50 text-sm">
            Crie, venda ingressos e acompanhe check-ins em tempo real.
          </p>
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
            <h1 class="text-2xl font-bold">Entrar na sua conta</h1>
            <p :if={!@current_scope} class="mt-2 text-sm text-base-content/60">
              Não tem conta? <.link
                navigate={~p"/customers/register"}
                class="font-semibold text-primary hover:underline"
                phx-no-format
              >Criar conta</.link>
            </p>
            <p :if={@current_scope} class="mt-2 text-sm text-base-content/60">
              Você precisa se autenticar novamente para realizar ações sensíveis na sua conta.
            </p>
          </div>

          <div :if={local_mail_adapter?()} class="alert alert-info">
            <.icon name="hero-information-circle" class="size-6 shrink-0" />
            <div>
              <p>Você está usando o adaptador de e-mail local.</p>
              <p>
                Para ver e-mails enviados, visite <.link href="/dev/mailbox" class="underline">a caixa de entrada</.link>.
              </p>
            </div>
          </div>

          <.form
            :let={f}
            for={@form}
            id="login_form_magic"
            action={~p"/customers/log-in"}
            phx-submit="submit_magic"
          >
            <.input
              readonly={!!@current_scope}
              field={f[:email]}
              type="email"
              label="E-mail"
              autocomplete="username"
              spellcheck="false"
              required
              phx-mounted={JS.focus()}
            />
            <.button class="btn btn-primary w-full">
              Entrar com e-mail <span aria-hidden="true">&rarr;</span>
            </.button>
          </.form>

          <div class="divider text-sm text-base-content/40">ou</div>

          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/customers/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
          >
            <.input
              readonly={!!@current_scope}
              field={f[:email]}
              type="email"
              label="E-mail"
              autocomplete="username"
              spellcheck="false"
              required
            />
            <.input
              field={@form[:password]}
              type="password"
              label="Senha"
              autocomplete="current-password"
              spellcheck="false"
            />
            <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
              Entrar e manter conectado <span aria-hidden="true">&rarr;</span>
            </.button>
            <.button class="btn btn-ghost w-full mt-2">
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
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:customer), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "customer")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"customer" => %{"email" => email}}, socket) do
    if customer = Customers.get_customer_by_email(email) do
      Customers.deliver_login_instructions(
        customer,
        &url(~p"/customers/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/customers/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:pretex, Pretex.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
