defmodule PretexWeb.Admin.OrderLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Orders
  alias Pretex.Orders.Order
  alias Pretex.Events
  alias Pretex.Organizations
  alias Pretex.Catalog

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp org_fixture(attrs \\ %{}) do
    {:ok, org} =
      attrs
      |> Enum.into(%{
        name: "Test Org #{System.unique_integer([:positive])}",
        slug: "test-org-#{System.unique_integer([:positive])}",
        display_name: "Test Organization"
      })
      |> Organizations.create_organization()

    org
  end

  defp event_fixture(org, attrs \\ %{}) do
    base = %{
      name: "Test Event #{System.unique_integer([:positive])}",
      slug: "test-event-#{System.unique_integer([:positive])}",
      starts_at: ~U[2030-06-01 10:00:00Z],
      ends_at: ~U[2030-06-01 18:00:00Z],
      venue: "Main Stage"
    }

    {:ok, event} = Events.create_event(org, Enum.into(attrs, base))
    event
  end

  defp item_fixture(event, attrs \\ %{}) do
    base = %{
      name: "Test Item #{System.unique_integer([:positive])}",
      price_cents: 5000
    }

    {:ok, item} = Catalog.create_item(event, Enum.into(attrs, base))
    item
  end

  defp order_fixture(event, attrs \\ %{}) do
    base = %{
      name: "João Silva #{System.unique_integer([:positive])}",
      email: "joao#{System.unique_integer([:positive])}@example.com",
      payment_method: "pix",
      status: "pending",
      total_cents: 5000,
      confirmation_code: :crypto.strong_rand_bytes(3) |> Base.encode16(),
      expires_at:
        DateTime.utc_now()
        |> DateTime.add(30 * 60, :second)
        |> DateTime.truncate(:second)
    }

    merged = Map.merge(base, attrs)

    %Order{}
    |> Order.changeset(merged)
    |> Ecto.Changeset.put_change(:event_id, event.id)
    |> Ecto.Changeset.put_change(:status, merged[:status] || "pending")
    |> Ecto.Changeset.put_change(:total_cents, merged[:total_cents] || 5000)
    |> Ecto.Changeset.put_change(:confirmation_code, merged[:confirmation_code])
    |> Ecto.Changeset.put_change(:expires_at, merged[:expires_at])
    |> Pretex.Repo.insert!()
  end

  defp confirmed_order_fixture(event, attrs \\ %{}) do
    order_fixture(event, Map.merge(%{status: "confirmed"}, attrs))
  end

  # ---------------------------------------------------------------------------
  # Order Index — listing
  # ---------------------------------------------------------------------------

  describe "Index - order list page" do
    setup :register_and_log_in_user

    test "renders the orders page for authenticated user", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Summer Fest"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert html =~ "Pedidos"
      assert html =~ "Summer Fest"
    end

    test "shows empty state when no orders exist", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert html =~ "Nenhum pedido encontrado"
    end

    test "shows list of orders for the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event, %{name: "Maria Fernanda"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert html =~ order.name
      assert html =~ order.confirmation_code
    end

    test "shows order email in the list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event, %{email: "unique_list_test@example.com"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert html =~ order.email
    end

    test "shows multiple orders", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order1 = order_fixture(event, %{name: "Alice Wonderland"})
      order2 = order_fixture(event, %{name: "Bob Builder"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert html =~ order1.name
      assert html =~ order2.name
    end

    test "does not show orders from other events", %{conn: conn} do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      other_order = order_fixture(event1, %{name: "Other Event User"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event2}/orders")

      refute html =~ other_order.name
    end

    test "shows status badge for each order", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _order = confirmed_order_fixture(event)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert html =~ "Confirmado"
    end

    test "shows pending badge for pending orders", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _order = order_fixture(event, %{status: "pending"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert html =~ "Pendente"
    end

    test "shows a View link for each order", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}/orders/#{order.id}\"]"
             )
    end

    test "shows 'Novo Pedido Manual' button", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert has_element?(view, "a", "Novo Pedido Manual")
    end

    test "shows back link to the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}\"]"
             )
    end

    test "shows total count of orders found", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _o1 = order_fixture(event)
      _o2 = order_fixture(event)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert html =~ "pedido(s) encontrado(s)"
    end

    test "redirects unauthenticated users", %{conn: _conn} do
      org = org_fixture()
      event = event_fixture(org)

      unauthenticated_conn = Phoenix.ConnTest.build_conn()

      result = live(unauthenticated_conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      assert {:error, {:redirect, %{to: path}}} = result
      assert path =~ "/staff/log-in"
    end
  end

  # ---------------------------------------------------------------------------
  # Order Index — search filter
  # ---------------------------------------------------------------------------

  describe "Index - search filter" do
    setup :register_and_log_in_user

    test "search by name filters orders", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      alice = order_fixture(event, %{name: "Alice Searches"})
      _bob = order_fixture(event, %{name: "Bob Stays"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      html =
        view
        |> element("input[name='query']")
        |> render_change(%{"query" => "alice"})

      assert html =~ alice.name
      refute html =~ "Bob Stays"
    end

    test "search by email filters orders", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      target = order_fixture(event, %{email: "findme_search@test.com", name: "Target Person"})
      _other = order_fixture(event, %{email: "other_search@example.com", name: "Other Person"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      html =
        view
        |> element("input[name='query']")
        |> render_change(%{"query" => "findme_search"})

      assert html =~ target.name
      refute html =~ "Other Person"
    end

    test "clearing search restores full list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      alice = order_fixture(event, %{name: "Alice Clear"})
      bob = order_fixture(event, %{name: "Bob Clear"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      # Filter first
      view
      |> element("input[name='query']")
      |> render_change(%{"query" => "alice"})

      # Then clear
      view
      |> element("button[phx-click='clear_filters']")
      |> render_click()

      html = render(view)
      assert html =~ alice.name
      assert html =~ bob.name
    end

    test "shows empty state hint when search returns no results", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _order = order_fixture(event, %{name: "Real Person"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      html =
        view
        |> element("input[name='query']")
        |> render_change(%{"query" => "xyznonexistent"})

      assert html =~ "Nenhum pedido encontrado"
      assert html =~ "Tente ajustar os filtros"
    end
  end

  # ---------------------------------------------------------------------------
  # Order Index — status filter
  # ---------------------------------------------------------------------------

  describe "Index - status filter" do
    setup :register_and_log_in_user

    test "filter by status shows only matching orders", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      confirmed = confirmed_order_fixture(event, %{name: "Confirmed Person"})
      _pending = order_fixture(event, %{name: "Pending Person", status: "pending"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      html =
        view
        |> element("select[name='status']")
        |> render_change(%{"status" => "confirmed"})

      assert html =~ confirmed.name
      refute html =~ "Pending Person"
    end

    test "filter by pending status", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      pending = order_fixture(event, %{name: "Pending Only Person", status: "pending"})
      _confirmed = confirmed_order_fixture(event, %{name: "Confirmed Only Person"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      html =
        view
        |> element("select[name='status']")
        |> render_change(%{"status" => "pending"})

      assert html =~ pending.name
      refute html =~ "Confirmed Only Person"
    end

    test "clearing filters after status filter restores all orders", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      confirmed = confirmed_order_fixture(event, %{name: "Confirmed Status Clear"})
      pending = order_fixture(event, %{name: "Pending Status Clear", status: "pending"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders")

      view
      |> element("select[name='status']")
      |> render_change(%{"status" => "confirmed"})

      view
      |> element("button[phx-click='clear_filters']")
      |> render_click()

      html = render(view)
      assert html =~ confirmed.name
      assert html =~ pending.name
    end
  end

  # ---------------------------------------------------------------------------
  # Order Show page
  # ---------------------------------------------------------------------------

  describe "Show - order detail" do
    setup :register_and_log_in_user

    test "renders order detail page", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event, %{name: "Show Test User", email: "showtest@example.com"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert html =~ order.name
      assert html =~ order.email
      assert html =~ order.confirmation_code
    end

    test "shows order status badge", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = confirmed_order_fixture(event)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert html =~ "Confirmado"
    end

    test "shows pending status badge for pending order", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event, %{status: "pending"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert html =~ "Pendente"
    end

    test "shows order total", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event, %{total_cents: 15000})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert html =~ "150"
    end

    test "shows back link to order list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}/orders\"]"
             )
    end

    test "shows audit/timeline section", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert html =~ "Auditoria"
      assert html =~ "Pedido criado"
    end

    test "shows items section", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert html =~ "Itens do Pedido"
    end

    test "shows 'Cancelar Pedido' button for confirmed order", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = confirmed_order_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert has_element?(view, "button[phx-click='cancel_order']")
    end

    test "shows 'Cancelar Pedido' button for pending order", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event, %{status: "pending"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert has_element?(view, "button[phx-click='cancel_order']")
    end

    test "does not show 'Cancelar Pedido' button for cancelled order", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event, %{status: "cancelled"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      refute has_element?(view, "button[phx-click='cancel_order']")
    end

    test "shows 'Reenviar Ingressos' button for confirmed order", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = confirmed_order_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert has_element?(view, "button[phx-click='resend_tickets']")
    end

    test "does not show 'Reenviar Ingressos' button for pending order", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event, %{status: "pending"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      refute has_element?(view, "button[phx-click='resend_tickets']")
    end

    test "shows lock button when order is not locked", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      assert has_element?(view, "button[phx-click='lock_order']")
      refute has_element?(view, "button[phx-click='unlock_order']")
    end

    test "shows lock warning when order is locked", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)
      {:ok, locked_order} = Orders.lock_order_for_editing(order)

      {:ok, view, html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/orders/#{locked_order.id}"
        )

      assert html =~ "Pedido bloqueado para edição"
      assert has_element?(view, "button[phx-click='unlock_order']")
      refute has_element?(view, "button[phx-click='lock_order']")
    end
  end

  # ---------------------------------------------------------------------------
  # Order Show — events (resend, lock, cancel)
  # ---------------------------------------------------------------------------

  describe "Show - resend tickets event" do
    setup :register_and_log_in_user

    test "clicking 'Reenviar Ingressos' puts success flash for confirmed order", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = confirmed_order_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      # Use the specific top-bar resend button by id
      view
      |> element("#resend-tickets-top")
      |> render_click()

      html = render(view)
      assert html =~ "E-mail de ingressos reenviado com sucesso"
    end
  end

  describe "Show - lock and unlock order" do
    setup :register_and_log_in_user

    test "clicking 'Bloquear' locks the order and shows unlock button", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      view
      |> element("button[phx-click='lock_order']")
      |> render_click()

      html = render(view)
      assert html =~ "Pedido bloqueado para edição"
      assert has_element?(view, "button[phx-click='unlock_order']")
    end

    test "clicking 'Desbloquear' unlocks the order and shows lock button", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)
      {:ok, locked} = Orders.lock_order_for_editing(order)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{locked.id}")

      view
      |> element("button[phx-click='unlock_order']")
      |> render_click()

      html = render(view)
      refute html =~ "Pedido bloqueado para edição"
      assert has_element?(view, "button[phx-click='lock_order']")
    end
  end

  describe "Show - cancel order" do
    setup :register_and_log_in_user

    test "cancelling confirmed order changes status to cancelled", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = confirmed_order_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      view
      |> element("#cancel-order-top")
      |> render_click()

      html = render(view)
      assert html =~ "Pedido cancelado com sucesso"
      assert html =~ "Cancelado"
    end

    test "cancelling pending order changes status to cancelled", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event, %{status: "pending"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/#{order.id}")

      view
      |> element("#cancel-order-top")
      |> render_click()

      html = render(view)
      assert html =~ "Pedido cancelado com sucesso"
    end
  end

  # ---------------------------------------------------------------------------
  # New Manual Order page
  # ---------------------------------------------------------------------------

  describe "NewManual - form render" do
    setup :register_and_log_in_user

    test "renders the new manual order form", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      assert html =~ "Novo Pedido Manual"
      assert html =~ event.name
    end

    test "shows name field", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      assert has_element?(view, "input[name='order[name]']")
    end

    test "shows email field", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      assert has_element?(view, "input[name='order[email]']")
    end

    test "shows status dropdown with paid and comp options", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      assert html =~ "paid"
      assert html =~ "comp"
    end

    test "shows 'Adicionar Item' button", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _item = item_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      assert has_element?(view, "button[phx-click='add_item']")
    end

    test "shows back link to orders list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}/orders\"]"
             )
    end

    test "shows warning when catalog has no items", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      assert html =~ "Nenhum item no catálogo"
    end

    test "shows item selector when catalog has items", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{name: "VIP Pass"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      assert html =~ item.name
    end

    test "shows quota bypass info alert", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      assert html =~ "não decrementam"
    end
  end

  describe "NewManual - add/remove items" do
    setup :register_and_log_in_user

    test "clicking 'add_item' adds a new item row", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _item = item_fixture(event, %{name: "Regular Ticket"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      # There should be one row initially
      initial_html = render(view)
      initial_count = count_item_rows(initial_html)

      view
      |> element("#add-item-header")
      |> render_click()

      new_html = render(view)
      assert count_item_rows(new_html) == initial_count + 1
    end

    test "clicking 'remove_item' removes an item row", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _item = item_fixture(event, %{name: "Removable Ticket"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      # Add one more row first
      view
      |> element("#add-item-header")
      |> render_click()

      html_after_add = render(view)
      count_before_remove = count_item_rows(html_after_add)

      view
      |> element("button[phx-click='remove_item'][phx-value-index='0']")
      |> render_click()

      new_html = render(view)
      assert count_item_rows(new_html) == count_before_remove - 1
    end
  end

  describe "NewManual - save" do
    setup :register_and_log_in_user

    test "submitting valid form creates order and redirects to order list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{name: "Festival Pass", price_cents: 10_000})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      assert view
             |> form("#manual-order-form",
               order: %{
                 name: "Novo Participante",
                 email: "novo@example.com",
                 status: "paid",
                 items: %{
                   "0" => %{
                     item_id: item.id,
                     quantity: "1",
                     unit_price_cents: "10000"
                   }
                 }
               }
             )
             |> render_submit()

      assert_redirect(
        view,
        ~p"/admin/organizations/#{org}/events/#{event}/orders"
      )
    end

    test "creating a manual order puts success flash", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{name: "Backstage Pass", price_cents: 20_000})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      view
      |> form("#manual-order-form",
        order: %{
          name: "Flash Test User",
          email: "flash@example.com",
          status: "comp",
          items: %{
            "0" => %{
              item_id: item.id,
              quantity: "1",
              unit_price_cents: "0"
            }
          }
        }
      )
      |> render_submit()

      # After redirect, the flash should be set
      {path, flash} = assert_redirect(view)
      assert path =~ "/orders"
      assert flash["info"] =~ "Pedido manual criado com sucesso"
    end

    test "submitting with missing name shows error flash", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      html =
        view
        |> form("#manual-order-form",
          order: %{
            name: "",
            email: "test@example.com",
            status: "paid",
            items: %{
              "0" => %{
                item_id: item.id,
                quantity: "1",
                unit_price_cents: "5000"
              }
            }
          }
        )
        |> render_submit()

      assert html =~ "Erro ao criar pedido"
    end

    test "submitting with invalid email shows error flash", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/orders/new")

      html =
        view
        |> form("#manual-order-form",
          order: %{
            name: "Valid Name",
            email: "not-a-valid-email",
            status: "paid",
            items: %{
              "0" => %{
                item_id: item.id,
                quantity: "1",
                unit_price_cents: "5000"
              }
            }
          }
        )
        |> render_submit()

      assert html =~ "Erro ao criar pedido"
    end
  end

  # ---------------------------------------------------------------------------
  # Helper functions
  # ---------------------------------------------------------------------------

  defp count_item_rows(html) do
    # Count occurrences of the item row pattern in rendered HTML
    html
    |> String.split("phx-click=\"remove_item\"")
    |> length()
    |> Kernel.-(1)
  end
end
