defmodule PretexWeb.Admin.VoucherLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Events
  alias Pretex.Organizations
  alias Pretex.Vouchers

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

  defp voucher_fixture(event, attrs \\ %{}) do
    base = %{
      code: "CODE#{System.unique_integer([:positive])}",
      effect: "fixed_discount",
      value: 1000,
      active: true
    }

    {:ok, voucher} = Vouchers.create_voucher(event, Enum.into(attrs, base))
    voucher
  end

  # ---------------------------------------------------------------------------
  # Index — listing vouchers
  # ---------------------------------------------------------------------------

  describe "Index - listing vouchers" do
    setup :register_and_log_in_user

    test "renders the vouchers page for an event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Rock Festival"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Vouchers"
      assert html =~ "Rock Festival"
    end

    test "shows empty state when no vouchers exist", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Nenhum voucher cadastrado"
    end

    test "lists vouchers for the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "MYCODE"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ voucher.code
    end

    test "does not show vouchers from other events", %{conn: conn} do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      _voucher = voucher_fixture(event1, %{code: "EXCLUSIVEEVENT1"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event2}/vouchers")

      refute html =~ "EXCLUSIVEEVENT1"
    end

    test "shows the effect label for a fixed_discount voucher", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "FX001", effect: "fixed_discount"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Desconto Fixo"
    end

    test "shows the effect label for a percentage_discount voucher", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "PCT001", effect: "percentage_discount", value: 500})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Desconto Percentual"
    end

    test "shows active badge for active voucher", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "ACT001", active: true})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Ativo"
    end

    test "shows inactive badge for inactive voucher", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "INACT001", active: false})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Inativo"
    end

    test "shows Novo Voucher button", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Novo Voucher"
    end

    test "shows Geração em Lote button", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Geração em Lote"
    end

    test "shows back link to the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Voltar ao Evento"
    end

    test "shows delete button for each voucher", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "DELME"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Excluir"
    end

    test "shows edit link for each voucher", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "EDITME"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Editar"
    end

    test "shows toggle active button for each voucher", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "TOGGLE1", active: true})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Desativar"
    end

    test "shows tag filter pills when vouchers have tags", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "VIP001", tag: "vip"})
      voucher_fixture(event, %{code: "PROMO001", tag: "promo"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "vip"
      assert html =~ "promo"
    end

    test "does not show tag filter when no tags exist", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "NOTAG1", tag: nil})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      refute html =~ "Filtrar por tag"
    end
  end

  # ---------------------------------------------------------------------------
  # New voucher modal
  # ---------------------------------------------------------------------------

  describe "New voucher modal" do
    setup :register_and_log_in_user

    test "navigating to /vouchers/new opens the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/new")

      assert html =~ "Novo Voucher"
    end

    test "shows the voucher form inside the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/new")

      assert html =~ "Código"
      assert html =~ "Efeito"
      assert html =~ "Valor"
    end

    test "creates a fixed_discount voucher and shows it in the list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/new")

      view
      |> form("#voucher-form",
        voucher: %{code: "NEWCODE", effect: "fixed_discount", value: "1500"}
      )
      |> render_submit()

      html = render(view)
      assert html =~ "NEWCODE"
      assert html =~ "Voucher criado com sucesso"
    end

    test "creates a percentage_discount voucher and shows it in the list", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/new")

      view
      |> form("#voucher-form",
        voucher: %{code: "PCT10", effect: "percentage_discount", value: "1000"}
      )
      |> render_submit()

      html = render(view)
      assert html =~ "PCT10"
    end

    test "shows validation error when code is blank", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/new")

      html =
        view
        |> form("#voucher-form", voucher: %{code: "", effect: "fixed_discount", value: "100"})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "shows validation error for negative value", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/new")

      html =
        view
        |> form("#voucher-form",
          voucher: %{code: "NEGV", effect: "fixed_discount", value: "-100"}
        )
        |> render_change()

      assert html =~ "must be greater than or equal to"
    end

    test "clicking Cancel closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/new")

      assert has_element?(view, "#voucher-modal")

      view |> element("button", "Cancelar") |> render_click()

      refute has_element?(view, "#voucher-modal")
    end

    test "clicking X button closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/new")

      assert has_element?(view, "#voucher-modal")

      view |> element("button[aria-label='Fechar']") |> render_click()

      refute has_element?(view, "#voucher-modal")
    end

    test "newly created voucher appears in the stream after save", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/new")

      view
      |> form("#voucher-form",
        voucher: %{code: "STREAM001", effect: "fixed_discount", value: "500"}
      )
      |> render_submit()

      html = render(view)
      assert html =~ "STREAM001"
    end

    test "creates a voucher with a tag", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/new")

      view
      |> form("#voucher-form",
        voucher: %{code: "TAGGED1", effect: "fixed_discount", value: "200", tag: "parceiro"}
      )
      |> render_submit()

      html = render(view)
      assert html =~ "TAGGED1"
      assert html =~ "parceiro"
    end

    test "creates vouchers with all supported effect types", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      for {effect, label, idx} <- [
            {"fixed_discount", "Desconto Fixo", 1},
            {"percentage_discount", "Desconto Percentual", 2},
            {"custom_price", "Preço Personalizado", 3},
            {"reveal", "Revelar Item", 4},
            {"grant_access", "Acesso Especial", 5}
          ] do
        {:ok, view, _html} =
          live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/new")

        code = "EFF#{idx}#{System.unique_integer([:positive])}"

        view
        |> form("#voucher-form", voucher: %{code: code, effect: effect, value: "0"})
        |> render_submit()

        html = render(view)
        assert html =~ code, "Expected #{code} to be in HTML for effect #{effect}"
        assert html =~ label, "Expected label #{label} for effect #{effect}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edit voucher modal
  # ---------------------------------------------------------------------------

  describe "Edit voucher modal" do
    setup :register_and_log_in_user

    test "navigating to /vouchers/:id/edit opens modal pre-filled", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "EDITCODE"})

      {:ok, _view, html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/vouchers/#{voucher.id}/edit"
        )

      assert html =~ "Editar Voucher"
      assert html =~ "EDITCODE"
    end

    test "shows the form pre-filled with current values", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "PREFILLED", value: 2500})

      {:ok, _view, html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/vouchers/#{voucher.id}/edit"
        )

      assert html =~ "PREFILLED"
      assert html =~ "2500"
    end

    test "saves changes and updates the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "SAVEUPDATE", value: 500})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/vouchers/#{voucher.id}/edit"
        )

      view
      |> form("#voucher-form", voucher: %{value: "9999"})
      |> render_submit()

      html = render(view)
      assert html =~ "Voucher atualizado com sucesso"
      assert html =~ "99,99"
    end

    test "shows validation errors on invalid update", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/vouchers/#{voucher.id}/edit"
        )

      html =
        view
        |> form("#voucher-form", voucher: %{code: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "cancelling edit closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/vouchers/#{voucher.id}/edit"
        )

      assert has_element?(view, "#voucher-modal")

      view |> element("button", "Cancelar") |> render_click()

      refute has_element?(view, "#voucher-modal")
    end
  end

  # ---------------------------------------------------------------------------
  # Delete voucher
  # ---------------------------------------------------------------------------

  describe "Delete voucher" do
    setup :register_and_log_in_user

    test "removes the voucher from the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "DELETEME"})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "DELETEME"

      view
      |> element("button[phx-click='delete'][phx-value-id='#{voucher.id}']")
      |> render_click()

      html = render(view)
      refute html =~ "DELETEME"
      assert html =~ "Voucher removido com sucesso"
    end

    test "shows empty state after deleting the only voucher", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "LASTCODE"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      view
      |> element("button[phx-click='delete'][phx-value-id='#{voucher.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Nenhum voucher cadastrado"
    end

    test "only removes the targeted voucher, leaving others intact", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _voucher1 = voucher_fixture(event, %{code: "KEEP001"})
      voucher2 = voucher_fixture(event, %{code: "REMOVE001"})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "KEEP001"
      assert html =~ "REMOVE001"

      view
      |> element("button[phx-click='delete'][phx-value-id='#{voucher2.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "KEEP001"
      refute html =~ "REMOVE001"
    end
  end

  # ---------------------------------------------------------------------------
  # Toggle active
  # ---------------------------------------------------------------------------

  describe "Toggle active" do
    setup :register_and_log_in_user

    test "toggling an active voucher marks it inactive", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "TOGGLEACT", active: true})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Desativar"

      view
      |> element("button[phx-click='toggle_active'][phx-value-id='#{voucher.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Ativar"
      assert html =~ "Inativo"
    end

    test "toggling an inactive voucher marks it active", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "TOGGLEINACT", active: false})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert html =~ "Ativar"

      view
      |> element("button[phx-click='toggle_active'][phx-value-id='#{voucher.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Desativar"
      assert html =~ "Ativo"
    end

    test "toggling changes the badge", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "BADGETEST", active: true})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      view
      |> element("button[phx-click='toggle_active'][phx-value-id='#{voucher.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Inativo"
    end
  end

  # ---------------------------------------------------------------------------
  # Bulk generation
  # ---------------------------------------------------------------------------

  describe "Bulk generation modal" do
    setup :register_and_log_in_user

    test "navigating to /vouchers/bulk opens the bulk modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/bulk")

      assert html =~ "Geração em Lote"
    end

    test "shows the bulk generation form fields", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/bulk")

      assert html =~ "Prefixo"
      assert html =~ "Quantidade"
      assert html =~ "Efeito"
    end

    test "generates vouchers with the given prefix", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/bulk")

      view
      |> form("#bulk-form",
        bulk: %{
          prefix: "VERAO",
          quantity: "3",
          effect: "fixed_discount",
          value: "500"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "voucher(s) gerado(s) com sucesso"
    end

    test "all generated vouchers appear in the list with the prefix", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/bulk")

      view
      |> form("#bulk-form",
        bulk: %{
          prefix: "PREFX",
          quantity: "2",
          effect: "fixed_discount",
          value: "0"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "PREFX"
    end

    test "shows flash message with count of generated vouchers", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/bulk")

      view
      |> form("#bulk-form",
        bulk: %{
          prefix: "CNT",
          quantity: "5",
          effect: "fixed_discount",
          value: "100"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "5 voucher(s) gerado(s) com sucesso"
    end

    test "bulk form generates vouchers with a tag", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/bulk")

      view
      |> form("#bulk-form",
        bulk: %{
          prefix: "TAGGED",
          quantity: "2",
          effect: "fixed_discount",
          value: "0",
          tag: "lote1"
        }
      )
      |> render_submit()

      html = render(view)
      # tag should be visible after generation
      assert html =~ "lote1"
    end

    test "clicking Cancel closes the bulk modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers/bulk")

      assert has_element?(view, "#bulk-modal")

      view |> element("button", "Cancelar") |> render_click()

      refute has_element?(view, "#bulk-modal")
    end
  end

  # ---------------------------------------------------------------------------
  # Tag filter
  # ---------------------------------------------------------------------------

  describe "Tag filter" do
    setup :register_and_log_in_user

    test "tag filter shows only vouchers with the selected tag", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "VIP001", tag: "vip"})
      voucher_fixture(event, %{code: "PROMO001", tag: "promo"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      # Click the "vip" tag filter
      view
      |> element("button[phx-click='filter_tag'][phx-value-tag='vip']")
      |> render_click()

      html = render(view)
      assert html =~ "VIP001"
      refute html =~ "PROMO001"
    end

    test "clicking All resets tag filter and shows all vouchers", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "VIP002", tag: "vip"})
      voucher_fixture(event, %{code: "PROMO002", tag: "promo"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      # Filter by vip
      view
      |> element("button[phx-click='filter_tag'][phx-value-tag='vip']")
      |> render_click()

      # Reset to all
      view
      |> element("button[phx-click='filter_tag'][phx-value-tag='']")
      |> render_click()

      html = render(view)
      assert html =~ "VIP002"
      assert html =~ "PROMO002"
    end

    test "filter tag is highlighted when active", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "VIP003", tag: "vip"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      view
      |> element("button[phx-click='filter_tag'][phx-value-tag='vip']")
      |> render_click()

      html = render(view)
      # The active pill should have badge-secondary class
      assert html =~ "badge-secondary"
    end
  end

  # ---------------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------------

  describe "Authentication" do
    test "redirects unauthenticated users", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      result = live(conn, ~p"/admin/organizations/#{org}/events/#{event}/vouchers")

      assert {:error, {:redirect, %{to: path}}} = result
      assert path =~ "/staff/log-in"
    end
  end
end
