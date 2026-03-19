defmodule PretexWeb.Admin.QuotaLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Catalog
  alias Pretex.Catalog.Quota
  alias Pretex.Events
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    quotas = Catalog.list_quotas(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:page_title, "Quotas — #{event.name}")
      |> stream(:quotas, quotas)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Quotas — #{socket.assigns.event.name}")
    |> assign(:quota, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Quota")
    |> assign(:quota, %Quota{})
    |> assign(:form, to_form(Catalog.change_quota(%Quota{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    quota = Catalog.get_quota!(id)

    socket
    |> assign(:page_title, "Edit Quota")
    |> assign(:quota, quota)
    |> assign(:form, to_form(Catalog.change_quota(quota)))
  end

  @impl true
  def handle_event("validate", %{"quota" => params}, socket) do
    changeset =
      socket.assigns.quota
      |> Catalog.change_quota(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"quota" => params}, socket) do
    case socket.assigns.live_action do
      :new -> do_create(socket, params)
      :edit -> do_update(socket, params)
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    quota = Catalog.get_quota!(id)

    case Catalog.delete_quota(quota) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Quota deleted.")
         |> stream_delete(:quotas, quota)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete quota.")}
    end
  end

  def handle_event("close_modal", _params, socket) do
    org = socket.assigns.org
    event = socket.assigns.event

    {:noreply, push_patch(socket, to: ~p"/admin/organizations/#{org}/events/#{event}/quotas")}
  end

  defp do_create(socket, params) do
    event = socket.assigns.event
    org = socket.assigns.org

    case Catalog.create_quota(event, params) do
      {:ok, quota} ->
        quota = Catalog.get_quota!(quota.id)

        {:noreply,
         socket
         |> put_flash(:info, "Quota created successfully.")
         |> stream_insert(:quotas, quota)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/quotas")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp do_update(socket, params) do
    quota = socket.assigns.quota
    org = socket.assigns.org
    event = socket.assigns.event

    case Catalog.update_quota(quota, params) do
      {:ok, updated} ->
        updated = Catalog.get_quota!(updated.id)

        {:noreply,
         socket
         |> put_flash(:info, "Quota updated successfully.")
         |> stream_insert(:quotas, updated)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/quotas")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
