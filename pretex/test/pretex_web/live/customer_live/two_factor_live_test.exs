defmodule PretexWeb.CustomerLive.TwoFactorTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Pretex.CustomersFixtures

  alias Pretex.Customers

  describe "two-factor challenge page" do
    test "unauthenticated customer is redirected to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/customers/two-factor")
      assert path == ~p"/customers/log-in"
    end

    test "authenticated customer without TOTP can access the page", %{conn: conn} do
      customer = customer_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_customer(customer)
        |> live(~p"/customers/two-factor")

      assert has_element?(lv, "#recovery-form")
    end

    test "authenticated customer without TOTP does not see TOTP form", %{conn: conn} do
      customer = customer_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_customer(customer)
        |> live(~p"/customers/two-factor")

      refute has_element?(lv, "#totp-form")
    end

    test "authenticated customer with TOTP enabled sees TOTP form", %{conn: conn} do
      customer = customer_fixture()
      secret = Customers.generate_totp_secret()
      {:ok, customer} = Customers.enable_totp(customer, secret)

      {:ok, lv, _html} =
        conn
        |> log_in_customer(customer)
        |> live(~p"/customers/two-factor")

      assert has_element?(lv, "#totp-form")
    end

    test "authenticated customer with TOTP sees recovery form too", %{conn: conn} do
      customer = customer_fixture()
      secret = Customers.generate_totp_secret()
      {:ok, customer} = Customers.enable_totp(customer, secret)

      {:ok, lv, _html} =
        conn
        |> log_in_customer(customer)
        |> live(~p"/customers/two-factor")

      assert has_element?(lv, "#recovery-form")
    end

    test "entering wrong TOTP code shows error", %{conn: conn} do
      customer = customer_fixture()
      secret = Customers.generate_totp_secret()
      {:ok, customer} = Customers.enable_totp(customer, secret)

      {:ok, lv, _html} =
        conn
        |> log_in_customer(customer)
        |> live(~p"/customers/two-factor")

      html =
        lv
        |> form("#totp-form", totp: %{code: "000000"})
        |> render_submit()

      assert html =~ "Invalid authentication code"
    end

    test "entering invalid recovery code shows error", %{conn: conn} do
      customer = customer_fixture()
      _codes = Customers.generate_recovery_codes(customer)

      {:ok, lv, _html} =
        conn
        |> log_in_customer(customer)
        |> live(~p"/customers/two-factor")

      html =
        lv
        |> form("#recovery-form", recovery: %{code: "XXXX-XXXX"})
        |> render_submit()

      assert html =~ "Invalid or already-used recovery code"
    end

    test "recovery section is always visible", %{conn: conn} do
      customer = customer_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_customer(customer)
        |> live(~p"/customers/two-factor")

      assert html =~ "Recovery Code"
    end
  end
end
