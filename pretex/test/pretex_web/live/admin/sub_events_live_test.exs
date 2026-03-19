defmodule PretexWeb.Admin.SubEventLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

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

  defp series_event_fixture(org, attrs \\ %{}) do
    event = event_fixture(org, attrs)
    {:ok, event} = Events.enable_series(event)
    event
  end

  defp sub_event_fixture(event, attrs \\ %{}) do
    base = %{
      name: "Sub Event #{System.unique_integer([:positive])}",
      starts_at: ~U[2030-06-01 10:00:00Z],
      ends_at: ~U[2030-06-01 12:00:00Z],
      venue: "Room A"
    }

    {:ok, sub_event} = Events.create_sub_event(event, Enum.into(attrs, base))
    sub_event
  end

  # ---------------------------------------------------------------------------
  # Index — list page
  # ---------------------------------------------------------------------------

  describe "Index - listing sub-events" do
    setup :register_and_log_in_user

    test "renders the sub-events page for a series event", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org, %{name: "Festival 2030"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert html =~ "Sub-Events"
      assert html =~ "Festival 2030"
    end

    test "shows a listed sub-event", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)
      sub_event = sub_event_fixture(event, %{name: "Morning Keynote"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert html =~ sub_event.name
    end

    test "shows empty state when no sub-events exist", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert html =~ "No sub-events yet"
    end

    test "shows series-disabled notice when event is not a series", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert html =~ "Series mode is not enabled"
    end

    test "shows Enable Series button when event is not a series", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert has_element?(view, "#enable-series")
    end

    test "shows Disable Series button when event is a series", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert has_element?(view, "#disable-series")
    end

    test "shows status badge for each sub-event", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)
      _sub_event = sub_event_fixture(event)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert html =~ "draft"
    end

    test "shows publish button for draft sub-events", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)
      sub_event = sub_event_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert has_element?(view, "#publish-#{sub_event.id}")
    end

    test "shows slug in monospace for sub-events", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)
      sub_event = sub_event_fixture(event, %{name: "Day One"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert html =~ sub_event.slug
    end

    test "back link navigates to the parent event", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}\"]"
             )
    end
  end

  # ---------------------------------------------------------------------------
  # Enable / disable series
  # ---------------------------------------------------------------------------

  describe "enable_series" do
    setup :register_and_log_in_user

    test "clicking Enable Series marks the event as a series and shows the list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert has_element?(view, "#enable-series")

      view
      |> element("#enable-series")
      |> render_click()

      html = render(view)
      assert html =~ "Series mode enabled"
      assert has_element?(view, "#disable-series")
      refute has_element?(view, "#enable-series")
    end
  end

  describe "disable_series" do
    setup :register_and_log_in_user

    test "clicking Disable Series unmarks the event as a series", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert has_element?(view, "#disable-series")

      view
      |> element("#disable-series")
      |> render_click()

      html = render(view)
      assert html =~ "Series mode disabled"
      assert has_element?(view, "#enable-series")
      refute has_element?(view, "#disable-series")
    end
  end

  # ---------------------------------------------------------------------------
  # New sub-event (modal)
  # ---------------------------------------------------------------------------

  describe "New sub-event" do
    setup :register_and_log_in_user

    test "navigating to /new opens the modal", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events/new")

      assert has_element?(view, "#sub-event-modal")
      assert render(view) =~ "New Sub-Event"
    end

    test "shows validation errors on blank name", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events/new")

      view
      |> form("#sub-event-form", sub_event: %{name: ""})
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "shows validation errors when name is too short", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events/new")

      view
      |> form("#sub-event-form", sub_event: %{name: "X"})
      |> render_change()

      assert render(view) =~ "should be at least 2 character"
    end

    test "creates sub-event and closes modal on valid submit", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events/new")

      view
      |> form("#sub-event-form",
        sub_event: %{
          name: "Brand New Session",
          starts_at: "2030-06-01T10:00",
          ends_at: "2030-06-01T12:00"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Sub-event created successfully"
      assert html =~ "Brand New Session"
      refute has_element?(view, "#sub-event-modal")
    end

    test "clicking cancel closes the modal", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events/new")

      assert has_element?(view, "#sub-event-modal")

      view
      |> element("button[phx-click=\"cancel\"].btn-ghost.btn-sm:not(.btn-circle)")
      |> render_click()

      refute has_element?(view, "#sub-event-modal")
    end
  end

  # ---------------------------------------------------------------------------
  # Edit sub-event (modal)
  # ---------------------------------------------------------------------------

  describe "Edit sub-event" do
    setup :register_and_log_in_user

    test "navigating to /edit opens the modal pre-filled", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)
      sub_event = sub_event_fixture(event, %{name: "Editable Session"})

      {:ok, view, html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/sub-events/#{sub_event.id}/edit"
        )

      assert has_element?(view, "#sub-event-modal")
      assert html =~ "Edit Sub-Event"
      assert html =~ "Editable Session"
    end

    test "saves changes and updates the stream", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)
      sub_event = sub_event_fixture(event, %{name: "Old Name"})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/sub-events/#{sub_event.id}/edit"
        )

      view
      |> form("#sub-event-form", sub_event: %{name: "Updated Session Name"})
      |> render_submit()

      html = render(view)
      assert html =~ "Sub-event updated successfully"
      assert html =~ "Updated Session Name"
      refute has_element?(view, "#sub-event-modal")
    end

    test "shows validation errors on invalid update", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)
      sub_event = sub_event_fixture(event)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/sub-events/#{sub_event.id}/edit"
        )

      view
      |> form("#sub-event-form", sub_event: %{name: ""})
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end
  end

  # ---------------------------------------------------------------------------
  # Delete sub-event
  # ---------------------------------------------------------------------------

  describe "delete sub-event" do
    setup :register_and_log_in_user

    test "removes the sub-event from the stream", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)
      sub_event = sub_event_fixture(event, %{name: "To Be Deleted"})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      assert html =~ sub_event.name

      view
      |> element("#delete-#{sub_event.id}")
      |> render_click()

      html = render(view)
      assert html =~ "Sub-event deleted"
      refute html =~ sub_event.name
    end
  end

  # ---------------------------------------------------------------------------
  # Publish sub-event
  # ---------------------------------------------------------------------------

  describe "publish sub-event" do
    setup :register_and_log_in_user

    test "publishes a draft sub-event and updates its badge", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)
      sub_event = sub_event_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      view
      |> element("#publish-#{sub_event.id}")
      |> render_click()

      html = render(view)
      assert html =~ "Sub-event published"
      assert html =~ "published"
    end
  end

  # ---------------------------------------------------------------------------
  # Hide sub-event
  # ---------------------------------------------------------------------------

  describe "hide sub-event" do
    setup :register_and_log_in_user

    test "hides a draft sub-event and updates its badge", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)
      sub_event = sub_event_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      view
      |> element("#hide-#{sub_event.id}")
      |> render_click()

      html = render(view)
      assert html =~ "Sub-event hidden"
      assert html =~ "hidden"
    end

    test "hides a published sub-event", %{conn: conn} do
      org = org_fixture()
      event = series_event_fixture(org)
      sub_event = sub_event_fixture(event)
      {:ok, published} = Events.publish_sub_event(sub_event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/sub-events")

      view
      |> element("#hide-#{published.id}")
      |> render_click()

      assert render(view) =~ "Sub-event hidden"
    end
  end
end
