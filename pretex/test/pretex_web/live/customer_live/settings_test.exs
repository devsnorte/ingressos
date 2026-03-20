defmodule PretexWeb.CustomerLive.SettingsTest do
  use PretexWeb.ConnCase, async: true

  alias Pretex.Customers
  import Phoenix.LiveViewTest
  import Pretex.CustomersFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_customer(customer_fixture())
        |> live(~p"/customers/settings")

      assert html =~ "Alterar E-mail"
      assert html =~ "Salvar Senha"
    end

    test "redirects if customer is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/customers/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/customers/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if customer is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_customer(customer_fixture(),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/customers/settings")
        |> follow_redirect(conn, ~p"/customers/log-in")

      assert conn.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      customer = customer_fixture()
      %{conn: log_in_customer(conn, customer), customer: customer}
    end

    test "updates the customer email", %{conn: conn, customer: customer} do
      new_email = unique_customer_email()

      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      result =
        lv
        |> form("#email_form", %{
          "customer" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Customers.get_customer_by_email(customer.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "customer" => %{"email" => "with spaces"}
        })

      assert result =~ "Alterar E-mail"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, customer: customer} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      result =
        lv
        |> form("#email_form", %{
          "customer" => %{"email" => customer.email}
        })
        |> render_submit()

      assert result =~ "Alterar E-mail"
      assert result =~ "did not change"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      customer = customer_fixture()
      %{conn: log_in_customer(conn, customer), customer: customer}
    end

    test "updates the customer password", %{conn: conn, customer: customer} do
      new_password = valid_customer_password()

      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      form =
        form(lv, "#password_form", %{
          "customer" => %{
            "email" => customer.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/customers/settings"

      assert get_session(new_password_conn, :customer_token) != get_session(conn, :customer_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Customers.get_customer_by_email_and_password(customer.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "customer" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Salvar Senha"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      result =
        lv
        |> form("#password_form", %{
          "customer" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Salvar Senha"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      customer = customer_fixture()
      email = unique_customer_email()

      token =
        extract_customer_token(fn url ->
          Customers.deliver_customer_update_email_instructions(
            %{customer | email: email},
            customer.email,
            url
          )
        end)

      %{conn: log_in_customer(conn, customer), token: token, email: email, customer: customer}
    end

    test "updates the customer email once", %{
      conn: conn,
      customer: customer,
      token: token,
      email: email
    } do
      {:error, redirect} = live(conn, ~p"/customers/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/customers/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Customers.get_customer_by_email(customer.email)
      assert Customers.get_customer_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/customers/settings/confirm-email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/customers/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, customer: customer} do
      {:error, redirect} = live(conn, ~p"/customers/settings/confirm-email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/customers/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Customers.get_customer_by_email(customer.email)
    end

    test "redirects if customer is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/customers/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/customers/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
