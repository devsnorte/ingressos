defmodule PretexWeb.CustomerLive.PrivacyTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Customers

  describe "Privacy page - unauthenticated" do
    test "redirects to login when not authenticated", %{conn: conn} do
      result = live(conn, ~p"/account/privacy")
      assert {:error, {:redirect, %{to: "/customers/log-in"}}} = result
    end
  end

  describe "Privacy page - authenticated" do
    setup :register_and_log_in_customer

    test "renders the privacy page with both sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/privacy")

      assert has_element?(view, "#data-export-hook")
      assert has_element?(view, "#delete-account-form")
    end

    test "shows the export data button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/privacy")

      assert has_element?(view, "#export-data-btn")
    end

    test "shows the delete account button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/privacy")

      assert has_element?(view, "#delete-account-btn")
    end

    test "shows customer email in deletion warning", %{conn: conn, customer: customer} do
      {:ok, _view, html} = live(conn, ~p"/account/privacy")

      assert html =~ customer.email
    end
  end

  describe "Data export" do
    setup :register_and_log_in_customer

    test "clicking export button pushes download_data event with correct filename", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/privacy")

      view |> element("#export-data-btn") |> render_click()

      assert_push_event(view, "download_data", %{filename: "pretex-data-export.json"})
    end

    test "exported data contains customer email", %{conn: conn, customer: customer} do
      {:ok, view, _html} = live(conn, ~p"/account/privacy")

      view |> element("#export-data-btn") |> render_click()

      assert_push_event(view, "download_data", %{content: content})
      decoded = Jason.decode!(content)
      assert decoded["email"] == customer.email
    end

    test "exported payload includes exported_at timestamp", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/privacy")

      view |> element("#export-data-btn") |> render_click()

      assert_push_event(view, "download_data", %{content: content})
      decoded = Jason.decode!(content)
      assert Map.has_key?(decoded, "exported_at")
    end
  end

  describe "Account deletion" do
    setup :register_and_log_in_customer

    test "shows error flash when wrong email is submitted", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/privacy")

      view
      |> form("#delete-account-form", %{"delete" => %{"email_confirmation" => "wrong@email.com"}})
      |> render_submit()

      assert has_element?(view, "#flash-error", "does not match")
    end

    test "does not delete account when wrong email submitted", %{
      conn: conn,
      customer: customer
    } do
      {:ok, view, _html} = live(conn, ~p"/account/privacy")

      view
      |> form("#delete-account-form", %{
        "delete" => %{"email_confirmation" => "notmyemail@example.com"}
      })
      |> render_submit()

      assert Customers.get_customer!(customer.id)
    end

    test "deletes account and redirects when correct email submitted", %{
      conn: conn,
      customer: customer
    } do
      {:ok, view, _html} = live(conn, ~p"/account/privacy")

      result =
        view
        |> form("#delete-account-form", %{
          "delete" => %{"email_confirmation" => customer.email}
        })
        |> render_submit()

      assert {:error, {:redirect, %{to: "/customers/log-out"}}} = result
    end

    test "customer record is removed from database after correct email submitted", %{
      conn: conn,
      customer: customer
    } do
      {:ok, view, _html} = live(conn, ~p"/account/privacy")

      view
      |> form("#delete-account-form", %{
        "delete" => %{"email_confirmation" => customer.email}
      })
      |> render_submit()

      assert_raise Ecto.NoResultsError, fn ->
        Customers.get_customer!(customer.id)
      end
    end

    test "email comparison is case-insensitive", %{conn: conn, customer: customer} do
      {:ok, view, _html} = live(conn, ~p"/account/privacy")

      result =
        view
        |> form("#delete-account-form", %{
          "delete" => %{"email_confirmation" => String.upcase(customer.email)}
        })
        |> render_submit()

      assert {:error, {:redirect, %{to: "/customers/log-out"}}} = result
    end
  end
end
