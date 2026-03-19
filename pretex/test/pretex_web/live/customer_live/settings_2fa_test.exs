defmodule PretexWeb.CustomerLive.Settings2faTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Pretex.CustomersFixtures

  alias Pretex.Customers

  setup %{conn: conn} do
    customer = customer_fixture()
    %{conn: log_in_customer(conn, customer), customer: customer}
  end

  describe "2FA section on settings page" do
    test "settings page renders TOTP section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/customers/settings")
      assert html =~ "Authenticator App"
    end

    test "settings page renders recovery codes section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/customers/settings")
      assert html =~ "Recovery Codes"
    end

    test "settings page renders WebAuthn section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/customers/settings")
      assert html =~ "Security Keys"
    end

    test "shows Enable Authenticator App button when TOTP not enabled", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")
      assert has_element?(lv, "#enable-totp-btn")
    end

    test "shows TOTP setup form after clicking Enable Authenticator App", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      lv |> element("#enable-totp-btn") |> render_click()

      assert has_element?(lv, "#totp-setup")
      assert has_element?(lv, "#totp-verify-form")
    end

    test "shows QR code and base32 secret during TOTP setup", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      lv |> element("#enable-totp-btn") |> render_click()

      html = render(lv)
      assert html =~ "Scan QR Code"
      assert has_element?(lv, "#totp-qr")
      assert has_element?(lv, "#totp-secret-b32")
    end

    test "shows error flash for wrong TOTP code during setup", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      lv |> element("#enable-totp-btn") |> render_click()

      html =
        lv
        |> form("#totp-verify-form", totp: %{code: "000000"})
        |> render_submit()

      assert html =~ "Invalid code"
    end

    test "cancel TOTP setup hides the setup form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      lv |> element("#enable-totp-btn") |> render_click()
      assert has_element?(lv, "#totp-setup")

      lv |> element("#cancel-totp-setup") |> render_click()
      refute has_element?(lv, "#totp-setup")
    end

    test "shows enabled badge when TOTP is already enabled", %{conn: conn, customer: customer} do
      secret = Customers.generate_totp_secret()
      {:ok, _customer} = Customers.enable_totp(customer, secret)

      {:ok, lv, _html} =
        conn
        |> Plug.Conn.put_session(:customer_2fa_verified, true)
        |> live(~p"/customers/settings")

      assert has_element?(lv, "#totp-enabled-badge")
      refute has_element?(lv, "#enable-totp-btn")
    end

    test "shows Disable button when TOTP is enabled", %{conn: conn, customer: customer} do
      secret = Customers.generate_totp_secret()
      {:ok, _customer} = Customers.enable_totp(customer, secret)

      {:ok, lv, _html} =
        conn
        |> Plug.Conn.put_session(:customer_2fa_verified, true)
        |> live(~p"/customers/settings")

      assert has_element?(lv, "#disable-totp-btn")
    end

    test "shows Add Security Key button", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")
      assert has_element?(lv, "#add-webauthn-btn")
    end

    test "shows security key label form after clicking Add Security Key", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      lv |> element("#add-webauthn-btn") |> render_click()

      assert has_element?(lv, "#webauthn-label-form-inner")
    end

    test "shows regenerate recovery codes button", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")
      assert has_element?(lv, "#regenerate-codes-btn")
    end

    test "shows remaining recovery codes count", %{conn: conn, customer: customer} do
      Customers.generate_recovery_codes(customer)

      {:ok, _lv, html} = live(conn, ~p"/customers/settings")
      assert html =~ "8"
    end

    test "regenerating recovery codes shows the new codes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      html =
        lv
        |> element("#regenerate-codes-btn")
        |> render_click()

      assert html =~ "Save your recovery codes"
      assert has_element?(lv, "#recovery-codes-list")
    end

    test "confirming codes saved hides the codes reveal panel", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")

      lv |> element("#regenerate-codes-btn") |> render_click()
      assert has_element?(lv, "#recovery-codes-reveal")

      lv |> element("#confirm-codes-saved") |> render_click()
      refute has_element?(lv, "#recovery-codes-reveal")
    end

    test "shows no security keys message when none registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/settings")
      assert has_element?(lv, "#no-webauthn-keys")
    end
  end
end
