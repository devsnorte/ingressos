defmodule PretexWeb.Admin.SeatingLive.Show do
  @moduledoc """
  Displays the details of a seating plan: its sections, seat counts, and
  item mappings. Allows organizers to:
  - Map sections to catalog items/variations.
  - Assign the plan to an event.
  """

  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Organizations
  alias Pretex.Seating

  @impl true
  def mount(%{"org_id" => org_id, "id" => plan_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    plan = Seating.get_seating_plan!(plan_id)
    events = Events.list_events(org)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:plan, plan)
      |> assign(:events, events)
      |> assign(:page_title, "Planta — #{plan.name}")
      |> assign(:mapping_section_id, nil)
      |> assign(:mapping_form, nil)
      |> assign(:assign_event_form, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("map_section", %{"section_id" => section_id_str}, socket) do
    section_id = String.to_integer(section_id_str)
    org = socket.assigns.org
    event_items = list_items_for_org(org.id)

    {:noreply,
     socket
     |> assign(:mapping_section_id, section_id)
     |> assign(:event_items, event_items)
     |> assign(:mapping_form, to_form(%{"item_id" => "", "item_variation_id" => ""}))}
  end

  def handle_event("cancel_mapping", _params, socket) do
    {:noreply,
     socket
     |> assign(:mapping_section_id, nil)
     |> assign(:mapping_form, nil)}
  end

  def handle_event(
        "save_mapping",
        %{"mapping" => %{"item_id" => item_id_str, "item_variation_id" => var_id_str}},
        socket
      ) do
    section_id = socket.assigns.mapping_section_id
    item_id = parse_optional_id(item_id_str)
    variation_id = parse_optional_id(var_id_str)

    case Seating.map_section_to_item(section_id, item_id, variation_id) do
      {:ok, _section} ->
        plan = Seating.get_seating_plan!(socket.assigns.plan.id)

        {:noreply,
         socket
         |> assign(:plan, plan)
         |> assign(:mapping_section_id, nil)
         |> assign(:mapping_form, nil)
         |> put_flash(:info, "Seção mapeada com sucesso.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Seção não encontrada.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar mapeamento.")}
    end
  end

  def handle_event("show_assign_event", _params, socket) do
    {:noreply, assign(socket, :assign_event_form, to_form(%{"event_id" => ""}))}
  end

  def handle_event("cancel_assign_event", _params, socket) do
    {:noreply, assign(socket, :assign_event_form, nil)}
  end

  def handle_event("assign_to_event", %{"assignment" => %{"event_id" => event_id_str}}, socket) do
    plan = socket.assigns.plan

    case parse_optional_id(event_id_str) do
      nil ->
        {:noreply, put_flash(socket, :error, "Selecione um evento.")}

      event_id ->
        case Seating.assign_plan_to_event(event_id, plan.id) do
          {:ok, _event} ->
            {:noreply,
             socket
             |> assign(:assign_event_form, nil)
             |> put_flash(:info, "Planta atribuída ao evento com sucesso.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Erro ao atribuir a planta ao evento.")}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp list_items_for_org(org_id) do
    alias Pretex.Repo
    import Ecto.Query

    Pretex.Catalog.Item
    |> join(:inner, [i], e in Pretex.Events.Event, on: i.event_id == e.id)
    |> where([_i, e], e.organization_id == ^org_id)
    |> where([i, _e], i.item_type == "ticket" and i.status == "active")
    |> preload(:variations)
    |> Repo.all()
  end

  defp parse_optional_id(""), do: nil
  defp parse_optional_id(nil), do: nil

  defp parse_optional_id(str) when is_binary(str) do
    case Integer.parse(str) do
      {id, ""} -> id
      _ -> nil
    end
  end

  defp parse_optional_id(id) when is_integer(id), do: id

  defp section_item_label(nil), do: "—"

  defp section_item_label(item) do
    item.name
  end

  defp section_variation_label(nil), do: nil

  defp section_variation_label(variation) do
    variation.name
  end
end
