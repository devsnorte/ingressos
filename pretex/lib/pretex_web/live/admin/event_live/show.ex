defmodule PretexWeb.Admin.EventLive.Show do
  use PretexWeb, :live_view

  alias Pretex.Catalog
  alias Pretex.Events
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "id" => id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(id)
    ticket_count = Catalog.count_items(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:ticket_count, ticket_count)
      |> assign(:page_title, event.name)

    {:ok, socket}
  end

  @impl true
  def handle_event("publish", _params, socket) do
    event = socket.assigns.event

    case Events.publish_event(event) do
      {:ok, updated_event} ->
        {:noreply,
         socket
         |> assign(:event, updated_event)
         |> put_flash(:info, "Evento publicado com sucesso.")}

      {:error, :no_catalog_items} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Adicione pelo menos um item no catálogo antes de publicar."
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível publicar o evento.")}
    end
  end

  @impl true
  def handle_event("complete", _params, socket) do
    event = socket.assigns.event

    case Events.complete_event(event) do
      {:ok, updated_event} ->
        {:noreply,
         socket
         |> assign(:event, updated_event)
         |> put_flash(:info, "Evento marcado como concluído.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível concluir o evento.")}
    end
  end

  @impl true
  def handle_event("clone", _params, socket) do
    event = socket.assigns.event
    org = socket.assigns.org

    case Events.clone_event(event) do
      {:ok, new_event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evento clonado com sucesso.")
         |> push_navigate(to: ~p"/admin/organizations/#{org}/events/#{new_event}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível clonar o evento.")}
    end
  end
end
