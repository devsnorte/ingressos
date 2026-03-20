defmodule PretexWeb.CustomerLive.Registration do
  use PretexWeb, :live_view

  alias Pretex.Customers
  alias Pretex.Customers.Customer

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
            <h1 class="text-2xl font-bold">Criar sua conta</h1>
            <p class="mt-2 text-sm text-base-content/60">
              Já tem conta?
              <.link
                navigate={~p"/customers/log-in"}
                class="font-semibold text-primary hover:underline"
              >
                Entrar
              </.link>
            </p>
          </div>

          <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
            <.input
              field={@form[:email]}
              type="email"
              label="E-mail"
              autocomplete="username"
              spellcheck="false"
              required
              phx-mounted={JS.focus()}
            />

            <.button phx-disable-with="Criando conta..." class="btn btn-primary w-full">
              Criar conta
            </.button>
          </.form>

          <Layouts.flash_group flash={@flash} />
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{customer: customer}}} = socket)
      when not is_nil(customer) do
    {:ok, redirect(socket, to: PretexWeb.CustomerAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Customers.change_customer_email(%Customer{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"customer" => customer_params}, socket) do
    case Customers.register_customer(customer_params) do
      {:ok, customer} ->
        {:ok, _} =
          Customers.deliver_login_instructions(
            customer,
            &url(~p"/customers/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{customer.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/customers/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"customer" => customer_params}, socket) do
    changeset =
      Customers.change_customer_email(%Customer{}, customer_params, validate_unique: false)

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "customer")
    assign(socket, form: form)
  end
end
