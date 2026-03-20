defmodule PretexWeb.EventsLive.PaymentStatus do
  @moduledoc """
  LiveView for tracking the status of an async or redirect-based payment.

  Attendees land here after completing checkout when the payment method does
  not provide immediate inline confirmation (e.g. Pix, boleto, bank transfer,
  or after returning from a redirect-based provider).

  The view subscribes to the order's payment PubSub topic so status updates
  arrive in real time — no polling required on the client side.

  Route: /events/:slug/orders/:code/payment-status
  """

  use PretexWeb, :live_view

  alias Pretex.Orders
  alias Pretex.Payments

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <.customer_layout
      current_scope={@current_scope}
      current_path={"/events/#{@event.slug}/orders/#{@order.confirmation_code}/payment-status"}
      flash={@flash}
    >
      <div class="mx-auto max-w-xl">
        <%!-- Header --%>
        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold text-base-content tracking-tight">Status do Pagamento</h1>
          <p class="mt-1 text-sm text-base-content/60">
            Pedido
            <span class="font-mono font-bold text-base-content">{@order.confirmation_code}</span>
          </p>
        </div>

        <%!-- Status card --%>
        <div class="rounded-2xl border border-base-200 bg-base-100 shadow-sm overflow-hidden mb-6">
          <%!-- Status banner --%>
          <div class={[
            "px-6 py-5 border-b flex items-center gap-4",
            status_banner_class(@payment_status)
          ]}>
            <div class={["rounded-full p-3", status_icon_bg(@payment_status)]}>
              <.icon
                name={status_icon(@payment_status)}
                class={["size-8", status_icon_color(@payment_status)]}
              />
            </div>
            <div>
              <p class="font-bold text-lg text-base-content">{status_title(@payment_status)}</p>
              <p class="text-sm text-base-content/60">{status_subtitle(@payment_status, @payment)}</p>
            </div>
            <div :if={@payment_status == :pending} class="ml-auto">
              <span class="loading loading-spinner loading-md text-primary"></span>
            </div>
          </div>

          <div class="p-6 space-y-5">
            <%!-- Pix QR Code --%>
            <div
              :if={show_pix_qr?(@payment)}
              class="flex flex-col items-center gap-4 py-2"
            >
              <p class="text-sm text-base-content/70 text-center">
                Escaneie o QR Code abaixo com seu aplicativo bancário.
              </p>

              <div class="rounded-2xl border-4 border-primary/20 p-4 bg-white">
                <img
                  src={"data:image/png;base64,#{@payment.qr_code_image_base64}"}
                  alt="QR Code Pix"
                  class="size-48"
                />
              </div>

              <div
                :if={@payment.qr_code_text}
                class="w-full rounded-xl bg-base-200/50 border border-base-200 p-3"
              >
                <p class="text-xs text-base-content/50 mb-1 font-medium uppercase tracking-wide">
                  Pix Copia e Cola
                </p>
                <div class="flex items-center gap-2">
                  <p class="text-xs font-mono text-base-content break-all flex-1">
                    {@payment.qr_code_text}
                  </p>
                  <button
                    type="button"
                    phx-click={JS.dispatch("pretex:copy", detail: %{text: @payment.qr_code_text})}
                    class="btn btn-ghost btn-xs shrink-0"
                    title="Copiar código Pix"
                  >
                    <.icon name="hero-clipboard" class="size-4" />
                  </button>
                </div>
              </div>

              <p :if={@payment && @payment.expires_at} class="text-xs text-base-content/50">
                Este código expira em {format_expiry(@payment.expires_at)}.
              </p>
            </div>

            <%!-- Async instructions (boleto / bank transfer) --%>
            <div
              :if={show_async_instructions?(@payment)}
              class="rounded-xl bg-info/10 border border-info/20 p-4 text-sm text-base-content/70"
            >
              <p class="font-medium text-base-content mb-1 flex items-center gap-1">
                <.icon name="hero-information-circle" class="size-4 text-info" />
                Instruções de Pagamento
              </p>
              <p>{async_instructions(@payment && @payment.payment_method)}</p>
            </div>

            <%!-- Order summary --%>
            <div class="rounded-xl bg-base-200/40 border border-base-200 p-4 space-y-2 text-sm">
              <div class="flex justify-between">
                <span class="text-base-content/60">Evento</span>
                <span class="font-medium text-base-content">{@event.name}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-base-content/60">Participante</span>
                <span class="font-medium text-base-content">{@order.name}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-base-content/60">E-mail</span>
                <span class="font-medium text-base-content">{@order.email}</span>
              </div>
              <div class="h-px bg-base-200 my-1" />
              <div class="flex justify-between">
                <span class="text-base-content/60">Forma de Pagamento</span>
                <span class="font-medium text-base-content">
                  {payment_method_label(@order.payment_method)}
                </span>
              </div>
              <div class="flex justify-between">
                <span class="text-base-content/60">Total</span>
                <span class="font-bold text-primary">{format_price(@order.total_cents)}</span>
              </div>
            </div>

            <%!-- Refund notice --%>
            <div
              :if={@payment_status == :refunded}
              class="rounded-xl bg-warning/10 border border-warning/20 p-4 text-sm text-base-content/70"
            >
              <p class="font-medium text-base-content mb-1 flex items-center gap-1">
                <.icon name="hero-arrow-uturn-left" class="size-4 text-warning" /> Reembolso Iniciado
              </p>
              <p>
                Identificamos que o ingresso não pôde ser reservado após o pagamento.
                Um reembolso completo foi iniciado automaticamente e você receberá
                um e-mail com os detalhes. O prazo depende do seu método de pagamento.
              </p>
            </div>

            <%!-- Failed notice --%>
            <div
              :if={@payment_status == :failed}
              class="rounded-xl bg-error/10 border border-error/20 p-4 text-sm text-base-content/70"
            >
              <p class="font-medium text-base-content mb-1 flex items-center gap-1">
                <.icon name="hero-x-circle" class="size-4 text-error" /> Pagamento Recusado
              </p>
              <p>
                {(@payment && @payment.failure_reason) || "Não foi possível processar o pagamento."}
              </p>
              <p class="mt-1 text-xs">Sua reserva não foi perdida. Você pode tentar novamente.</p>
            </div>
          </div>
        </div>

        <%!-- Actions --%>
        <div class="flex flex-col sm:flex-row gap-3 justify-center">
          <%!-- Confirmed: go to order --%>
          <.link
            :if={@payment_status == :confirmed}
            navigate={~p"/events/#{@event.slug}/orders/#{@order.confirmation_code}"}
            class="btn btn-success gap-2"
          >
            <.icon name="hero-ticket" class="size-4" /> Ver Meu Ingresso
          </.link>

          <%!-- Failed: retry checkout --%>
          <.link
            :if={@payment_status == :failed}
            navigate={~p"/events/#{@event.slug}"}
            class="btn btn-primary gap-2"
          >
            <.icon name="hero-arrow-path" class="size-4" /> Tentar Novamente
          </.link>

          <%!-- Pending: check order page --%>
          <.link
            :if={@payment_status == :pending}
            navigate={~p"/events/#{@event.slug}/orders/#{@order.confirmation_code}"}
            class="btn btn-ghost gap-2"
          >
            <.icon name="hero-eye" class="size-4" /> Ver Detalhes do Pedido
          </.link>

          <%!-- Always: explore events --%>
          <.link
            :if={@payment_status in [:refunded, :failed]}
            navigate={~p"/events"}
            class="btn btn-ghost gap-2"
          >
            <.icon name="hero-magnifying-glass" class="size-4" /> Explorar Eventos
          </.link>
        </div>
      </div>
    </.customer_layout>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount — no DB queries here
  # ---------------------------------------------------------------------------

  @impl true
  def mount(%{"slug" => slug, "code" => code}, _session, socket) do
    event = Pretex.Events.get_event_by_slug!(slug)

    socket =
      socket
      |> assign(:page_title, "Status do Pagamento")
      |> assign(:event, event)
      |> assign(:order, nil)
      |> assign(:payment, nil)
      |> assign(:payment_status, :pending)

    case Orders.get_order_by_confirmation_code(code) do
      {:ok, order} ->
        payment = Payments.get_payment_for_order(order)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(Pretex.PubSub, Payments.payment_topic(order.id))
        end

        socket =
          socket
          |> assign(:order, order)
          |> assign(:payment, payment)
          |> assign(:payment_status, derive_status(payment, order))

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Pedido não encontrado.")
         |> push_navigate(to: ~p"/events/#{event.slug}")}
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub — real-time updates
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:payment_updated, payment}, socket) do
    order = socket.assigns.order
    new_status = derive_status(payment, order)

    socket =
      socket
      |> assign(:payment, payment)
      |> assign(:payment_status, new_status)

    # Auto-navigate to confirmation on successful payment
    socket =
      if new_status == :confirmed && order do
        push_navigate(socket,
          to: ~p"/events/#{socket.assigns.event.slug}/orders/#{order.confirmation_code}"
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:refund_initiated, _refund}, socket) do
    {:noreply, assign(socket, :payment_status, :refunded)}
  end

  def handle_info(:late_payment_refunded, socket) do
    {:noreply, assign(socket, :payment_status, :refunded)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp derive_status(nil, _order), do: :pending
  defp derive_status(%{status: "confirmed"}, _order), do: :confirmed
  defp derive_status(%{status: "failed"}, _order), do: :failed
  defp derive_status(%{status: "refunded"}, _order), do: :refunded
  defp derive_status(%{status: "cancelled"}, _order), do: :failed
  defp derive_status(%{status: "pending"}, _order), do: :pending
  defp derive_status(_, _), do: :pending

  defp show_pix_qr?(%{payment_method: "pix", status: "pending", qr_code_image_base64: img})
       when is_binary(img),
       do: true

  defp show_pix_qr?(_), do: false

  defp show_async_instructions?(%{payment_method: method, status: "pending"})
       when method in ~w(boleto bank_transfer),
       do: true

  defp show_async_instructions?(_), do: false

  defp async_instructions("boleto"),
    do:
      "Pague o boleto em qualquer banco, lotérica ou pelo aplicativo do seu banco. " <>
        "A confirmação ocorrerá automaticamente em até 1 dia útil após o pagamento."

  defp async_instructions("bank_transfer"),
    do:
      "Realize a transferência bancária para a conta informada pelo organizador. " <>
        "A confirmação ocorrerá automaticamente após a identificação do pagamento."

  defp async_instructions(_), do: "Aguardando confirmação do pagamento."

  defp status_title(:pending), do: "Aguardando Pagamento"
  defp status_title(:confirmed), do: "Pagamento Confirmado!"
  defp status_title(:failed), do: "Pagamento Recusado"
  defp status_title(:refunded), do: "Reembolso em Andamento"

  defp status_subtitle(:pending, %{payment_method: "pix"}),
    do: "Escaneie o QR Code para concluir o pagamento."

  defp status_subtitle(:pending, %{payment_method: "boleto"}),
    do: "Pague o boleto para confirmar sua reserva."

  defp status_subtitle(:pending, %{payment_method: "bank_transfer"}),
    do: "Realize a transferência para confirmar sua reserva."

  defp status_subtitle(:pending, _),
    do: "Seu pedido está aguardando confirmação do pagamento."

  defp status_subtitle(:confirmed, _), do: "Seus ingressos estão prontos."

  defp status_subtitle(:failed, _),
    do: "O pagamento não pôde ser processado. Tente novamente."

  defp status_subtitle(:refunded, _),
    do: "Um reembolso foi iniciado automaticamente."

  defp status_banner_class(:pending), do: "border-base-200 bg-base-200/30"
  defp status_banner_class(:confirmed), do: "border-success/20 bg-success/5"
  defp status_banner_class(:failed), do: "border-error/20 bg-error/5"
  defp status_banner_class(:refunded), do: "border-warning/20 bg-warning/5"

  defp status_icon_bg(:pending), do: "bg-primary/10"
  defp status_icon_bg(:confirmed), do: "bg-success/10"
  defp status_icon_bg(:failed), do: "bg-error/10"
  defp status_icon_bg(:refunded), do: "bg-warning/10"

  defp status_icon(:pending), do: "hero-clock"
  defp status_icon(:confirmed), do: "hero-check-circle"
  defp status_icon(:failed), do: "hero-x-circle"
  defp status_icon(:refunded), do: "hero-arrow-uturn-left"

  defp status_icon_color(:pending), do: "text-primary"
  defp status_icon_color(:confirmed), do: "text-success"
  defp status_icon_color(:failed), do: "text-error"
  defp status_icon_color(:refunded), do: "text-warning"

  defp payment_method_label("credit_card"), do: "Cartão de Crédito"
  defp payment_method_label("debit_card"), do: "Cartão de Débito"
  defp payment_method_label("pix"), do: "Pix"
  defp payment_method_label("boleto"), do: "Boleto"
  defp payment_method_label("bank_transfer"), do: "Transferência Bancária"
  defp payment_method_label("cash"), do: "Dinheiro"
  defp payment_method_label(nil), do: "—"
  defp payment_method_label(m), do: String.capitalize(m)

  defp format_price(nil), do: "Grátis"
  defp format_price(0), do: "Grátis"

  defp format_price(cents) do
    reais = div(cents, 100)
    centavos = rem(cents, 100)
    "R$ #{reais},#{String.pad_leading(Integer.to_string(centavos), 2, "0")}"
  end

  defp format_expiry(nil), do: "breve"

  defp format_expiry(%DateTime{} = dt) do
    diff = DateTime.diff(dt, DateTime.utc_now(), :second)

    cond do
      diff <= 0 -> "expirado"
      diff < 60 -> "#{diff} segundos"
      diff < 3600 -> "#{div(diff, 60)} minutos"
      true -> "#{div(diff, 3600)} horas"
    end
  end
end
