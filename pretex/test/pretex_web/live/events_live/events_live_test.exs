defmodule PretexWeb.EventsLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Catalog
  alias Pretex.Events
  alias Pretex.Orders
  alias Pretex.Organizations

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp org_fixture(attrs \\ %{}) do
    {:ok, org} =
      attrs
      |> Enum.into(%{name: "Test Org", slug: "test-org-#{System.unique_integer([:positive])}"})
      |> Organizations.create_organization()

    org
  end

  defp event_fixture(org, attrs \\ %{}) do
    base = %{
      name: "My Event #{System.unique_integer([:positive])}",
      starts_at: ~U[2030-06-01 10:00:00Z],
      ends_at: ~U[2030-06-01 18:00:00Z],
      venue: "Main Stage"
    }

    {:ok, event} = Events.create_event(org, Enum.into(attrs, base))
    event
  end

  defp ticket_type_fixture(event) do
    changeset =
      %Pretex.Events.TicketType{}
      |> Pretex.Events.TicketType.changeset(%{name: "General", price_cents: 1000})
      |> Ecto.Changeset.put_change(:event_id, event.id)

    {:ok, tt} = Pretex.Repo.insert(changeset)
    tt
  end

  defp published_event_fixture(org, attrs \\ %{}) do
    event = event_fixture(org, attrs)
    ticket_type_fixture(event)
    {:ok, published} = Events.publish_event(event)
    published
  end

  defp item_fixture(event, attrs \\ %{}) do
    base = %{
      name: "Test Ticket #{System.unique_integer([:positive])}",
      price_cents: 2500,
      item_type: "ticket",
      status: "active"
    }

    {:ok, item} = Catalog.create_item(event, Enum.into(attrs, base))
    item
  end

  defp cart_with_item_fixture(event, item) do
    {:ok, cart} = Orders.create_cart(event)
    Orders.add_to_cart(cart, item)
    Orders.get_cart_by_token(cart.session_token)
  end

  # ---------------------------------------------------------------------------
  # Events Index
  # ---------------------------------------------------------------------------

  describe "Events Index" do
    test "renders list of published events", %{conn: conn} do
      org = org_fixture()
      _event = published_event_fixture(org, %{name: "Rock Concert 2030"})

      {:ok, _view, html} = live(conn, ~p"/events")

      assert html =~ "Rock Concert 2030"
    end

    test "does not show draft events", %{conn: conn} do
      org = org_fixture()
      _draft = event_fixture(org, %{name: "Draft Event Hidden"})

      {:ok, _view, html} = live(conn, ~p"/events")

      refute html =~ "Draft Event Hidden"
    end

    test "shows event venue", %{conn: conn} do
      org = org_fixture()
      _event = published_event_fixture(org, %{name: "Venue Test Event", venue: "Grand Arena"})

      {:ok, _view, html} = live(conn, ~p"/events")

      assert html =~ "Grand Arena"
    end

    test "shows a Get Tickets link for each event", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)

      {:ok, _view, html} = live(conn, ~p"/events")

      assert html =~ "/events/#{event.slug}"
      assert html =~ "Ver Ingressos"
    end

    test "shows organization name on event card", %{conn: conn} do
      org =
        org_fixture(%{name: "Super Org", slug: "super-org-#{System.unique_integer([:positive])}"})

      _event = published_event_fixture(org)

      {:ok, _view, html} = live(conn, ~p"/events")

      assert html =~ "Super Org"
    end

    test "renders page with no events shows empty state content", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/events")

      # Should render without crashing; empty state or no event cards
      assert html =~ "Eventos"
    end

    test "works for unauthenticated users", %{conn: conn} do
      org = org_fixture()
      _event = published_event_fixture(org, %{name: "Public Event"})

      {:ok, _view, html} = live(conn, ~p"/events")

      assert html =~ "Public Event"
    end

    test "works for authenticated customers", %{conn: conn} do
      org = org_fixture()
      _event = published_event_fixture(org, %{name: "Auth Event"})

      %{conn: conn} = register_and_log_in_customer(%{conn: conn})

      {:ok, _view, html} = live(conn, ~p"/events")

      assert html =~ "Auth Event"
    end
  end

  # ---------------------------------------------------------------------------
  # Event Show
  # ---------------------------------------------------------------------------

  describe "Event Show" do
    test "renders for a published event", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org, %{name: "Awesome Festival"})

      {:ok, _view, html} = live(conn, ~p"/events/#{event.slug}")

      assert html =~ "Awesome Festival"
    end

    test "raises for a draft event (not published)", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Draft Only Event"})

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/events/#{event.slug}")
      end
    end

    test "renders event venue", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org, %{venue: "Madison Square Garden"})

      {:ok, _view, html} = live(conn, ~p"/events/#{event.slug}")

      assert html =~ "Madison Square Garden"
    end

    test "renders event description", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org, %{description: "The best event of the year."})

      {:ok, _view, html} = live(conn, ~p"/events/#{event.slug}")

      assert html =~ "The best event of the year."
    end

    test "renders item names and prices", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      _item = item_fixture(event, %{name: "VIP Ticket", price_cents: 15000})

      {:ok, _view, html} = live(conn, ~p"/events/#{event.slug}")

      assert html =~ "VIP Ticket"
      assert html =~ "150"
    end

    test "shows empty cart sidebar when no cart", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)

      {:ok, _view, html} = live(conn, ~p"/events/#{event.slug}")

      assert html =~ "Seu Carrinho"
      assert html =~ "Seu carrinho está vazio"
    end

    test "shows cart items when cart_token is provided", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{name: "GA Ticket", price_cents: 5000})
      cart = cart_with_item_fixture(event, item)

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event.slug}?cart_token=#{cart.session_token}")

      assert html =~ "GA Ticket"
    end

    test "add to cart creates a new cart and adds item", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{name: "Standard Ticket", price_cents: 3000})

      {:ok, view, _html} = live(conn, ~p"/events/#{event.slug}")

      view
      |> element("#add-#{item.id}")
      |> render_click()

      html = render(view)
      assert html =~ "Standard Ticket"
    end

    test "remove from cart removes the item", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{name: "Remove Me Ticket", price_cents: 1000})
      cart = cart_with_item_fixture(event, item)

      {:ok, view, _html} =
        live(conn, ~p"/events/#{event.slug}?cart_token=#{cart.session_token}")

      cart_item = hd(cart.cart_items)

      view
      |> element("#remove-#{cart_item.id}")
      |> render_click()

      html = render(view)
      assert html =~ "Seu carrinho está vazio"
    end

    test "shows checkout link when cart has items", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_with_item_fixture(event, item)

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event.slug}?cart_token=#{cart.session_token}")

      assert html =~ "Finalizar Compra"
      assert html =~ cart.session_token
    end

    test "ignores invalid cart_token gracefully", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event.slug}?cart_token=invalid-token-xyz")

      assert html =~ "Seu carrinho está vazio"
    end
  end

  # ---------------------------------------------------------------------------
  # Checkout
  # ---------------------------------------------------------------------------

  describe "Checkout - info step" do
    test "renders the checkout page with items in cart", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{name: "Checkout Ticket", price_cents: 5000})
      cart = cart_with_item_fixture(event, item)

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event.slug}/checkout?cart_token=#{cart.session_token}")

      assert html =~ "Suas Informações"
      assert html =~ "Nome Completo"
      assert html =~ "E-mail"
    end

    test "redirects to event show when no cart_token is provided", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/events/#{event.slug}/checkout")

      assert path == ~p"/events/#{event.slug}"
    end

    test "redirects to event show when cart_token is invalid", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/events/#{event.slug}/checkout?cart_token=bad-token")

      assert path == ~p"/events/#{event.slug}"
    end

    test "shows step indicator", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_with_item_fixture(event, item)

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event.slug}/checkout?cart_token=#{cart.session_token}")

      assert html =~ "Informações"
      assert html =~ "Pagamento"
    end

    test "submitting info form transitions to summary step", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_with_item_fixture(event, item)

      {:ok, view, _html} =
        live(conn, ~p"/events/#{event.slug}/checkout?cart_token=#{cart.session_token}")

      view
      |> form("#checkout-info-form", %{checkout: %{name: "John Smith", email: "john@example.com"}})
      |> render_submit()

      html = render(view)
      assert html =~ "Resumo do Pedido"
      assert html =~ "Pagamento"
    end
  end

  describe "Checkout - summary step" do
    test "renders summary page", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{name: "Summary Ticket", price_cents: 7500})
      cart = cart_with_item_fixture(event, item)

      {:ok, _view, html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      assert html =~ "Resumo do Pedido"
      assert html =~ "Summary Ticket"
    end

    test "shows payment method buttons", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_with_item_fixture(event, item)

      {:ok, _view, html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      assert html =~ "Cartão de Crédito"
      assert html =~ "Pix"
      assert html =~ "Boleto"
      assert html =~ "Transferência"
    end

    test "selecting a payment method highlights it", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_with_item_fixture(event, item)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      view
      |> element("#pay-pix")
      |> render_click()

      assert has_element?(view, "#pay-pix")
    end

    test "place_order redirects to confirmation page", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 1000})
      cart = cart_with_item_fixture(event, item)

      # First go through info step to set attendee info
      {:ok, view, _html} =
        live(conn, ~p"/events/#{event.slug}/checkout?cart_token=#{cart.session_token}")

      view
      |> form("#checkout-info-form", %{checkout: %{name: "Alice Smith", email: "alice@test.com"}})
      |> render_submit()

      # Select payment
      view
      |> element("#pay-pix")
      |> render_click()

      # Place order
      view
      |> element("#place-order-btn")
      |> render_click()

      # Should redirect to confirmation
      {path, _flash} = assert_redirect(view)
      assert String.contains?(path, "/orders/")
    end
  end

  # ---------------------------------------------------------------------------
  # Confirmation
  # ---------------------------------------------------------------------------

  describe "Order Confirmation" do
    test "renders confirmation page with valid code", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 1000})
      cart = cart_with_item_fixture(event, item)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Bob Builder",
          email: "bob@example.com",
          payment_method: "pix"
        })

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event.slug}/orders/#{order.confirmation_code}")

      assert html =~ "Pedido Confirmado"
      assert html =~ order.confirmation_code
      assert html =~ "Bob Builder"
      assert html =~ "bob@example.com"
    end

    test "shows event name on confirmation page", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org, %{name: "Grand Finale Concert"})
      item = item_fixture(event)
      cart = cart_with_item_fixture(event, item)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test User",
          email: "user@example.com",
          payment_method: "credit_card"
        })

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event.slug}/orders/#{order.confirmation_code}")

      assert html =~ "Grand Finale Concert"
    end

    test "shows ticket items on confirmation page", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{name: "Confirmation Ticket", price_cents: 5000})
      cart = cart_with_item_fixture(event, item)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test User",
          email: "user@example.com",
          payment_method: "boleto"
        })

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event.slug}/orders/#{order.confirmation_code}")

      assert html =~ "Confirmation Ticket"
    end

    test "shows total on confirmation page", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 2500})
      cart = cart_with_item_fixture(event, item)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test User",
          email: "user@example.com",
          payment_method: "pix"
        })

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event.slug}/orders/#{order.confirmation_code}")

      # 2500 cents = R$ 25,00
      assert html =~ "25"
    end

    test "redirects to events when confirmation code is invalid", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)

      assert {:error, {:live_redirect, %{to: "/events"}}} =
               live(conn, ~p"/events/#{event.slug}/orders/ZZZZZZ")
    end

    test "shows Browse More Events link", %{conn: conn} do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_with_item_fixture(event, item)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test",
          email: "test@example.com",
          payment_method: "pix"
        })

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event.slug}/orders/#{order.confirmation_code}")

      assert html =~ "Explorar Mais Eventos"
      assert html =~ "/events"
    end
  end
end
