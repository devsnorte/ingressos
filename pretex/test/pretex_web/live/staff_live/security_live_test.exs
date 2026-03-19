defmodule PretexWeb.StaffLive.SecurityTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Pretex.AccountsFixtures

  alias Pretex.Accounts

  describe "staff security page" do
    test "unauthenticated user is redirected to staff login", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/staff/security")
      assert path == ~p"/staff/log-in"
    end

    test "authenticated staff user can access the security page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      assert html =~ "Security Settings"
    end

    test "security page renders TOTP section", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      assert html =~ "Authenticator App"
    end

    test "security page renders recovery codes section", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      assert html =~ "Recovery Codes"
    end

    test "security page renders WebAuthn section", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      assert html =~ "Security Keys"
    end

    test "shows Enable Authenticator App button when TOTP not enabled", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      assert has_element?(lv, "#enable-totp-btn")
    end

    test "shows TOTP setup form after clicking Enable Authenticator App", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      lv |> element("#enable-totp-btn") |> render_click()

      assert has_element?(lv, "#totp-setup")
      assert has_element?(lv, "#totp-verify-form")
    end

    test "shows QR code and base32 secret during TOTP setup", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      lv |> element("#enable-totp-btn") |> render_click()

      html = render(lv)
      assert html =~ "Scan QR Code"
      assert has_element?(lv, "#totp-qr")
      assert has_element?(lv, "#totp-secret-b32")
    end

    test "shows error flash for wrong TOTP code during setup", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      lv |> element("#enable-totp-btn") |> render_click()

      html =
        lv
        |> form("#totp-verify-form", totp: %{code: "000000"})
        |> render_submit()

      assert html =~ "Invalid code"
    end

    test "cancel TOTP setup hides the setup form", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      lv |> element("#enable-totp-btn") |> render_click()
      assert has_element?(lv, "#totp-setup")

      lv |> element("#cancel-totp-setup") |> render_click()
      refute has_element?(lv, "#totp-setup")
    end

    test "shows enabled badge when TOTP is already enabled", %{conn: conn} do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      {:ok, _user} = Accounts.enable_totp(user, secret)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> Plug.Conn.put_session(:user_2fa_verified, true)
        |> live(~p"/staff/security")

      assert has_element?(lv, "#totp-enabled-badge")
      refute has_element?(lv, "#enable-totp-btn")
    end

    test "shows Disable button when TOTP is enabled", %{conn: conn} do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      {:ok, _user} = Accounts.enable_totp(user, secret)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> Plug.Conn.put_session(:user_2fa_verified, true)
        |> live(~p"/staff/security")

      assert has_element?(lv, "#disable-totp-btn")
    end

    test "shows regenerate recovery codes button", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      assert has_element?(lv, "#regenerate-codes-btn")
    end

    test "regenerating recovery codes shows the new codes", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      html =
        lv
        |> element("#regenerate-codes-btn")
        |> render_click()

      assert html =~ "Save your recovery codes"
      assert has_element?(lv, "#recovery-codes-list")
    end

    test "shows Add Security Key button", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      assert has_element?(lv, "#add-webauthn-btn")
    end

    test "shows security key label form after clicking Add Security Key", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      lv |> element("#add-webauthn-btn") |> render_click()

      assert has_element?(lv, "#webauthn-label-form-inner")
    end

    test "shows no security keys message when none registered", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/staff/security")

      assert has_element?(lv, "#no-webauthn-keys")
    end

    test "shows remaining recovery codes count", %{conn: conn} do
      user = user_fixture()
      Accounts.generate_recovery_codes(user)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/staff/security")

      assert html =~ "8"
    end
  end
end
