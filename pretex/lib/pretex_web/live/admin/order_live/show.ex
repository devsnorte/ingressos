defmodule PretexWeb.Admin.OrderLive.Show do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Orders
  alias Pretex.Organizations
  alias Pretex.Payments

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id, "id" => id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    order = Orders.get_order_with_details!(id)
    payment = Payments.get_payment_for_order(order)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:order, order)
      |> assign(:payment, payment)
      |> assign(:page_title, "Pedido ##{order.confirmation_code}")

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("resend_tickets", _params, socket) do
    case Orders.resend_ticket_email(socket.assigns.order) do
      {:ok, :sent} ->
        {:noreply, put_flash(socket, :info, "E-mail de ingressos reenviado com sucesso.")}

      {:error, :not_confirmed} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Não é possível reenviar ingressos de um pedido não confirmado."
         )}
    end
  end

  @impl true
  def handle_event("lock_order", _params, socket) do
    case Orders.lock_order_for_editing(socket.assigns.order) do
      {:ok, updated_order} ->
        {:noreply,
         socket
         |> assign(:order, updated_order)
         |> put_flash(:info, "Pedido bloqueado para edição.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Não foi possível bloquear o pedido.")}
    end
  end

  @impl true
  def handle_event("unlock_order", _params, socket) do
    case Orders.unlock_order(socket.assigns.order) do
      {:ok, updated_order} ->
        {:noreply,
         socket
         |> assign(:order, updated_order)
         |> put_flash(:info, "Pedido desbloqueado.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Não foi possível desbloquear o pedido.")}
    end
  end

  @impl true
  def handle_event("cancel_order", _params, socket) do
    case Orders.cancel_order(socket.assigns.order) do
      {:ok, updated_order} ->
        updated_order = Orders.get_order_with_details!(updated_order.id)

        {:noreply,
         socket
         |> assign(:order, updated_order)
         |> put_flash(:info, "Pedido cancelado com sucesso.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Não foi possível cancelar o pedido.")}
    end
  end

  @impl true
  def handle_event("confirm_payment", _params, socket) do
    case socket.assigns.payment do
      nil ->
        {:noreply, put_flash(socket, :error, "Nenhum pagamento encontrado para este pedido.")}

      payment ->
        case Payments.confirm_payment(payment) do
          {:ok, confirmed_payment} ->
            updated_order = Orders.get_order_with_details!(socket.assigns.order.id)

            {:noreply,
             socket
             |> assign(:order, updated_order)
             |> assign(:payment, confirmed_payment)
             |> put_flash(:info, "Pagamento confirmado com sucesso.")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Não foi possível confirmar o pagamento.")}
        end
    end
  end
end
