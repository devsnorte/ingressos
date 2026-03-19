defmodule PretexWeb.CustomerLive.Settings do
  use PretexWeb, :live_view

  on_mount {PretexWeb.CustomerAuth, :require_sudo_mode}

  alias Pretex.Customers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          Account Settings
          <:subtitle>Manage your account email address and password settings</:subtitle>
        </.header>
      </div>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          spellcheck="false"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/customers/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_customer_email"
          spellcheck="false"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label="New password"
          autocomplete="new-password"
          spellcheck="false"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          autocomplete="new-password"
          spellcheck="false"
        />
        <.button variant="primary" phx-disable-with="Saving...">
          Save Password
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Customers.update_customer_email(socket.assigns.current_scope.customer, token) do
        {:ok, _customer} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/customers/settings")}
  end

  def mount(_params, _session, socket) do
    customer = socket.assigns.current_scope.customer
    email_changeset = Customers.change_customer_email(customer, %{}, validate_unique: false)
    password_changeset = Customers.change_customer_password(customer, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, customer.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"customer" => customer_params} = params

    email_form =
      socket.assigns.current_scope.customer
      |> Customers.change_customer_email(customer_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"customer" => customer_params} = params
    customer = socket.assigns.current_scope.customer
    true = Customers.sudo_mode?(customer)

    case Customers.change_customer_email(customer, customer_params) do
      %{valid?: true} = changeset ->
        Customers.deliver_customer_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          customer.email,
          &url(~p"/customers/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"customer" => customer_params} = params

    password_form =
      socket.assigns.current_scope.customer
      |> Customers.change_customer_password(customer_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"customer" => customer_params} = params
    customer = socket.assigns.current_scope.customer
    true = Customers.sudo_mode?(customer)

    case Customers.change_customer_password(customer, customer_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
