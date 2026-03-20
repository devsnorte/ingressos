defmodule PretexWeb.Components.DashboardTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias PretexWeb.Components.Dashboard

  @org %{id: 1, name: "Devs Norte", display_name: "Devs Norte Community", slug: "devs-norte"}

  describe "dashboard_layout/1" do
    test "renders sidebar and content area" do
      html =
        render_component(&Dashboard.dashboard_layout/1,
          current_path: "/admin/organizations/1/events",
          org: @org,
          inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Main Content" end}]
        )

      assert html =~ "Pretex"
      assert html =~ "Devs Norte Community"
      assert html =~ "drawer"
    end
  end

  describe "sidebar/1" do
    test "renders nav items" do
      html =
        render_component(&Dashboard.sidebar/1,
          current_path: "/admin/organizations/1/events",
          org: @org
        )

      assert html =~ "Eventos"
      assert html =~ "Equipe"
      assert html =~ "Navegação"
      assert html =~ "Todas as organizações"
    end

    test "highlights active nav item" do
      html =
        render_component(&Dashboard.sidebar/1,
          current_path: "/admin/organizations/1/events",
          org: @org
        )

      assert html =~ "sidebar-item-active"
    end

    test "disables placeholder items" do
      html =
        render_component(&Dashboard.sidebar/1,
          current_path: "/admin/organizations/1",
          org: @org
        )

      assert html =~ "sidebar-item-disabled"
    end
  end

  describe "sidebar_item/1" do
    test "renders with icon and label" do
      html =
        render_component(&Dashboard.sidebar_item/1,
          icon: "hero-home",
          label: "Dashboard",
          path: "/admin",
          active: false,
          disabled: false
        )

      assert html =~ "Dashboard"
      assert html =~ "hero-home"
      assert html =~ "sidebar-item"
    end

    test "renders active state" do
      html =
        render_component(&Dashboard.sidebar_item/1,
          icon: "hero-home",
          label: "Dashboard",
          path: "/admin",
          active: true,
          disabled: false
        )

      assert html =~ "sidebar-item-active"
    end

    test "renders with badge" do
      html =
        render_component(&Dashboard.sidebar_item/1,
          icon: "hero-home",
          label: "Dashboard",
          path: "/admin",
          active: false,
          disabled: false,
          badge: 5
        )

      assert html =~ "5"
      assert html =~ "badge"
    end
  end

  describe "breadcrumb/1" do
    test "renders breadcrumb trail" do
      html =
        render_component(&Dashboard.breadcrumb/1,
          items: [{"Events", "/events"}, {"Manage Event", nil}]
        )

      assert html =~ "Events"
      assert html =~ "Manage Event"
      assert html =~ "breadcrumbs"
    end

    test "last item has no link" do
      html =
        render_component(&Dashboard.breadcrumb/1,
          items: [{"Events", "/events"}, {"Current", nil}]
        )

      # First item has href, last doesn't
      assert html =~ ~s(href="/events")
      refute html =~ ~s(href="Current")
    end
  end

  describe "page_header/1" do
    test "renders title" do
      html =
        render_component(&Dashboard.page_header/1,
          title: "My Event"
        )

      assert html =~ "My Event"
    end

    test "renders subtitle" do
      html =
        render_component(&Dashboard.page_header/1,
          title: "My Event",
          subtitle: "Manage your event settings"
        )

      assert html =~ "Manage your event settings"
    end
  end

  describe "step_tabs/1" do
    @steps [
      %{id: :team, icon: "hero-user-group", label: "Team"},
      %{id: :register, icon: "hero-clipboard-document-check", label: "Register"},
      %{id: :tickets, icon: "hero-ticket", label: "Tickets"}
    ]

    test "renders all steps" do
      html =
        render_component(&Dashboard.step_tabs/1,
          steps: @steps,
          current: :register
        )

      assert html =~ "Team"
      assert html =~ "Register"
      assert html =~ "Tickets"
    end

    test "marks current step as active" do
      html =
        render_component(&Dashboard.step_tabs/1,
          steps: @steps,
          current: :register
        )

      assert html =~ "step-tab-active"
    end

    test "marks completed steps" do
      html =
        render_component(&Dashboard.step_tabs/1,
          steps: @steps,
          current: :tickets
        )

      assert html =~ "step-tab-completed"
    end
  end

  describe "date_badge/1" do
    test "renders month and day" do
      html =
        render_component(&Dashboard.date_badge/1,
          month: "JUN",
          day: 20
        )

      assert html =~ "JUN"
      assert html =~ "20"
      assert html =~ "date-badge"
    end
  end

  describe "progress_bar/1" do
    test "renders step count and progress" do
      html =
        render_component(&Dashboard.progress_bar/1,
          current: 3,
          total: 8
        )

      assert html =~ "Step 3 of 8"
      assert html =~ "progress"
    end
  end

  describe "stat_card/1" do
    test "renders title and value" do
      html =
        render_component(&Dashboard.stat_card/1,
          title: "Total Sales",
          value: "R$ 12,500"
        )

      assert html =~ "Total Sales"
      assert html =~ "R$ 12,500"
    end

    test "renders with icon" do
      html =
        render_component(&Dashboard.stat_card/1,
          title: "Events",
          value: "24",
          icon: "hero-calendar-days"
        )

      assert html =~ "hero-calendar-days"
    end
  end

  describe "item_card/1" do
    test "renders card with content" do
      html =
        render_component(&Dashboard.item_card/1,
          inner_block: [
            %{__slot__: :inner_block, inner_block: fn _, _ -> "Card Content" end}
          ]
        )

      assert html =~ "Card Content"
      assert html =~ "rounded-xl"
    end
  end
end
