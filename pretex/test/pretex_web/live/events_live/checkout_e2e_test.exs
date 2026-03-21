defmodule PretexWeb.EventsLive.CheckoutE2ETest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.Orders
  alias Pretex.Payments
  alias Pretex.Repo

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  defp manual_provider_fixture(org) do
    {:ok, provider} =
      Payments.create_provider(%{
        organization_id: org.id,
        type: "manual",
        name: "Transferência Bancária E2E #{System.unique_integer([:positive])}",
        credentials: %{"bank_info" => "Banco do Brasil Ag 0001 CC 12345-6"},
        is_active: true
      })

    {:ok, provider} = Payments.validate_provider(provider)
    provider
  end

  # Extracts a named query-string parameter from a URL path string.
  defp query_param(path, key) do
    path
    |> URI.parse()
    |> Map.get(:query, "")
    |> URI.decode_query()
    |> Map.fetch!(key)
  end

  # ---------------------------------------------------------------------------
  # End-to-end: events list → event page → add to cart → checkout → confirmation
  # ---------------------------------------------------------------------------

  describe "full purchase flow" do
    test "user browses events, adds a ticket to cart and completes purchase", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{name: "Ingresso Geral", price_cents: 5000})
      provider = manual_provider_fixture(org)

      # ── Step 1: events list shows the event ──────────────────────────────────
      {:ok, _view, html} = live(conn, ~p"/events")
      assert html =~ event.name

      # ── Step 2: event page shows ticket and price ─────────────────────────────
      {:ok, show_view, html} = live(conn, ~p"/events/#{event.slug}")
      assert html =~ "Ingresso Geral"
      assert html =~ "R$ 50,00"

      # ── Step 3: add the ticket to the cart ───────────────────────────────────
      # phx-value-item_id is collected automatically from the element
      show_view |> element("#add-#{item.id}") |> render_click()

      # The show page push_patches to ?cart_token=... — extract the token
      patch_path = assert_patch(show_view)
      cart_token = query_param(patch_path, "cart_token")

      # Cart sidebar now shows the item and the proceed-to-checkout link
      show_html = render(show_view)
      assert show_html =~ "Ingresso Geral"
      assert show_html =~ "Finalizar Compra"

      # ── Step 4: checkout info step ────────────────────────────────────────────
      {:ok, view, html} =
        live(conn, ~p"/events/#{event.slug}/checkout?cart_token=#{cart_token}")

      assert html =~ "Suas Informações"
      assert html =~ "Nome Completo"
      assert html =~ "E-mail"

      view
      |> form("#checkout-info-form", %{checkout: %{name: "João Silva", email: "joao@example.com"}})
      |> render_submit()

      # push_patch → summary step (same LiveView process)
      assert_patch(view)

      # ── Step 5: summary step shows order details ──────────────────────────────
      summary_html = render(view)
      assert summary_html =~ "Resumo do Pedido"
      assert summary_html =~ "Ingresso Geral"
      assert summary_html =~ "R$ 50,00"
      assert summary_html =~ "Concluir Pedido"

      # ── Step 6: select payment method ────────────────────────────────────────
      view
      |> element("#pay-bank_transfer")
      |> render_click(%{"method" => "bank_transfer", "provider-id" => to_string(provider.id)})

      # ── Step 7: place the order ───────────────────────────────────────────────
      view |> element("#place-order-btn") |> render_click()

      # push_patch → payment step; the URL carries the order_code
      payment_path = assert_patch(view)
      assert payment_path =~ "/checkout/payment"

      order_code = query_param(payment_path, "order_code")

      # The payment step renders the "waiting for payment" UI — item names are
      # not shown here, but the order amount and status heading are.
      payment_html = render(view)
      assert payment_html =~ "Aguardando Pagamento"
      assert payment_html =~ "R$ 50,00"

      # ── Step 8: simulate payment confirmation (webhook / admin action) ─────────
      {:ok, order} = Orders.get_order_by_confirmation_code(order_code)
      assert order.name == "João Silva"
      assert order.email == "joao@example.com"
      assert order.total_cents == 5000

      payment = Payments.get_payment_for_order(order)
      assert payment.payment_method == "bank_transfer"

      {:ok, _confirmed_payment} = Payments.confirm_payment(payment)

      # The LiveView receives the PubSub broadcast and redirects to confirmation
      assert_redirect(view, ~p"/events/#{event.slug}/orders/#{order_code}")

      # ── Step 9: confirmation page ─────────────────────────────────────────────
      {:ok, _view, html} = live(conn, ~p"/events/#{event.slug}/orders/#{order_code}")

      assert html =~ "Pedido Confirmado!"
      assert html =~ order_code
      assert html =~ "João Silva"
      assert html =~ "joao@example.com"
      assert html =~ "Ingresso Geral"
      assert html =~ "R$ 50,00"
    end

    # Regression test for the "cart expired" bug:
    #   - extend_cart_expiry updated the DB row but the stale CartSession struct
    #     (with the old expires_at) was still stored in socket.assigns.cart.
    #   - create_order_from_cart received the stale struct and validate_cart_not_expired
    #     always returned {:error, :cart_expired}.
    test "an already-expired cart is recoverable — visiting checkout extends the TTL", %{
      conn: conn
    } do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{name: "Ingresso VIP", price_cents: 15000})
      provider = manual_provider_fixture(org)

      {:ok, raw_cart} = Orders.create_cart(event)
      Orders.add_to_cart(raw_cart, item)
      cart = Orders.get_cart_by_token(raw_cart.session_token)

      # Backdate the expiry so the cart looks already expired
      expired_at =
        DateTime.utc_now() |> DateTime.add(-120, :second) |> DateTime.truncate(:second)

      Repo.update!(Ecto.Changeset.change(cart, expires_at: expired_at))

      # Opening the checkout page must extend the TTL and NOT redirect away
      {:ok, view, html} =
        live(conn, ~p"/events/#{event.slug}/checkout?cart_token=#{cart.session_token}")

      refute html =~ "expirou"
      assert html =~ "Suas Informações"

      # Fill in info — the form must accept the submission
      view
      |> form("#checkout-info-form", %{
        checkout: %{name: "Maria Souza", email: "maria@test.com"}
      })
      |> render_submit()

      assert_patch(view)
      assert render(view) =~ "Resumo do Pedido"

      # Select payment method and place the order — must NOT raise cart_expired
      view
      |> element("#pay-bank_transfer")
      |> render_click(%{"method" => "bank_transfer", "provider-id" => to_string(provider.id)})

      view |> element("#place-order-btn") |> render_click()

      # Reaching the payment step proves no cart_expired error was raised
      payment_path = assert_patch(view)
      assert payment_path =~ "/checkout/payment"

      order_code = query_param(payment_path, "order_code")
      {:ok, order} = Orders.get_order_by_confirmation_code(order_code)
      payment = Payments.get_payment_for_order(order)
      {:ok, _} = Payments.confirm_payment(payment)

      assert_redirect(view, ~p"/events/#{event.slug}/orders/#{order_code}")

      {:ok, _view, html} = live(conn, ~p"/events/#{event.slug}/orders/#{order_code}")
      assert html =~ "Pedido Confirmado!"
      assert html =~ "Maria Souza"
      assert html =~ "R$ 150,00"
    end
  end
end
