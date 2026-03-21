defmodule PretexWeb.Admin.GiftCardLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Organizations
  alias Pretex.GiftCards

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

  defp gift_card_fixture(org, attrs) do
    base = %{
      code: "GC-TEST#{System.unique_integer([:positive])}",
      balance_cents: 5000,
      active: true
    }

    {:ok, gc} = GiftCards.create_gift_card(org, Enum.into(attrs, base))
    gc
  end

  # ---------------------------------------------------------------------------
  # Index — listing gift cards
  # ---------------------------------------------------------------------------

  describe "Index - listing gift cards" do
    setup :register_and_log_in_user

    test "renders the gift cards page for an organization", %{conn: conn} do
      org = org_fixture()

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards")

      assert html =~ "Vale-Presentes"
      assert html =~ org.name
    end

    test "shows empty state when no gift cards exist", %{conn: conn} do
      org = org_fixture()

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards")

      assert html =~ "Nenhum vale-presente cadastrado"
    end

    test "lists gift cards for the organization", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-LISTED01"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards")

      assert html =~ gc.code
    end

    test "shows gift card balance", %{conn: conn} do
      org = org_fixture()
      _gc = gift_card_fixture(org, %{code: "GC-BALANCE1", balance_cents: 10_000})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards")

      assert html =~ "R$ 100,00"
    end

    test "shows active badge for active gift card", %{conn: conn} do
      org = org_fixture()
      _gc = gift_card_fixture(org, %{code: "GC-ACTIVE01", active: true})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards")

      assert html =~ "Ativo"
    end

    test "shows inactive badge for inactive gift card", %{conn: conn} do
      org = org_fixture()
      _gc = gift_card_fixture(org, %{code: "GC-INACT01", active: false})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards")

      assert html =~ "Inativo"
    end

    test "shows link back to organization", %{conn: conn} do
      org = org_fixture()

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards")

      assert html =~ "Voltar à Organização"
    end
  end

  # ---------------------------------------------------------------------------
  # New gift card form
  # ---------------------------------------------------------------------------

  describe "New gift card form" do
    setup :register_and_log_in_user

    test "renders the new gift card modal", %{conn: conn} do
      org = org_fixture()

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/new")

      assert html =~ "Novo Vale-Presente"
      assert html =~ "Código"
      assert html =~ "Saldo"
    end

    test "auto-generates a code when opening the new form", %{conn: conn} do
      org = org_fixture()

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/new")

      assert html =~ "GC-"
    end

    test "creates a gift card with valid attrs", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/new")

      html =
        view
        |> form("#gift-card-form", %{
          "gift_card" => %{
            "code" => "GC-NEWCARD1",
            "balance_cents" => "5000",
            "initial_balance_cents" => "5000",
            "active" => "true"
          }
        })
        |> render_submit()

      assert html =~ "Vale-presente criado com sucesso"

      gc = GiftCards.get_gift_card_by_code("GC-NEWCARD1")
      assert {:ok, _} = gc
    end

    test "shows validation errors for missing code", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/new")

      html =
        view
        |> form("#gift-card-form", %{
          "gift_card" => %{
            "code" => "",
            "balance_cents" => "5000"
          }
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "shows validation errors for negative balance", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/new")

      html =
        view
        |> form("#gift-card-form", %{
          "gift_card" => %{
            "code" => "GC-NEGBAL01",
            "balance_cents" => "-100"
          }
        })
        |> render_submit()

      assert html =~ "must be greater than or equal to"
    end

    test "generate_code button populates the code field", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/new")

      html = render_click(view, "generate_code")

      assert html =~ "GC-"
    end

    test "shows duplicate code error", %{conn: conn} do
      org = org_fixture()
      _existing = gift_card_fixture(org, %{code: "GC-DUPTEST1"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/new")

      html =
        view
        |> form("#gift-card-form", %{
          "gift_card" => %{
            "code" => "GC-DUPTEST1",
            "balance_cents" => "1000"
          }
        })
        |> render_submit()

      assert html =~ "has already been taken"
    end
  end

  # ---------------------------------------------------------------------------
  # Edit gift card
  # ---------------------------------------------------------------------------

  describe "Edit gift card" do
    setup :register_and_log_in_user

    test "renders the edit gift card modal", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-EDIT01"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/#{gc.id}/edit")

      assert html =~ "Editar Vale-Presente"
      assert html =~ gc.code
    end

    test "updates a gift card with valid attrs", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-EDIT02", note: "original"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/#{gc.id}/edit")

      html =
        view
        |> form("#gift-card-form", %{
          "gift_card" => %{
            "code" => gc.code,
            "balance_cents" => "8000",
            "note" => "updated note"
          }
        })
        |> render_submit()

      assert html =~ "Vale-presente atualizado com sucesso"

      updated = GiftCards.get_gift_card!(gc.id)
      assert updated.balance_cents == 8000
      assert updated.note == "updated note"
    end

    test "validates on change", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-VALCH01"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/#{gc.id}/edit")

      html =
        view
        |> form("#gift-card-form", %{
          "gift_card" => %{
            "code" => gc.code,
            "balance_cents" => "-1"
          }
        })
        |> render_change()

      assert html =~ "must be greater than or equal to"
    end
  end

  # ---------------------------------------------------------------------------
  # Delete gift card
  # ---------------------------------------------------------------------------

  describe "Delete gift card" do
    setup :register_and_log_in_user

    test "deletes a gift card", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-DELETE01"})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards")

      assert html =~ gc.code

      html =
        view
        |> element("[phx-click='delete'][phx-value-id='#{gc.id}']")
        |> render_click()

      assert html =~ "Vale-presente removido com sucesso"
      refute html =~ gc.code
    end
  end

  # ---------------------------------------------------------------------------
  # Toggle active
  # ---------------------------------------------------------------------------

  describe "Toggle active" do
    setup :register_and_log_in_user

    test "toggles a gift card from active to inactive", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-TOGGLE01", active: true})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards")

      html =
        view
        |> element("[phx-click='toggle_active'][phx-value-id='#{gc.id}']")
        |> render_click()

      assert html =~ "Inativo"

      updated = GiftCards.get_gift_card!(gc.id)
      assert updated.active == false
    end

    test "toggles a gift card from inactive to active", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-TOGGLE02", active: false})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards")

      html =
        view
        |> element("[phx-click='toggle_active'][phx-value-id='#{gc.id}']")
        |> render_click()

      assert html =~ "Ativo"

      updated = GiftCards.get_gift_card!(gc.id)
      assert updated.active == true
    end
  end

  # ---------------------------------------------------------------------------
  # Top-up
  # ---------------------------------------------------------------------------

  describe "Top-up gift card" do
    setup :register_and_log_in_user

    test "renders the top-up modal", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-TOPUP01"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/#{gc.id}/top-up")

      assert html =~ "Recarregar Vale-Presente"
      assert html =~ gc.code
    end

    test "shows current balance in the top-up modal", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-TOPUP02", balance_cents: 5000})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/#{gc.id}/top-up")

      assert html =~ "R$ 50,00"
    end

    test "adds balance successfully", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-TOPUP03", balance_cents: 5000})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/#{gc.id}/top-up")

      html =
        view
        |> form("#top-up-form", %{"top_up" => %{"amount_cents" => "2000"}})
        |> render_submit()

      assert html =~ "Vale-presente recarregado com sucesso"

      updated = GiftCards.get_gift_card!(gc.id)
      assert updated.balance_cents == 7000
    end

    test "shows error for zero amount", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-TOPUP04", balance_cents: 5000})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/#{gc.id}/top-up")

      html =
        view
        |> form("#top-up-form", %{"top_up" => %{"amount_cents" => "0"}})
        |> render_submit()

      assert html =~ "valor válido"
    end

    test "shows error for invalid (non-numeric) amount", %{conn: conn} do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-TOPUP05", balance_cents: 5000})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/#{gc.id}/top-up")

      html =
        view
        |> form("#top-up-form", %{"top_up" => %{"amount_cents" => "abc"}})
        |> render_submit()

      assert html =~ "valor válido"
    end
  end

  # ---------------------------------------------------------------------------
  # Close modal
  # ---------------------------------------------------------------------------

  describe "Close modal" do
    setup :register_and_log_in_user

    test "close_modal event navigates back to index", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/gift-cards/new")

      html = render_click(view, "close_modal")

      # Should no longer show the modal content
      refute html =~ "Criar Vale-Presente"
    end
  end

  # ---------------------------------------------------------------------------
  # Authentication guard
  # ---------------------------------------------------------------------------

  describe "Authentication" do
    test "redirects unauthenticated users", %{conn: conn} do
      org = org_fixture()

      assert {:error, redirect} =
               live(conn, ~p"/admin/organizations/#{org}/gift-cards")

      assert {:redirect, %{to: path}} = redirect
      assert path =~ "/staff/log-in"
    end
  end
end
