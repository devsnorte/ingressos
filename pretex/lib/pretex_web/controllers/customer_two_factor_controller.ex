defmodule PretexWeb.CustomerTwoFactorController do
  use PretexWeb, :controller

  alias Pretex.Customers

  def complete(conn, %{"method" => "totp", "totp" => %{"code" => code}}) do
    customer = conn.assigns.current_scope.customer

    if Customers.valid_totp_code?(customer.totp_secret, code) do
      conn
      |> put_session(:customer_2fa_verified, true)
      |> redirect(to: ~p"/")
    else
      conn
      |> put_flash(:error, "Invalid authenticator code.")
      |> redirect(to: ~p"/customers/two-factor")
    end
  end

  def complete(conn, %{"method" => "recovery", "recovery" => %{"code" => code}}) do
    customer = conn.assigns.current_scope.customer

    case Customers.use_recovery_code(customer, code) do
      :ok ->
        conn
        |> put_session(:customer_2fa_verified, true)
        |> redirect(to: ~p"/")

      :error ->
        conn
        |> put_flash(:error, "Invalid or already-used recovery code.")
        |> redirect(to: ~p"/customers/two-factor")
    end
  end

  def complete(conn, _params) do
    conn
    |> put_flash(:error, "Invalid request.")
    |> redirect(to: ~p"/customers/two-factor")
  end
end
