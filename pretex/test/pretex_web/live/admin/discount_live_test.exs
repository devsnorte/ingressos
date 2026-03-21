defmodule PretexWeb.Admin.DiscountLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Events
  alias Pretex.Organizations
  alias Pretex.Discounts

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

  defp discount_rule_fixture(event, attrs) do
    base = %{
      name: "Regra Teste #{System.unique_integer([:positive])}",
      condition_type: "min_quantity",
      min_quantity: 2,
      value_type: "percentage",
      value: 1000,
      active: true
    }

    {:ok, rule} = Discounts.create_discount_rule(event, Enum.into(attrs, base))
    rule
  end

  # ---------------------------------------------------------------------------
  # Index — listing discount rules
  # ---------------------------------------------------------------------------

  describe "Index - listing discount rules" do
    setup :register_and_log_in_user

    test "renders the discounts page for an event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Rock Festival"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      assert html =~ "Descontos Automáticos"
      assert html =~ "Rock Festival"
    end

    test "shows empty state when no discount rules exist", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      assert html =~ "Nenhuma regra de desconto cadastrada"
    end

    test "lists discount rules for the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event, %{name: "Desconto de Grupo"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      assert html =~ rule.name
    end

    test "does not show rules from other events", %{conn: conn} do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      _rule = discount_rule_fixture(event1, %{name: "Regra do Evento 1 Exclusiva"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event2}/discounts")

      refute html =~ "Regra do Evento 1 Exclusiva"
    end

    test "shows active badge for an active rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      discount_rule_fixture(event, %{active: true})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      assert html =~ "Ativo"
    end

    test "shows inactive badge for an inactive rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      discount_rule_fixture(event, %{active: false})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      assert html =~ "Inativo"
    end

    test "shows percentage condition label", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      discount_rule_fixture(event, %{condition_type: "min_quantity", min_quantity: 3})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      assert html =~ "3"
    end

    test "shows fixed discount effect value", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      discount_rule_fixture(event, %{
        name: "Desconto Fixo",
        value_type: "fixed",
        value: 1000
      })

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      assert html =~ "10,00"
    end

    test "shows percentage discount effect value", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      discount_rule_fixture(event, %{
        name: "Desconto Percentual",
        value_type: "percentage",
        value: 500
      })

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      assert html =~ "5,00%"
    end
  end

  # ---------------------------------------------------------------------------
  # New — create discount rule form
  # ---------------------------------------------------------------------------

  describe "New - create discount rule" do
    setup :register_and_log_in_user

    test "renders the new form", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts/new")

      assert html =~ "Nova Regra de Desconto"
      assert html =~ "Nome"
      assert html =~ "Tipo de Condição"
    end

    test "creates a min_quantity percentage discount rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts/new")

      html =
        view
        |> form("#discount-rule-form", %{
          discount_rule: %{
            name: "Desconto Grupo 3+",
            condition_type: "min_quantity",
            min_quantity: 3,
            value_type: "percentage",
            value: 1000,
            active: true
          }
        })
        |> render_submit()

      assert html =~ "Desconto Grupo 3+"
    end

    test "creates a fixed discount rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts/new")

      html =
        view
        |> form("#discount-rule-form", %{
          discount_rule: %{
            name: "Desconto R$10",
            condition_type: "min_quantity",
            min_quantity: 1,
            value_type: "fixed",
            value: 1000,
            active: true
          }
        })
        |> render_submit()

      assert html =~ "Desconto R$10"
    end

    test "shows validation error for negative value", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts/new")

      html =
        view
        |> form("#discount-rule-form", %{
          discount_rule: %{
            name: "Inválido",
            condition_type: "min_quantity",
            value_type: "fixed",
            value: -100
          }
        })
        |> render_submit()

      assert html =~ "must be greater than or equal to"
    end

    test "shows validation error for percentage above 10000", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts/new")

      html =
        view
        |> form("#discount-rule-form", %{
          discount_rule: %{
            name: "Percentual Inválido",
            condition_type: "min_quantity",
            value_type: "percentage",
            value: 10_001
          }
        })
        |> render_submit()

      assert html =~ "não pode exceder 100%"
    end

    test "shows validation error when name is too short", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts/new")

      html =
        view
        |> form("#discount-rule-form", %{
          discount_rule: %{
            name: "X",
            condition_type: "min_quantity",
            value_type: "fixed",
            value: 100
          }
        })
        |> render_submit()

      assert html =~ "should be at least"
    end

    test "validate event keeps form open and shows changes", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts/new")

      html =
        view
        |> form("#discount-rule-form", %{
          discount_rule: %{
            name: "Teste Validação",
            condition_type: "min_quantity",
            value_type: "percentage",
            value: 500
          }
        })
        |> render_change()

      assert html =~ "Teste Validação"
    end

    test "close_modal navigates back to index", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts/new")

      view
      |> element("button[phx-click='close_modal']", "Cancelar")
      |> render_click()

      assert_patch(view, ~p"/admin/organizations/#{org}/events/#{event}/discounts")
    end
  end

  # ---------------------------------------------------------------------------
  # Edit — update discount rule
  # ---------------------------------------------------------------------------

  describe "Edit - update discount rule" do
    setup :register_and_log_in_user

    test "renders the edit form with existing values", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event, %{name: "Regra Original", value: 1500})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts/#{rule.id}/edit")

      assert html =~ "Editar Regra de Desconto"
      assert html =~ "Regra Original"
    end

    test "editing a rule updates it", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event, %{name: "Antes da Edição", value: 500})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts/#{rule.id}/edit")

      html =
        view
        |> form("#discount-rule-form", %{
          discount_rule: %{
            name: "Depois da Edição",
            condition_type: "min_quantity",
            min_quantity: 2,
            value_type: "percentage",
            value: 2000
          }
        })
        |> render_submit()

      assert html =~ "Depois da Edição"
      refute html =~ "Antes da Edição"
    end

    test "editing a rule shows flash success message", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event, %{name: "Regra Para Editar"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts/#{rule.id}/edit")

      view
      |> form("#discount-rule-form", %{
        discount_rule: %{
          name: "Regra Editada",
          condition_type: "min_quantity",
          min_quantity: 1,
          value_type: "fixed",
          value: 500
        }
      })
      |> render_submit()

      assert_patch(view, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      html = render(view)
      assert html =~ "atualizada com sucesso"
    end
  end

  # ---------------------------------------------------------------------------
  # Delete — remove discount rule
  # ---------------------------------------------------------------------------

  describe "Delete - remove discount rule" do
    setup :register_and_log_in_user

    test "deleting a rule removes it from the list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event, %{name: "Regra Para Excluir"})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      assert html =~ rule.name

      view
      |> element("[phx-click='delete'][phx-value-id='#{rule.id}']")
      |> render_click()

      html = render(view)
      refute html =~ rule.name
    end

    test "shows flash success after deletion", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event, %{name: "Excluível"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      view
      |> element("[phx-click='delete'][phx-value-id='#{rule.id}']")
      |> render_click()

      assert render(view) =~ "removida com sucesso"
    end
  end

  # ---------------------------------------------------------------------------
  # Toggle active
  # ---------------------------------------------------------------------------

  describe "Toggle active" do
    setup :register_and_log_in_user

    test "toggling active on an active rule makes it inactive", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event, %{active: true})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      assert html =~ "Ativo"

      view
      |> element("[phx-click='toggle_active'][phx-value-id='#{rule.id}']")
      |> render_click()

      assert render(view) =~ "Inativo"
    end

    test "toggling active on an inactive rule makes it active", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event, %{active: false})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/discounts")

      assert html =~ "Inativo"

      view
      |> element("[phx-click='toggle_active'][phx-value-id='#{rule.id}']")
      |> render_click()

      assert render(view) =~ "Ativo"
    end
  end
end
