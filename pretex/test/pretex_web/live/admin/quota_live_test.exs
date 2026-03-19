defmodule PretexWeb.Admin.QuotaLiveTest do
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

  defp quota_fixture(event, attrs \\ %{}) do
    base = %{
      name: "General Quota #{System.unique_integer([:positive])}",
      capacity: 100
    }

    {:ok, quota} = Catalog.create_quota(event, Enum.into(attrs, base))
    quota
  end

  # ---------------------------------------------------------------------------
  # Index — listing quotas
  # ---------------------------------------------------------------------------

  describe "Index - listing quotas" do
    setup :register_and_log_in_user

    test "renders the quotas page for an event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Summer Festival"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert html =~ "Quotas"
      assert html =~ "Summer Festival"
    end

    test "shows empty state when no quotas exist", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert html =~ "No quotas yet"
    end

    test "lists quotas for the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "VIP Section", capacity: 50})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert html =~ quota.name
    end

    test "does not show quotas from other events", %{conn: conn} do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      quota = quota_fixture(event1, %{name: "Other Event Quota"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event2}/quotas")

      refute html =~ quota.name
    end

    test "shows capacity for each quota", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _quota = quota_fixture(event, %{name: "Weekend Pass", capacity: 250})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert html =~ "250"
    end

    test "shows sold count for each quota", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _quota = quota_fixture(event, %{name: "Day Pass", capacity: 100})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert html =~ "Sold"
    end

    test "shows available quantity for each quota", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _quota = quota_fixture(event, %{name: "Night Pass", capacity: 80})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert html =~ "Available"
    end

    test "shows assigned item count for each quota", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "Multi-item Quota"})
      item = item_fixture(event)
      {:ok, _} = Catalog.assign_item_to_quota(quota, item)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert html =~ "Items assigned"
    end

    test "shows New Quota button", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert has_element?(view, "a", "New Quota")
    end

    test "shows back link to the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}\"]"
             )
    end

    test "shows a progress bar for each quota", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _quota = quota_fixture(event, %{name: "Progress Quota", capacity: 100})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert html =~ "progress"
    end

    test "shows delete button for each quota", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "Deletable Quota"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert has_element?(view, "#delete-#{quota.id}")
    end

    test "shows edit link for each quota", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "Editable Quota"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}/quotas/#{quota.id}/edit\"]"
             )
    end
  end

  # ---------------------------------------------------------------------------
  # New quota via modal
  # ---------------------------------------------------------------------------

  describe "New quota modal" do
    setup :register_and_log_in_user

    test "navigating to /quotas/new opens the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/new")

      assert has_element?(view, "#quota-modal")
      assert render(view) =~ "New Quota"
    end

    test "shows the quota form inside the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/new")

      assert has_element?(view, "#quota-form")
    end

    test "shows validation error when name is blank", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/new")

      view
      |> form("#quota-form", quota: %{name: ""})
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "shows validation error when name is too short", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/new")

      view
      |> form("#quota-form", quota: %{name: "X"})
      |> render_change()

      assert render(view) =~ "should be at least 2 character"
    end

    test "shows validation error when capacity is zero", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/new")

      view
      |> form("#quota-form", quota: %{name: "Bad Quota", capacity: 0})
      |> render_change()

      assert render(view) =~ "must be greater than 0"
    end

    test "creates quota and closes modal on valid submit", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/new")

      view
      |> form("#quota-form", quota: %{name: "General Admission", capacity: 500})
      |> render_submit()

      html = render(view)
      assert html =~ "Quota created successfully"
      assert html =~ "General Admission"
      refute has_element?(view, "#quota-modal")
    end

    test "clicking Cancel closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/new")

      assert has_element?(view, "#quota-modal")

      view
      |> element("button[phx-click=\"close_modal\"].btn-ghost.btn-sm:not(.btn-circle)")
      |> render_click()

      refute has_element?(view, "#quota-modal")
    end

    test "clicking X button closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/new")

      assert has_element?(view, "#quota-modal")

      view
      |> element("button[phx-click=\"close_modal\"].btn-circle")
      |> render_click()

      refute has_element?(view, "#quota-modal")
    end

    test "newly created quota appears in the stream after save", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/new")

      view
      |> form("#quota-form", quota: %{name: "Brand New Quota", capacity: 1000})
      |> render_submit()

      assert render(view) =~ "Brand New Quota"
    end
  end

  # ---------------------------------------------------------------------------
  # Edit quota via modal
  # ---------------------------------------------------------------------------

  describe "Edit quota modal" do
    setup :register_and_log_in_user

    test "navigating to /quotas/:id/edit opens modal pre-filled", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "Editable Quota", capacity: 75})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/#{quota.id}/edit")

      assert has_element?(view, "#quota-modal")
      assert html =~ "Edit Quota"
      assert html =~ "Editable Quota"
    end

    test "shows the quota form pre-filled with current values", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "Pre-filled Quota", capacity: 200})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/#{quota.id}/edit")

      assert html =~ "Pre-filled Quota"
    end

    test "saves changes and updates the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "Old Quota Name", capacity: 50})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/#{quota.id}/edit")

      view
      |> form("#quota-form", quota: %{name: "Updated Quota Name", capacity: 150})
      |> render_submit()

      html = render(view)
      assert html =~ "Quota updated successfully"
      assert html =~ "Updated Quota Name"
      refute has_element?(view, "#quota-modal")
    end

    test "shows validation errors on invalid update", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/#{quota.id}/edit")

      view
      |> form("#quota-form", quota: %{name: ""})
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "shows validation error when updating capacity to zero", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/#{quota.id}/edit")

      view
      |> form("#quota-form", quota: %{capacity: 0})
      |> render_change()

      assert render(view) =~ "must be greater than 0"
    end

    test "cancelling edit closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas/#{quota.id}/edit")

      assert has_element?(view, "#quota-modal")

      view
      |> element("button[phx-click=\"close_modal\"].btn-ghost.btn-sm:not(.btn-circle)")
      |> render_click()

      refute has_element?(view, "#quota-modal")
    end
  end

  # ---------------------------------------------------------------------------
  # Delete quota
  # ---------------------------------------------------------------------------

  describe "Delete quota" do
    setup :register_and_log_in_user

    test "removes the quota from the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "To Be Deleted", capacity: 100})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      assert html =~ quota.name

      view
      |> element("#delete-#{quota.id}")
      |> render_click()

      html = render(view)
      assert html =~ "Quota deleted"
      refute html =~ quota.name
    end

    test "shows empty state after deleting the only quota", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "Only Quota", capacity: 50})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      view
      |> element("#delete-#{quota.id}")
      |> render_click()

      assert render(view) =~ "No quotas yet"
    end

    test "can delete a quota that has items assigned", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "Quota With Items", capacity: 100})
      item = item_fixture(event)
      {:ok, _} = Catalog.assign_item_to_quota(quota, item)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/quotas")

      view
      |> element("#delete-#{quota.id}")
      |> render_click()

      assert render(view) =~ "Quota deleted"
    end
  end
end
