defmodule PretexWeb.PageControllerTest do
  use PretexWeb.ConnCase, async: true

  test "GET / renders the landing page with key sections", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    # Hero section
    assert html =~ "Pretex"
    assert html =~ "plataforma"

    # Features section
    assert html =~ "Gestão de Eventos"
    assert html =~ "Venda de Ingressos"

    # CTA
    assert html =~ "Começar Agora"
  end

  test "GET / contains navigation links", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(href="/events")
    assert html =~ ~s(href="/customers/register")
  end
end
