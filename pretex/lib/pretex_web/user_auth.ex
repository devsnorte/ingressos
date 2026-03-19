defmodule PretexWeb.UserAuth do
  @moduledoc """
  Plug and LiveView on_mount hooks for staff user authentication.
  """
  use PretexWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Pretex.Accounts

  # How long session tokens live in the browser cookie (seconds)
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_pretex_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  # ── Plugs ──────────────────────────────────────────────────────────────────

  @doc "Plugs the current staff user into `:current_user` conn assign."
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)
    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_session(conn, :user_token, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc "Redirects unauthenticated staff to /staff/log-in."
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: ~p"/staff/log-in")
      |> halt()
    end
  end

  @doc "Logs a user in by writing a signed session token."
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params), do: conn

  @doc "Logs the current user out."
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/staff/log-in")
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp signed_in_path(_conn), do: ~p"/admin/organizations"

  # ── LiveView on_mount hooks ───────────────────────────────────────────────

  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(session, socket)}
  end

  def on_mount(:require_authenticated_user, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be logged in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/staff/log-in")

      {:halt, socket}
    end
  end

  defp mount_current_user(session, socket) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if token = session["user_token"] do
        Accounts.get_user_by_session_token(token)
      end
    end)
  end
end
