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
            <h1 class="text-2xl font-bold">Acesso Staff</h1>
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

          <div :if={@email_sent} class="alert alert-success">
            <.icon name="hero-envelope" class="size-5 shrink-0" />
            <span>Se esse e-mail estiver cadastrado, um link de acesso está a caminho.</span>
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
              label="E-mail"
              autocomplete="email"
              required
              phx-mounted={JS.focus()}
            />
            <.button class="btn btn-primary w-full mt-2">
              Entrar com e-mail <span aria-hidden="true">&rarr;</span>
            </.button>
          </.form>

          <Layouts.flash_group flash={@flash} />
        </div>
      </div>
    </div>
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
