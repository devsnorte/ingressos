# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Safe to run multiple times — all inserts use on_conflict: :nothing.

alias Pretex.Repo
alias Pretex.Organizations.Organization
alias Pretex.Accounts.User
alias Pretex.Teams.Membership
alias Pretex.Customers.Customer
alias Pretex.Events.Event
alias Pretex.Events.TicketType
alias Pretex.Events.SubEvent
alias Pretex.Catalog.ItemCategory
alias Pretex.Catalog.Item
alias Pretex.Catalog.ItemVariation
alias Pretex.Catalog.Bundle
alias Pretex.Catalog.AddonAssignment
alias Pretex.Catalog.Quota
alias Pretex.Catalog.QuotaItem
alias Pretex.Catalog.Question
alias Pretex.Catalog.QuestionOption
alias Pretex.Catalog.AttendeeFieldConfig
alias Pretex.Orders.Order
alias Pretex.Orders.OrderItem
alias Pretex.Orders.CartSession
alias Pretex.Orders.CartItem

import Ecto.Query

now = DateTime.utc_now(:second)

# ─────────────────────────────────────────────────────────────────
# Organizations
# ─────────────────────────────────────────────────────────────────

IO.puts("\n→ Seeding organizations...")

org_data = [
  %{
    name: "Devs do Norte",
    slug: "devsnorte",
    display_name: "Devs do Norte",
    description: "Developer community in Northern Brazil"
  },
  %{
    name: "Elixir Brasil",
    slug: "elixir-br",
    display_name: "Elixir Brasil",
    description: "Brazilian Elixir and Erlang community"
  },
  %{
    name: "PyNorte",
    slug: "pynorte",
    display_name: "PyNorte",
    description: "Python community in Northern Brazil"
  }
]

Enum.each(org_data, fn attrs ->
  %Organization{}
  |> Organization.creation_changeset(attrs)
  |> Repo.insert!(on_conflict: :nothing, conflict_target: :slug)
end)

devsnorte = Repo.get_by!(Organization, slug: "devsnorte")
elixir_br = Repo.get_by!(Organization, slug: "elixir-br")
pynorte = Repo.get_by!(Organization, slug: "pynorte")

IO.puts("   done (#{length(org_data)} organizations)")

# ─────────────────────────────────────────────────────────────────
# Staff users
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding staff users...")

staff_data = [
  %{name: "Alice Admin", email: "alice@pretex.dev"},
  %{name: "Bob Manager", email: "bob@pretex.dev"},
  %{name: "Carol Operator", email: "carol@pretex.dev"}
]

Enum.each(staff_data, fn attrs ->
  %User{}
  |> User.changeset(attrs)
  |> Repo.insert!(on_conflict: :nothing, conflict_target: :email)
end)

alice = Repo.get_by!(User, email: "alice@pretex.dev")
bob = Repo.get_by!(User, email: "bob@pretex.dev")
carol = Repo.get_by!(User, email: "carol@pretex.dev")

IO.puts("   done (#{length(staff_data)} users)")

# ─────────────────────────────────────────────────────────────────
# Memberships
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding memberships...")

membership_data = [
  {alice, devsnorte, "admin"},
  {alice, elixir_br, "admin"},
  {bob, devsnorte, "event_manager"},
  {bob, elixir_br, "event_manager"},
  {carol, devsnorte, "checkin_operator"},
  {carol, pynorte, "admin"}
]

Enum.each(membership_data, fn {user, org, role} ->
  %Membership{}
  |> Membership.changeset(%{role: role})
  |> Ecto.Changeset.put_change(:organization_id, org.id)
  |> Ecto.Changeset.put_change(:user_id, user.id)
  |> Repo.insert!(on_conflict: :nothing, conflict_target: [:organization_id, :user_id])
end)

IO.puts("   done (#{length(membership_data)} memberships)")

# ─────────────────────────────────────────────────────────────────
# Customers (attendees)
# Password for all: helloworld123
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding customers...")

password = "helloworld123"

customer_emails = [
  "mario@example.com",
  "ana@example.com",
  "lucas@example.com",
  "julia@example.com",
  "guest@example.com"
]

Enum.each(customer_emails, fn email ->
  %Customer{}
  |> Customer.email_changeset(%{email: email}, validate_unique: false)
  |> Customer.password_changeset(%{password: password, password_confirmation: password})
  |> Ecto.Changeset.put_change(:confirmed_at, now)
  |> Repo.insert!(on_conflict: :nothing, conflict_target: :email)
end)

mario = Repo.get_by!(Customer, email: "mario@example.com")
ana = Repo.get_by!(Customer, email: "ana@example.com")
lucas = Repo.get_by!(Customer, email: "lucas@example.com")

IO.puts("   done (#{length(customer_emails)} customers)")

# ─────────────────────────────────────────────────────────────────
# Events
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding events...")

events_data = [
  # --- Devs do Norte ---
  %{
    org: devsnorte,
    attrs: %{
      name: "ElixirConf Brasil 2026",
      slug: "elixirconf-brasil-2026",
      description:
        "A maior conferência de Elixir da América Latina. Dois dias de palestras, workshops e networking com a comunidade Elixir brasileira e convidados internacionais.",
      starts_at: ~U[2026-07-10 09:00:00Z],
      ends_at: ~U[2026-07-11 18:00:00Z],
      venue: "Centro de Convenções de Belém — Belém, PA",
      primary_color: "#6366f1",
      accent_color: "#f43f5e",
      is_series: true,
      publish: true
    }
  },
  %{
    org: devsnorte,
    attrs: %{
      name: "DevFest Norte 2026",
      slug: "devfest-norte-2026",
      description:
        "Festival de desenvolvedores organizado pela comunidade GDG Belém. Palestras sobre Android, Web, Cloud e muito mais.",
      starts_at: ~U[2026-09-05 08:00:00Z],
      ends_at: ~U[2026-09-05 18:00:00Z],
      venue: "UFPA — Belém, PA",
      primary_color: "#0ea5e9",
      accent_color: "#f59e0b",
      is_series: false,
      publish: false
    }
  },
  # --- Elixir Brasil ---
  %{
    org: elixir_br,
    attrs: %{
      name: "Workshop Elixir Intensivo",
      slug: "workshop-elixir-intensivo",
      description:
        "Três horas de workshop hands-on cobrindo OTP, supervisores, GenServer e Phoenix LiveView. Vagas limitadas para garantir atenção individualizada.",
      starts_at: ~U[2026-08-15 09:00:00Z],
      ends_at: ~U[2026-08-15 12:00:00Z],
      venue: "Online — Google Meet",
      primary_color: "#8b5cf6",
      accent_color: "#10b981",
      is_series: false,
      publish: true
    }
  },
  # --- PyNorte ---
  %{
    org: pynorte,
    attrs: %{
      name: "PyNorte Meetup — Agosto 2026",
      slug: "pynorte-meetup-agosto-2026",
      description:
        "Meetup mensal da comunidade Python do Norte do Brasil. Palestras relâmpago, networking e muito Python! Entrada gratuita, mas apoiadores são bem-vindos.",
      starts_at: ~U[2026-08-20 18:30:00Z],
      ends_at: ~U[2026-08-20 21:30:00Z],
      venue: "Campus IFPA — Belém, PA",
      primary_color: "#3b82f6",
      accent_color: "#f97316",
      is_series: false,
      publish: true
    }
  },
  %{
    org: pynorte,
    attrs: %{
      name: "PyNorte 2025",
      slug: "pynorte-2025",
      description: "Edição 2025 do PyNorte. Evento encerrado.",
      starts_at: ~U[2025-08-10 09:00:00Z],
      ends_at: ~U[2025-08-10 18:00:00Z],
      venue: "UFPA — Belém, PA",
      primary_color: "#3b82f6",
      accent_color: "#f97316",
      is_series: false,
      publish: true,
      complete: true
    }
  }
]

created_events =
  Enum.map(events_data, fn %{org: org, attrs: attrs} ->
    {publish, attrs} = Map.pop(attrs, :publish, false)
    {complete, attrs} = Map.pop(attrs, :complete, false)
    {is_series, attrs} = Map.pop(attrs, :is_series, false)

    event =
      case Repo.get_by(Event, slug: attrs.slug) do
        nil ->
          {:ok, e} =
            %Event{}
            |> Event.changeset(attrs)
            |> Ecto.Changeset.put_change(:organization_id, org.id)
            |> Ecto.Changeset.put_change(:status, "draft")
            |> Ecto.Changeset.put_change(:is_series, is_series)
            |> Repo.insert()

          e

        existing ->
          existing
      end

    # Insert a placeholder TicketType so publish_event passes the guard
    %TicketType{}
    |> TicketType.changeset(%{name: "Ingresso", price_cents: 0, status: "active"})
    |> Ecto.Changeset.put_change(:event_id, event.id)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [])

    event =
      cond do
        publish and event.status == "draft" ->
          {:ok, e} = Pretex.Events.publish_event(event)
          e

        complete and event.status in ["draft", "published"] ->
          event =
            if event.status == "draft" do
              {:ok, e} = Pretex.Events.publish_event(event)
              e
            else
              event
            end

          {:ok, e} = Pretex.Events.complete_event(event)
          e

        true ->
          event
      end

    {attrs.slug, event}
  end)
  |> Map.new()

elixirconf = created_events["elixirconf-brasil-2026"]
workshop = created_events["workshop-elixir-intensivo"]
pynorte_meetup = created_events["pynorte-meetup-agosto-2026"]
pynorte_2025 = created_events["pynorte-2025"]
devfest = created_events["devfest-norte-2026"]

IO.puts("   done (#{length(events_data)} events)")

# ─────────────────────────────────────────────────────────────────
# Sub-Events — ElixirConf Brasil 2026 (is_series)
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding sub-events...")

sub_events_data = [
  %{
    name: "Dia 1: Palestras",
    description: "Primeiro dia: keynotes e palestras principais no auditório central.",
    starts_at: ~U[2026-07-10 09:00:00Z],
    ends_at: ~U[2026-07-10 18:00:00Z],
    venue: "Auditório Principal — Centro de Convenções",
    capacity: 300,
    status: "published"
  },
  %{
    name: "Dia 2: Workshops",
    description: "Segundo dia: workshops práticos em salas menores. Vagas limitadas por sala.",
    starts_at: ~U[2026-07-11 09:00:00Z],
    ends_at: ~U[2026-07-11 18:00:00Z],
    venue: "Salas de Workshop — Centro de Convenções",
    capacity: 60,
    status: "published"
  },
  %{
    name: "Dia 3: Hackathon",
    description: "Terceiro dia de hackathon colaborativo. Em preparação.",
    starts_at: ~U[2026-07-12 09:00:00Z],
    ends_at: ~U[2026-07-12 18:00:00Z],
    venue: "A confirmar",
    capacity: 40,
    status: "hidden"
  }
]

Enum.each(sub_events_data, fn attrs ->
  case Repo.get_by(SubEvent, parent_event_id: elixirconf.id, name: attrs.name) do
    nil ->
      %SubEvent{}
      |> SubEvent.changeset(attrs)
      |> Ecto.Changeset.put_change(:parent_event_id, elixirconf.id)
      |> Ecto.Changeset.put_change(:status, attrs.status)
      |> Repo.insert!()

    _existing ->
      :ok
  end
end)

IO.puts("   done (#{length(sub_events_data)} sub-events for ElixirConf)")

# ─────────────────────────────────────────────────────────────────
# Item Categories
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding item categories...")

defp_upsert_category = fn event, name, position ->
  case Repo.get_by(ItemCategory, event_id: event.id, name: name) do
    nil ->
      {:ok, cat} =
        %ItemCategory{}
        |> ItemCategory.changeset(%{name: name, position: position})
        |> Ecto.Changeset.put_change(:event_id, event.id)
        |> Repo.insert()

      cat

    existing ->
      existing
  end
end

# ElixirConf categories
cat_ec_ingressos = defp_upsert_category.(elixirconf, "Ingressos", 0)
cat_ec_merch = defp_upsert_category.(elixirconf, "Merchandise", 1)
cat_ec_extras = defp_upsert_category.(elixirconf, "Extras", 2)

# Workshop categories
cat_ws_vagas = defp_upsert_category.(workshop, "Vagas", 0)

# PyNorte categories
cat_pn_ingressos = defp_upsert_category.(pynorte_meetup, "Ingressos", 0)

IO.puts("   done")

# ─────────────────────────────────────────────────────────────────
# Items
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding items...")

defp_upsert_item = fn event, attrs ->
  case Repo.get_by(Item, event_id: event.id, name: attrs.name) do
    nil ->
      {:ok, item} =
        %Item{}
        |> Item.changeset(attrs)
        |> Ecto.Changeset.put_change(:event_id, event.id)
        |> Repo.insert()

      item

    existing ->
      existing
  end
end

# ── ElixirConf items ──────────────────────────────────────────────

item_ec_early_bird =
  defp_upsert_item.(elixirconf, %{
    name: "Ingresso Early Bird",
    description:
      "Ingresso com desconto para os primeiros compradores. Acesso completo aos dois dias.",
    price_cents: 9900,
    available_quantity: 100,
    item_type: "ticket",
    require_voucher: false,
    min_per_order: 1,
    max_per_order: 2,
    status: "active",
    category_id: cat_ec_ingressos.id
  })

item_ec_regular =
  defp_upsert_item.(elixirconf, %{
    name: "Ingresso Regular",
    description: "Ingresso com acesso completo aos dois dias de evento.",
    price_cents: 14900,
    available_quantity: 150,
    item_type: "ticket",
    require_voucher: false,
    min_per_order: 1,
    max_per_order: 5,
    status: "active",
    category_id: cat_ec_ingressos.id
  })

item_ec_vip =
  defp_upsert_item.(elixirconf, %{
    name: "Ingresso VIP",
    description:
      "Acesso completo + jantar com palestrantes, camiseta exclusiva, e acesso à área VIP nos coffee breaks.",
    price_cents: 34900,
    available_quantity: 30,
    item_type: "ticket",
    require_voucher: false,
    min_per_order: 1,
    max_per_order: 2,
    status: "active",
    category_id: cat_ec_ingressos.id
  })

item_ec_speaker =
  defp_upsert_item.(elixirconf, %{
    name: "Ingresso Palestrante",
    description: "Ingresso exclusivo para palestrantes confirmados. Requer voucher.",
    price_cents: 0,
    available_quantity: 50,
    item_type: "ticket",
    require_voucher: true,
    status: "active",
    category_id: cat_ec_ingressos.id
  })

item_ec_tshirt =
  defp_upsert_item.(elixirconf, %{
    name: "Camiseta ElixirConf 2026",
    description: "Camiseta oficial do evento, 100% algodão, estampa exclusiva.",
    price_cents: 4900,
    item_type: "merchandise",
    status: "active",
    category_id: cat_ec_merch.id
  })

item_ec_parking =
  defp_upsert_item.(elixirconf, %{
    name: "Estacionamento (2 dias)",
    description: "Vaga de estacionamento no estacionamento do Centro de Convenções por 2 dias.",
    price_cents: 2500,
    item_type: "addon",
    is_addon: true,
    status: "active",
    category_id: cat_ec_extras.id
  })

item_ec_lunch =
  defp_upsert_item.(elixirconf, %{
    name: "Almoço Premium (por dia)",
    description:
      "Almoço buffet no restaurante do Centro de Convenções. Opções vegetarianas inclusas.",
    price_cents: 4500,
    item_type: "addon",
    is_addon: true,
    min_per_order: 1,
    max_per_order: 2,
    status: "active",
    category_id: cat_ec_extras.id
  })

# ── Workshop items ────────────────────────────────────────────────

item_ws_individual =
  defp_upsert_item.(workshop, %{
    name: "Vaga Individual",
    description:
      "Uma vaga no workshop. Inclui material de apoio em PDF e acesso à gravação por 30 dias.",
    price_cents: 29900,
    available_quantity: 30,
    item_type: "ticket",
    min_per_order: 1,
    max_per_order: 1,
    status: "active",
    category_id: cat_ws_vagas.id
  })

item_ws_dupla =
  defp_upsert_item.(workshop, %{
    name: "Vaga Dupla",
    description:
      "Duas vagas com desconto. Ideal para times. Cada participante recebe o material.",
    price_cents: 49900,
    available_quantity: 10,
    item_type: "ticket",
    min_per_order: 1,
    max_per_order: 1,
    status: "active",
    category_id: cat_ws_vagas.id
  })

# ── PyNorte Meetup items ──────────────────────────────────────────

item_pn_free =
  defp_upsert_item.(pynorte_meetup, %{
    name: "Entrada Gratuita",
    description: "Entrada gratuita para o meetup. Garanta sua vaga para o controle de acesso.",
    price_cents: 0,
    available_quantity: 150,
    item_type: "ticket",
    min_per_order: 1,
    max_per_order: 1,
    status: "active",
    category_id: cat_pn_ingressos.id
  })

item_pn_supporter =
  defp_upsert_item.(pynorte_meetup, %{
    name: "Ingresso Apoiador",
    description:
      "Apoie a comunidade PyNorte! Seu nome nos créditos do evento e camiseta de apoiador.",
    price_cents: 5000,
    available_quantity: 30,
    item_type: "ticket",
    min_per_order: 1,
    max_per_order: 3,
    status: "active",
    category_id: cat_pn_ingressos.id
  })

IO.puts("   done")

# ─────────────────────────────────────────────────────────────────
# Item Variations — Camiseta ElixirConf
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding item variations...")

defp_upsert_variation = fn item, attrs ->
  case Repo.get_by(ItemVariation, item_id: item.id, name: attrs.name) do
    nil ->
      {:ok, v} =
        %ItemVariation{}
        |> ItemVariation.changeset(attrs)
        |> Ecto.Changeset.put_change(:item_id, item.id)
        |> Repo.insert()

      v

    existing ->
      existing
  end
end

var_tshirt_p =
  defp_upsert_variation.(item_ec_tshirt, %{
    name: "P",
    price_cents: 4900,
    stock: 40,
    status: "active"
  })

var_tshirt_m =
  defp_upsert_variation.(item_ec_tshirt, %{
    name: "M",
    price_cents: 4900,
    stock: 60,
    status: "active"
  })

var_tshirt_g =
  defp_upsert_variation.(item_ec_tshirt, %{
    name: "G",
    price_cents: 4900,
    stock: 50,
    status: "active"
  })

var_tshirt_gg =
  defp_upsert_variation.(item_ec_tshirt, %{
    name: "GG",
    price_cents: 5400,
    stock: 25,
    status: "active"
  })

_var_tshirt_xgg =
  defp_upsert_variation.(item_ec_tshirt, %{
    name: "XGG",
    price_cents: 5400,
    stock: 10,
    status: "active"
  })

IO.puts("   done (5 camiseta variations)")

# ─────────────────────────────────────────────────────────────────
# Bundles
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding bundles...")

defp_upsert_bundle = fn event, name, description, price_cents, items ->
  case Repo.get_by(Bundle, event_id: event.id, name: name) do
    nil ->
      {:ok, b} =
        %Bundle{}
        |> Bundle.changeset(%{name: name, description: description, price_cents: price_cents})
        |> Ecto.Changeset.put_change(:event_id, event.id)
        |> Ecto.Changeset.put_assoc(:items, items)
        |> Repo.insert()

      b

    existing ->
      existing
  end
end

_bundle_vip_package =
  defp_upsert_bundle.(
    elixirconf,
    "Pacote VIP Completo",
    "Ingresso VIP + Camiseta M + Estacionamento. Tudo que você precisa para um evento inesquecível.",
    41900,
    [item_ec_vip, item_ec_tshirt, item_ec_parking]
  )

_bundle_early_tshirt =
  defp_upsert_bundle.(
    elixirconf,
    "Early Bird + Camiseta",
    "Ingresso Early Bird com camiseta do evento. Economize R$ 9,00 no combo.",
    14000,
    [item_ec_early_bird, item_ec_tshirt]
  )

IO.puts("   done (2 bundles for ElixirConf)")

# ─────────────────────────────────────────────────────────────────
# Addon Assignments
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding addon assignments...")

defp_upsert_addon = fn addon_item, parent_item ->
  case Repo.get_by(AddonAssignment,
         item_id: addon_item.id,
         parent_item_id: parent_item.id
       ) do
    nil ->
      %AddonAssignment{}
      |> AddonAssignment.changeset(%{
        item_id: addon_item.id,
        parent_item_id: parent_item.id
      })
      |> Repo.insert!(on_conflict: :nothing)

    _existing ->
      :ok
  end
end

# Parking available on Regular + VIP tickets
defp_upsert_addon.(item_ec_parking, item_ec_regular)
defp_upsert_addon.(item_ec_parking, item_ec_vip)

# Lunch available on Regular + VIP
defp_upsert_addon.(item_ec_lunch, item_ec_regular)
defp_upsert_addon.(item_ec_lunch, item_ec_vip)

IO.puts("   done")

# ─────────────────────────────────────────────────────────────────
# Quotas
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding quotas...")

defp_upsert_quota = fn event, name, capacity ->
  case Repo.get_by(Quota, event_id: event.id, name: name) do
    nil ->
      {:ok, q} =
        %Quota{}
        |> Quota.changeset(%{name: name, capacity: capacity})
        |> Ecto.Changeset.put_change(:event_id, event.id)
        |> Repo.insert()

      q

    existing ->
      existing
  end
end

defp_assign_quota_item = fn quota, item ->
  case Repo.get_by(QuotaItem, quota_id: quota.id, item_id: item.id) do
    nil ->
      %QuotaItem{}
      |> QuotaItem.changeset(%{quota_id: quota.id, item_id: item.id})
      |> Repo.insert!(on_conflict: :nothing)

    _existing ->
      :ok
  end
end

# ElixirConf — capacidade geral (Early Bird + Regular share the main venue)
quota_ec_geral = defp_upsert_quota.(elixirconf, "Capacidade Geral", 250)
defp_assign_quota_item.(quota_ec_geral, item_ec_early_bird)
defp_assign_quota_item.(quota_ec_geral, item_ec_regular)
defp_assign_quota_item.(quota_ec_geral, item_ec_speaker)

# ElixirConf — área VIP (limited VIP seats)
quota_ec_vip = defp_upsert_quota.(elixirconf, "Área VIP", 30)
defp_assign_quota_item.(quota_ec_vip, item_ec_vip)

# ElixirConf — estacionamento
quota_ec_parking = defp_upsert_quota.(elixirconf, "Vagas de Estacionamento", 80)
defp_assign_quota_item.(quota_ec_parking, item_ec_parking)

# Workshop — capacidade total
quota_ws_total = defp_upsert_quota.(workshop, "Capacidade do Workshop", 30)
defp_assign_quota_item.(quota_ws_total, item_ws_individual)
defp_assign_quota_item.(quota_ws_total, item_ws_dupla)

# PyNorte — capacidade do local
quota_pn_geral = defp_upsert_quota.(pynorte_meetup, "Capacidade do Espaço", 150)
defp_assign_quota_item.(quota_pn_geral, item_pn_free)
defp_assign_quota_item.(quota_pn_geral, item_pn_supporter)

IO.puts("   done (quotas + assignments)")

# ─────────────────────────────────────────────────────────────────
# Questions
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding questions...")

defp_upsert_question = fn event, label, question_type, is_required, position ->
  case Repo.get_by(Question, event_id: event.id, label: label) do
    nil ->
      {:ok, q} =
        %Question{}
        |> Question.changeset(%{
          label: label,
          question_type: question_type,
          is_required: is_required,
          position: position
        })
        |> Ecto.Changeset.put_change(:event_id, event.id)
        |> Repo.insert()

      q

    existing ->
      existing
  end
end

defp_upsert_option = fn question, label, position ->
  case Repo.get_by(QuestionOption, question_id: question.id, label: label) do
    nil ->
      {:ok, o} =
        %QuestionOption{}
        |> QuestionOption.changeset(%{label: label, position: position})
        |> Ecto.Changeset.put_change(:question_id, question.id)
        |> Repo.insert()

      o

    existing ->
      existing
  end
end

defp_scope_question = fn question, item ->
  Repo.insert_all(
    "question_item_scopes",
    [
      %{
        question_id: question.id,
        item_id: item.id,
        inserted_at: now,
        updated_at: now
      }
    ],
    on_conflict: :nothing
  )
end

# ── ElixirConf questions ──────────────────────────────────────────

q_ec_cargo = defp_upsert_question.(elixirconf, "Qual é o seu cargo atual?", "text", false, 0)

q_ec_empresa =
  defp_upsert_question.(elixirconf, "Nome da empresa ou projeto", "text", false, 1)

q_ec_dieta =
  defp_upsert_question.(
    elixirconf,
    "Possui alguma restrição alimentar?",
    "yes_no",
    false,
    2
  )

q_ec_tshirt_size =
  defp_upsert_question.(elixirconf, "Tamanho da camiseta VIP", "single_choice", true, 3)

defp_upsert_option.(q_ec_tshirt_size, "P", 0)
defp_upsert_option.(q_ec_tshirt_size, "M", 1)
defp_upsert_option.(q_ec_tshirt_size, "G", 2)
defp_upsert_option.(q_ec_tshirt_size, "GG", 3)

# T-shirt size question is scoped to VIP only
defp_scope_question.(q_ec_tshirt_size, item_ec_vip)

q_ec_pais =
  defp_upsert_question.(elixirconf, "País de residência", "country", false, 4)

q_ec_como_soube =
  defp_upsert_question.(
    elixirconf,
    "Como ficou sabendo do ElixirConf Brasil?",
    "multiple_choice",
    false,
    5
  )

defp_upsert_option.(q_ec_como_soube, "Redes sociais", 0)
defp_upsert_option.(q_ec_como_soube, "Indicação de amigo", 1)
defp_upsert_option.(q_ec_como_soube, "Newsletter", 2)
defp_upsert_option.(q_ec_como_soube, "Comunidade Elixir", 3)
defp_upsert_option.(q_ec_como_soube, "Outro", 4)

q_ec_acessibilidade =
  defp_upsert_question.(
    elixirconf,
    "Precisa de recurso de acessibilidade?",
    "yes_no",
    false,
    6
  )

# ── Workshop questions ────────────────────────────────────────────

q_ws_nivel =
  defp_upsert_question.(workshop, "Nível de experiência com Elixir", "single_choice", true, 0)

defp_upsert_option.(q_ws_nivel, "Nunca usei — sou totalmente iniciante", 0)
defp_upsert_option.(q_ws_nivel, "Conheço a sintaxe básica", 1)
defp_upsert_option.(q_ws_nivel, "Já fiz alguns projetos pequenos", 2)
defp_upsert_option.(q_ws_nivel, "Uso em produção", 3)

q_ws_github =
  defp_upsert_question.(workshop, "URL do seu GitHub (opcional)", "text", false, 1)

q_ws_expectativa =
  defp_upsert_question.(
    workshop,
    "Qual sua principal expectativa com o workshop?",
    "multiline",
    false,
    2
  )

# ── PyNorte questions ─────────────────────────────────────────────

q_pn_primeira_vez =
  defp_upsert_question.(
    pynorte_meetup,
    "É sua primeira vez no PyNorte?",
    "yes_no",
    false,
    0
  )

q_pn_como_soube =
  defp_upsert_question.(
    pynorte_meetup,
    "Como ficou sabendo do meetup?",
    "single_choice",
    false,
    1
  )

defp_upsert_option.(q_pn_como_soube, "Telegram / WhatsApp da comunidade", 0)
defp_upsert_option.(q_pn_como_soube, "Instagram", 1)
defp_upsert_option.(q_pn_como_soube, "Indicação de amigo", 2)
defp_upsert_option.(q_pn_como_soube, "Outro", 3)

q_pn_palestra =
  defp_upsert_question.(
    pynorte_meetup,
    "Gostaria de dar uma palestra relâmpago (5 min)?",
    "yes_no",
    false,
    2
  )

IO.puts("   done (#{7} ElixirConf + #{3} Workshop + #{3} PyNorte questions)")

# ─────────────────────────────────────────────────────────────────
# Attendee Field Configs
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding attendee field configs...")

defp_upsert_field_config = fn event, field_name, is_enabled, is_required ->
  case Repo.get_by(AttendeeFieldConfig, event_id: event.id, field_name: field_name) do
    nil ->
      %AttendeeFieldConfig{}
      |> AttendeeFieldConfig.changeset(%{
        field_name: field_name,
        is_enabled: is_enabled,
        is_required: is_required
      })
      |> Ecto.Changeset.put_change(:event_id, event.id)
      |> Repo.insert!(
        on_conflict: :nothing,
        conflict_target: [:event_id, :field_name]
      )

    existing ->
      existing
  end
end

# ElixirConf: require company, show phone optionally
defp_upsert_field_config.(elixirconf, "company", true, true)
defp_upsert_field_config.(elixirconf, "phone", true, false)
defp_upsert_field_config.(elixirconf, "address", false, false)

# Workshop: require nothing extra
defp_upsert_field_config.(workshop, "company", true, false)
defp_upsert_field_config.(workshop, "phone", false, false)

# PyNorte: minimal — just name + email (defaults)
defp_upsert_field_config.(pynorte_meetup, "company", false, false)
defp_upsert_field_config.(pynorte_meetup, "phone", false, false)

IO.puts("   done")

# ─────────────────────────────────────────────────────────────────
# Simulate Orders (confirmed purchases)
# ─────────────────────────────────────────────────────────────────

IO.puts("→ Seeding sample orders...")

defp_upsert_order = fn event, customer, attrs, items_with_qty ->
  case Repo.get_by(Order, confirmation_code: attrs.confirmation_code) do
    nil ->
      total =
        Enum.reduce(items_with_qty, 0, fn {item, qty, variation}, acc ->
          price = if variation, do: variation.price_cents, else: item.price_cents
          acc + price * qty
        end)

      {:ok, order} =
        %Order{}
        |> Order.changeset(%{
          email: attrs.email,
          name: attrs.name,
          payment_method: attrs.payment_method
        })
        |> Ecto.Changeset.put_change(:event_id, event.id)
        |> Ecto.Changeset.put_change(:customer_id, if(customer, do: customer.id, else: nil))
        |> Ecto.Changeset.put_change(:status, attrs.status)
        |> Ecto.Changeset.put_change(:total_cents, total)
        |> Ecto.Changeset.put_change(:confirmation_code, attrs.confirmation_code)
        |> Ecto.Changeset.put_change(
          :expires_at,
          DateTime.add(now, 15 * 60, :second)
        )
        |> Repo.insert()

      Enum.each(items_with_qty, fn {item, qty, variation} ->
        price = if variation, do: variation.price_cents, else: item.price_cents

        {:ok, _} =
          %OrderItem{}
          |> OrderItem.changeset(%{
            quantity: qty,
            unit_price_cents: price
          })
          |> Ecto.Changeset.put_change(:order_id, order.id)
          |> Ecto.Changeset.put_change(:item_id, item.id)
          |> Ecto.Changeset.put_change(
            :item_variation_id,
            if(variation, do: variation.id, else: nil)
          )
          |> Ecto.Changeset.put_change(
            :ticket_code,
            :crypto.strong_rand_bytes(4) |> Base.encode16()
          )
          |> Ecto.Changeset.put_change(:attendee_name, attrs.name)
          |> Ecto.Changeset.put_change(:attendee_email, attrs.email)
          |> Repo.insert()
      end)

      # Bump quota sold_count for items in this order
      Enum.each(items_with_qty, fn {item, qty, variation} ->
        quota_ids =
          if variation do
            QuotaItem
            |> where([qi], qi.item_variation_id == ^variation.id)
            |> select([qi], qi.quota_id)
            |> Repo.all()
          else
            QuotaItem
            |> where([qi], qi.item_id == ^item.id)
            |> select([qi], qi.quota_id)
            |> Repo.all()
          end

        if quota_ids != [] do
          from(q in Quota, where: q.id in ^quota_ids)
          |> Repo.update_all(inc: [sold_count: qty])
        end
      end)

      order

    existing ->
      existing
  end
end

# ── ElixirConf orders ─────────────────────────────────────────────

# Mario: VIP ticket (confirmed, paid via credit card)
defp_upsert_order.(
  elixirconf,
  mario,
  %{
    email: mario.email,
    name: "Mário Silva",
    payment_method: "credit_card",
    status: "confirmed",
    confirmation_code: "CONF01"
  },
  [
    {item_ec_vip, 1, nil},
    {item_ec_parking, 1, nil}
  ]
)

# Ana: Regular + T-shirt M (confirmed, pix)
defp_upsert_order.(
  elixirconf,
  ana,
  %{
    email: ana.email,
    name: "Ana Beatriz Costa",
    payment_method: "pix",
    status: "confirmed",
    confirmation_code: "CONF02"
  },
  [
    {item_ec_regular, 1, nil},
    {item_ec_tshirt, 1, var_tshirt_m}
  ]
)

# Lucas: Early Bird × 2 (confirmed, credit card)
defp_upsert_order.(
  elixirconf,
  lucas,
  %{
    email: lucas.email,
    name: "Lucas Mendes",
    payment_method: "credit_card",
    status: "confirmed",
    confirmation_code: "CONF03"
  },
  [
    {item_ec_early_bird, 2, nil}
  ]
)

# Guest (no account): Regular (pending, boleto)
defp_upsert_order.(
  elixirconf,
  nil,
  %{
    email: "renata.oliveira@gmail.com",
    name: "Renata Oliveira",
    payment_method: "boleto",
    status: "pending",
    confirmation_code: "CONF04"
  },
  [
    {item_ec_regular, 1, nil},
    {item_ec_tshirt, 1, var_tshirt_g}
  ]
)

# Another guest: Regular + Lunch (confirmed, pix)
defp_upsert_order.(
  elixirconf,
  nil,
  %{
    email: "pedro.alves@outlook.com",
    name: "Pedro Alves",
    payment_method: "pix",
    status: "confirmed",
    confirmation_code: "CONF05"
  },
  [
    {item_ec_regular, 1, nil},
    {item_ec_lunch, 2, nil}
  ]
)

# Cancelled order example
defp_upsert_order.(
  elixirconf,
  nil,
  %{
    email: "teste@cancelado.com",
    name: "Fulano Cancelado",
    payment_method: "credit_card",
    status: "cancelled",
    confirmation_code: "CONF06"
  },
  [
    {item_ec_early_bird, 1, nil}
  ]
)

# ── Workshop orders ───────────────────────────────────────────────

defp_upsert_order.(
  workshop,
  mario,
  %{
    email: mario.email,
    name: "Mário Silva",
    payment_method: "credit_card",
    status: "confirmed",
    confirmation_code: "CONF07"
  },
  [
    {item_ws_individual, 1, nil}
  ]
)

defp_upsert_order.(
  workshop,
  nil,
  %{
    email: "carla.tech@gmail.com",
    name: "Carla Ferreira",
    payment_method: "pix",
    status: "confirmed",
    confirmation_code: "CONF08"
  },
  [
    {item_ws_dupla, 1, nil}
  ]
)

defp_upsert_order.(
  workshop,
  ana,
  %{
    email: ana.email,
    name: "Ana Beatriz Costa",
    payment_method: "pix",
    status: "pending",
    confirmation_code: "CONF09"
  },
  [
    {item_ws_individual, 1, nil}
  ]
)

# ── PyNorte Meetup orders ─────────────────────────────────────────

defp_upsert_order.(
  pynorte_meetup,
  mario,
  %{
    email: mario.email,
    name: "Mário Silva",
    payment_method: "pix",
    status: "confirmed",
    confirmation_code: "CONF10"
  },
  [
    {item_pn_supporter, 1, nil}
  ]
)

defp_upsert_order.(
  pynorte_meetup,
  lucas,
  %{
    email: lucas.email,
    name: "Lucas Mendes",
    payment_method: "credit_card",
    status: "confirmed",
    confirmation_code: "CONF11"
  },
  [
    {item_pn_free, 1, nil}
  ]
)

# Simulate a batch of free attendees for PyNorte
free_attendees = [
  {"julia.souza@email.com", "Júlia Souza", "CONF12"},
  {"marcos.dev@gmail.com", "Marcos Dev", "CONF13"},
  {"fatima.py@gmail.com", "Fátima Python", "CONF14"},
  {"joao.backend@outlook.com", "João Backend", "CONF15"},
  {"sabrina.data@gmail.com", "Sabrina Data", "CONF16"}
]

Enum.each(free_attendees, fn {email, name, code} ->
  defp_upsert_order.(
    pynorte_meetup,
    nil,
    %{
      email: email,
      name: name,
      payment_method: "pix",
      status: "confirmed",
      confirmation_code: code
    },
    [{item_pn_free, 1, nil}]
  )
end)

# ── Active cart (for browsing demo) ───────────────────────────────

case Repo.get_by(CartSession, session_token: "demo-cart-token-elixirconf-0001") do
  nil ->
    {:ok, demo_cart} =
      %CartSession{}
      |> CartSession.changeset(%{
        session_token: "demo-cart-token-elixirconf-0001",
        expires_at: DateTime.add(now, 2 * 60 * 60, :second),
        status: "active"
      })
      |> Ecto.Changeset.put_change(:event_id, elixirconf.id)
      |> Repo.insert()

    %CartItem{}
    |> CartItem.changeset(%{quantity: 1, item_id: item_ec_regular.id})
    |> Ecto.Changeset.put_change(:cart_session_id, demo_cart.id)
    |> Repo.insert!(on_conflict: :nothing)

  _existing ->
    :ok
end

IO.puts("   done (16 orders + 1 active demo cart)")

# ─────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────

IO.puts("""

✓ Seeds completos!

╔══════════════════════════════════════════════════════════════════╗
║                    CREDENCIAIS DE ACESSO                        ║
╠══════════════════════════════════════════════════════════════════╣
║  STAFF (magic link em /staff/log-in)                            ║
║    alice@pretex.dev   · admin → Devs do Norte + Elixir Brasil  ║
║    bob@pretex.dev     · event_manager → ambas orgs             ║
║    carol@pretex.dev   · admin → PyNorte, operador → DevNorte   ║
╠══════════════════════════════════════════════════════════════════╣
║  CUSTOMERS (senha: helloworld123)                               ║
║    mario@example.com  · 3 pedidos (ElixirConf VIP, Workshop,   ║
║                          PyNorte)                               ║
║    ana@example.com    · 2 pedidos (ElixirConf Regular, Workshop)║
║    lucas@example.com  · 2 pedidos (ElixirConf Early Bird ×2,   ║
║                          PyNorte)                               ║
║    julia@example.com  · sem pedidos                             ║
║    guest@example.com  · sem pedidos                             ║
╠══════════════════════════════════════════════════════════════════╣
║  EVENTOS                                                        ║
║    [PUBLICADO] ElixirConf Brasil 2026 (devsnorte)              ║
║      → série com 3 sub-eventos (2 publicados, 1 oculto)        ║
║      → 7 items, 5 variações de camiseta, 2 bundles             ║
║      → 3 quotas, 7 perguntas, 6 pedidos                        ║
║    [PUBLICADO] Workshop Elixir Intensivo (elixir-br)           ║
║      → 2 items, 1 quota, 3 perguntas, 3 pedidos                ║
║    [PUBLICADO] PyNorte Meetup — Agosto 2026 (pynorte)          ║
║      → 2 items, 1 quota, 3 perguntas, 11 pedidos               ║
║    [RASCUNHO]  DevFest Norte 2026 (devsnorte)                  ║
║    [CONCLUÍDO] PyNorte 2025 (pynorte)                          ║
╠══════════════════════════════════════════════════════════════════╣
║  PEDIDOS DE EXEMPLO (usar código na URL /events/:slug/orders/)  ║
║    CONF01 · Mário  · ElixirConf VIP + Estac.  · confirmado    ║
║    CONF02 · Ana    · ElixirConf Regular + Cam. · confirmado    ║
║    CONF03 · Lucas  · ElixirConf Early Bird ×2  · confirmado    ║
║    CONF04 · Renata · ElixirConf Regular (boleto)· pendente     ║
║    CONF05 · Pedro  · ElixirConf Regular + Almoço· confirmado   ║
║    CONF06 · -      · ElixirConf Early Bird      · cancelado    ║
║    CONF07 · Mário  · Workshop Individual        · confirmado   ║
║    CONF08 · Carla  · Workshop Dupla             · confirmado   ║
║    CONF09 · Ana    · Workshop Individual (pix)  · pendente     ║
║    CONF10 · Mário  · PyNorte Apoiador           · confirmado   ║
║    CONF11–16 · PyNorte entradas gratuitas        · confirmados  ║
╚══════════════════════════════════════════════════════════════════╝
""")
