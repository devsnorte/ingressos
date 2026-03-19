defmodule Pretex.Teams do
  @moduledoc """
  The Teams context manages memberships, invitations, and permissions
  for organizations.
  """

  import Ecto.Query
  alias Pretex.Repo
  alias Pretex.Accounts
  alias Pretex.Accounts.User
  alias Pretex.Organizations.Organization
  alias Pretex.Teams.Membership
  alias Pretex.Teams.Invitation
  alias Pretex.Teams.OrganizationPermission
  alias Pretex.Teams.InvitationEmail
  alias Pretex.Mailer

  # ---------------------------------------------------------------------------
  # Memberships
  # ---------------------------------------------------------------------------

  @doc """
  Returns all memberships for an organization with preloaded users.
  """
  def list_memberships(%Organization{id: org_id}) do
    Membership
    |> where([m], m.organization_id == ^org_id)
    |> preload(:user)
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single membership by id, preloading user. Raises if not found.
  """
  def get_membership!(id) do
    Membership
    |> preload(:user)
    |> Repo.get!(id)
  end

  @doc """
  Creates a membership linking a user to an organization.
  The organization_id and user_id are set explicitly (not via cast).
  """
  def create_membership(%Organization{} = organization, %User{} = user, attrs) do
    %Membership{}
    |> Membership.changeset(attrs)
    |> Ecto.Changeset.put_change(:organization_id, organization.id)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Repo.insert()
  end

  @doc """
  Updates an existing membership (role or is_active).
  """
  def update_membership(%Membership{} = membership, attrs) do
    membership
    |> Membership.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Removes a member (deletes the membership record).
  Returns {:error, :last_admin} if the membership is the last active admin
  in the organization.
  """
  def remove_member(%Membership{} = membership) do
    if last_admin?(membership) do
      {:error, :last_admin}
    else
      Repo.delete(membership)
    end
  end

  @doc """
  Returns true if the given membership is the only active admin in its
  organization. Used to guard removal and deactivation of admins.
  """
  def last_admin?(%Membership{} = membership) do
    if membership.role != "admin" or not membership.is_active do
      false
    else
      active_admin_count =
        Membership
        |> where(
          [m],
          m.organization_id == ^membership.organization_id and
            m.role == "admin" and
            m.is_active == true
        )
        |> Repo.aggregate(:count)

      active_admin_count <= 1
    end
  end

  # ---------------------------------------------------------------------------
  # Invitations
  # ---------------------------------------------------------------------------

  @doc """
  Creates an invitation record and sends the invitation email.
  """
  def invite_member(%Organization{} = organization, %User{} = invited_by, attrs) do
    token = generate_token()
    expires_at = DateTime.add(DateTime.utc_now(), 7, :day) |> DateTime.truncate(:second)

    invitation =
      %Invitation{}
      |> Invitation.changeset(attrs)
      |> Ecto.Changeset.put_change(:organization_id, organization.id)
      |> Ecto.Changeset.put_change(:invited_by_id, invited_by.id)
      |> Ecto.Changeset.put_change(:token, token)
      |> Ecto.Changeset.put_change(:expires_at, expires_at)

    with {:ok, invitation} <- Repo.insert(invitation) do
      invitation
      |> InvitationEmail.invite(organization)
      |> Mailer.deliver()

      {:ok, invitation}
    end
  end

  @doc """
  Gets an invitation by its token. Raises if not found.
  """
  def get_invitation_by_token!(token) do
    Repo.get_by!(Invitation, token: token)
  end

  @doc """
  Accepts an invitation: creates the user if not existing, creates the
  membership, and marks the invitation as accepted.
  """
  def accept_invitation(%Invitation{} = invitation, user_attrs) do
    Repo.transaction(fn ->
      user =
        case Accounts.get_user_by_email(invitation.email) do
          nil ->
            case Accounts.create_user(Map.merge(user_attrs, %{email: invitation.email})) do
              {:ok, user} -> user
              {:error, changeset} -> Repo.rollback(changeset)
            end

          existing_user ->
            existing_user
        end

      organization = Repo.get!(Pretex.Organizations.Organization, invitation.organization_id)

      case create_membership(organization, user, %{role: invitation.role}) do
        {:ok, membership} ->
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          invitation
          |> Ecto.Changeset.change(accepted_at: now)
          |> Repo.update!()

          membership

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Lists pending (not yet accepted, not expired) invitations for an organization.
  """
  def list_invitations(%Organization{id: org_id}) do
    now = DateTime.utc_now()

    Invitation
    |> where(
      [i],
      i.organization_id == ^org_id and
        is_nil(i.accepted_at) and
        i.expires_at > ^now
    )
    |> order_by([i], asc: i.inserted_at)
    |> Repo.all()
  end

  @doc """
  Revokes (deletes) an invitation.
  """
  def revoke_invitation(%Invitation{} = invitation) do
    Repo.delete(invitation)
  end

  # ---------------------------------------------------------------------------
  # Permissions
  # ---------------------------------------------------------------------------

  @doc """
  Lists all OrganizationPermissions for a given membership.
  """
  def list_permissions(%Membership{id: membership_id}) do
    OrganizationPermission
    |> where([p], p.membership_id == ^membership_id)
    |> order_by([p], asc: p.resource)
    |> Repo.all()
  end

  @doc """
  Upserts permissions for a membership. permissions_list is a list of maps
  like `%{resource: "orders", can_read: true, can_write: false}`.
  """
  def set_permissions(%Membership{} = membership, permissions_list) do
    Enum.each(permissions_list, fn attrs ->
      resource = attrs[:resource] || attrs["resource"]
      can_read = Map.get(attrs, :can_read, Map.get(attrs, "can_read", true))
      can_write = Map.get(attrs, :can_write, Map.get(attrs, "can_write", false))
      event_id = Map.get(attrs, :event_id, Map.get(attrs, "event_id", nil))

      existing =
        OrganizationPermission
        |> where(
          [p],
          p.membership_id == ^membership.id and
            p.resource == ^resource
        )
        |> then(fn query ->
          if is_nil(event_id) do
            where(query, [p], is_nil(p.event_id))
          else
            where(query, [p], p.event_id == ^event_id)
          end
        end)
        |> Repo.one()

      case existing do
        nil ->
          %OrganizationPermission{}
          |> OrganizationPermission.changeset(%{
            resource: resource,
            can_read: can_read,
            can_write: can_write,
            event_id: event_id
          })
          |> Ecto.Changeset.put_change(:membership_id, membership.id)
          |> Repo.insert!()

        perm ->
          perm
          |> OrganizationPermission.changeset(%{can_read: can_read, can_write: can_write})
          |> Repo.update!()
      end
    end)

    {:ok, list_permissions(membership)}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
