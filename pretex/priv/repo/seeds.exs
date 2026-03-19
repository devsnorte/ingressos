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

now = DateTime.utc_now(:second)
password = "helloworld123"

customer_emails = [
  "mario@example.com",
  "ana@example.com",
  "lucas@example.com",
  "julia@example.com",
  "guest@example.com"
]

Enum.each(customer_emails, fn email ->
  # validate_unique: false skips the pre-flight SELECT so on_conflict: :nothing
  # can handle duplicates cleanly on subsequent seed runs.
  %Customer{}
  |> Customer.email_changeset(%{email: email}, validate_unique: false)
  |> Customer.password_changeset(%{password: password, password_confirmation: password})
  |> Ecto.Changeset.put_change(:confirmed_at, now)
  |> Repo.insert!(on_conflict: :nothing, conflict_target: :email)
end)

IO.puts("   done (#{length(customer_emails)} customers)")

IO.puts("""

✓ Seeds complete!

  Staff users  (no password — request a magic link at /customers/log-in)
    alice@pretex.dev   · admin in Devs do Norte + Elixir Brasil
    bob@pretex.dev     · event manager in Devs do Norte + Elixir Brasil
    carol@pretex.dev   · admin in PyNorte, check-in operator in Devs do Norte

  Customer accounts  (password: helloworld123)
    mario@example.com
    ana@example.com
    lucas@example.com
    julia@example.com
    guest@example.com
""")
