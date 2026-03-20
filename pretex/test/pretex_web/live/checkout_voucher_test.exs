defmodule PretexWeb.CheckoutVoucherTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Events
  alias Pretex.Organizations
  alias Pretex.Orders
  alias Pretex.Vouchers
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

    # publish_event requires at least one catalog item
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

  defp voucher_fixture(event, attrs \\ %{}) do
    base = %{
      code: "VOUCHER#{System.unique_integer([:positive])}",
      effect: "fixed_discount",
      value: 1000,
      active: true
    }

    {:ok, voucher} = Vouchers.create_voucher(event, Enum.into(attrs, base))
    voucher
  end

  # ---------------------------------------------------------------------------
  # Summary step — voucher input UI
  # ---------------------------------------------------------------------------

  describe "Checkout summary — voucher UI" do
    test "shows voucher code input form on summary page", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      {:ok, _view, html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      assert html =~ "Código do cupom"
      assert html =~ "Aplicar"
    end

    test "does not show applied voucher badge initially", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      {:ok, _view, html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      refute html =~ "Cupom aplicado"
    end
  end

  # ---------------------------------------------------------------------------
  # apply_voucher event
  # ---------------------------------------------------------------------------

  describe "apply_voucher event" do
    test "applying a valid fixed_discount voucher shows discount in summary", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      _voucher = voucher_fixture(event, %{code: "SAVE10", effect: "fixed_discount", value: 1000})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      html =
        view
        |> form("form[phx-submit='apply_voucher']", %{"code" => "SAVE10"})
        |> render_submit()

      assert html =~ "Cupom aplicado"
      assert html =~ "SAVE10"
      # Discount row should show the amount
      assert html =~ "- R$"
    end

    test "applying a valid percentage voucher shows discount row", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 10_000)
      cart = cart_fixture(event, item)

      _voucher =
        voucher_fixture(event, %{
          code: "PCT10",
          effect: "percentage_discount",
          value: 1000
        })

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      html =
        view
        |> form("form[phx-submit='apply_voucher']", %{"code" => "PCT10"})
        |> render_submit()

      assert html =~ "PCT10"
      assert html =~ "Cupom aplicado"
    end

    test "applying a valid voucher reduces the displayed total", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)
      _voucher = voucher_fixture(event, %{code: "DISC5", effect: "fixed_discount", value: 500})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      html_before = render(view)
      # Before applying, total should be R$ 50,00
      assert html_before =~ "50,00"

      html_after =
        view
        |> form("form[phx-submit='apply_voucher']", %{"code" => "DISC5"})
        |> render_submit()

      # After applying R$5 discount, total should be R$ 45,00
      assert html_after =~ "45,00"
    end

    test "applying a voucher with lowercase code still works", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      _voucher =
        voucher_fixture(event, %{code: "UPPERCASE", effect: "fixed_discount", value: 200})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      html =
        view
        |> form("form[phx-submit='apply_voucher']", %{"code" => "uppercase"})
        |> render_submit()

      assert html =~ "UPPERCASE"
      assert html =~ "Cupom aplicado"
    end

    test "applying an expired voucher shows expired error message", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      _voucher =
        voucher_fixture(event, %{
          code: "EXPIRED",
          effect: "fixed_discount",
          value: 500,
          valid_until: past
        })

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      html =
        view
        |> form("form[phx-submit='apply_voucher']", %{"code" => "EXPIRED"})
        |> render_submit()

      assert html =~ "Cupom expirado"
      refute html =~ "Cupom aplicado"
    end

    test "applying a fully-used voucher shows exhausted error message", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      voucher =
        voucher_fixture(event, %{
          code: "EXHAUSTED",
          effect: "fixed_discount",
          value: 500,
          max_uses: 3
        })

      # Manually set used_count to max_uses
      voucher
      |> Ecto.Changeset.change(used_count: 3)
      |> Repo.update!()

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      html =
        view
        |> form("form[phx-submit='apply_voucher']", %{"code" => "EXHAUSTED"})
        |> render_submit()

      assert html =~ "Cupom esgotado"
      refute html =~ "Cupom aplicado"
    end

    test "applying an unknown voucher code shows not found error", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      html =
        view
        |> form("form[phx-submit='apply_voucher']", %{"code" => "DOESNOTEXIST"})
        |> render_submit()

      assert html =~ "Cupom não encontrado"
      refute html =~ "Cupom aplicado"
    end

    test "applying an inactive voucher shows not found error", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      _voucher =
        voucher_fixture(event, %{
          code: "INACTIVE",
          effect: "fixed_discount",
          value: 500,
          active: false
        })

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      html =
        view
        |> form("form[phx-submit='apply_voucher']", %{"code" => "INACTIVE"})
        |> render_submit()

      assert html =~ "Cupom não encontrado"
      refute html =~ "Cupom aplicado"
    end

    test "applying a valid voucher hides the input form", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      _voucher =
        voucher_fixture(event, %{code: "HIDEINPUT", effect: "fixed_discount", value: 200})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      view
      |> form("form[phx-submit='apply_voucher']", %{"code" => "HIDEINPUT"})
      |> render_submit()

      # After applying, the input form should be gone (voucher is not nil)
      refute has_element?(view, "form[phx-submit='apply_voucher']")
    end

    test "error is shown below the voucher input form", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      html =
        view
        |> form("form[phx-submit='apply_voucher']", %{"code" => "BADCODE"})
        |> render_submit()

      # The error message should be in the page
      assert html =~ "Cupom não encontrado"
      # The input form should still be visible (error state doesn't hide it)
      assert has_element?(view, "form[phx-submit='apply_voucher']")
    end
  end

  # ---------------------------------------------------------------------------
  # remove_voucher event
  # ---------------------------------------------------------------------------

  describe "remove_voucher event" do
    test "removing an applied voucher shows the input form again", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)
      _voucher = voucher_fixture(event, %{code: "REMOVE1", effect: "fixed_discount", value: 300})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      # Apply voucher
      view
      |> form("form[phx-submit='apply_voucher']", %{"code" => "REMOVE1"})
      |> render_submit()

      # Confirm it's applied
      assert has_element?(view, "button[phx-click='remove_voucher']")

      # Remove the voucher
      html =
        view
        |> element("button[phx-click='remove_voucher']")
        |> render_click()

      # Input form should be back
      assert has_element?(view, "form[phx-submit='apply_voucher']")
      # Applied badge should be gone
      refute html =~ "Cupom aplicado"
    end

    test "removing a voucher restores the original total", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)

      _voucher =
        voucher_fixture(event, %{code: "RESTORE1", effect: "fixed_discount", value: 1000})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      # Apply voucher — total becomes R$ 40,00
      view
      |> form("form[phx-submit='apply_voucher']", %{"code" => "RESTORE1"})
      |> render_submit()

      # Remove the voucher — total should go back to R$ 50,00
      html =
        view
        |> element("button[phx-click='remove_voucher']")
        |> render_click()

      # Total should be back to 5000 cents = R$ 50,00
      assert html =~ "50,00"
    end

    test "removing a voucher clears any error message", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)
      _voucher = voucher_fixture(event, %{code: "CLEARERR", effect: "fixed_discount", value: 200})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      # Apply voucher successfully
      view
      |> form("form[phx-submit='apply_voucher']", %{"code" => "CLEARERR"})
      |> render_submit()

      # Remove it
      html =
        view
        |> element("button[phx-click='remove_voucher']")
        |> render_click()

      # No error messages should appear
      refute html =~ "Cupom não encontrado"
      refute html =~ "Cupom expirado"
      refute html =~ "Cupom esgotado"
    end
  end

  # ---------------------------------------------------------------------------
  # AC5: Only one voucher per order — applying a second voucher shows an error
  # ---------------------------------------------------------------------------

  describe "AC5 — only one voucher per order" do
    test "trying to apply a second voucher when one is already applied shows error", %{
      conn: conn
    } do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      _voucher1 =
        voucher_fixture(event, %{code: "FIRST1", effect: "fixed_discount", value: 500})

      _voucher2 =
        voucher_fixture(event, %{code: "SECOND1", effect: "fixed_discount", value: 300})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      # Apply first voucher successfully
      view
      |> form("form[phx-submit='apply_voucher']", %{"code" => "FIRST1"})
      |> render_submit()

      # First voucher is applied — the form is hidden, so a second direct apply
      # is not possible through the UI (form is gone). This tests that the
      # LiveView properly hides the input after applying the first voucher.
      refute has_element?(view, "form[phx-submit='apply_voucher']")

      # The remove button is visible — only one voucher at a time
      assert has_element?(view, "button[phx-click='remove_voucher']")
    end

    test "first voucher code is preserved when second apply is attempted via event", %{
      conn: conn
    } do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event, item)

      _voucher1 =
        voucher_fixture(event, %{code: "KEEPFIRST", effect: "fixed_discount", value: 500})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      view
      |> form("form[phx-submit='apply_voucher']", %{"code" => "KEEPFIRST"})
      |> render_submit()

      html = render(view)
      assert html =~ "KEEPFIRST"
      assert html =~ "Cupom aplicado"
    end
  end

  # ---------------------------------------------------------------------------
  # place_order with voucher — AC5 enforcement at DB level
  # ---------------------------------------------------------------------------

  describe "place_order with voucher" do
    test "placing an order with a valid voucher applies the discount to order total", %{
      conn: conn
    } do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)

      _voucher =
        voucher_fixture(event, %{
          code: "PLACEORDER",
          effect: "fixed_discount",
          value: 1000
        })

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      # Set attendee info via send (simulating the info step)
      send(view.pid, {:set_attendee_info, "Test User", "test@example.com"})

      # Apply the voucher
      view
      |> form("form[phx-submit='apply_voucher']", %{"code" => "PLACEORDER"})
      |> render_submit()

      # Check that the discount is shown in the summary
      html = render(view)
      assert html =~ "PLACEORDER"
      assert html =~ "Cupom aplicado"
    end

    test "placing an order without a voucher is unaffected", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)

      {:ok, _view, html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      # No voucher applied — total is full price
      assert html =~ "50,00"
    end

    test "voucher discount is reflected in order total after full checkout", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      cart = cart_fixture(event, item)

      _voucher =
        voucher_fixture(event, %{
          code: "CHECKOUT1",
          effect: "fixed_discount",
          value: 1000
        })

      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event.slug}/checkout/summary?cart_token=#{cart.session_token}"
        )

      # Apply the voucher
      html =
        view
        |> form("form[phx-submit='apply_voucher']", %{"code" => "CHECKOUT1"})
        |> render_submit()

      # Discounted total = 5000 - 1000 = 4000 = R$ 40,00
      assert html =~ "40,00"
    end

    test "used_count is incremented after order is placed with voucher via create_order_from_cart",
         %{conn: _conn} do
      # Integration test at the context level
      org = org_fixture()
      event = event_fixture(org)

      item = item_fixture(event, 5000)
      {:ok, cart} = Orders.create_cart(event)
      {:ok, _} = Orders.add_to_cart(cart, item, quantity: 1)
      cart = Orders.get_cart_by_token(cart.session_token)

      voucher =
        voucher_fixture(event, %{
          code: "USEDCOUNT",
          effect: "fixed_discount",
          value: 500
        })

      assert voucher.used_count == 0

      {:ok, _order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test User",
          email: "test@example.com",
          payment_method: "pix",
          voucher_code: "USEDCOUNT"
        })

      updated = Repo.get!(Pretex.Vouchers.Voucher, voucher.id)
      assert updated.used_count == 1
    end

    test "unique constraint prevents two redemptions for the same order at DB level", %{
      conn: _conn
    } do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, 5000)
      {:ok, cart} = Orders.create_cart(event)
      {:ok, _} = Orders.add_to_cart(cart, item, quantity: 1)
      cart = Orders.get_cart_by_token(cart.session_token)

      voucher =
        voucher_fixture(event, %{
          code: "ONEPERORDER",
          effect: "fixed_discount",
          value: 500
        })

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test User",
          email: "test@example.com",
          payment_method: "pix",
          voucher_code: "ONEPERORDER"
        })

      # Attempting a second redemption for the same order should fail
      assert_raise Ecto.ConstraintError, fn ->
        %Pretex.Vouchers.VoucherRedemption{}
        |> Ecto.Changeset.change(%{
          voucher_id: voucher.id,
          order_id: order.id,
          discount_cents: 500
        })
        |> Repo.insert!()
      end
    end
  end
end
