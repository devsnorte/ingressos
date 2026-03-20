defmodule PretexWeb.Admin.CatalogLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Catalog
  alias Pretex.Events
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
      name: "Test Event #{System.unique_integer([:positive])}",
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
      price_cents: 1000,
      item_type: "ticket",
      status: "active"
    }

    {:ok, item} = Catalog.create_item(event, Enum.into(attrs, base))
    item
  end

  # ---------------------------------------------------------------------------
  # Index
  # ---------------------------------------------------------------------------

  describe "Index" do
    setup :register_and_log_in_user

    test "renders catalog page for event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog")

      assert html =~ "Catálogo de Itens"
      assert html =~ event.name
    end

    test "shows empty state when no items", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog")

      assert html =~ "Nenhum item ainda."
    end

    test "lists items for the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{name: "General Admission"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog")

      assert html =~ item.name
    end

    test "does not show items from other events", %{conn: conn} do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      item = item_fixture(event1, %{name: "Other Event Item"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event2}/catalog")

      refute html =~ item.name
    end

    test "shows New Item button", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog")

      assert has_element?(view, "a", "Novo Item")
    end

    test "shows back link to event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}\"]"
             )
    end

    test "shows bundles section", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog")

      assert html =~ "Pacotes"
    end

    test "shows item status badge", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _item = item_fixture(event, %{name: "Badge Item", status: "active"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog")

      assert html =~ "active"
    end

    test "shows item type badge", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _item = item_fixture(event, %{name: "Type Item", item_type: "merchandise"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog")

      assert html =~ "merchandise"
    end

    test "shows formatted price for item", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _item = item_fixture(event, %{name: "Priced Item", price_cents: 150})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog")

      assert html =~ "R$"
    end
  end

  # ---------------------------------------------------------------------------
  # New item via modal
  # ---------------------------------------------------------------------------

  describe "New item modal" do
    setup :register_and_log_in_user

    test "navigating to /catalog/new opens the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/new")

      assert has_element?(view, "#item-modal")
      assert render(view) =~ "Novo Item"
    end

    test "shows validation errors on blank name", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/new")

      view
      |> form("#item-form", item: %{name: ""})
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "shows validation error when name is too short", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/new")

      view
      |> form("#item-form", item: %{name: "X"})
      |> render_change()

      assert render(view) =~ "should be at least 2 character"
    end

    test "creates item and closes modal on valid submit", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/new")

      view
      |> form("#item-form",
        item: %{
          name: "Brand New Ticket",
          price_cents: 2500,
          item_type: "ticket",
          status: "active"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Item created successfully"
      assert html =~ "Brand New Ticket"
      refute has_element?(view, "#item-modal")
    end

    test "clicking cancel closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/new")

      assert has_element?(view, "#item-modal")

      view
      |> element("#item-modal button[phx-click=\"cancel\"].btn-ghost.btn-sm:not(.btn-circle)")
      |> render_click()

      refute has_element?(view, "#item-modal")
    end
  end

  # ---------------------------------------------------------------------------
  # Edit item via modal
  # ---------------------------------------------------------------------------

  describe "Edit item modal" do
    setup :register_and_log_in_user

    test "navigating to /catalog/:id/edit opens modal pre-filled", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{name: "Editable Item"})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/#{item.id}/edit")

      assert has_element?(view, "#item-modal")
      assert html =~ "Editar Item"
      assert html =~ "Editable Item"
    end

    test "saves changes and updates the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{name: "Old Item Name"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/#{item.id}/edit")

      view
      |> form("#item-form", item: %{name: "Updated Item Name"})
      |> render_submit()

      html = render(view)
      assert html =~ "Item updated successfully"
      assert html =~ "Updated Item Name"
      refute has_element?(view, "#item-modal")
    end

    test "shows validation errors on invalid update", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/#{item.id}/edit")

      view
      |> form("#item-form", item: %{name: ""})
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end
  end

  # ---------------------------------------------------------------------------
  # Delete item
  # ---------------------------------------------------------------------------

  describe "Delete item" do
    setup :register_and_log_in_user

    test "removes the item from the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{name: "To Be Deleted"})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog")

      assert html =~ item.name

      view
      |> element("#delete-#{item.id}")
      |> render_click()

      html = render(view)
      assert html =~ "Item deleted"
      refute html =~ item.name
    end
  end

  # ---------------------------------------------------------------------------
  # ItemForm — new
  # ---------------------------------------------------------------------------

  describe "ItemForm :new" do
    setup :register_and_log_in_user

    test "renders the new item form page", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/new")

      assert html =~ "Novo Item"
      assert html =~ event.name
    end

    test "shows item form", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/new")

      assert has_element?(view, "#item-form")
    end

    test "shows validation errors on blank name", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/new")

      view
      |> form("#item-form", item: %{name: ""})
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "creates item and navigates to catalog on valid submit", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/new")

      view
      |> form("#item-form",
        item: %{
          name: "Full Form Item",
          price_cents: 3000,
          item_type: "merchandise",
          status: "active"
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/admin/organizations/#{org}/events/#{event}/catalog")
    end

    test "does not show variations section on new", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/new")

      refute has_element?(view, "#add-variation-btn")
    end
  end

  # ---------------------------------------------------------------------------
  # ItemForm — edit
  # ---------------------------------------------------------------------------

  describe "ItemForm :edit" do
    setup :register_and_log_in_user

    test "renders edit form pre-filled with item data", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{name: "Existing Item"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/#{item.id}")

      assert html =~ "Editar Item"
      assert html =~ "Existing Item"
    end

    test "shows variations section when editing", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/#{item.id}")

      assert has_element?(view, "#add-variation-btn")
    end

    test "shows no-variations notice when item has none", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/#{item.id}")

      assert html =~ "Nenhuma variação ainda."
    end

    test "saves changes and navigates to catalog", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{name: "Old Name"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/#{item.id}")

      view
      |> form("#item-form", item: %{name: "New Name"})
      |> render_submit()

      assert_redirect(view, ~p"/admin/organizations/#{org}/events/#{event}/catalog")
    end

    test "clicking Add Variation shows the variation form", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/#{item.id}")

      view
      |> element("#add-variation-btn")
      |> render_click()

      assert has_element?(view, "#variation-form")
    end

    test "adding a valid variation shows it in the list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/#{item.id}")

      view
      |> element("#add-variation-btn")
      |> render_click()

      view
      |> form("#variation-form",
        item_variation: %{name: "Extra Large", price_cents: 1200, status: "active"}
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Variation added"
      assert html =~ "Extra Large"
    end

    test "deleting a variation removes it from the list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      {:ok, variation} =
        Catalog.create_variation(item, %{name: "To Delete", price_cents: 500, status: "active"})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/#{item.id}")

      assert html =~ "To Delete"

      view
      |> element("#delete-variation-#{variation.id}")
      |> render_click()

      html = render(view)
      assert html =~ "Variation removed"
      refute html =~ "To Delete"
    end

    test "shows back link to catalog", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/catalog/items/#{item.id}")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}/catalog\"]"
             )
    end
  end
end
