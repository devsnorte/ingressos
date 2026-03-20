defmodule PretexWeb.Admin.FeeLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Events
  alias Pretex.Fees
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

  defp fee_rule_fixture(event, attrs \\ %{}) do
    base = %{
      name: "Taxa de Serviço #{System.unique_integer([:positive])}",
      fee_type: "service",
      value_type: "fixed",
      value: 200,
      apply_mode: "automatic",
      active: true
    }

    {:ok, rule} = Fees.create_fee_rule(event, Enum.into(attrs, base))
    rule
  end

  # ---------------------------------------------------------------------------
  # Index — listing fee rules
  # ---------------------------------------------------------------------------

  describe "Index - listing fee rules" do
    setup :register_and_log_in_user

    test "renders the fees page for an event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Summer Festival"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert html =~ "Taxas e Cobranças"
      assert html =~ "Summer Festival"
    end

    test "shows empty state when no fee rules exist", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert html =~ "Nenhuma taxa configurada"
    end

    test "lists fee rules for the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{name: "Taxa de Envio"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert html =~ rule.name
    end

    test "does not show fee rules from other events", %{conn: conn} do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      rule = fee_rule_fixture(event1, %{name: "Taxa Exclusiva Evento 1"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event2}/fees")

      refute html =~ rule.name
    end

    test "shows value formatted for fixed fee rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _rule = fee_rule_fixture(event, %{value_type: "fixed", value: 250})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert html =~ "R$"
      assert html =~ "2,50"
    end

    test "shows value formatted for percentage fee rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _rule = fee_rule_fixture(event, %{value_type: "percentage", value: 500})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert html =~ "5,00%"
    end

    test "shows apply mode badge", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      fee_rule_fixture(event, %{apply_mode: "automatic"})
      fee_rule_fixture(event, %{apply_mode: "manual"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert html =~ "Automática"
      assert html =~ "Manual"
    end

    test "shows active badge for active fee rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _rule = fee_rule_fixture(event, %{active: true})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert html =~ "Ativo"
    end

    test "shows inactive badge for inactive fee rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _rule = fee_rule_fixture(event, %{active: false})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert html =~ "Inativo"
    end

    test "shows Nova Taxa button", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert has_element?(view, "a", "Nova Taxa")
    end

    test "shows back link to the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}\"]"
             )
    end

    test "shows delete button for each fee rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert has_element?(view, "#delete-#{rule.id}")
    end

    test "shows edit link for each fee rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}/fees/#{rule.id}/edit\"]"
             )
    end

    test "shows toggle active button for each fee rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert has_element?(view, "#toggle-#{rule.id}")
    end
  end

  # ---------------------------------------------------------------------------
  # New fee rule via modal
  # ---------------------------------------------------------------------------

  describe "New fee rule modal" do
    setup :register_and_log_in_user

    test "navigating to /fees/new opens the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

      assert has_element?(view, "#fee-modal")
      assert render(view) =~ "Nova Taxa"
    end

    test "shows the fee rule form inside the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

      assert has_element?(view, "#fee-rule-form")
    end

    test "creates a fixed fee rule and shows it in the list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

      view
      |> form("#fee-rule-form",
        fee_rule: %{
          name: "Taxa de Serviço",
          fee_type: "service",
          value_type: "fixed",
          value: 300,
          apply_mode: "automatic"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Taxa criada com sucesso"
      assert html =~ "Taxa de Serviço"
      refute has_element?(view, "#fee-modal")
    end

    test "creates a percentage fee rule and shows it in the list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

      view
      |> form("#fee-rule-form",
        fee_rule: %{
          name: "Taxa Percentual 5%",
          fee_type: "handling",
          value_type: "percentage",
          value: 500,
          apply_mode: "automatic"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Taxa criada com sucesso"
      assert html =~ "Taxa Percentual 5%"
      refute has_element?(view, "#fee-modal")
    end

    test "shows validation error when name is blank", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

      view
      |> form("#fee-rule-form",
        fee_rule: %{
          name: "",
          fee_type: "service",
          value_type: "fixed",
          value: 100,
          apply_mode: "automatic"
        }
      )
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "shows validation error for negative value", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

      view
      |> form("#fee-rule-form",
        fee_rule: %{
          name: "Taxa Negativa",
          fee_type: "service",
          value_type: "fixed",
          value: -100,
          apply_mode: "automatic"
        }
      )
      |> render_change()

      assert render(view) =~ "must be zero or positive"
    end

    test "shows validation error when percentage exceeds 10000 basis points", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

      view
      |> form("#fee-rule-form",
        fee_rule: %{
          name: "Taxa Impossível",
          fee_type: "service",
          value_type: "percentage",
          value: 10001,
          apply_mode: "automatic"
        }
      )
      |> render_change()

      assert render(view) =~ "percentage cannot exceed 100%"
    end

    test "clicking Cancel closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

      assert has_element?(view, "#fee-modal")

      view
      |> element("button[phx-click=\"close_modal\"].btn-ghost.btn-sm:not(.btn-circle)")
      |> render_click()

      refute has_element?(view, "#fee-modal")
    end

    test "clicking X button closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

      assert has_element?(view, "#fee-modal")

      view
      |> element("button[phx-click=\"close_modal\"].btn-circle")
      |> render_click()

      refute has_element?(view, "#fee-modal")
    end

    test "newly created fee rule appears in the stream after save", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

      view
      |> form("#fee-rule-form",
        fee_rule: %{
          name: "Nova Taxa Incrível",
          fee_type: "custom",
          value_type: "fixed",
          value: 999,
          apply_mode: "manual"
        }
      )
      |> render_submit()

      assert render(view) =~ "Nova Taxa Incrível"
    end

    test "creates a fee rule with manual apply mode", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

      view
      |> form("#fee-rule-form",
        fee_rule: %{
          name: "Taxa Manual de Cancelamento",
          fee_type: "cancellation",
          value_type: "fixed",
          value: 1500,
          apply_mode: "manual"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Taxa criada com sucesso"
      assert html =~ "Taxa Manual de Cancelamento"
    end

    test "creates a fee rule with all supported fee types", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      for {fee_type, label} <- [
            {"service", "Taxa de Serviço"},
            {"handling", "Taxa de Manuseio"},
            {"shipping", "Taxa de Envio"},
            {"cancellation", "Taxa de Cancelamento"},
            {"custom", "Personalizada"}
          ] do
        {:ok, view, _html} =
          live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/new")

        rule_name = "Taxa #{fee_type} #{System.unique_integer([:positive])}"

        view
        |> form("#fee-rule-form",
          fee_rule: %{
            name: rule_name,
            fee_type: fee_type,
            value_type: "fixed",
            value: 100,
            apply_mode: "automatic"
          }
        )
        |> render_submit()

        html = render(view)
        assert html =~ "Taxa criada com sucesso"
        assert html =~ rule_name
        # Check the fee type label appears in the list
        assert html =~ label
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edit fee rule via modal
  # ---------------------------------------------------------------------------

  describe "Edit fee rule modal" do
    setup :register_and_log_in_user

    test "navigating to /fees/:id/edit opens modal pre-filled", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{name: "Taxa Editável", value: 500})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/#{rule.id}/edit")

      assert has_element?(view, "#fee-modal")
      assert html =~ "Editar Taxa"
      assert html =~ "Taxa Editável"
    end

    test "shows the fee rule form pre-filled with current values", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{name: "Taxa Pré-Preenchida", value: 750})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/#{rule.id}/edit")

      assert html =~ "Taxa Pré-Preenchida"
    end

    test "saves changes and updates the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{name: "Nome Antigo", value: 100})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/#{rule.id}/edit")

      view
      |> form("#fee-rule-form",
        fee_rule: %{
          name: "Nome Atualizado",
          value: 999
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Taxa atualizada com sucesso"
      assert html =~ "Nome Atualizado"
      refute has_element?(view, "#fee-modal")
    end

    test "shows validation errors on invalid update", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/#{rule.id}/edit")

      view
      |> form("#fee-rule-form", fee_rule: %{name: ""})
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "shows validation error on negative value update", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/#{rule.id}/edit")

      view
      |> form("#fee-rule-form", fee_rule: %{value: -1})
      |> render_change()

      assert render(view) =~ "must be zero or positive"
    end

    test "cancelling edit closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees/#{rule.id}/edit")

      assert has_element?(view, "#fee-modal")

      view
      |> element("button[phx-click=\"close_modal\"].btn-ghost.btn-sm:not(.btn-circle)")
      |> render_click()

      refute has_element?(view, "#fee-modal")
    end
  end

  # ---------------------------------------------------------------------------
  # Delete fee rule
  # ---------------------------------------------------------------------------

  describe "Delete fee rule" do
    setup :register_and_log_in_user

    test "removes the fee rule from the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{name: "Taxa a Ser Excluída"})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert html =~ rule.name

      view
      |> element("#delete-#{rule.id}")
      |> render_click()

      html = render(view)
      assert html =~ "Taxa removida com sucesso"
      refute html =~ rule.name
    end

    test "shows empty state after deleting the only fee rule", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{name: "Única Taxa"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      view
      |> element("#delete-#{rule.id}")
      |> render_click()

      assert render(view) =~ "Nenhuma taxa configurada"
    end

    test "only removes the targeted fee rule, leaving others intact", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule1 = fee_rule_fixture(event, %{name: "Taxa Para Excluir"})
      rule2 = fee_rule_fixture(event, %{name: "Taxa Para Manter"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      view
      |> element("#delete-#{rule1.id}")
      |> render_click()

      html = render(view)
      refute html =~ "Taxa Para Excluir"
      assert html =~ "Taxa Para Manter"
      _ = rule2
    end
  end

  # ---------------------------------------------------------------------------
  # Toggle active
  # ---------------------------------------------------------------------------

  describe "Toggle active" do
    setup :register_and_log_in_user

    test "toggling an active fee rule marks it inactive", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{active: true})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert html =~ "Ativo"

      view
      |> element("#toggle-#{rule.id}")
      |> render_click()

      assert render(view) =~ "Inativo"
    end

    test "toggling an inactive fee rule marks it active", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{active: false})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      assert html =~ "Inativo"

      view
      |> element("#toggle-#{rule.id}")
      |> render_click()

      assert render(view) =~ "Ativo"
    end

    test "toggling changes the badge class", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{active: true})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      view
      |> element("#toggle-#{rule.id}")
      |> render_click()

      html = render(view)
      # After toggling, the badge should reflect inactive state
      assert html =~ "badge-error"
    end

    test "toggle button label changes after toggling", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{active: true})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")

      # Initially should say "Desativar"
      assert has_element?(view, "#toggle-#{rule.id}", "Desativar")

      view
      |> element("#toggle-#{rule.id}")
      |> render_click()

      # After toggle should say "Ativar"
      assert has_element?(view, "#toggle-#{rule.id}", "Ativar")
    end
  end

  # ---------------------------------------------------------------------------
  # Authentication guard
  # ---------------------------------------------------------------------------

  describe "Authentication" do
    test "redirects unauthenticated users", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, {:redirect, %{to: "/staff/log-in"}}} =
               live(conn, ~p"/admin/organizations/#{org}/events/#{event}/fees")
    end
  end
end
