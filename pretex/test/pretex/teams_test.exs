defmodule Pretex.TeamsTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures

  alias Pretex.Accounts
  alias Pretex.Teams
  alias Pretex.Teams.Membership
  alias Pretex.Teams.Invitation

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

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

  defp unique_email do
    "user#{System.unique_integer([:positive])}@example.com"
  end

  # ---------------------------------------------------------------------------
  # Memberships
  # ---------------------------------------------------------------------------

  describe "list_memberships/1" do
    test "returns all memberships for the organization with preloaded users" do
      org = org_fixture()
      user1 = user_fixture(%{name: "Alice", email: "alice@example.com"})
      user2 = user_fixture(%{name: "Bob", email: "bob@example.com"})

      membership_fixture(org, user1, %{role: "admin"})
      membership_fixture(org, user2, %{role: "event_manager"})

      memberships = Teams.list_memberships(org)

      assert length(memberships) == 2
      assert Enum.all?(memberships, &match?(%Membership{user: %Accounts.User{}}, &1))
      emails = Enum.map(memberships, & &1.user.email)
      assert "alice@example.com" in emails
      assert "bob@example.com" in emails
    end

    test "returns empty list when organization has no members" do
      org = org_fixture()
      assert Teams.list_memberships(org) == []
    end

    test "does not return memberships for other organizations" do
      org1 = org_fixture(%{name: "Org 1", slug: "org-1-#{System.unique_integer([:positive])}"})
      org2 = org_fixture(%{name: "Org 2", slug: "org-2-#{System.unique_integer([:positive])}"})
      user = user_fixture()

      membership_fixture(org1, user)

      assert Teams.list_memberships(org2) == []
    end
  end

  describe "create_membership/3" do
    test "creates a membership with valid attrs" do
      org = org_fixture()
      user = user_fixture()

      assert {:ok, %Membership{} = membership} =
               Teams.create_membership(org, user, %{role: "admin"})

      assert membership.organization_id == org.id
      assert membership.user_id == user.id
      assert membership.role == "admin"
      assert membership.is_active == true
    end

    test "creates a membership with event_manager role" do
      org = org_fixture()
      user = user_fixture()

      assert {:ok, %Membership{role: "event_manager"}} =
               Teams.create_membership(org, user, %{role: "event_manager"})
    end

    test "creates a membership with checkin_operator role" do
      org = org_fixture()
      user = user_fixture()

      assert {:ok, %Membership{role: "checkin_operator"}} =
               Teams.create_membership(org, user, %{role: "checkin_operator"})
    end

    test "returns error with invalid role" do
      org = org_fixture()
      user = user_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Teams.create_membership(org, user, %{role: "superuser"})

      assert %{role: [_]} = errors_on(changeset)
    end

    test "returns error when role is missing" do
      org = org_fixture()
      user = user_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Teams.create_membership(org, user, %{})

      assert %{role: [_]} = errors_on(changeset)
    end

    test "returns error on duplicate membership for same org and user" do
      org = org_fixture()
      user = user_fixture()

      membership_fixture(org, user)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Teams.create_membership(org, user, %{role: "event_manager"})

      assert %{organization_id: [_]} = errors_on(changeset)
    end
  end

  describe "remove_member/1" do
    test "deletes the membership when not the last admin" do
      org = org_fixture()
      user1 = user_fixture()
      user2 = user_fixture()

      m1 = membership_fixture(org, user1, %{role: "admin"})
      m2 = membership_fixture(org, user2, %{role: "admin"})

      assert {:ok, %Membership{}} = Teams.remove_member(m2)

      memberships = Teams.list_memberships(org)
      assert length(memberships) == 1
      assert hd(memberships).id == m1.id
    end

    test "deletes a non-admin membership" do
      org = org_fixture()
      admin_user = user_fixture()
      member_user = user_fixture()

      membership_fixture(org, admin_user, %{role: "admin"})
      membership = membership_fixture(org, member_user, %{role: "event_manager"})

      assert {:ok, %Membership{}} = Teams.remove_member(membership)
      assert length(Teams.list_memberships(org)) == 1
    end

    test "returns {:error, :last_admin} when removing the last admin" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user, %{role: "admin"})

      assert {:error, :last_admin} = Teams.remove_member(membership)
      assert length(Teams.list_memberships(org)) == 1
    end
  end

  describe "last_admin?/1" do
    test "returns true when the membership is the only active admin" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user, %{role: "admin"})

      assert Teams.last_admin?(membership) == true
    end

    test "returns false when there are two active admins" do
      org = org_fixture()
      user1 = user_fixture()
      user2 = user_fixture()

      m1 = membership_fixture(org, user1, %{role: "admin"})
      membership_fixture(org, user2, %{role: "admin"})

      assert Teams.last_admin?(m1) == false
    end

    test "returns false when the membership role is not admin" do
      org = org_fixture()
      admin_user = user_fixture()
      member_user = user_fixture()

      membership_fixture(org, admin_user, %{role: "admin"})
      non_admin = membership_fixture(org, member_user, %{role: "event_manager"})

      assert Teams.last_admin?(non_admin) == false
    end

    test "returns false when the admin membership is inactive" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user, %{role: "admin"})

      {:ok, inactive} = Teams.update_membership(membership, %{is_active: false})

      assert Teams.last_admin?(inactive) == false
    end

    test "returns false when there are no admins at all" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user, %{role: "event_manager"})

      assert Teams.last_admin?(membership) == false
    end
  end

  # ---------------------------------------------------------------------------
  # Invitations
  # ---------------------------------------------------------------------------

  describe "invite_member/3" do
    test "creates an invitation record with token and expiry" do
      org = org_fixture()
      inviter = user_fixture()

      assert {:ok, %Invitation{} = invitation} =
               Teams.invite_member(org, inviter, %{
                 email: "newmember@example.com",
                 role: "event_manager"
               })

      assert invitation.organization_id == org.id
      assert invitation.invited_by_id == inviter.id
      assert invitation.email == "newmember@example.com"
      assert invitation.role == "event_manager"
      assert invitation.token != nil
      assert String.length(invitation.token) > 0
      assert invitation.accepted_at == nil
      assert %DateTime{} = invitation.expires_at
    end

    test "invitation expires in roughly 7 days" do
      org = org_fixture()
      inviter = user_fixture()

      {:ok, invitation} =
        Teams.invite_member(org, inviter, %{
          email: "newmember@example.com",
          role: "admin"
        })

      diff = DateTime.diff(invitation.expires_at, DateTime.utc_now(), :hour)
      assert diff >= 167 and diff <= 169
    end

    test "returns error with duplicate pending invitation for same email and org" do
      org = org_fixture()
      inviter = user_fixture()

      {:ok, _} =
        Teams.invite_member(org, inviter, %{
          email: "dup@example.com",
          role: "admin"
        })

      assert {:error, %Ecto.Changeset{} = changeset} =
               Teams.invite_member(org, inviter, %{
                 email: "dup@example.com",
                 role: "event_manager"
               })

      assert %{organization_id: [_]} = errors_on(changeset)
    end

    test "returns error with invalid email" do
      org = org_fixture()
      inviter = user_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Teams.invite_member(org, inviter, %{
                 email: "not-an-email",
                 role: "admin"
               })

      assert %{email: [_]} = errors_on(changeset)
    end

    test "returns error with blank email" do
      org = org_fixture()
      inviter = user_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Teams.invite_member(org, inviter, %{
                 email: "",
                 role: "admin"
               })

      assert %{email: [_]} = errors_on(changeset)
    end

    test "returns error with invalid role" do
      org = org_fixture()
      inviter = user_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Teams.invite_member(org, inviter, %{
                 email: "valid@example.com",
                 role: "superadmin"
               })

      assert %{role: [_]} = errors_on(changeset)
    end

    test "generates unique tokens for different invitations" do
      org = org_fixture()
      inviter = user_fixture()

      {:ok, inv1} =
        Teams.invite_member(org, inviter, %{email: "a@example.com", role: "admin"})

      org2 = org_fixture()

      {:ok, inv2} =
        Teams.invite_member(org2, inviter, %{email: "a@example.com", role: "admin"})

      assert inv1.token != inv2.token
    end
  end

  describe "get_invitation_by_token!/1" do
    test "returns the invitation for a valid token" do
      org = org_fixture()
      inviter = user_fixture()

      {:ok, invitation} =
        Teams.invite_member(org, inviter, %{email: "tok@example.com", role: "admin"})

      found = Teams.get_invitation_by_token!(invitation.token)
      assert found.id == invitation.id
    end

    test "raises when token does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Teams.get_invitation_by_token!("nonexistent-token")
      end
    end
  end

  describe "list_invitations/1" do
    test "returns pending invitations for the organization" do
      org = org_fixture()
      inviter = user_fixture()

      {:ok, _} =
        Teams.invite_member(org, inviter, %{email: "pending@example.com", role: "admin"})

      invitations = Teams.list_invitations(org)
      assert length(invitations) == 1
      assert hd(invitations).email == "pending@example.com"
    end

    test "does not return invitations from other organizations" do
      org1 = org_fixture()
      org2 = org_fixture()
      inviter = user_fixture()

      {:ok, _} = Teams.invite_member(org1, inviter, %{email: "x@example.com", role: "admin"})

      assert Teams.list_invitations(org2) == []
    end
  end

  describe "revoke_invitation/1" do
    test "deletes the invitation" do
      org = org_fixture()
      inviter = user_fixture()

      {:ok, invitation} =
        Teams.invite_member(org, inviter, %{email: "revoke@example.com", role: "admin"})

      assert {:ok, %Invitation{}} = Teams.revoke_invitation(invitation)
      assert Teams.list_invitations(org) == []
    end
  end

  # ---------------------------------------------------------------------------
  # Permissions
  # ---------------------------------------------------------------------------

  describe "set_permissions/2 and list_permissions/1" do
    test "inserts permissions for a membership" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      permissions_list = [
        %{resource: "events", can_read: true, can_write: true},
        %{resource: "orders", can_read: true, can_write: false},
        %{resource: "reports", can_read: false, can_write: false}
      ]

      {:ok, permissions} = Teams.set_permissions(membership, permissions_list)

      assert length(permissions) == 3

      events_perm = Enum.find(permissions, &(&1.resource == "events"))
      assert events_perm.can_read == true
      assert events_perm.can_write == true

      orders_perm = Enum.find(permissions, &(&1.resource == "orders"))
      assert orders_perm.can_read == true
      assert orders_perm.can_write == false
    end

    test "list_permissions/1 returns permissions for a membership" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      {:ok, _} =
        Teams.set_permissions(membership, [
          %{resource: "vouchers", can_read: true, can_write: true},
          %{resource: "settings", can_read: false, can_write: false}
        ])

      permissions = Teams.list_permissions(membership)
      assert length(permissions) == 2
      resources = Enum.map(permissions, & &1.resource)
      assert "vouchers" in resources
      assert "settings" in resources
    end

    test "updates existing permissions on repeated set_permissions" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      {:ok, _} =
        Teams.set_permissions(membership, [
          %{resource: "events", can_read: true, can_write: false}
        ])

      {:ok, updated} =
        Teams.set_permissions(membership, [
          %{resource: "events", can_read: true, can_write: true}
        ])

      events_perm = Enum.find(updated, &(&1.resource == "events"))
      assert events_perm.can_write == true

      # Should not duplicate
      all = Teams.list_permissions(membership)
      events_count = Enum.count(all, &(&1.resource == "events"))
      assert events_count == 1
    end

    test "list_permissions/1 returns empty list when no permissions set" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      assert Teams.list_permissions(membership) == []
    end

    test "permissions are scoped to the correct membership" do
      org = org_fixture()
      user1 = user_fixture()
      user2 = user_fixture()

      m1 = membership_fixture(org, user1)
      m2 = membership_fixture(org, user2, %{role: "event_manager"})

      {:ok, _} =
        Teams.set_permissions(m1, [%{resource: "events", can_read: true, can_write: true}])

      assert Teams.list_permissions(m2) == []
    end

    test "all five resources can be set independently" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      all_resources =
        Enum.map(
          ~w(events orders vouchers reports settings),
          &%{resource: &1, can_read: true, can_write: false}
        )

      {:ok, permissions} = Teams.set_permissions(membership, all_resources)
      assert length(permissions) == 5

      assert Enum.all?(permissions, fn p ->
               p.resource in ~w(events orders vouchers reports settings)
             end)
    end
  end

  describe "update_membership/2" do
    test "updates the role" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user, %{role: "admin"})

      # Add a second admin so the update is not blocked
      user2 = user_fixture()
      membership_fixture(org, user2, %{role: "admin"})

      {:ok, updated} = Teams.update_membership(membership, %{role: "event_manager"})
      assert updated.role == "event_manager"
    end

    test "updates is_active" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user, %{role: "event_manager"})

      {:ok, updated} = Teams.update_membership(membership, %{is_active: false})
      assert updated.is_active == false
    end

    test "returns error with invalid role" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      assert {:error, %Ecto.Changeset{}} = Teams.update_membership(membership, %{role: "invalid"})
    end
  end

  describe "get_membership!/1" do
    test "returns the membership with preloaded user" do
      org = org_fixture()
      user = user_fixture()
      membership = membership_fixture(org, user)

      found = Teams.get_membership!(membership.id)
      assert found.id == membership.id
      assert found.user.id == user.id
    end

    test "raises when membership does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Teams.get_membership!(0)
      end
    end
  end
end
