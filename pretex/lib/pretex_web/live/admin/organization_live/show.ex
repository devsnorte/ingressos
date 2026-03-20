defmodule PretexWeb.Admin.OrganizationLive.Show do
  use PretexWeb, :live_view

  alias Pretex.Organizations

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    organization = Organizations.get_organization!(id)

    {:noreply,
     socket
     |> assign(:page_title, organization.name)
     |> assign(:organization, organization)}
  end

  @impl true
  def handle_event("toggle_require_2fa", _params, socket) do
    org = socket.assigns.organization
    new_value = !org.require_2fa

    case Organizations.set_require_2fa(org, new_value) do
      {:ok, updated_org} ->
        {:noreply,
         socket
         |> assign(:organization, updated_org)
         |> put_flash(
           :info,
           if(new_value, do: "Exigência de 2FA ativada.", else: "Exigência de 2FA desativada.")
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Falha ao atualizar exigência de 2FA.")}
    end
  end

  @impl true
  def handle_info(
        {PretexWeb.Admin.OrganizationLive.FormComponent, {:saved, organization}},
        socket
      ) do
    {:noreply, assign(socket, :organization, organization)}
  end
end
