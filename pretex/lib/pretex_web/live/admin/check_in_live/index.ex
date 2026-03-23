defmodule PretexWeb.Admin.CheckInLive.Index do
  use PretexWeb, :live_view

  alias Pretex.CheckIns
  alias Pretex.Events
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pretex.PubSub, CheckIns.checkin_topic(event.id))
    end

    checked_in_count = CheckIns.get_check_in_count(event.id)
    total_tickets = CheckIns.get_total_tickets(event.id)
    gates = CheckIns.list_gates(event.id)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:checked_in_count, checked_in_count)
      |> assign(:total_tickets, total_tickets)
      |> assign(:scan_result, nil)
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:gates, gates)
      |> assign(:selected_gate_id, nil)
      |> assign(:page_title, "Check-in — #{event.name}")

    {:ok, socket}
  end

  @impl true
  def handle_event("select_gate", %{"gate_id" => gate_id}, socket) do
    selected = if gate_id == "", do: nil, else: String.to_integer(gate_id)

    {:noreply,
     socket
     |> assign(:selected_gate_id, selected)
     |> assign(:search_query, "")
     |> assign(:search_results, [])}
  end

  @impl true
  def handle_event("scan", %{"code" => code}, socket) do
    event = socket.assigns.event
    operator_id = socket.assigns.current_user.id
    gate_id = socket.assigns.selected_gate_id

    result =
      if gate_id do
        CheckIns.check_in_at_gate(event.id, code, operator_id, gate_id)
      else
        CheckIns.check_in_by_ticket_code(event.id, code, operator_id)
      end

    scan_result =
      case result do
        {:ok, check_in} ->
          order_item =
            Pretex.Repo.preload(check_in, order_item: [:item]).order_item

          %{
            status: :success,
            message: "Check-in realizado!",
            attendee_name: order_item.attendee_name,
            item_name: order_item.item.name,
            ticket_code: order_item.ticket_code
          }

        {:error, :invalid_ticket} ->
          %{status: :error, message: "Ingresso inválido", attendee_name: nil}

        {:error, :wrong_event} ->
          %{status: :error, message: "Ingresso não pertence a este evento", attendee_name: nil}

        {:error, :ticket_cancelled} ->
          %{status: :error, message: "Ingresso cancelado", attendee_name: nil}

        {:error, :already_checked_in} ->
          %{status: :error, message: "Já foi feito check-in", attendee_name: nil}

        {:error, :not_on_list} ->
          %{
            status: :error,
            message: "Ingresso não válido para este ponto de entrada",
            attendee_name: nil
          }

        {:error, :list_not_active} ->
          %{
            status: :error,
            message: "Lista de check-in fora do horário ativo",
            attendee_name: nil
          }
      end

    socket =
      socket
      |> assign(:scan_result, scan_result)
      |> assign(:checked_in_count, CheckIns.get_check_in_count(event.id))

    {:noreply, socket}
  end

  @impl true
  def handle_event("scan_error", %{"message" => msg}, socket) do
    {:noreply, put_flash(socket, :error, msg)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        attendees = CheckIns.search_attendees(socket.assigns.event.id, query)

        Enum.map(attendees, fn oi ->
          active_ci = CheckIns.get_active_check_in(oi.id, socket.assigns.event.id)

          %{
            order_item_id: oi.id,
            attendee_name: oi.attendee_name,
            attendee_email: oi.attendee_email,
            ticket_code: oi.ticket_code,
            item_name: oi.item.name,
            checked_in: active_ci != nil,
            check_in_id: active_ci && active_ci.id
          }
        end)
      else
        []
      end

    {:noreply, assign(socket, search_query: query, search_results: results)}
  end

  @impl true
  def handle_event("check_in_attendee", %{"ticket-code" => code}, socket) do
    event = socket.assigns.event
    operator_id = socket.assigns.current_user.id
    gate_id = socket.assigns.selected_gate_id

    result =
      if gate_id do
        CheckIns.check_in_at_gate(event.id, code, operator_id, gate_id)
      else
        CheckIns.check_in_by_ticket_code(event.id, code, operator_id)
      end

    case result do
      {:ok, _} ->
        results = refresh_search(socket)

        {:noreply,
         socket
         |> assign(:search_results, results)
         |> assign(:checked_in_count, CheckIns.get_check_in_count(event.id))
         |> put_flash(:info, "Check-in realizado!")}

      {:error, reason} ->
        msg =
          case reason do
            :already_checked_in -> "Já foi feito check-in"
            :ticket_cancelled -> "Ingresso cancelado"
            :not_on_list -> "Ingresso não válido para este ponto de entrada"
            :list_not_active -> "Lista fora do horário ativo"
            _ -> "Erro ao fazer check-in"
          end

        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  @impl true
  def handle_event("annul_check_in", %{"check-in-id" => check_in_id}, socket) do
    operator_id = socket.assigns.current_user.id
    {id, _} = Integer.parse(check_in_id)

    case CheckIns.annul_check_in(id, operator_id) do
      {:ok, _} ->
        results = refresh_search(socket)

        {:noreply,
         socket
         |> assign(:search_results, results)
         |> assign(:checked_in_count, CheckIns.get_check_in_count(socket.assigns.event.id))
         |> put_flash(:info, "Check-in anulado.")}

      {:error, :already_annulled} ->
        {:noreply, put_flash(socket, :error, "Check-in já foi anulado.")}
    end
  end

  @impl true
  def handle_event("clear_scan_result", _, socket) do
    {:noreply, assign(socket, :scan_result, nil)}
  end

  @impl true
  def handle_info({:check_in_updated, count}, socket) do
    {:noreply, assign(socket, :checked_in_count, count)}
  end

  defp refresh_search(socket) do
    query = socket.assigns.search_query

    if String.length(query) >= 2 do
      attendees = CheckIns.search_attendees(socket.assigns.event.id, query)

      Enum.map(attendees, fn oi ->
        active_ci = CheckIns.get_active_check_in(oi.id, socket.assigns.event.id)

        %{
          order_item_id: oi.id,
          attendee_name: oi.attendee_name,
          attendee_email: oi.attendee_email,
          ticket_code: oi.ticket_code,
          item_name: oi.item.name,
          checked_in: active_ci != nil,
          check_in_id: active_ci && active_ci.id
        }
      end)
    else
      []
    end
  end
end
