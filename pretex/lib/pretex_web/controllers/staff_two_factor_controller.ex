defmodule PretexWeb.StaffTwoFactorController do
  use PretexWeb, :controller

  alias Pretex.Accounts

  def complete(conn, %{"method" => "totp", "totp" => %{"code" => code}}) do
    user = conn.assigns.current_user

    if Accounts.valid_totp_code?(user.totp_secret, code) do
      conn
      |> put_session(:user_2fa_verified, true)
      |> redirect(to: ~p"/admin/organizations")
    else
      conn
      |> put_flash(:error, "Invalid authenticator code.")
      |> redirect(to: ~p"/staff/two-factor")
    end
  end

  def complete(conn, %{"method" => "recovery", "recovery" => %{"code" => code}}) do
    user = conn.assigns.current_user

    case Accounts.use_recovery_code(user, code) do
      :ok ->
        conn
        |> put_session(:user_2fa_verified, true)
        |> redirect(to: ~p"/admin/organizations")

      :error ->
        conn
        |> put_flash(:error, "Invalid or already-used recovery code.")
        |> redirect(to: ~p"/staff/two-factor")
    end
  end

  def complete(conn, _params) do
    conn
    |> put_flash(:error, "Invalid request.")
    |> redirect(to: ~p"/staff/two-factor")
  end
end
