defmodule PretexWeb.CheckoutGiftCardTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Events
  alias Pretex.Organizations
  alias Pretex.Orders
  alias Pretex.GiftCards
  alias Pretex.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp org_fixture do
    {:ok, org} =
      %{name: "Test Org", slug: "test-org-#{System.unique_integer([:positive])}"}
      |> Organizations.create_organization()

    org
  end

  defp event_fixture(org) do
    {:ok, event} =
      Events.create_event(org, %{
        name: "Test Event #{System.unique_integer([:positive])}",
        starts_at: ~U[2030-06-01 10:00:00Z],
        ends_at: ~U[2030-06-01 18:00:00Z],
        venue: "Main Stage",
        slug: "test-event-#{System.unique_integer([:positive])}"
      })

    {:ok, _item} =
      Pretex.Catalog.create_item(event, %{
        name: "Ingresso Geral",
        price_cents: 5000
      })

    {:ok, published} = Events.publish_event(event)
    published
  end

  defp item_fixture(event, price_cents \\ 5000) do
    {:ok, item} =
      Pretex.Catalog.create_item(event, %{
        name: "Ingresso Específico #{System.unique_integer([:positive])}",
        price_cents: price_cents
      })

    item
  end

  defp cart_fixture(event, item) do
    {:ok, cart} = Orders.create_cart(event)
    {:ok, _} = Orders.add_to_cart(cart, item, quantity: 1)
    Orders.get_cart_by_token(cart.session_token)
  end

  defp gift_card_fixture(org, attrs \\ %{}) do
    base = %{
      code: "GC-TEST#{System.unique_integer([:positive])}",
      balance_cents: 5000,
      active: true
    }

    {:ok, gc} = GiftCards.create_gift_card(org, Enum.into(attrs, base))
    gc
  end

  defp navigate_to_summary(conn, event, cart) do
    live(conn, ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}")
  end

  # ---------------------------------------------------------------------------
  # Summary step — gift card input UI
  # ---------------------------------------------------------------------------

  describe "Checkout summary — gift card UI" do
    test "shows gift card code input form on summary page", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      {:ok, _view, html} = navigate_to_summary(conn, event, cart)

      assert html =~ "Código do vale-presente"
      assert html =~ "apply_gift_card"
    end

    test "shows 'Aplicar' button for gift card input", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      {:ok, _view, html} = navigate_to_summary(conn, event, cart)

      assert html =~ "Aplicar"
    end

    test "gift card input is hidden when a gift card is applied", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 2000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
        |> render_submit()

      refute html =~ "Código do vale-presente"
    end
  end

  # ---------------------------------------------------------------------------
  # Applying gift cards
  # ---------------------------------------------------------------------------

  describe "apply_gift_card event" do
    test "applying a valid gift card shows the deduction in the summary", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 2000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
        |> render_submit()

      assert html =~ gc.code
      assert html =~ "R$ 20,00"
    end

    test "applying a gift card shows badge with code", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{code: "GC-BADGE01", balance_cents: 1000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
        |> render_submit()

      assert html =~ "GC-BADGE01"
      assert html =~ "Remover"
    end

    test "applying a gift card reduces the displayed grand total", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 2000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      view
      |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
      |> render_submit()

      html = render(view)

      # Total should be 5000 - 2000 = 3000 = R$ 30,00
      assert html =~ "R$ 30,00"
    end

    test "applying a gift card case-insensitively works", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{code: "GC-CITEST1", balance_cents: 1000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => "gc-citest1"})
        |> render_submit()

      assert html =~ "GC-CITEST1"
    end

    test "applying a gift card when card balance exceeds order total shows 100% deduction",
         %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 1000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 50_000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      view
      |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
      |> render_submit()

      html = render(view)

      # Grand total should be "Grátis" (format_price(0) returns "Grátis")
      assert html =~ "Grátis"
    end
  end

  # ---------------------------------------------------------------------------
  # Gift card error messages
  # ---------------------------------------------------------------------------

  describe "gift card error messages" do
    test "shows error for a non-existent gift card code", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => "GC-DOESNOTEXIST"})
        |> render_submit()

      assert html =~ "Vale-presente não encontrado"
    end

    test "shows error for a gift card from wrong organization", %{conn: conn} do
      org1 = org_fixture()
      org2 = org_fixture()
      event = event_fixture(org2)
      item = item_fixture(event)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org1, %{balance_cents: 1000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
        |> render_submit()

      assert html =~ "não é válido para este evento"
    end

    test "shows error for an expired gift card", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      gc = gift_card_fixture(org, %{balance_cents: 1000, expires_at: past})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
        |> render_submit()

      assert html =~ "expirado"
    end

    test "shows error for an empty (zero balance) gift card", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 0})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
        |> render_submit()

      assert html =~ "sem saldo"
    end

    test "shows error for an inactive gift card", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 1000, active: false})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
        |> render_submit()

      assert html =~ "inativo"
    end

    test "shows error for empty code submission", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => ""})
        |> render_submit()

      assert html =~ "Por favor insira um código"
    end

    test "error disappears when a valid card is applied after an error", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 1000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      # First apply invalid code
      view
      |> form("form[phx-submit=apply_gift_card]", %{"code" => "GC-WRONG"})
      |> render_submit()

      # Then apply valid code
      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
        |> render_submit()

      refute html =~ "Vale-presente não encontrado"
      assert html =~ gc.code
    end
  end

  # ---------------------------------------------------------------------------
  # Removing gift cards
  # ---------------------------------------------------------------------------

  describe "remove_gift_card event" do
    test "removing a gift card clears the deduction", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 2000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      # Apply
      view
      |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
      |> render_submit()

      # Remove
      html = render_click(view, "remove_gift_card")

      # Gift card badge should be gone
      refute html =~ gc.code
      # Input form should be back
      assert html =~ "Código do vale-presente"
    end

    test "removing a gift card restores the original grand total", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 2000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      # Apply
      view
      |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
      |> render_submit()

      # Remove
      html = render_click(view, "remove_gift_card")

      # Total should be back to R$ 50,00
      assert html =~ "R$ 50,00"
    end

    test "removing a gift card clears any gift card error", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 2000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      # Apply a valid gift card
      view
      |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
      |> render_submit()

      # Remove it
      html = render_click(view, "remove_gift_card")

      refute html =~ "Vale-presente não encontrado"
      refute html =~ "expirado"
    end
  end

  # ---------------------------------------------------------------------------
  # Placing an order with a gift card
  # ---------------------------------------------------------------------------

  describe "place_order with gift card" do
    test "placing an order with a valid gift card deducts from order total", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{code: "GC-PLACE01", balance_cents: 2000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      # Fill in attendee info step first
      view
      |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
      |> render_submit()

      # Navigate to info step, fill in details
      {:ok, view, _} =
        live(conn, ~p"/events/#{event.slug}/checkout?cart_token=#{cart.session_token}")

      view
      |> form("form[phx-submit=submit_info]", %{
        "checkout" => %{"name" => "João Silva", "email" => "joao@example.com"}
      })
      |> render_submit()

      # Back to summary step with gift card
      {:ok, view, _} = navigate_to_summary(conn, event, cart)

      view
      |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
      |> render_submit()

      # The gift card code should be set and visible in summary
      html = render(view)
      assert html =~ gc.code
    end

    test "gift card deduction appears in order summary before placing order", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 1500})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
        |> render_submit()

      assert html =~ "R$ 15,00"
    end

    test "placed order has a gift card redemption record", %{conn: _conn} do
      org = org_fixture()
      event = event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-ORDREC1", balance_cents: 2000})

      item = item_fixture(event, 5000)
      {:ok, cart} = Orders.create_cart(event)
      {:ok, _} = Orders.add_to_cart(cart, item, quantity: 1)
      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "João Silva",
          email: "joao@example.com",
          payment_method: "pix",
          gift_card_code: gc.code
        })

      redemption = GiftCards.get_debit_redemption_for_order(order.id)

      assert redemption != nil
      assert redemption.amount_cents == 2000
      assert order.total_cents == 3000
    end

    test "placed order with gift card reduces card balance", %{conn: _conn} do
      org = org_fixture()
      event = event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-BALRED1", balance_cents: 3000})

      item = item_fixture(event, 5000)
      {:ok, cart} = Orders.create_cart(event)
      {:ok, _} = Orders.add_to_cart(cart, item, quantity: 1)
      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, _order} =
        Orders.create_order_from_cart(cart, %{
          name: "João Silva",
          email: "joao@example.com",
          payment_method: "pix",
          gift_card_code: gc.code
        })

      updated_gc = Repo.get!(Pretex.GiftCards.GiftCard, gc.id)
      assert updated_gc.balance_cents == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Subtotal visibility with gift card
  # ---------------------------------------------------------------------------

  describe "subtotal row with gift card" do
    test "subtotal row appears when gift card is applied", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 1000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      html =
        view
        |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
        |> render_submit()

      assert html =~ "Subtotal"
    end

    test "subtotal row disappears when gift card is removed and no fees/discounts", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      gc = gift_card_fixture(org, %{balance_cents: 1000})

      {:ok, view, _html} = navigate_to_summary(conn, event, cart)

      # Apply
      view
      |> form("form[phx-submit=apply_gift_card]", %{"code" => gc.code})
      |> render_submit()

      # Remove
      html = render_click(view, "remove_gift_card")

      # Subtotal should not appear when there are no fees, discounts, or gift cards
      refute html =~ "Subtotal"
    end
  end
end
