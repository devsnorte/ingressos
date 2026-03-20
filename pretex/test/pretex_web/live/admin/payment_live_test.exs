defmodule PretexWeb.Admin.PaymentLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Pretex.OrganizationsFixtures

  alias Pretex.Payments

  defp create_provider(org, attrs \\ %{}) do
    defaults = %{
      organization_id: org.id,
      type: "stripe",
      name: "Stripe Principal",
      credentials: %{"secret_key" => "sk_test_abc123456789"}
    }

    {:ok, provider} = Payments.create_provider(Map.merge(defaults, attrs))
    provider
  end

  # ---------------------------------------------------------------------------
  # Index — lista de provedores
  # ---------------------------------------------------------------------------

  describe "Index" do
    setup :register_and_log_in_user

    test "exibe estado vazio quando não há provedores", %{conn: conn} do
      org = org_fixture()

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/payments")
      assert html =~ "Nenhum provedor configurado"
      assert html =~ "Provedores de Pagamento"
    end

    test "lista provedores configurados", %{conn: conn} do
      org = org_fixture()
      provider = create_provider(org)

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/payments")
      assert html =~ provider.name
      assert html =~ "stripe"
      assert html =~ "Pendente"
    end

    test "exibe badge de padrão quando provedor é padrão", %{conn: conn} do
      org = org_fixture()
      provider = create_provider(org)
      {:ok, _} = Payments.set_default_provider(provider)

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/payments")
      assert html =~ "Padrão"
    end

    test "exibe credenciais mascaradas", %{conn: conn} do
      org = org_fixture()
      create_provider(org, %{credentials: %{"secret_key" => "sk_test_abcdef123456"}})

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/payments")
      assert html =~ "••••3456"
      refute html =~ "sk_test_abcdef123456"
    end

    test "exibe badge de status ativo após validação", %{conn: conn} do
      org = org_fixture()

      provider =
        create_provider(org, %{
          type: "manual",
          name: "Manual",
          credentials: %{"bank_info" => "Banco do Brasil"}
        })

      {:ok, _} = Payments.validate_provider(provider)

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/payments")
      assert html =~ "Ativo"
    end
  end

  # ---------------------------------------------------------------------------
  # Adicionar provedor
  # ---------------------------------------------------------------------------

  describe "Novo provedor" do
    setup :register_and_log_in_user

    test "exibe seleção de tipos de provedores", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/payments")

      # Navigate to add provider - goes to manual type selection page
      {:ok, view, html} = live(conn, ~p"/admin/organizations/#{org}/payments/new/manual")
      assert html =~ "Configurar"
      assert html =~ "Nome do provedor"
    end

    test "cria um novo provedor stripe com sucesso", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/payments/new/stripe")

      view
      |> form("#provider-form",
        provider: %{name: "Meu Stripe", credentials: %{secret_key: "sk_test_novo123"}}
      )
      |> render_submit()

      assert_patch(view, ~p"/admin/organizations/#{org}/payments")

      html = render(view)
      assert html =~ "Provedor adicionado com sucesso!"
      assert html =~ "Meu Stripe"
    end

    test "cria um novo provedor manual com sucesso", %{conn: conn} do
      org = org_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/payments/new/manual")

      view
      |> form("#provider-form",
        provider: %{name: "Transferência", credentials: %{bank_info: "PIX: 123.456.789-00"}}
      )
      |> render_submit()

      assert_patch(view, ~p"/admin/organizations/#{org}/payments")

      html = render(view)
      assert html =~ "Provedor adicionado com sucesso!"
      assert html =~ "Transferência"
    end
  end

  # ---------------------------------------------------------------------------
  # Validar provedor
  # ---------------------------------------------------------------------------

  describe "Validar provedor" do
    setup :register_and_log_in_user

    test "valida provedor com sucesso", %{conn: conn} do
      org = org_fixture()

      provider =
        create_provider(org, %{
          type: "manual",
          name: "Manual",
          credentials: %{"bank_info" => "PIX"}
        })

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/payments")

      view
      |> element("button[phx-click='validate_provider'][phx-value-id='#{provider.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "validado com sucesso"
      assert html =~ "Ativo"
    end

    test "exibe erro quando validação falha", %{conn: conn} do
      org = org_fixture()

      provider =
        create_provider(org, %{
          type: "stripe",
          name: "Stripe Inválido",
          credentials: %{"secret_key" => "invalid_key"}
        })

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/payments")

      view
      |> element("button[phx-click='validate_provider'][phx-value-id='#{provider.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Falha na validação"
    end
  end

  # ---------------------------------------------------------------------------
  # Definir padrão
  # ---------------------------------------------------------------------------

  describe "Definir provedor padrão" do
    setup :register_and_log_in_user

    test "define provedor como padrão", %{conn: conn} do
      org = org_fixture()

      # Create and validate a provider so it's active
      provider =
        create_provider(org, %{
          type: "manual",
          name: "Manual",
          credentials: %{"bank_info" => "PIX"}
        })

      {:ok, _} = Payments.validate_provider(provider)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/payments")

      view
      |> element("button[phx-click='set_default'][phx-value-id='#{provider.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "definido como padrão"
    end
  end

  # ---------------------------------------------------------------------------
  # Remover provedor
  # ---------------------------------------------------------------------------

  describe "Remover provedor" do
    setup :register_and_log_in_user

    test "remove um provedor", %{conn: conn} do
      org = org_fixture()
      provider = create_provider(org)

      {:ok, view, html} = live(conn, ~p"/admin/organizations/#{org}/payments")
      assert html =~ provider.name

      view
      |> element("button[phx-click='delete'][phx-value-id='#{provider.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "removido"
      # Provider card should be gone (empty state shown)
      assert html =~ "Nenhum provedor configurado"
    end
  end

  # ---------------------------------------------------------------------------
  # Editar provedor
  # ---------------------------------------------------------------------------

  describe "Editar provedor" do
    setup :register_and_log_in_user

    test "exibe formulário de edição com dados preenchidos", %{conn: conn} do
      org = org_fixture()
      provider = create_provider(org)

      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org}/payments/#{provider}/edit")
      assert html =~ "Editar"
      assert html =~ provider.name
    end

    test "atualiza nome do provedor", %{conn: conn} do
      org = org_fixture()
      provider = create_provider(org)

      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org}/payments/#{provider}/edit")

      view
      |> form("#provider-form", provider: %{name: "Stripe Atualizado"})
      |> render_submit()

      assert_patch(view, ~p"/admin/organizations/#{org}/payments")

      html = render(view)
      assert html =~ "Provedor atualizado com sucesso!"
      assert html =~ "Stripe Atualizado"
    end
  end
end
