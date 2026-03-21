defmodule PretexWeb.PageControllerTest do
  use PretexWeb.ConnCase, async: true

  describe "GET / - unauthenticated" do
    test "renders the landing page with key sections", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "Pretex"
      assert html =~ "plataforma"
    end

    test "renders features section", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "Gestão de Eventos"
      assert html =~ "Venda de Ingressos"
    end

    test "renders call-to-action links", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "Começar Agora"
    end

    test "navbar shows login and register links when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ ~s(href="/customers/log-in")
      assert html =~ ~s(href="/customers/register")
    end

    test "navbar does not show logout or orders links when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      refute html =~ "Meus Pedidos"
      refute html =~ "Sair"
    end

    test "contains navigation links to events and register", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ ~s(href="/events")
      assert html =~ ~s(href="/customers/register")
    end
  end

  describe "GET / - authenticated" do
    setup :register_and_log_in_customer

    test "renders the landing page successfully", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Pretex"
    end

    test "navbar shows customer email when authenticated", %{conn: conn, customer: customer} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ customer.email
    end

    test "navbar shows orders and logout links when authenticated", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "Meus Pedidos"
      assert html =~ "Sair"
    end

    test "navbar does not show login or register links when authenticated", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      refute html =~ "Entrar"
      refute html =~ "Criar Conta"
    end

    test "navbar orders link points to account orders page", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ ~s(href="/account/orders")
    end
  end
end
