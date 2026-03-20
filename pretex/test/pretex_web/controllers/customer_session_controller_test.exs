defmodule PretexWeb.CustomerSessionControllerTest do
  use PretexWeb.ConnCase, async: true

  import Pretex.CustomersFixtures
  alias Pretex.Customers

  setup do
    %{unconfirmed_customer: unconfirmed_customer_fixture(), customer: customer_fixture()}
  end

  describe "POST /customers/log-in - email and password" do
    test "logs the customer in", %{conn: conn, customer: customer} do
      customer = set_password(customer)

      conn =
        post(conn, ~p"/customers/log-in", %{
          "customer" => %{"email" => customer.email, "password" => valid_customer_password()}
        })

      assert get_session(conn, :customer_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the customer in with remember me", %{conn: conn, customer: customer} do
      customer = set_password(customer)

      conn =
        post(conn, ~p"/customers/log-in", %{
          "customer" => %{
            "email" => customer.email,
            "password" => valid_customer_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_pretex_web_customer_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the customer in with return to", %{conn: conn, customer: customer} do
      customer = set_password(customer)

      conn =
        conn
        |> init_test_session(customer_return_to: "/foo/bar")
        |> post(~p"/customers/log-in", %{
          "customer" => %{
            "email" => customer.email,
            "password" => valid_customer_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "redirects to login page with invalid credentials", %{conn: conn, customer: customer} do
      conn =
        post(conn, ~p"/customers/log-in?mode=password", %{
          "customer" => %{"email" => customer.email, "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/customers/log-in"
    end
  end

  describe "POST /customers/log-in - magic link" do
    test "logs the customer in", %{conn: conn, customer: customer} do
      {token, _hashed_token} = generate_customer_magic_link_token(customer)

      conn =
        post(conn, ~p"/customers/log-in", %{
          "customer" => %{"token" => token}
        })

      assert get_session(conn, :customer_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "confirms unconfirmed customer", %{conn: conn, unconfirmed_customer: customer} do
      {token, _hashed_token} = generate_customer_magic_link_token(customer)
      refute customer.confirmed_at

      conn =
        post(conn, ~p"/customers/log-in", %{
          "customer" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :customer_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Customer confirmed successfully."

      assert Customers.get_customer!(customer.id).confirmed_at
    end

    test "redirects to login page when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/customers/log-in", %{
          "customer" => %{"token" => "invalid"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The link is invalid or it has expired."

      assert redirected_to(conn) == ~p"/customers/log-in"
    end
  end

  describe "DELETE /customers/log-out" do
    test "logs the customer out", %{conn: conn, customer: customer} do
      conn = conn |> log_in_customer(customer) |> delete(~p"/customers/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :customer_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the customer is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/customers/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :customer_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
