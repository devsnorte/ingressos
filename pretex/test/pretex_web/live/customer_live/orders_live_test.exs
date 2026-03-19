defmodule PretexWeb.CustomerLive.OrdersTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Orders page - unauthenticated" do
    test "redirects to login when not authenticated", %{conn: conn} do
      result = live(conn, ~p"/account/orders")
      assert {:error, {:redirect, %{to: "/customers/log-in"}}} = result
    end
  end

  describe "Orders page - authenticated" do
    setup :register_and_log_in_customer

    test "renders the orders empty-state page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/orders")

      assert has_element?(view, "h1", "No orders yet")
    end

    test "shows the browse events CTA link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/orders")

      assert has_element?(view, "a[href='/']")
    end

    test "shows ticket icon in empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/orders")

      assert has_element?(view, ".hero-ticket")
    end

    test "shows the customer email in the nav", %{conn: conn, customer: customer} do
      {:ok, _view, html} = live(conn, ~p"/account/orders")

      assert html =~ customer.email
    end
  end
end
