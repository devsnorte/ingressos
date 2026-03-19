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
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-sm space-y-6 text-center">
        <h1 class="text-2xl font-bold">Welcome, {@user.email}</h1>
        <p class="text-base-content/60 text-sm">Click below to complete your login.</p>

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
            Log in and stay logged in
          </.button>
          <.button class="btn btn-primary btn-soft w-full mt-2">
            Log in only this time
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("confirm", _params, socket) do
    {:noreply, assign(socket, trigger_submit: true)}
  end
end
