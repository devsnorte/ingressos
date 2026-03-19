defmodule PretexWeb.UserSessionController do
  use PretexWeb, :controller

  alias Pretex.Accounts
  alias PretexWeb.UserAuth

  @doc "Handles the POST from the magic-link confirmation LiveView."
  def create(conn, %{"user" => %{"token" => token} = params}) do
    case Accounts.consume_user_magic_link_token(token) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Logged in successfully.")
        |> UserAuth.log_in_user(user, params)

      {:error, :invalid} ->
        conn
        |> put_flash(:error, "The login link is invalid or has expired.")
        |> redirect(to: ~p"/staff/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
