defmodule PretexWeb.Admin.OrganizationLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Organizations
  alias Pretex.Organizations.Organization

  @impl true
  def mount(_params, _session, socket) do
    # NO queries in mount — Iron Law
    {:ok, assign(socket, :page_title, "Organizations")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    organizations = Organizations.list_organizations()

    socket
    |> assign(:organizations, organizations)
    |> assign(:organization, nil)
  end

  defp apply_action(socket, :new, _params) do
    organizations = Organizations.list_organizations()

    socket
    |> assign(:organizations, organizations)
    |> assign(:organization, %Organization{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    organizations = Organizations.list_organizations()

    socket
    |> assign(:organizations, organizations)
    |> assign(:organization, Organizations.get_organization!(id))
  end

  @impl true
  def handle_info(
        {PretexWeb.Admin.OrganizationLive.FormComponent, {:saved, _organization}},
        socket
      ) do
    {:noreply, assign(socket, :organizations, Organizations.list_organizations())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    organization = Organizations.get_organization!(id)
    {:ok, _} = Organizations.delete_organization(organization)

    {:noreply, assign(socket, :organizations, Organizations.list_organizations())}
  end
end
