defmodule PretexWeb.Components.EventPageTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias PretexWeb.Components.EventPage

  describe "event_hero/1" do
    test "renders event name and date" do
      html =
        render_component(&EventPage.event_hero/1,
          event_name: "DEVS NORTE",
          event_date: "10-12 de Setembro",
          event_venue: "Centro de Convenções, Belém"
        )

      assert html =~ "DEVS NORTE"
      assert html =~ "10-12 de Setembro"
      assert html =~ "Centro de Convenções, Belém"
    end

    test "renders accent text" do
      html =
        render_component(&EventPage.event_hero/1,
          event_name: "FUTURE TECH",
          event_date: "2024",
          accent_text: "2024"
        )

      assert html =~ "FUTURE TECH"
      assert html =~ "2024"
      assert html =~ "text-primary"
    end

    test "renders ticket CTA when url provided" do
      html =
        render_component(&EventPage.event_hero/1,
          event_name: "Test Event",
          event_date: "2024",
          ticket_url: "/events/1/checkout"
        )

      assert html =~ "Comprar Ingresso"
      assert html =~ "/events/1/checkout"
    end

    test "renders banner image when provided" do
      html =
        render_component(&EventPage.event_hero/1,
          event_name: "Test",
          event_date: "2024",
          banner_url: "/images/banner.jpg"
        )

      assert html =~ "/images/banner.jpg"
    end

    test "renders gradient fallback without banner" do
      html =
        render_component(&EventPage.event_hero/1,
          event_name: "Test",
          event_date: "2024"
        )

      assert html =~ "radial-gradient"
    end
  end

  describe "event_description/1" do
    test "renders description text" do
      html =
        render_component(&EventPage.event_description/1,
          description: "Reunindo entusiastas de tecnologia"
        )

      assert html =~ "Reunindo entusiastas de tecnologia"
    end

    test "renders ticket button when url provided" do
      html =
        render_component(&EventPage.event_description/1,
          description: "Test",
          ticket_url: "/checkout"
        )

      assert html =~ "Comprar Ingresso"
    end

    test "supports light mode" do
      html =
        render_component(&EventPage.event_description/1,
          description: "Test",
          dark: false
        )

      assert html =~ "bg-base-100"
      refute html =~ "bg-neutral"
    end
  end

  describe "event_topics/1" do
    @topics [
      %{title: "Elixir", description: "Linguagem funcional", icon: "hero-code-bracket"},
      %{title: "Phoenix", description: "Framework web", icon: "hero-fire"},
      %{title: "OTP", description: "Tolerância a falhas", icon: "hero-shield-check"}
    ]

    test "renders all topic cards" do
      html = render_component(&EventPage.event_topics/1, topics: @topics)

      assert html =~ "Elixir"
      assert html =~ "Phoenix"
      assert html =~ "OTP"
      assert html =~ "Linguagem funcional"
    end

    test "renders topic icons" do
      html = render_component(&EventPage.event_topics/1, topics: @topics)

      assert html =~ "hero-code-bracket"
      assert html =~ "hero-fire"
    end
  end

  describe "event_stats/1" do
    @stats [
      %{value: "34", label: "PALESTRANTES", accent: false},
      %{value: "80", label: "HORAS", accent: true},
      %{value: "3", label: "DIAS", accent: false}
    ]

    test "renders stat values and labels" do
      html = render_component(&EventPage.event_stats/1, stats: @stats)

      assert html =~ "34"
      assert html =~ "PALESTRANTES"
      assert html =~ "80"
      assert html =~ "HORAS"
    end

    test "highlights accent stats" do
      html = render_component(&EventPage.event_stats/1, stats: @stats)

      # The accent stat (80 HORAS) should have text-primary
      assert html =~ "text-primary"
    end

    test "renders photo when provided" do
      html =
        render_component(&EventPage.event_stats/1,
          stats: @stats,
          photo_url: "/images/event.jpg"
        )

      assert html =~ "/images/event.jpg"
    end

    test "renders placeholder without photo" do
      html = render_component(&EventPage.event_stats/1, stats: @stats)

      assert html =~ "hero-photo"
    end
  end

  describe "event_speakers/1" do
    @speakers [
      %{name: "Iago Cavalcante", role: "Elixir Developer", time: "09/10 - 14:00"},
      %{name: "Ana Silva", role: "Designer", time: "09/11 - 10:00"}
    ]

    test "renders speaker names and roles" do
      html = render_component(&EventPage.event_speakers/1, speakers: @speakers)

      assert html =~ "Iago Cavalcante"
      assert html =~ "Elixir Developer"
      assert html =~ "Ana Silva"
    end

    test "renders speaker times" do
      html = render_component(&EventPage.event_speakers/1, speakers: @speakers)

      assert html =~ "09/10 - 14:00"
    end

    test "renders initial when no avatar" do
      html = render_component(&EventPage.event_speakers/1, speakers: @speakers)

      # First letter of "Iago"
      assert html =~ "I"
      # First letter of "Ana"
      assert html =~ "A"
    end

    test "shows +N more card when total_speakers exceeds displayed" do
      html =
        render_component(&EventPage.event_speakers/1,
          speakers: @speakers,
          total_speakers: 30
        )

      assert html =~ "28+"
      assert html =~ "Ver Todos"
    end

    test "renders section title" do
      html = render_component(&EventPage.event_speakers/1, speakers: @speakers)

      assert html =~ "Palestrantes"
    end
  end

  describe "event_cta_banner/1" do
    test "renders title and ticket button" do
      html =
        render_component(&EventPage.event_cta_banner/1,
          ticket_url: "/checkout"
        )

      assert html =~ "Garanta sua vaga"
      assert html =~ "Comprar Ingresso"
    end

    test "renders custom title and subtitle" do
      html =
        render_component(&EventPage.event_cta_banner/1,
          title: "Não perca!",
          subtitle: "Vagas limitadas",
          ticket_url: "/checkout"
        )

      assert html =~ "Não perca!"
      assert html =~ "Vagas limitadas"
    end
  end

  describe "event_footer/1" do
    test "renders event and org name" do
      html =
        render_component(&EventPage.event_footer/1,
          event_name: "DevsFest Belém 2024",
          org_name: "Devs Norte"
        )

      assert html =~ "DevsFest Belém 2024"
      assert html =~ "Devs Norte"
      assert html =~ "Pretex"
    end
  end
end
