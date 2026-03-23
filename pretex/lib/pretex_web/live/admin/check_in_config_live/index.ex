defmodule PretexWeb.Admin.CheckInConfigLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Catalog
  alias Pretex.CheckIns

  alias Pretex.Events
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    check_in_lists = CheckIns.list_check_in_lists(event.id)
    gates = CheckIns.list_gates(event.id)
    catalog_items = Catalog.list_items(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:catalog_items, catalog_items)
      |> assign(:check_in_lists, check_in_lists)
      |> assign(:gates, gates)
      |> assign(:form, nil)
      |> assign(:selected_item_ids, [])
      |> assign(:selected_list_ids, [])
      |> assign(:page_title, "Configuração de Check-in — #{event.name}")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:form, nil)
    |> assign(:selected_item_ids, [])
    |> assign(:selected_list_ids, [])
  end

  defp apply_action(socket, :new_list, _params) do
    form = to_form(%{"name" => "", "starts_at_time" => "", "ends_at_time" => ""}, as: :list)

    socket
    |> assign(:form, form)
    |> assign(:selected_item_ids, [])
  end

  defp apply_action(socket, :edit_list, %{"list_id" => list_id}) do
    list = CheckIns.get_check_in_list!(list_id)
    item_ids = Enum.map(list.check_in_list_items, & &1.item_id)

    form =
      to_form(
        %{
          "name" => list.name,
          "starts_at_time" =>
            if(list.starts_at_time, do: Time.to_string(list.starts_at_time), else: ""),
          "ends_at_time" => if(list.ends_at_time, do: Time.to_string(list.ends_at_time), else: "")
        },
        as: :list
      )

    socket
    |> assign(:form, form)
    |> assign(:editing_list_id, list_id)
    |> assign(:selected_item_ids, item_ids)
  end

  defp apply_action(socket, :new_gate, _params) do
    form = to_form(%{"name" => ""}, as: :gate)

    socket
    |> assign(:form, form)
    |> assign(:selected_list_ids, [])
  end

  defp apply_action(socket, :edit_gate, %{"gate_id" => gate_id}) do
    gate = CheckIns.get_gate!(gate_id)
    list_ids = Enum.map(gate.check_in_lists, & &1.id)

    form = to_form(%{"name" => gate.name}, as: :gate)

    socket
    |> assign(:form, form)
    |> assign(:editing_gate_id, gate_id)
    |> assign(:selected_list_ids, list_ids)
  end

  @impl true
  def handle_event("toggle_item", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    current = socket.assigns.selected_item_ids

    updated =
      if id in current,
        do: List.delete(current, id),
        else: [id | current]

    {:noreply, assign(socket, :selected_item_ids, updated)}
  end

  @impl true
  def handle_event("toggle_list", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    current = socket.assigns.selected_list_ids

    updated =
      if id in current,
        do: List.delete(current, id),
        else: [id | current]

    {:noreply, assign(socket, :selected_list_ids, updated)}
  end

  @impl true
  def handle_event("save_list", %{"list" => params}, socket) do
    event = socket.assigns.event
    item_ids = socket.assigns.selected_item_ids

    attrs = %{
      name: params["name"],
      item_ids: item_ids,
      starts_at_time: parse_time(params["starts_at_time"]),
      ends_at_time: parse_time(params["ends_at_time"])
    }

    result =
      if socket.assigns.live_action == :edit_list do
        CheckIns.update_check_in_list(socket.assigns.editing_list_id, attrs)
      else
        CheckIns.create_check_in_list(event.id, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:check_in_lists, CheckIns.list_check_in_lists(event.id))
         |> put_flash(:info, "Lista salva com sucesso.")
         |> push_patch(to: config_path(socket))}

      {:error, :no_items} ->
        {:noreply, put_flash(socket, :error, "Selecione pelo menos um item.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar lista.")}
    end
  end

  @impl true
  def handle_event("save_gate", %{"gate" => params}, socket) do
    event = socket.assigns.event
    list_ids = socket.assigns.selected_list_ids

    attrs = %{
      name: params["name"],
      check_in_list_ids: list_ids
    }

    result =
      if socket.assigns.live_action == :edit_gate do
        CheckIns.update_gate(socket.assigns.editing_gate_id, attrs)
      else
        CheckIns.create_gate(event.id, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:gates, CheckIns.list_gates(event.id))
         |> put_flash(:info, "Portão salvo com sucesso.")
         |> push_patch(to: config_path(socket))}

      {:error, :no_check_in_lists} ->
        {:noreply, put_flash(socket, :error, "Selecione pelo menos uma lista.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar portão.")}
    end
  end

  @impl true
  def handle_event("delete_list", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    {:ok, _} = CheckIns.delete_check_in_list(id)

    {:noreply,
     socket
     |> assign(:check_in_lists, CheckIns.list_check_in_lists(socket.assigns.event.id))
     |> assign(:gates, CheckIns.list_gates(socket.assigns.event.id))
     |> put_flash(:info, "Lista excluída.")}
  end

  @impl true
  def handle_event("delete_gate", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    {:ok, _} = CheckIns.delete_gate(id)

    {:noreply,
     socket
     |> assign(:gates, CheckIns.list_gates(socket.assigns.event.id))
     |> put_flash(:info, "Portão excluído.")}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: config_path(socket))}
  end

  defp config_path(socket) do
    ~p"/admin/organizations/#{socket.assigns.org}/events/#{socket.assigns.event}/check-in/config"
  end

  defp parse_time(""), do: nil
  defp parse_time(nil), do: nil

  defp parse_time(str) do
    case Time.from_iso8601(str <> ":00") do
      {:ok, time} ->
        time

      _ ->
        case Time.from_iso8601(str) do
          {:ok, time} -> time
          _ -> nil
        end
    end
  end
end
