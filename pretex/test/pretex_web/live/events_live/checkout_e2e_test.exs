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

      # 1. Events list
      {:ok, _view, html} = live(conn, ~p"/events")
      assert html =~ event.name

      # 2. Event detail page
      {:ok, view, html} = live(conn, ~p"/events/#{event.slug}")
      assert html =~ event.name
      assert html =~ item.name

      # 3. Add ticket to cart — the page push_patches with the cart token
      view |> element("#add-#{item.id}") |> render_click()
      patch_path = assert_patch(view)
      assert patch_path =~ "cart_token"

      cart_token = query_param(patch_path, "cart_token")

      # 4. Checkout — info step
      {:ok, view, html} =
        live(conn, ~p"/events/#{event.slug}/checkout?cart_token=#{cart_token}")

      assert html =~ "Suas Informações"

      view
      |> form("#checkout-info-form", %{
        checkout: %{name: "João Silva", email: "joao@test.com"}
      })
      |> render_submit()

      assert_patch(view)

      # 5. Summary step
      html = render(view)
      assert html =~ "Resumo do Pedido"
      assert html =~ item.name

      # 6. Select payment method
      view
      |> element("#pay-bank_transfer")
      |> render_click(%{"method" => "bank_transfer", "provider-id" => to_string(provider.id)})

      # 7. Place order
      view |> element("#place-order-btn") |> render_click()

      payment_path = assert_patch(view)
      assert payment_path =~ "/checkout/payment"

      order_code = query_param(payment_path, "order_code")
      {:ok, order} = Orders.get_order_by_confirmation_code(order_code)
      payment = Payments.get_payment_for_order(order)

      # 8. Confirm payment (simulating admin/webhook)
      {:ok, _} = Payments.confirm_payment(payment)

      assert_redirect(view, ~p"/events/#{event.slug}/orders/#{order_code}")

      # 9. Order confirmation page
      {:ok, _view, html} = live(conn, ~p"/events/#{event.slug}/orders/#{order_code}")
      assert html =~ "Pedido Confirmado!"
      assert html =~ "João Silva"
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

  # ---------------------------------------------------------------------------
  # Bank transfer note submission
  # ---------------------------------------------------------------------------

  describe "bank transfer note" do
    test "payment step shows the transfer note form for bank_transfer", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{name: "Ingresso TED", price_cents: 8000})
      provider = manual_provider_fixture(org)

      {:ok, raw_cart} = Orders.create_cart(event)
      Orders.add_to_cart(raw_cart, item)
      cart = Orders.get_cart_by_token(raw_cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Ana Lima",
          email: "ana@example.com",
          payment_method: "bank_transfer",
          payment_provider_id: provider.id
        })

      {:ok, _payment} = Payments.create_payment(order, provider, "bank_transfer")

      {:ok, view, html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/payment?cart_token=#{cart.session_token}&order_code=#{order.confirmation_code}"
        )

      assert html =~ "Envie o comprovante da transferência"
      assert has_element?(view, "#transfer-note-input")
    end

    test "submitting a transfer note saves it and shows confirmation", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{name: "Ingresso PIX", price_cents: 3000})
      provider = manual_provider_fixture(org)

      {:ok, raw_cart} = Orders.create_cart(event)
      Orders.add_to_cart(raw_cart, item)
      cart = Orders.get_cart_by_token(raw_cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Carlos Melo",
          email: "carlos@example.com",
          payment_method: "bank_transfer",
          payment_provider_id: provider.id
        })

      {:ok, _payment} = Payments.create_payment(order, provider, "bank_transfer")

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/payment?cart_token=#{cart.session_token}&order_code=#{order.confirmation_code}"
        )

      view
      |> element("form[phx-submit='submit_transfer_note']")
      |> render_submit(%{"note" => "TED · ID 123456 · R$ 30,00"})

      html = render(view)
      assert html =~ "Comprovante enviado!"

      payment = Payments.get_payment_for_order(order)
      assert payment.transfer_note == "TED · ID 123456 · R$ 30,00"
    end

    test "submitting an empty note shows an error and does not persist", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{name: "Ingresso DOC", price_cents: 4500})
      provider = manual_provider_fixture(org)

      {:ok, raw_cart} = Orders.create_cart(event)
      Orders.add_to_cart(raw_cart, item)
      cart = Orders.get_cart_by_token(raw_cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Paula Dias",
          email: "paula@example.com",
          payment_method: "bank_transfer",
          payment_provider_id: provider.id
        })

      {:ok, _payment} = Payments.create_payment(order, provider, "bank_transfer")

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/payment?cart_token=#{cart.session_token}&order_code=#{order.confirmation_code}"
        )

      view
      |> element("form[phx-submit='submit_transfer_note']")
      |> render_submit(%{"note" => "   "})

      html = render(view)
      # Form stays visible and note was not persisted
      refute html =~ "Comprovante enviado!"

      payment = Payments.get_payment_for_order(order)
      assert is_nil(payment.transfer_note)
    end
  end

  # ---------------------------------------------------------------------------
  # customer_id linking — orders appear in /account/orders
  # ---------------------------------------------------------------------------

  describe "customer_id on orders" do
    test "order created by a logged-in customer is linked to their account", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 5000})
      provider = manual_provider_fixture(org)

      # Log in as a customer
      %{conn: authed_conn, customer: customer} = register_and_log_in_customer(%{conn: conn})

      {:ok, raw_cart} = Orders.create_cart(event)
      Orders.add_to_cart(raw_cart, item)
      cart = Orders.get_cart_by_token(raw_cart.session_token)

      {:ok, view, _html} =
        live(authed_conn, ~p"/events/#{event.slug}/checkout?cart_token=#{cart.session_token}")

      view
      |> form("#checkout-info-form", %{
        checkout: %{name: "Sofia Rocha", email: "sofia@example.com"}
      })
      |> render_submit()

      assert_patch(view)

      view
      |> element("#pay-bank_transfer")
      |> render_click(%{"method" => "bank_transfer", "provider-id" => to_string(provider.id)})

      view |> element("#place-order-btn") |> render_click()
      payment_path = assert_patch(view)
      order_code = query_param(payment_path, "order_code")

      {:ok, order} = Orders.get_order_by_confirmation_code(order_code)
      assert order.customer_id == customer.id

      # The order must appear in /account/orders
      {:ok, _view, html} = live(authed_conn, ~p"/account/orders")
      assert html =~ order_code
    end

    test "order created by a guest has no customer_id", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 2000})
      provider = manual_provider_fixture(org)

      {:ok, raw_cart} = Orders.create_cart(event)
      Orders.add_to_cart(raw_cart, item)
      cart = Orders.get_cart_by_token(raw_cart.session_token)

      # Unauthenticated connection — no current_scope customer
      {:ok, view, _html} =
        live(conn, ~p"/events/#{event.slug}/checkout?cart_token=#{cart.session_token}")

      view
      |> form("#checkout-info-form", %{
        checkout: %{name: "Visitante Guest", email: "guest@example.com"}
      })
      |> render_submit()

      assert_patch(view)

      view
      |> element("#pay-bank_transfer")
      |> render_click(%{"method" => "bank_transfer", "provider-id" => to_string(provider.id)})

      view |> element("#place-order-btn") |> render_click()
      payment_path = assert_patch(view)
      order_code = query_param(payment_path, "order_code")

      {:ok, order} = Orders.get_order_by_confirmation_code(order_code)
      assert is_nil(order.customer_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Admin payment confirmation
  # ---------------------------------------------------------------------------

  describe "admin confirm payment" do
    setup :register_and_log_in_user

    test "admin sees the payment card with transfer note on the order show page", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 7500})
      provider = manual_provider_fixture(org)

      {:ok, raw_cart} = Orders.create_cart(event)
      Orders.add_to_cart(raw_cart, item)
      cart = Orders.get_cart_by_token(raw_cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Luisa Ferreira",
          email: "luisa@example.com",
          payment_method: "bank_transfer",
          payment_provider_id: provider.id
        })

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")
      {:ok, _} = Payments.update_payment_transfer_note(payment, "TED confirmada · ID 998877")

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert html =~ "Comprovante enviado pelo cliente"
      assert html =~ "TED confirmada · ID 998877"
      assert html =~ "Confirmar Pagamento"
    end

    test "admin sees placeholder when no transfer note was submitted", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 4000})
      provider = manual_provider_fixture(org)

      {:ok, raw_cart} = Orders.create_cart(event)
      Orders.add_to_cart(raw_cart, item)
      cart = Orders.get_cart_by_token(raw_cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Ricardo Nunes",
          email: "ricardo@example.com",
          payment_method: "bank_transfer",
          payment_provider_id: provider.id
        })

      {:ok, _payment} = Payments.create_payment(order, provider, "bank_transfer")

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert html =~ "Nenhum comprovante enviado ainda"
      assert html =~ "Confirmar Pagamento"
    end

    test "admin clicking confirm_payment confirms the order and updates the UI", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 6000})
      provider = manual_provider_fixture(org)

      {:ok, raw_cart} = Orders.create_cart(event)
      Orders.add_to_cart(raw_cart, item)
      cart = Orders.get_cart_by_token(raw_cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Beatriz Teles",
          email: "beatriz@example.com",
          payment_method: "bank_transfer",
          payment_provider_id: provider.id
        })

      {:ok, _payment} = Payments.create_payment(order, provider, "bank_transfer")

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert html =~ "Pendente"
      assert html =~ "Confirmar Pagamento"

      view |> element("#confirm-payment-card") |> render_click()

      html = render(view)
      assert html =~ "Confirmado"
      assert html =~ "Pagamento confirmado com sucesso"
      refute has_element?(view, "#confirm-payment-card")

      # The order must be confirmed in the database
      confirmed_order = Orders.get_order_with_details!(order.id)
      assert confirmed_order.status == "confirmed"
    end

    test "admin cannot see confirm button for an already confirmed order", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 5000})
      provider = manual_provider_fixture(org)

      {:ok, raw_cart} = Orders.create_cart(event)
      Orders.add_to_cart(raw_cart, item)
      cart = Orders.get_cart_by_token(raw_cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Fernanda Leal",
          email: "fernanda@example.com",
          payment_method: "bank_transfer",
          payment_provider_id: provider.id
        })

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")
      {:ok, _} = Payments.confirm_payment(payment)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert html =~ "Confirmado"
      refute html =~ "Confirmar Pagamento"
    end
  end
end
