defmodule PretexWeb.Admin.OrganizationLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Pretex.Organizations

  @create_attrs %{name: "Devs Norte", slug: "devs-norte", display_name: "DN Community"}
  @update_attrs %{name: "Updated Name", display_name: "Updated Display"}

  defp create_organization(_) do
    {:ok, organization} = Organizations.create_organization(@create_attrs)
    %{organization: organization}
  end

  describe "Index" do
    setup [:create_organization]

    test "lists all organizations", %{conn: conn, organization: organization} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/organizations")
      assert html =~ "Organizations"
      assert html =~ organization.name
    end

    test "shows empty state when no organizations", %{conn: conn} do
      for org <- Organizations.list_organizations() do
        Organizations.delete_organization(org)
      end

      {:ok, _index_live, html} = live(conn, ~p"/admin/organizations")
      assert html =~ "Organizations"
    end

    test "saves new organization", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/organizations")

      index_live
      |> element("a", "New Organization")
      |> render_click()

      assert_patch(index_live, ~p"/admin/organizations/new")

      assert index_live
             |> form("#organization-form", organization: %{name: "", slug: ""})
             |> render_change() =~ "can&#39;t be blank"

      index_live
      |> form("#organization-form", organization: %{name: "New Org", slug: "new-org"})
      |> render_submit()

      assert_patch(index_live, ~p"/admin/organizations")

      html = render(index_live)
      assert html =~ "New Org"
    end

    test "updates organization in listing", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/organizations")

      index_live
      |> element("a", "Edit")
      |> render_click()

      index_live
      |> form("#organization-form", organization: @update_attrs)
      |> render_submit()

      assert_patch(index_live, ~p"/admin/organizations")

      html = render(index_live)
      assert html =~ "Updated Name"
    end

    test "deletes organization in listing", %{conn: conn, organization: organization} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/organizations")

      assert index_live
             |> element("a", "Delete")
             |> render_click()

      refute render(index_live) =~ organization.name
    end
  end

  describe "Show" do
    setup [:create_organization]

    test "displays organization", %{conn: conn, organization: organization} do
      {:ok, _show_live, html} = live(conn, ~p"/admin/organizations/#{organization}")
      assert html =~ organization.name
      assert html =~ organization.slug
    end

    test "updates organization within modal", %{conn: conn, organization: organization} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/organizations/#{organization}/show/edit")

      show_live
      |> form("#organization-form", organization: @update_attrs)
      |> render_submit()

      assert_patch(show_live, ~p"/admin/organizations/#{organization}")

      html = render(show_live)
      assert html =~ "Updated Name"
    end
  end
end
