defmodule PretexWeb.CustomerLive.ConfirmationTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Pretex.CustomersFixtures

  alias Pretex.Customers

  setup do
    %{
      unconfirmed_customer: unconfirmed_customer_fixture(),
      confirmed_customer: customer_fixture()
    }
  end

  describe "Confirm customer" do
    test "renders confirmation page for unconfirmed customer", %{
      conn: conn,
      unconfirmed_customer: customer
    } do
      token =
        extract_customer_token(fn url ->
          Customers.deliver_login_instructions(customer, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/customers/log-in/#{token}")
      assert html =~ "Confirm and stay logged in"
    end

    test "renders login page for confirmed customer", %{conn: conn, confirmed_customer: customer} do
      token =
        extract_customer_token(fn url ->
          Customers.deliver_login_instructions(customer, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/customers/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Keep me logged in on this device"
    end

    test "renders login page for already logged in customer", %{
      conn: conn,
      confirmed_customer: customer
    } do
      conn = log_in_customer(conn, customer)

      token =
        extract_customer_token(fn url ->
          Customers.deliver_login_instructions(customer, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/customers/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Log in"
    end

    test "confirms the given token once", %{conn: conn, unconfirmed_customer: customer} do
      token =
        extract_customer_token(fn url ->
          Customers.deliver_login_instructions(customer, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/customers/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"customer" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Customer confirmed successfully"

      assert Customers.get_customer!(customer.id).confirmed_at
      # we are logged in now
      assert get_session(conn, :customer_token)
      assert redirected_to(conn) == ~p"/"

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"/customers/log-in/#{token}")
        |> follow_redirect(conn, ~p"/customers/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "logs confirmed customer in without changing confirmed_at", %{
      conn: conn,
      confirmed_customer: customer
    } do
      token =
        extract_customer_token(fn url ->
          Customers.deliver_login_instructions(customer, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/customers/log-in/#{token}")

      form = form(lv, "#login_form", %{"customer" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome back!"

      assert Customers.get_customer!(customer.id).confirmed_at == customer.confirmed_at

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"/customers/log-in/#{token}")
        |> follow_redirect(conn, ~p"/customers/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "raises error for invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/customers/log-in/invalid-token")
        |> follow_redirect(conn, ~p"/customers/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end
  end
end
