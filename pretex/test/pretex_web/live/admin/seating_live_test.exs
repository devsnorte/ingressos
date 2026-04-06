defmodule PretexWeb.Admin.SeatingLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Events
  alias Pretex.Organizations
  alias Pretex.Seating

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

  defp event_fixture(org, attrs) do
    base = %{
      name: "Test Event #{System.unique_integer([:positive])}",
      starts_at: ~U[2030-06-01 10:00:00Z],
      ends_at: ~U[2030-06-01 18:00:00Z],
      venue: "Main Stage"
    }

    {:ok, event} = Events.create_event(org, Enum.into(attrs, base))
    event
  end

  defp seating_plan_fixture(org_id, attrs \\ %{}) do
    layout = %{
      "sections" => [
        %{
          "name" => "Pista",
          "rows" => [%{"label" => "A", "seats" => 3}]
        }
      ]
    }

    attrs =
      Enum.into(attrs, %{
        name: "Test Plan #{System.unique_integer([:positive])}",
        layout: layout
      })

    {:ok, plan} = Seating.create_seating_plan(org_id, attrs)
    plan
  end

  # ---------------------------------------------------------------------------
  # Index — list plans
  # ---------------------------------------------------------------------------

  describe "Index — list plans" do
    setup :register_and_log_in_user

    test "renders the seating index page", %{conn: conn} do
      org = org_fixture()

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/seating")

      assert html =~ "Plantas de Assentos"
      assert html =~ org.name
    end

    test "shows empty state when no plans exist", %{conn: conn} do
      org = org_fixture()

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/seating")

      assert html =~ "Nenhuma planta ainda."
    end

    test "lists existing seating plans", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id, %{name: "Teatro Principal"})

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/seating")

      assert html =~ plan.name
    end

    test "shows link to create new plan", %{conn: conn} do
      org = org_fixture()

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/seating")

      assert html =~ "Nova Planta"
    end
  end

  # ---------------------------------------------------------------------------
  # Index — new plan upload
  # ---------------------------------------------------------------------------

  describe "Index — new plan form" do
    setup :register_and_log_in_user

    test "renders the upload form when navigating to :new", %{conn: conn} do
      org = org_fixture()

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/seating/new")

      assert html =~ "Carregar Nova Planta"
      assert html =~ "Nome da planta"
    end

    test "shows validation error for missing plan name", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/seating/new")

      html =
        view
        |> form("form", %{"seating_plan" => %{"name" => ""}})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "shows error when no file is uploaded", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/seating/new")

      html =
        view
        |> form("form", %{"seating_plan" => %{"name" => "My Plan"}})
        |> render_submit()

      assert html =~ "Selecione um arquivo JSON"
    end

    test "cancel navigates back to index", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/seating/new")

      view |> element("button", "Cancelar") |> render_click()

      assert_patch(view, ~p"/admin/organizations/#{org}/seating")
    end

    test "deletes a plan from the list", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id, %{name: "Planta Removível"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/seating")

      assert render(view) =~ plan.name

      view
      |> element("button[phx-click='delete'][phx-value-id='#{plan.id}']")
      |> render_click()

      refute render(view) =~ plan.name
    end
  end

  # ---------------------------------------------------------------------------
  # Show — plan details
  # ---------------------------------------------------------------------------

  describe "Show — plan details" do
    setup :register_and_log_in_user

    test "renders plan details with sections and seats", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id, %{name: "Teatro Central"})

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/seating/#{plan}")

      assert html =~ "Teatro Central"
      assert html =~ "Pista"
      # Seats like A-1
      assert html =~ "A-1"
      assert html =~ "A-3"
    end

    test "shows section capacity and row count", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id)

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/seating/#{plan}")

      assert html =~ "3 assentos"
    end

    test "shows back navigation link", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id)

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/seating/#{plan}")

      assert html =~ "Voltar às Plantas"
    end

    test "shows assign to event button", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id)

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/seating/#{plan}")

      assert html =~ "Atribuir a Evento"
    end

    test "shows map section button for each section", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id)

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/seating/#{plan}")

      assert html =~ "Mapear"
    end

    test "clicking map section opens inline mapping form", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id)
      section = hd(plan.sections)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/seating/#{plan}")

      html =
        view
        |> element("button[phx-click='map_section'][phx-value-section_id='#{section.id}']")
        |> render_click()

      assert html =~ "Mapear seção a um tipo de ingresso"
    end

    test "cancel mapping hides the inline form", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id)
      section = hd(plan.sections)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/seating/#{plan}")

      view
      |> element("button[phx-click='map_section'][phx-value-section_id='#{section.id}']")
      |> render_click()

      html = view |> element("button", "Cancelar") |> render_click()

      refute html =~ "Mapear seção a um tipo de ingresso"
    end

    test "clicking assign to event shows event selection form", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id)
      _event = event_fixture(org, %{name: "Meu Evento"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/seating/#{plan}")

      html =
        view
        |> element("button[phx-click='show_assign_event']")
        |> render_click()

      assert html =~ "Atribuir Planta a Evento"
      assert html =~ "Meu Evento"
    end

    test "assigning to an event with no selection shows flash error", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/seating/#{plan}")

      view |> element("button[phx-click='show_assign_event']") |> render_click()

      html =
        view
        |> form("form", %{"assignment" => %{"event_id" => ""}})
        |> render_submit()

      assert html =~ "Selecione um evento"
    end

    test "successfully assigns plan to an event", %{conn: conn} do
      org = org_fixture()
      plan = seating_plan_fixture(org.id)
      event = event_fixture(org, %{name: "Festival de Verão"})

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/seating/#{plan}")

      view |> element("button[phx-click='show_assign_event']") |> render_click()

      view
      |> form("form", %{"assignment" => %{"event_id" => to_string(event.id)}})
      |> render_submit()

      html = render(view)
      assert html =~ "Planta atribuída ao evento"

      updated_event = Events.get_event!(event.id)
      assert updated_event.seating_plan_id == plan.id
    end
  end
end
