defmodule PretexWeb.CustomerSessionController do
  use PretexWeb, :controller

  alias Pretex.Customers
  alias PretexWeb.CustomerAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "Customer confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"customer" => %{"token" => token} = customer_params}, info) do
    case Customers.login_customer_by_magic_link(token) do
      {:ok, {customer, tokens_to_disconnect}} ->
        CustomerAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> CustomerAuth.log_in_customer(customer, customer_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/customers/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"customer" => customer_params}, info) do
    %{"email" => email, "password" => password} = customer_params

    if customer = Customers.get_customer_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> CustomerAuth.log_in_customer(customer, customer_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/customers/log-in")
    end
  end

  def update_password(conn, %{"customer" => customer_params} = params) do
    customer = conn.assigns.current_scope.customer
    true = Customers.sudo_mode?(customer)

    {:ok, {_customer, expired_tokens}} =
      Customers.update_customer_password(customer, customer_params)

    # disconnect all existing LiveViews with old sessions
    CustomerAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:customer_return_to, ~p"/customers/settings")
    |> create(params, "Password updated successfully!")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> CustomerAuth.log_out_customer()
  end
end
