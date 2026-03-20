defmodule PretexWeb.Admin.EventLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.Events

  defp catalog_item_fixture(event) do
    item_fixture(event, %{name: "Ingresso Geral", price_cents: 5000})
  end

  # ---------------------------------------------------------------------------
  # Index
  # ---------------------------------------------------------------------------

  describe "Index" do
    setup :register_and_log_in_user

    test "lists events for the organization", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/events")
      assert html =~ event.name
    end

    test "shows empty state when no events exist", %{conn: conn} do
      org = org_fixture()

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/events")
      assert html =~ "Nenhum evento ainda."
    end

    test "shows draft status badge", %{conn: conn} do
      org = org_fixture()
      _event = event_fixture(org)

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/events")
      assert html =~ "Rascunho"
    end

    test "publish button shows no-catalog-items error flash when none configured", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/events")

      view
      |> element("#publish-#{event.id}")
      |> render_click()

      assert render(view) =~ "pelo menos um item no catálogo"
    end

    test "publish button succeeds when catalog items are configured", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      catalog_item_fixture(event)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/events")

      view
      |> element("#publish-#{event.id}")
      |> render_click()

      assert render(view) =~ "Publicado"
    end

    test "delete removes the event from the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, html} = live(conn, ~p"/admin/organizations/#{org}/events")
      assert html =~ event.name

      view
      |> element("#delete-#{event.id}")
      |> render_click()

      refute render(view) =~ event.name
    end

    test "clone creates a new event in the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Original Event"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/events")

      view
      |> element("#clone-#{event.id}")
      |> render_click()

      assert render(view) =~ "Original Event (copy)"
    end
  end

  # ---------------------------------------------------------------------------
  # New
  # ---------------------------------------------------------------------------

  describe "New" do
    setup :register_and_log_in_user

    test "renders the new event form", %{conn: conn} do
      org = org_fixture()

      {:ok, view, html} = live(conn, ~p"/admin/organizations/#{org}/events/new")
      assert html =~ "Novo Evento"
      assert has_element?(view, "#event-form")
    end

    test "shows validation errors on blank name", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/events/new")

      view
      |> form("#event-form", event: %{name: ""})
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "saves new event and redirects to index", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/events/new")

      view
      |> form("#event-form",
        event: %{
          name: "Brand New Event",
          starts_at: "2030-08-01T10:00",
          ends_at: "2030-08-01T18:00"
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/admin/organizations/#{org}/events")
    end
  end

  # ---------------------------------------------------------------------------
  # Edit
  # ---------------------------------------------------------------------------

  describe "Edit" do
    setup :register_and_log_in_user

    test "renders form pre-filled with event data", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Editable Event"})

      {:ok, view, html} = live(conn, ~p"/admin/organizations/#{org}/events/#{event}/edit")
      assert html =~ "Editable Event"
      assert has_element?(view, "#event-form")
    end

    test "saves changes and redirects to show", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/events/#{event}/edit")

      view
      |> form("#event-form", event: %{name: "Updated Event Name"})
      |> render_submit()

      assert_redirect(view, ~p"/admin/organizations/#{org}/events/#{event}")
    end
  end

  # ---------------------------------------------------------------------------
  # Show
  # ---------------------------------------------------------------------------

  describe "Show" do
    setup :register_and_log_in_user

    test "displays event details", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Showcase Event", venue: "Grand Hall"})

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/events/#{event}")
      assert html =~ "Showcase Event"
      assert html =~ "Grand Hall"
    end

    test "shows publish button for draft event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/events/#{event}")
      assert has_element?(view, "#publish-event")
    end

    test "shows complete button for published event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      catalog_item_fixture(event)

      {:ok, published} = Events.publish_event(event)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/events/#{published}")
      assert has_element?(view, "#complete-event")
    end

    test "shows no-catalog-items notice when count is zero", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/events/#{event}")
      assert html =~ "Adicione pelo menos um tipo de ingresso"
    end

    test "shows ticket count when catalog items exist", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      catalog_item_fixture(event)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/events/#{event}")
      assert has_element?(view, "#ticket-count")
    end

    test "shows edit button", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/events/#{event}")
      assert has_element?(view, "a[href$=\"/edit\"]")
    end

    test "clone navigates to the cloned event page", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Source Event"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/events/#{event}")

      view
      |> element("#clone-event")
      |> render_click()

      {path, _flash} = assert_redirect(view)
      assert String.starts_with?(path, "/admin/organizations/#{org.id}/events/")
    end
  end
end
