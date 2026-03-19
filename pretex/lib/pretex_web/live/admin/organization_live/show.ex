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
  def handle_info(
        {PretexWeb.Admin.OrganizationLive.FormComponent, {:saved, organization}},
        socket
      ) do
    {:noreply, assign(socket, :organization, organization)}
  end
end
