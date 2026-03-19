defmodule PretexWeb.Admin.TeamLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Organizations
  alias Pretex.Teams
  alias Pretex.Teams.Invitation

  @resources ~w(events orders vouchers reports settings)
  @roles [
    {"Admin", "admin"},
    {"Event Manager", "event_manager"},
    {"Check-in Operator", "checkin_operator"}
  ]

  @impl true
  def mount(%{"org_id" => org_id}, _session, socket) do
    organization = Organizations.get_organization!(org_id)
    memberships = Teams.list_memberships(organization)

    {:ok,
     socket
     |> assign(:organization, organization)
     |> assign(:page_title, "#{organization.name} — Team")
     |> assign(:roles, @roles)
     |> assign(:resources, @resources)
     |> assign(:selected_membership, nil)
     |> assign(:confirm_remove_membership, nil)
     |> assign(:confirm_form, nil)
     |> assign(:invite_form, nil)
     |> assign(:permissions_form, nil)
     |> stream(:memberships, memberships)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:selected_membership, nil)
    |> assign(:invite_form, nil)
    |> assign(:permissions_form, nil)
  end

  defp apply_action(socket, :invite, _params) do
    socket
    |> assign(:selected_membership, nil)
    |> assign(:invite_form, build_invite_form())
    |> assign(:permissions_form, nil)
  end

  defp apply_action(socket, :permissions, %{"id" => id}) do
    membership = Teams.get_membership!(id)
    permissions = Teams.list_permissions(membership)

    socket
    |> assign(:selected_membership, membership)
    |> assign(:invite_form, nil)
    |> assign(:permissions_form, build_permissions_form(permissions))
  end

  defp build_invite_form(attrs \\ %{}) do
    %Invitation{}
    |> Invitation.changeset(attrs)
    |> to_form()
  end

  defp build_permissions_form(permissions) do
    params =
      Enum.reduce(@resources, %{}, fn resource, acc ->
        perm = Enum.find(permissions, &(&1.resource == resource))

        acc
        |> Map.put("can_read_#{resource}", if(perm, do: perm.can_read, else: true))
        |> Map.put("can_write_#{resource}", if(perm, do: perm.can_write, else: false))
      end)

    to_form(params, as: :permissions)
  end

  @impl true
  def handle_event("validate_invite", %{"invitation" => params}, socket) do
    form =
      %Invitation{}
      |> Invitation.changeset(params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, :invite_form, form)}
  end

  def handle_event("send_invite", %{"invitation" => params}, socket) do
    org = socket.assigns.organization

    case find_inviter(org) do
      nil ->
        {:noreply,
         put_flash(socket, :error, "No admin member found to send the invitation on behalf of")}

      inviter ->
        case Teams.invite_member(org, inviter, params) do
          {:ok, _invitation} ->
            {:noreply,
             socket
             |> put_flash(:info, "Invitation sent to #{params["email"]}")
             |> push_navigate(to: ~p"/admin/organizations/#{org.id}/team")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :invite_form, to_form(changeset))}
        end
    end
  end

  def handle_event("confirm_remove", %{"id" => id}, socket) do
    membership = Teams.get_membership!(id)

    {:noreply,
     socket
     |> assign(:confirm_remove_membership, membership)
     |> assign(:confirm_form, to_form(%{"phrase" => ""}, as: :confirm))}
  end

  def handle_event("cancel_remove", _params, socket) do
    {:noreply,
     socket
     |> assign(:confirm_remove_membership, nil)
     |> assign(:confirm_form, nil)}
  end

  def handle_event("execute_remove", %{"confirm" => %{"phrase" => phrase}}, socket) do
    membership = socket.assigns.confirm_remove_membership
    expected_email = membership.user.email

    if phrase == expected_email do
      case Teams.remove_member(membership) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Member removed successfully")
           |> assign(:confirm_remove_membership, nil)
           |> assign(:confirm_form, nil)
           |> stream_delete(:memberships, membership)}

        {:error, :last_admin} ->
          {:noreply,
           socket
           |> put_flash(:error, "Cannot remove the last admin of the organization")
           |> assign(:confirm_remove_membership, nil)
           |> assign(:confirm_form, nil)}
      end
    else
      {:noreply,
       socket
       |> assign(:confirm_form, to_form(%{"phrase" => phrase}, as: :confirm))
       |> put_flash(:error, "The email you typed does not match. Please try again.")}
    end
  end

  def handle_event("save_permissions", %{"permissions" => params}, socket) do
    membership = socket.assigns.selected_membership

    permissions_list =
      Enum.map(@resources, fn resource ->
        %{
          resource: resource,
          can_read: params["can_read_#{resource}"] == "true",
          can_write: params["can_write_#{resource}"] == "true"
        }
      end)

    {:ok, _permissions} = Teams.set_permissions(membership, permissions_list)
    org = socket.assigns.organization

    {:noreply,
     socket
     |> put_flash(:info, "Permissions saved successfully")
     |> push_navigate(to: ~p"/admin/organizations/#{org.id}/team")}
  end

  defp find_inviter(organization) do
    organization
    |> Teams.list_memberships()
    |> Enum.find(&(&1.role == "admin" and &1.is_active))
    |> case do
      nil -> nil
      membership -> membership.user
    end
  end
end
