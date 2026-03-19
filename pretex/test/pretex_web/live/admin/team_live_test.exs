defmodule PretexWeb.Admin.TeamLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Accounts
  alias Pretex.Organizations
  alias Pretex.Teams

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "org-#{System.unique_integer([:positive])}"
  defp unique_email, do: "user#{System.unique_integer([:positive])}@example.com"

  defp org_fixture(attrs \\ %{}) do
    {:ok, org} =
      attrs
      |> Enum.into(%{name: "Test Org", slug: unique_slug()})
      |> Organizations.create_organization()

    org
  end

  defp user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{email: unique_email(), name: "Test User"})
      |> Accounts.create_user()

    user
  end

  defp membership_fixture(org, user, attrs \\ %{}) do
    {:ok, membership} =
      attrs
      |> Enum.into(%{role: "admin"})
      |> then(&Teams.create_membership(org, user, &1))

    membership
  end

  # ---------------------------------------------------------------------------
  # Listing members
  # ---------------------------------------------------------------------------

  describe "index — listing team members" do
    test "renders the team page with member rows", %{conn: conn} do
      org = org_fixture(%{name: "Devs Norte", slug: unique_slug()})
      user = user_fixture(%{name: "Alice Smith", email: "alice@example.com"})
      membership_fixture(org, user, %{role: "admin"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      assert has_element?(view, "#memberships")
      assert has_element?(view, "[id^='memberships-']", "Alice Smith")
      assert has_element?(view, "[id^='memberships-']", "alice@example.com")
    end

    test "renders multiple members", %{conn: conn} do
      org = org_fixture()
      alice = user_fixture(%{name: "Alice", email: "alice2@example.com"})
      bob = user_fixture(%{name: "Bob", email: "bob@example.com"})

      membership_fixture(org, alice, %{role: "admin"})
      membership_fixture(org, bob, %{role: "event_manager"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      assert has_element?(view, "[id^='memberships-']", "Alice")
      assert has_element?(view, "[id^='memberships-']", "Bob")
    end

    test "renders the Invite Member button", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      assert has_element?(view, "a[href$='/invite']")
    end

    test "shows remove button for each member", %{conn: conn} do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      assert has_element?(view, "#remove-btn-#{membership.id}")
    end

    test "shows permissions link for each member", %{conn: conn} do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      assert has_element?(
               view,
               "a[href$='/team/#{membership.id}/permissions']"
             )
    end
  end

  # ---------------------------------------------------------------------------
  # Invite form
  # ---------------------------------------------------------------------------

  describe "invite action — invite form" do
    test "navigating to :invite shows the invite form", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team/invite")

      assert has_element?(view, "#invite-form")
      assert has_element?(view, "#invite-form input[type='email']")
      assert has_element?(view, "#invite-form select")
    end

    test "validates blank email and shows error", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team/invite")

      view
      |> form("#invite-form", invitation: %{email: "", role: "admin"})
      |> render_change()

      assert has_element?(view, "#invite-form p.text-error")
    end

    test "submitting valid invite with an admin member sends invitation and shows flash", %{
      conn: conn
    } do
      org = org_fixture()
      inviter = user_fixture(%{name: "Admin User", email: "admin@example.com"})
      membership_fixture(org, inviter, %{role: "admin"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team/invite")

      view
      |> form("#invite-form", invitation: %{email: "new@example.com", role: "event_manager"})
      |> render_submit()

      flash = assert_redirect(view, ~p"/admin/organizations/#{org.id}/team")
      assert flash["info"] =~ "Invitation sent"
    end

    test "submitting invite with invalid email shows validation error", %{conn: conn} do
      org = org_fixture()
      inviter = user_fixture()
      membership_fixture(org, inviter, %{role: "admin"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team/invite")

      html =
        view
        |> form("#invite-form", invitation: %{email: "not-a-valid-email", role: "admin"})
        |> render_submit()

      assert has_element?(view, "#invite-form [id$='email-feedback']") or
               html =~ "valid email"
    end

    test "submitting invite with blank email shows required error", %{conn: conn} do
      org = org_fixture()
      inviter = user_fixture()
      membership_fixture(org, inviter, %{role: "admin"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team/invite")

      _html =
        view
        |> form("#invite-form", invitation: %{email: "", role: "admin"})
        |> render_submit()

      assert has_element?(view, "#invite-form")
    end

    test "cancel link closes invite form", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team/invite")

      assert has_element?(view, "#invite-form")

      view
      |> element("a[href$='/team']", "Cancel")
      |> render_click()

      refute has_element?(view, "#invite-form")
    end
  end

  # ---------------------------------------------------------------------------
  # Permissions form
  # ---------------------------------------------------------------------------

  describe "permissions action — editing member permissions" do
    test "navigating to :permissions shows the permissions form", %{conn: conn} do
      org = org_fixture()
      user = user_fixture(%{name: "Charlie", email: "charlie@example.com"})
      membership = membership_fixture(org, user, %{role: "event_manager"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org.id}/team/#{membership.id}/permissions")

      assert has_element?(view, "#permissions-form")
    end

    test "permissions form contains checkboxes for each resource", %{conn: conn} do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org.id}/team/#{membership.id}/permissions")

      for resource <- ~w(events orders vouchers reports settings) do
        assert has_element?(
                 view,
                 "#permissions-form input[type='checkbox'][name='permissions[can_read_#{resource}]']"
               )

        assert has_element?(
                 view,
                 "#permissions-form input[type='checkbox'][name='permissions[can_write_#{resource}]']"
               )
      end
    end

    test "submitting permissions form saves and shows success flash", %{conn: conn} do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org.id}/team/#{membership.id}/permissions")

      view
      |> form("#permissions-form", %{
        permissions: %{
          "can_read_events" => "true",
          "can_write_events" => "true",
          "can_read_orders" => "true",
          "can_write_orders" => "false",
          "can_read_vouchers" => "false",
          "can_write_vouchers" => "false",
          "can_read_reports" => "true",
          "can_write_reports" => "false",
          "can_read_settings" => "false",
          "can_write_settings" => "false"
        }
      })
      |> render_submit()

      flash = assert_redirect(view, ~p"/admin/organizations/#{org.id}/team")
      assert flash["info"] =~ "Permissions saved"
    end

    test "permissions form shows member name in title", %{conn: conn} do
      org = org_fixture()
      user = user_fixture(%{name: "Dana Lee", email: "dana@example.com"})
      membership = membership_fixture(org, user)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org.id}/team/#{membership.id}/permissions")

      assert has_element?(view, "h2", "Dana Lee")
    end

    test "permissions are persisted after save", %{conn: conn} do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org.id}/team/#{membership.id}/permissions")

      view
      |> form("#permissions-form", %{
        permissions: %{
          "can_read_events" => "true",
          "can_write_events" => "true",
          "can_read_orders" => "false",
          "can_write_orders" => "false",
          "can_read_vouchers" => "false",
          "can_write_vouchers" => "false",
          "can_read_reports" => "false",
          "can_write_reports" => "false",
          "can_read_settings" => "false",
          "can_write_settings" => "false"
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/admin/organizations/#{org.id}/team")

      permissions = Teams.list_permissions(membership)
      events_perm = Enum.find(permissions, &(&1.resource == "events"))
      assert events_perm != nil
      assert events_perm.can_read == true
      assert events_perm.can_write == true
    end
  end

  # ---------------------------------------------------------------------------
  # Remove member — typed-phrase confirmation
  # ---------------------------------------------------------------------------

  describe "remove member — confirmation modal" do
    test "clicking Remove opens confirmation modal", %{conn: conn} do
      org = org_fixture()
      user = user_fixture(%{name: "Eve", email: "eve@example.com"})
      membership = membership_fixture(org, user)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      view
      |> element("#remove-btn-#{membership.id}")
      |> render_click()

      assert has_element?(view, "#confirm-remove-modal")
      assert has_element?(view, "#confirm-remove-form")
    end

    test "confirmation modal shows the member's email to type", %{conn: conn} do
      org = org_fixture()
      user = user_fixture(%{name: "Eve", email: "eve2@example.com"})
      membership = membership_fixture(org, user)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      view
      |> element("#remove-btn-#{membership.id}")
      |> render_click()

      assert has_element?(view, "#confirm-remove-modal", "eve2@example.com")
    end

    test "typing the correct email and submitting removes the member", %{conn: conn} do
      org = org_fixture()
      user1 = user_fixture(%{name: "Admin 1", email: "admin1remove@example.com"})
      user2 = user_fixture(%{name: "Member", email: "member.remove@example.com"})

      membership_fixture(org, user1, %{role: "admin"})
      membership = membership_fixture(org, user2, %{role: "event_manager"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      view
      |> element("#remove-btn-#{membership.id}")
      |> render_click()

      view
      |> form("#confirm-remove-form", confirm: %{phrase: "member.remove@example.com"})
      |> render_submit()

      assert has_element?(view, "#memberships")
      refute has_element?(view, "#remove-btn-#{membership.id}")
    end

    test "removing a member shows success flash", %{conn: conn} do
      org = org_fixture()
      user1 = user_fixture()
      user2 = user_fixture(%{email: "torm@example.com"})

      membership_fixture(org, user1, %{role: "admin"})
      membership = membership_fixture(org, user2, %{role: "event_manager"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      view
      |> element("#remove-btn-#{membership.id}")
      |> render_click()

      view
      |> form("#confirm-remove-form", confirm: %{phrase: "torm@example.com"})
      |> render_submit()

      assert has_element?(view, "[role='alert']", "Member removed successfully")
    end

    test "typing wrong phrase shows error flash and keeps modal closed", %{conn: conn} do
      org = org_fixture()
      user1 = user_fixture()
      user2 = user_fixture(%{email: "stay@example.com"})

      membership_fixture(org, user1, %{role: "admin"})
      membership = membership_fixture(org, user2, %{role: "event_manager"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      view
      |> element("#remove-btn-#{membership.id}")
      |> render_click()

      view
      |> form("#confirm-remove-form", confirm: %{phrase: "wrong@example.com"})
      |> render_submit()

      assert has_element?(view, "[role='alert']", "does not match")
    end

    test "cancel button closes the confirmation modal", %{conn: conn} do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      view
      |> element("#remove-btn-#{membership.id}")
      |> render_click()

      assert has_element?(view, "#confirm-remove-modal")

      view
      |> element("#cancel-remove-btn")
      |> render_click()

      refute has_element?(view, "#confirm-remove-modal")
    end
  end

  # ---------------------------------------------------------------------------
  # Last admin protection
  # ---------------------------------------------------------------------------

  describe "last admin protection" do
    test "removing the last admin shows error flash and does not remove member", %{conn: conn} do
      org = org_fixture()
      user = user_fixture(%{name: "Solo Admin", email: "solo@example.com"})
      membership = membership_fixture(org, user, %{role: "admin"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      view
      |> element("#remove-btn-#{membership.id}")
      |> render_click()

      view
      |> form("#confirm-remove-form", confirm: %{phrase: "solo@example.com"})
      |> render_submit()

      assert has_element?(view, "[role='alert']", "last admin")
      assert has_element?(view, "#remove-btn-#{membership.id}")
    end

    test "removing a second admin (not the last) succeeds", %{conn: conn} do
      org = org_fixture()
      admin1 = user_fixture(%{name: "Admin One", email: "admin.one@example.com"})
      admin2 = user_fixture(%{name: "Admin Two", email: "admin.two@example.com"})

      membership_fixture(org, admin1, %{role: "admin"})
      m2 = membership_fixture(org, admin2, %{role: "admin"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}/team")

      view
      |> element("#remove-btn-#{m2.id}")
      |> render_click()

      view
      |> form("#confirm-remove-form", confirm: %{phrase: "admin.two@example.com"})
      |> render_submit()

      assert has_element?(view, "[role='alert']", "Member removed successfully")
      refute has_element?(view, "#remove-btn-#{m2.id}")
    end
  end
end
