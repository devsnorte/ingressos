defmodule PretexWeb.EventsLive.Checkout do
  use PretexWeb, :live_view

  alias Pretex.Events
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
      current_path={"/events/#{@event.slug}/checkout"}
      flash={@flash}
    >
      <div class="mx-auto max-w-3xl">
        <%!-- Step indicator --%>
        <div class="mb-8">
          <nav class="flex items-center justify-center gap-4">
            <div class={[
              "flex items-center gap-2 text-sm font-medium",
              if(@live_action == :info, do: "text-primary", else: "text-base-content/40")
            ]}>
              <span class={[
                "flex size-7 items-center justify-center rounded-full text-xs font-bold",
                if(@live_action == :info,
                  do: "bg-primary text-primary-content",
                  else: "bg-base-200 text-base-content/40"
                )
              ]}>
                1
              </span>
              Informações
            </div>

            <div class="h-px w-12 bg-base-200" />

            <div class={[
              "flex items-center gap-2 text-sm font-medium",
              if(@live_action in [:summary, :payment],
                do: "text-primary",
                else: "text-base-content/40"
              )
            ]}>
              <span class={[
                "flex size-7 items-center justify-center rounded-full text-xs font-bold",
                if(@live_action in [:summary, :payment],
                  do: "bg-primary text-primary-content",
                  else: "bg-base-200 text-base-content/40"
                )
              ]}>
                2
              </span>
              Pagamento
            </div>
          </nav>
        </div>

        <%!-- Step: Info --%>
        <div
          :if={@live_action == :info}
          class="rounded-2xl border border-base-200 bg-base-100 shadow-sm p-6"
        >
          <h2 class="text-xl font-bold text-base-content mb-6">Suas Informações</h2>

          <.form
            for={@form}
            id="checkout-info-form"
            phx-submit="submit_info"
            phx-change="validate_info"
            class="space-y-5"
          >
            <.input
              field={@form[:name]}
              type="text"
              label="Nome Completo"
              placeholder="Seu nome completo"
              required
            />
            <.input
              field={@form[:email]}
              type="email"
              label="E-mail"
              placeholder="voce@exemplo.com"
              required
            />

            <div class="pt-4 flex gap-3">
              <button type="button" phx-click="back_to_event" class="btn btn-ghost flex-1">
                <.icon name="hero-arrow-left" class="size-4" /> Voltar
              </button>
              <button type="submit" class="btn btn-primary flex-1">
                Continuar <.icon name="hero-arrow-right" class="size-4" />
              </button>
            </div>
          </.form>
        </div>

        <%!-- Step: Summary + Payment method selection --%>
        <div :if={@live_action == :summary} class="space-y-6">
          <%!-- Order summary --%>
          <div class="rounded-2xl border border-base-200 bg-base-100 shadow-sm overflow-hidden">
            <div class="p-5 border-b border-base-200 bg-base-200/30">
              <h2 class="text-lg font-bold text-base-content">Resumo do Pedido</h2>
            </div>
            <div class="p-5 space-y-3">
              <div class="text-sm text-base-content/60 mb-3">
                <span class="font-medium text-base-content">{@event.name}</span>
              </div>

              <div
                :for={cart_item <- @cart.cart_items}
                class="flex justify-between items-center text-sm py-2 border-b border-base-100 last:border-0"
              >
                <div>
                  <p class="font-medium text-base-content">{cart_item.item.name}</p>
                  <p :if={cart_item.item_variation} class="text-xs text-base-content/50">
                    {cart_item.item_variation.name}
                  </p>
                  <p class="text-xs text-base-content/50 mt-0.5">
                    Qtd: {cart_item.quantity}
                  </p>
                </div>
                <span class="font-semibold text-base-content">
                  {format_price(cart_item.quantity * item_unit_price(cart_item))}
                </span>
              </div>

              <%!-- Subtotal line (shown when there are fees) --%>
              <div
                :if={@fee_preview != []}
                class="flex justify-between items-center pt-2 text-sm text-base-content/70"
              >
                <span>Subtotal</span>
                <span>{format_price(@cart_total)}</span>
              </div>

              <%!-- Fee preview rows --%>
              <div
                :for={fee <- @fee_preview}
                class="flex justify-between items-center text-sm text-base-content/70"
              >
                <span class="flex items-center gap-1">
                  <.icon name="hero-receipt-percent" class="size-3 text-base-content/40" />
                  {fee.name}
                  <span class="text-xs text-base-content/40">
                    {if fee.value_type == "percentage" do
                      int_part = div(fee.value, 100)
                      dec_part = rem(fee.value, 100)
                      "(#{int_part},#{String.pad_leading(Integer.to_string(dec_part), 2, "0")}%)"
                    end}
                  </span>
                </span>
                <span>{format_price(fee.amount_cents)}</span>
              </div>

              <%!-- Total line --%>
              <div class="flex justify-between items-center pt-3 mt-2 border-t-2 border-base-200">
                <span class="font-bold text-base-content">Total</span>
                <span class="text-xl font-bold text-primary">
                  {format_price(@cart_total + @fee_total)}
                </span>
              </div>
            </div>
          </div>

          <%!-- Attendee info summary --%>
          <div class="rounded-2xl border border-base-200 bg-base-100 shadow-sm p-5">
            <div class="flex justify-between items-center mb-3">
              <h3 class="font-semibold text-base-content">Dados do Participante</h3>
              <button phx-click="back_to_info" class="btn btn-ghost btn-xs text-primary">
                Editar
              </button>
            </div>
            <div class="text-sm text-base-content/70 space-y-1">
              <p><span class="font-medium text-base-content">Nome:</span> {@attendee_name}</p>
              <p><span class="font-medium text-base-content">E-mail:</span> {@attendee_email}</p>
            </div>
          </div>

          <%!-- Payment method selection --%>
          <div class="rounded-2xl border border-base-200 bg-base-100 shadow-sm p-5">
            <h3 class="font-semibold text-base-content mb-4">Forma de Pagamento</h3>

            <%!-- No providers configured --%>
            <div
              :if={@payment_options == []}
              class="rounded-xl bg-warning/10 border border-warning/30 p-4 text-sm text-warning-content"
            >
              <.icon name="hero-exclamation-triangle" class="size-4 inline mr-1" />
              Nenhum método de pagamento disponível para este evento. Entre em contato com o organizador.
            </div>

            <%!-- Provider-backed methods --%>
            <div :if={@payment_options != []} class="grid grid-cols-2 gap-3">
              <button
                :for={option <- @payment_options}
                id={"pay-#{option.method}"}
                phx-click="select_payment"
                phx-value-method={option.method}
                phx-value-provider-id={option.provider_id}
                class={[
                  "flex items-center gap-3 rounded-xl border-2 p-4 text-sm font-medium transition-all duration-150 text-left",
                  if(@payment_method == option.method,
                    do: "border-primary bg-primary/5 text-primary",
                    else:
                      "border-base-200 bg-base-100 text-base-content/70 hover:border-primary/40 hover:bg-primary/5"
                  )
                ]}
              >
                <.icon name={payment_method_icon(option.method)} class="size-5 shrink-0" />
                <div class="flex-1 min-w-0">
                  <span class="block">{payment_method_label(option.method)}</span>
                  <span class="text-xs opacity-60 block mt-0.5">
                    {payment_flow_label(option.flow)}
                  </span>
                </div>
                <.icon
                  :if={@payment_method == option.method}
                  name="hero-check-circle"
                  class="size-4 ml-auto text-primary shrink-0"
                />
              </button>
            </div>

            <%!-- Reservation time warning for selected method --%>
            <div
              :if={@payment_method}
              class="mt-4 rounded-xl bg-info/10 border border-info/20 p-3 text-xs text-base-content/70 flex items-start gap-2"
            >
              <.icon name="hero-clock" class="size-4 shrink-0 text-info mt-0.5" />
              <span>{reservation_warning(@payment_method)}</span>
            </div>
          </div>

          <%!-- Place order --%>
          <div class="flex gap-3">
            <button phx-click="back_to_info" class="btn btn-ghost flex-1">
              <.icon name="hero-arrow-left" class="size-4" /> Voltar
            </button>
            <button
              id="place-order-btn"
              phx-click="place_order"
              phx-disable-with="Processando..."
              disabled={is_nil(@payment_method) or @placing_order}
              class="btn btn-primary flex-1 gap-2"
            >
              <.icon name="hero-lock-closed" class="size-4" /> Concluir Pedido
            </button>
          </div>
        </div>

        <%!-- Step: Payment (inline/async payment processing view) --%>
        <div :if={@live_action == :payment} class="space-y-6">
          <%!-- Pix QR Code --%>
          <div
            :if={@payment && @payment.payment_method == "pix" && @payment.qr_code_image_base64}
            class="rounded-2xl border border-base-200 bg-base-100 shadow-sm overflow-hidden"
          >
            <div class="p-5 border-b border-base-200 bg-base-200/30">
              <h2 class="text-lg font-bold text-base-content flex items-center gap-2">
                <.icon name="hero-qr-code" class="size-5 text-primary" /> Pagar com Pix
              </h2>
            </div>
            <div class="p-6 flex flex-col items-center gap-4">
              <p class="text-sm text-base-content/70 text-center">
                Escaneie o QR Code com seu aplicativo bancário para concluir o pagamento.
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
                  <p
                    id="pix-copy-code"
                    class="text-xs font-mono text-base-content break-all flex-1"
                  >
                    {@payment.qr_code_text}
                  </p>
                  <button
                    type="button"
                    phx-click={JS.dispatch("pretex:copy", detail: %{text: @payment.qr_code_text})}
                    class="btn btn-ghost btn-xs shrink-0"
                    title="Copiar código"
                  >
                    <.icon name="hero-clipboard" class="size-4" />
                  </button>
                </div>
              </div>

              <div class="flex items-center gap-2 text-sm text-base-content/60">
                <span class="loading loading-spinner loading-xs"></span>
                Aguardando confirmação do pagamento...
              </div>

              <p :if={@payment.expires_at} class="text-xs text-base-content/50">
                Este código expira em {format_expiry(@payment.expires_at)}.
              </p>
            </div>
          </div>

          <%!-- Async / bank transfer awaiting confirmation --%>
          <div
            :if={
              @payment && @payment.payment_method in ~w(boleto bank_transfer) &&
                @payment.status == "pending"
            }
            class="rounded-2xl border border-base-200 bg-base-100 shadow-sm overflow-hidden"
          >
            <div class="p-5 border-b border-base-200 bg-base-200/30">
              <h2 class="text-lg font-bold text-base-content flex items-center gap-2">
                <.icon name="hero-clock" class="size-5 text-warning" /> Aguardando Pagamento
              </h2>
            </div>
            <div class="p-6 space-y-4">
              <p class="text-sm text-base-content/70">
                {async_instructions(@payment.payment_method)}
              </p>

              <div class="rounded-xl bg-base-200/50 border border-base-200 p-4 text-sm space-y-2">
                <div class="flex justify-between">
                  <span class="text-base-content/60">Código do Pedido</span>
                  <span class="font-mono font-bold text-base-content">
                    {@order && @order.confirmation_code}
                  </span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/60">Valor</span>
                  <span class="font-semibold text-base-content">
                    {format_price(@order && @order.total_cents)}
                  </span>
                </div>
              </div>

              <div class="flex items-center gap-2 text-sm text-base-content/60">
                <span class="loading loading-spinner loading-xs"></span>
                Monitorando confirmação automática...
              </div>
            </div>
          </div>

          <%!-- Payment confirmed! --%>
          <div
            :if={@payment && @payment.status == "confirmed"}
            class="rounded-2xl border border-success/30 bg-success/5 shadow-sm p-8 text-center"
          >
            <div class="flex justify-center mb-4">
              <div class="rounded-full bg-success/10 p-4">
                <.icon name="hero-check-circle" class="size-12 text-success" />
              </div>
            </div>
            <h2 class="text-xl font-bold text-base-content mb-2">Pagamento Confirmado!</h2>
            <p class="text-sm text-base-content/60 mb-6">
              Seu pedido foi confirmado. Redirecionando para a confirmação...
            </p>
            <.link
              navigate={~p"/events/#{@event.slug}/orders/#{@order && @order.confirmation_code}"}
              class="btn btn-success gap-2"
            >
              <.icon name="hero-ticket" class="size-4" /> Ver Meu Ingresso
            </.link>
          </div>

          <%!-- Payment failed --%>
          <div
            :if={@payment && @payment.status == "failed"}
            class="rounded-2xl border border-error/30 bg-error/5 shadow-sm p-8 text-center"
          >
            <div class="flex justify-center mb-4">
              <div class="rounded-full bg-error/10 p-4">
                <.icon name="hero-x-circle" class="size-12 text-error" />
              </div>
            </div>
            <h2 class="text-xl font-bold text-base-content mb-2">Pagamento Recusado</h2>
            <p class="text-sm text-base-content/60 mb-2">
              {@payment.failure_reason || "Não foi possível processar o pagamento."}
            </p>
            <p class="text-xs text-base-content/50 mb-6">
              Sua reserva não foi perdida. Tente novamente com outro método de pagamento.
            </p>
            <button phx-click="retry_payment" class="btn btn-primary gap-2">
              <.icon name="hero-arrow-path" class="size-4" /> Tentar Novamente
            </button>
          </div>
        </div>
      </div>
    </.customer_layout>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    event = Events.get_event_by_slug!(slug)

    socket =
      socket
      |> assign(:page_title, "Checkout – #{event.name}")
      |> assign(:event, event)
      |> assign(:cart, nil)
      |> assign(:cart_total, 0)
      |> assign(:payment_options, [])
      |> assign(:payment_method, nil)
      |> assign(:selected_provider_id, nil)
      |> assign(:attendee_name, "")
      |> assign(:attendee_email, "")
      |> assign(:form, to_form(%{"name" => "", "email" => ""}, as: :checkout))
      |> assign(:placing_order, false)
      |> assign(:order, nil)
      |> assign(:payment, nil)
      |> assign(:fee_preview, [])
      |> assign(:fee_total, 0)

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # handle_params — loads cart and payment options on every navigation
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(params, _uri, socket) do
    cart_token = Map.get(params, "cart_token")
    event = socket.assigns.event

    socket =
      if cart_token do
        case Orders.get_cart_by_token(cart_token) do
          nil ->
            socket
            |> put_flash(:error, "Carrinho não encontrado. Por favor adicione itens primeiro.")
            |> push_navigate(to: ~p"/events/#{event.slug}")

          cart ->
            if cart.event_id == event.id && cart.status == "active" do
              payment_options = load_payment_options(event)
              subtotal = Orders.cart_total(cart)
              fee_preview = Pretex.Fees.compute_fees_for_cart(event, subtotal)
              fee_total = Pretex.Fees.total_fees_cents(fee_preview)

              socket
              |> assign(:cart, cart)
              |> assign(:cart_total, subtotal)
              |> assign(:payment_options, payment_options)
              |> assign(:fee_preview, fee_preview)
              |> assign(:fee_total, fee_total)
            else
              socket
              |> put_flash(:error, "Seu carrinho expirou. Por favor comece novamente.")
              |> push_navigate(to: ~p"/events/#{event.slug}")
            end
        end
      else
        socket
        |> put_flash(:error, "Nenhum carrinho encontrado. Por favor adicione itens primeiro.")
        |> push_navigate(to: ~p"/events/#{event.slug}")
      end

    # On the :payment step, load the order and payment and subscribe to updates
    socket =
      case socket.assigns.live_action do
        :payment ->
          order_code = Map.get(params, "order_code")
          load_payment_step(socket, order_code)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # PubSub — real-time payment status updates
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:payment_updated, payment}, socket) do
    socket = assign(socket, :payment, payment)

    # If payment is now confirmed, navigate to the order confirmation page
    socket =
      if payment.status == "confirmed" && socket.assigns.order do
        order = socket.assigns.order

        socket
        |> push_navigate(
          to: ~p"/events/#{socket.assigns.event.slug}/orders/#{order.confirmation_code}"
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:refund_initiated, _refund}, socket) do
    {:noreply,
     socket
     |> put_flash(
       :error,
       "Seu pagamento foi recebido, mas o evento esgotou. Um reembolso foi iniciado automaticamente."
     )
     |> push_navigate(to: ~p"/events/#{socket.assigns.event.slug}")}
  end

  def handle_info(:late_payment_refunded, socket) do
    {:noreply,
     socket
     |> put_flash(
       :error,
       "Seu pagamento chegou após o evento esgotar. Um reembolso completo foi iniciado."
     )
     |> push_navigate(to: ~p"/events/#{socket.assigns.event.slug}")}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("validate_info", %{"checkout" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: :checkout))}
  end

  def handle_event(
        "submit_info",
        %{"checkout" => %{"name" => name, "email" => email}},
        socket
      ) do
    cond do
      String.trim(name) == "" ->
        {:noreply,
         assign(socket, :form, to_form(%{"name" => name, "email" => email}, as: :checkout))}

      String.trim(email) == "" ->
        {:noreply,
         assign(socket, :form, to_form(%{"name" => name, "email" => email}, as: :checkout))}

      true ->
        cart = socket.assigns.cart

        socket =
          socket
          |> assign(:attendee_name, name)
          |> assign(:attendee_email, email)
          |> push_patch(
            to:
              ~p"/events/#{socket.assigns.event.slug}/checkout/summary?cart_token=#{cart.session_token}",
            replace: false
          )

        {:noreply, socket}
    end
  end

  def handle_event("select_payment", %{"method" => method, "provider-id" => provider_id}, socket) do
    {:noreply,
     socket
     |> assign(:payment_method, method)
     |> assign(:selected_provider_id, provider_id)}
  end

  def handle_event("select_payment", %{"method" => method}, socket) do
    # Fallback: find provider_id from payment_options
    option = Enum.find(socket.assigns.payment_options, &(&1.method == method))
    provider_id = option && to_string(option.provider_id)

    {:noreply,
     socket
     |> assign(:payment_method, method)
     |> assign(:selected_provider_id, provider_id)}
  end

  def handle_event("back_to_event", _params, socket) do
    cart = socket.assigns.cart
    event = socket.assigns.event

    path =
      if cart,
        do: ~p"/events/#{event.slug}?cart_token=#{cart.session_token}",
        else: ~p"/events/#{event.slug}"

    {:noreply, push_navigate(socket, to: path)}
  end

  def handle_event("back_to_info", _params, socket) do
    cart = socket.assigns.cart
    event = socket.assigns.event

    {:noreply,
     push_patch(socket,
       to: ~p"/events/#{event.slug}/checkout?cart_token=#{cart.session_token}",
       replace: false
     )}
  end

  def handle_event("place_order", _params, %{assigns: %{placing_order: true}} = socket) do
    # Debounce: ignore duplicate clicks while processing
    {:noreply, socket}
  end

  def handle_event("place_order", _params, socket) do
    cart = socket.assigns.cart
    payment_method = socket.assigns.payment_method
    provider_id = socket.assigns.selected_provider_id
    name = socket.assigns.attendee_name
    email = socket.assigns.attendee_email

    if is_nil(payment_method) do
      {:noreply, put_flash(socket, :error, "Por favor selecione uma forma de pagamento.")}
    else
      socket = assign(socket, :placing_order, true)

      attrs = %{
        name: name,
        email: email,
        payment_method: payment_method,
        payment_provider_id: provider_id && String.to_integer(provider_id)
      }

      case Orders.create_order_from_cart(cart, attrs) do
        {:ok, order} ->
          initiate_payment(socket, order, payment_method, provider_id)

        {:error, :cart_expired} ->
          {:noreply,
           socket
           |> assign(:placing_order, false)
           |> put_flash(:error, "Seu carrinho expirou. Por favor comece novamente.")
           |> push_navigate(to: ~p"/events/#{socket.assigns.event.slug}")}

        {:error, :cart_not_active} ->
          {:noreply,
           socket
           |> assign(:placing_order, false)
           |> put_flash(:error, "Seu carrinho não está mais ativo.")
           |> push_navigate(to: ~p"/events/#{socket.assigns.event.slug}")}

        {:error, changeset} ->
          error_msg = format_changeset_errors(changeset)

          {:noreply,
           socket
           |> assign(:placing_order, false)
           |> put_flash(:error, "Não foi possível criar o pedido: #{error_msg}")}
      end
    end
  end

  def handle_event("retry_payment", _params, socket) do
    cart_token = socket.assigns.cart && socket.assigns.cart.session_token

    path =
      if cart_token,
        do: ~p"/events/#{socket.assigns.event.slug}/checkout/summary?cart_token=#{cart_token}",
        else: ~p"/events/#{socket.assigns.event.slug}"

    {:noreply,
     socket
     |> assign(:payment, nil)
     |> assign(:payment_method, nil)
     |> assign(:placing_order, false)
     |> push_patch(to: path)}
  end

  # ---------------------------------------------------------------------------
  # Private — payment initiation
  # ---------------------------------------------------------------------------

  defp initiate_payment(socket, order, payment_method, provider_id) do
    event = socket.assigns.event

    case provider_id && Payments.get_provider(String.to_integer(provider_id)) do
      nil ->
        # No provider configured (e.g. free event or manual confirmation)
        # Navigate directly to the confirmation page
        {:noreply,
         socket
         |> assign(:placing_order, false)
         |> push_navigate(to: ~p"/events/#{event.slug}/orders/#{order.confirmation_code}")}

      provider ->
        case Payments.create_payment(order, provider, payment_method) do
          {:ok, payment} ->
            handle_payment_response(socket, order, payment)

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:placing_order, false)
             |> put_flash(:error, "Falha ao iniciar pagamento: #{inspect(reason)}")}
        end
    end
  end

  defp handle_payment_response(socket, _order, %{flow: "redirect", redirect_url: url} = _payment)
       when is_binary(url) do
    # Redirect-based flow: send the user to the provider's page
    {:noreply,
     socket
     |> assign(:placing_order, false)
     |> redirect(external: url)}
  end

  defp handle_payment_response(socket, order, %{flow: flow} = payment)
       when flow in ~w(inline async) do
    event = socket.assigns.event

    # Subscribe to real-time payment updates before navigating
    Phoenix.PubSub.subscribe(Pretex.PubSub, Payments.payment_topic(order.id))

    {:noreply,
     socket
     |> assign(:placing_order, false)
     |> assign(:order, order)
     |> assign(:payment, payment)
     |> push_patch(
       to:
         ~p"/events/#{event.slug}/checkout/payment?cart_token=#{socket.assigns.cart.session_token}&order_code=#{order.confirmation_code}",
       replace: false
     )}
  end

  defp handle_payment_response(socket, order, payment) do
    # Fallback: navigate to confirmation
    {:noreply,
     socket
     |> assign(:placing_order, false)
     |> assign(:order, order)
     |> assign(:payment, payment)
     |> push_navigate(
       to: ~p"/events/#{socket.assigns.event.slug}/orders/#{order.confirmation_code}"
     )}
  end

  # Load order and payment for the :payment live_action step.
  defp load_payment_step(socket, order_code) when is_binary(order_code) do
    case Orders.get_order_by_confirmation_code(order_code) do
      {:ok, order} ->
        payment = Payments.get_payment_for_order(order)

        # Subscribe to payment status updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Pretex.PubSub, Payments.payment_topic(order.id))
        end

        socket
        |> assign(:order, order)
        |> assign(:payment, payment)

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Pedido não encontrado.")
        |> push_navigate(to: ~p"/events/#{socket.assigns.event.slug}")
    end
  end

  defp load_payment_step(socket, _), do: socket

  # Load payment options from the event's organization's active providers.
  defp load_payment_options(event) do
    Payments.list_payment_options_for_organization(event.organization_id)
  rescue
    _ -> []
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp payment_method_label("credit_card"), do: "Cartão de Crédito"
  defp payment_method_label("debit_card"), do: "Cartão de Débito"
  defp payment_method_label("pix"), do: "Pix"
  defp payment_method_label("boleto"), do: "Boleto"
  defp payment_method_label("bank_transfer"), do: "Transferência"
  defp payment_method_label("cash"), do: "Dinheiro"
  defp payment_method_label(m), do: String.capitalize(m)

  defp payment_method_icon("credit_card"), do: "hero-credit-card"
  defp payment_method_icon("debit_card"), do: "hero-credit-card"
  defp payment_method_icon("pix"), do: "hero-qr-code"
  defp payment_method_icon("boleto"), do: "hero-document-text"
  defp payment_method_icon("bank_transfer"), do: "hero-building-library"
  defp payment_method_icon("cash"), do: "hero-banknotes"
  defp payment_method_icon(_), do: "hero-currency-dollar"

  defp payment_flow_label("inline"), do: "Pagamento imediato"
  defp payment_flow_label("redirect"), do: "Redireciona para o provedor"
  defp payment_flow_label("async"), do: "Confirmação automática"
  defp payment_flow_label(_), do: ""

  defp reservation_warning("credit_card"),
    do: "Sua reserva é válida por 15 minutos após a confirmação do pedido."

  defp reservation_warning("debit_card"),
    do: "Sua reserva é válida por 15 minutos após a confirmação do pedido."

  defp reservation_warning("pix"),
    do: "O QR Code expira em 15 minutos. Sua reserva será mantida durante esse período."

  defp reservation_warning("boleto"),
    do: "Sua reserva é válida por 30 minutos. O boleto deverá ser pago dentro desse prazo."

  defp reservation_warning("bank_transfer"),
    do:
      "Sua reserva é válida por 3 dias. Realize a transferência dentro desse prazo para garantir seu ingresso."

  defp reservation_warning(_),
    do: "Complete o pagamento para confirmar sua reserva."

  defp async_instructions("boleto"),
    do:
      "Pague o boleto em qualquer banco ou lotérica. A confirmação ocorrerá automaticamente após o pagamento ser processado."

  defp async_instructions("bank_transfer"),
    do:
      "Realize a transferência bancária com os dados do pedido. A confirmação ocorrerá automaticamente em até 1 dia útil."

  defp async_instructions(_), do: "Aguardando confirmação do pagamento."

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
      diff <= 0 -> "breve"
      diff < 60 -> "#{diff} segundos"
      diff < 3600 -> "#{div(diff, 60)} minutos"
      true -> "#{div(diff, 3600)} horas"
    end
  end

  defp item_unit_price(%{item_variation: %{price_cents: price}}) when not is_nil(price), do: price
  defp item_unit_price(%{item: %{price_cents: price}}), do: price
  defp item_unit_price(_), do: 0

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end
end
