defmodule PretexWeb.Components.EventPage do
  @moduledoc """
  Components for rendering individual event landing pages.
  Data-driven: organizers configure content, components render dynamically.
  All function components — no state, no queries.
  """
  use Phoenix.Component
  import PretexWeb.CoreComponents, only: [icon: 1]

  # ============================================================
  # 1. event_hero/1
  # Full-width hero with banner image, event metadata, and large title
  # ============================================================
  attr :event_name, :string, required: true
  attr :event_date, :string, required: true
  attr :event_tagline, :string, default: nil
  attr :event_venue, :string, default: nil
  attr :banner_url, :string, default: nil
  attr :accent_text, :string, default: nil
  attr :ticket_url, :string, default: nil

  def event_hero(assigns) do
    ~H"""
    <section class="relative min-h-[70vh] lg:min-h-[80vh] flex flex-col justify-end overflow-hidden bg-neutral">
      <%!-- Banner image or gradient fallback --%>
      <div :if={@banner_url} class="absolute inset-0">
        <img src={@banner_url} alt="" class="w-full h-full object-cover opacity-60" />
        <div class="absolute inset-0 bg-gradient-to-t from-neutral via-neutral/70 to-transparent">
        </div>
      </div>
      <div
        :if={!@banner_url}
        class="absolute inset-0"
        style="background: radial-gradient(ellipse 80% 50% at 50% 20%, rgba(94,210,158,0.15) 0%, transparent 60%), radial-gradient(ellipse 50% 40% at 80% 60%, rgba(134,239,172,0.08) 0%, transparent 50%), linear-gradient(180deg, rgba(30,41,59,0.0) 0%, rgba(30,41,59,1) 100%);"
      >
      </div>

      <%!-- Sticky event nav --%>
      <nav class="absolute top-0 left-0 right-0 z-20 py-4">
        <div class="container mx-auto px-4 sm:px-6 lg:px-8 flex items-center justify-between">
          <div class="flex items-center gap-2">
            <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
              <.icon name="hero-ticket" class="w-4 h-4 text-primary-content" />
            </div>
            <span class="font-bold text-neutral-content text-sm">Pretex</span>
          </div>
          <div class="hidden md:flex items-center gap-6 text-sm text-neutral-content/70">
            <a href="#about" class="hover:text-neutral-content transition-colors">Sobre</a>
            <a href="#topics" class="hover:text-neutral-content transition-colors">Programação</a>
            <a href="#speakers" class="hover:text-neutral-content transition-colors">Palestrantes</a>
          </div>
          <a :if={@ticket_url} href={@ticket_url} class="btn btn-primary btn-sm gap-1">
            Comprar Ingresso <.icon name="hero-arrow-top-right-on-square" class="w-3.5 h-3.5" />
          </a>
        </div>
      </nav>

      <%!-- Hero content --%>
      <div class="relative z-10 container mx-auto px-4 sm:px-6 lg:px-8 pb-12 lg:pb-16">
        <%!-- Metadata row --%>
        <div class="flex flex-wrap gap-x-8 gap-y-2 text-sm text-neutral-content/60 mb-4">
          <span>{@event_date}</span>
          <span :if={@event_tagline}>{@event_tagline}</span>
          <span :if={@event_venue}>{@event_venue}</span>
        </div>

        <%!-- Event title --%>
        <h1 class="text-4xl sm:text-6xl lg:text-8xl font-black tracking-tight text-neutral-content uppercase leading-none">
          {@event_name}
          <span :if={@accent_text} class="text-primary">{@accent_text}</span>
        </h1>
      </div>
    </section>
    """
  end

  # ============================================================
  # 2. event_description/1
  # Centered description block with CTA
  # ============================================================
  attr :description, :string, required: true
  attr :ticket_url, :string, default: nil
  attr :ticket_label, :string, default: "Comprar Ingresso"
  attr :dark, :boolean, default: true

  def event_description(assigns) do
    ~H"""
    <section
      id="about"
      class={[
        "py-16 lg:py-24",
        @dark && "bg-neutral text-neutral-content",
        !@dark && "bg-base-100 text-base-content"
      ]}
    >
      <div class="container mx-auto px-4 sm:px-6 lg:px-8 max-w-3xl">
        <div class="flex flex-col md:flex-row items-start md:items-center justify-between gap-8">
          <p class="text-lg lg:text-xl leading-relaxed opacity-80 max-w-xl">
            {@description}
          </p>
          <a :if={@ticket_url} href={@ticket_url} class="btn btn-primary btn-lg gap-2 shrink-0">
            {@ticket_label}
            <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
          </a>
        </div>
      </div>
    </section>
    """
  end

  # ============================================================
  # 3. event_topics/1
  # Topic/track cards in a grid
  # ============================================================
  attr :topics, :list, required: true
  attr :dark, :boolean, default: true

  def event_topics(assigns) do
    ~H"""
    <section
      id="topics"
      class={[
        "py-16 lg:py-24",
        @dark && "bg-neutral text-neutral-content",
        !@dark && "bg-base-200 text-base-content"
      ]}
    >
      <div class="container mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 max-w-5xl mx-auto">
          <.topic_card :for={topic <- @topics} topic={topic} dark={@dark} />
        </div>
      </div>
    </section>
    """
  end

  attr :topic, :map, required: true
  attr :dark, :boolean, default: true

  defp topic_card(assigns) do
    ~H"""
    <div class={[
      "rounded-2xl p-6 transition hover:-translate-y-1",
      @dark && "bg-neutral-content/5 border border-neutral-content/10 hover:bg-neutral-content/10",
      !@dark && "bg-base-100 border border-base-300 shadow-md hover:shadow-lg"
    ]}>
      <div class="w-16 h-16 rounded-2xl bg-primary/15 flex items-center justify-center mb-5">
        <.icon name={@topic.icon} class="w-8 h-8 text-primary" />
      </div>
      <h3 class="text-lg font-bold text-primary mb-2">{@topic.title}</h3>
      <p class={[
        "text-sm leading-relaxed",
        @dark && "text-neutral-content/60",
        !@dark && "text-base-content/60"
      ]}>
        {@topic.description}
      </p>
    </div>
    """
  end

  # ============================================================
  # 4. event_stats/1
  # Large typography stats with optional photo
  # ============================================================
  attr :stats, :list, required: true
  attr :photo_url, :string, default: nil
  attr :dark, :boolean, default: true

  def event_stats(assigns) do
    ~H"""
    <section class={[
      "py-16 lg:py-24",
      @dark && "bg-neutral text-neutral-content",
      !@dark && "bg-base-100 text-base-content"
    ]}>
      <div class="container mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center max-w-5xl mx-auto">
          <%!-- Stats column --%>
          <div class="space-y-4 lg:space-y-6">
            <div :for={stat <- @stats} class="flex items-baseline gap-3">
              <span class={[
                "text-4xl sm:text-5xl lg:text-6xl font-black tracking-tight",
                stat[:accent] && "text-primary",
                !stat[:accent] && ((@dark && "text-neutral-content/80") || "text-base-content/80")
              ]}>
                {stat.value}
              </span>
              <span class={[
                "text-lg sm:text-xl font-bold uppercase tracking-wider",
                stat[:accent] && "text-primary",
                !stat[:accent] && ((@dark && "text-neutral-content/40") || "text-base-content/40")
              ]}>
                {stat.label}
              </span>
            </div>
          </div>

          <%!-- Photo column --%>
          <div :if={@photo_url} class="rounded-2xl overflow-hidden shadow-2xl">
            <img src={@photo_url} alt="Foto do evento" class="w-full h-64 lg:h-80 object-cover" />
          </div>
          <div
            :if={!@photo_url}
            class="rounded-2xl overflow-hidden h-64 lg:h-80 bg-gradient-to-br from-primary/20 to-primary/5 flex items-center justify-center"
          >
            <.icon name="hero-photo" class="w-16 h-16 text-primary/30" />
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ============================================================
  # 5. event_speakers/1
  # Speaker cards with avatar, name, role, time
  # ============================================================
  attr :speakers, :list, required: true
  attr :total_speakers, :integer, default: nil
  attr :dark, :boolean, default: true

  def event_speakers(assigns) do
    ~H"""
    <section
      id="speakers"
      class={[
        "py-16 lg:py-24",
        @dark && "bg-neutral text-neutral-content",
        !@dark && "bg-base-200 text-base-content"
      ]}
    >
      <div class="container mx-auto px-4 sm:px-6 lg:px-8">
        <h2 class="text-2xl sm:text-3xl font-bold text-center mb-12">Palestrantes</h2>
        <div class="flex flex-wrap justify-center gap-8 lg:gap-12 max-w-4xl mx-auto">
          <.speaker_card :for={speaker <- @speakers} speaker={speaker} dark={@dark} />

          <%!-- "+N more" card --%>
          <div
            :if={@total_speakers && @total_speakers > length(@speakers)}
            class="flex flex-col items-center gap-3"
          >
            <div class={[
              "w-20 h-20 lg:w-24 lg:h-24 rounded-full flex items-center justify-center text-2xl font-bold",
              @dark && "bg-neutral-content/10 text-neutral-content/60",
              !@dark && "bg-base-300 text-base-content/60"
            ]}>
              {Integer.to_string(@total_speakers - length(@speakers))}+
            </div>
            <p class="text-sm font-medium opacity-70">Ver Todos</p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :speaker, :map, required: true
  attr :dark, :boolean, default: true

  defp speaker_card(assigns) do
    ~H"""
    <div class="flex flex-col items-center gap-3 text-center w-32 lg:w-36">
      <%!-- Avatar --%>
      <div
        :if={@speaker[:avatar_url]}
        class="w-20 h-20 lg:w-24 lg:h-24 rounded-full overflow-hidden ring-2 ring-primary/30 ring-offset-2 ring-offset-neutral"
      >
        <img src={@speaker.avatar_url} alt={@speaker.name} class="w-full h-full object-cover" />
      </div>
      <div
        :if={!@speaker[:avatar_url]}
        class={[
          "w-20 h-20 lg:w-24 lg:h-24 rounded-full flex items-center justify-center text-2xl font-bold ring-2 ring-primary/30 ring-offset-2",
          @dark && "bg-neutral-content/10 text-primary ring-offset-neutral",
          !@dark && "bg-primary/10 text-primary ring-offset-base-100"
        ]}
      >
        {String.first(@speaker.name)}
      </div>

      <%!-- Info --%>
      <div>
        <p class="font-semibold text-sm">{@speaker.name}</p>
        <p
          :if={@speaker[:role]}
          class={[
            "text-xs mt-0.5",
            @dark && "text-neutral-content/50",
            !@dark && "text-base-content/50"
          ]}
        >
          {@speaker.role}
        </p>
      </div>

      <%!-- Time --%>
      <p
        :if={@speaker[:time]}
        class={[
          "text-xs font-mono",
          @dark && "text-neutral-content/40",
          !@dark && "text-base-content/40"
        ]}
      >
        {@speaker.time}
      </p>
    </div>
    """
  end

  # ============================================================
  # 6. event_cta_banner/1
  # Final call-to-action banner
  # ============================================================
  attr :title, :string, default: "Garanta sua vaga"
  attr :subtitle, :string, default: nil
  attr :ticket_url, :string, required: true
  attr :ticket_label, :string, default: "Comprar Ingresso"
  attr :dark, :boolean, default: true

  def event_cta_banner(assigns) do
    ~H"""
    <section class={[
      "py-16 lg:py-24",
      @dark && "bg-neutral text-neutral-content border-t border-neutral-content/10",
      !@dark && "bg-primary/5 text-base-content"
    ]}>
      <div class="container mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 class="text-3xl sm:text-4xl font-bold mb-4">{@title}</h2>
        <p :if={@subtitle} class="text-lg opacity-60 mb-8 max-w-xl mx-auto">{@subtitle}</p>
        <a href={@ticket_url} class="btn btn-primary btn-lg gap-2">
          {@ticket_label}
          <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
        </a>
      </div>
    </section>
    """
  end

  # ============================================================
  # 7. event_footer/1
  # Minimal event footer
  # ============================================================
  attr :event_name, :string, required: true
  attr :org_name, :string, required: true

  def event_footer(assigns) do
    ~H"""
    <footer class="bg-neutral text-neutral-content/50 py-8 border-t border-neutral-content/10">
      <div class="container mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-sm">
        <p>{@event_name} · Organizado por {@org_name}</p>
        <p class="flex items-center gap-1">
          Powered by <a href="/" class="text-primary hover:underline font-medium">Pretex</a>
        </p>
      </div>
    </footer>
    """
  end
end
