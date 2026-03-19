---
feature: elixir-phoenix-migration
type: brief
parent-prd: 10-product/prd.md
generated: 2026-03-19
source-spec-modified: 2026-03-19
---

# Implementation Brief: Ingressos Migration to Elixir Phoenix

## 1. Feature Overview

Rebuild the Ingressos event ticketing platform from a Django/Python Pretix fork to a native Elixir Phoenix application with full feature parity (28+ domain models, 16 plugins, REST API, multi-tenant) plus a new "Bring Your Own Gateway" (BYOG) model where organizations configure their own payment providers. The migration targets improved real-time capabilities via LiveView, better concurrency on the same Fly.io infrastructure, and a codebase the Devs Norte community can own and extend.

See PRD Section 2 for full problem statement, hypotheses, and success criteria.

---

## 2. Stories Summary & Delivery Phases

### Delivery Phases

1. **Phase A — Foundation (Stories 1-4):** Multi-org, team permissions, customer accounts, and 2FA. These are platform prerequisites — every other feature depends on organizations and authentication existing first. Deliver first to establish the data isolation model and auth patterns that all subsequent work builds on.

2. **Phase B — Event Core (Stories 5-9):** Event management, sub-events, item catalog, quotas, and custom questions. This is the organizer's primary workflow. Blocked by Phase A (events belong to organizations). Deliver second to enable event setup without payment processing.

3. **Phase C — Purchase & Payment (Stories 10-14):** Checkout flow, BYOG configuration, payment processing, order management, and fees. The core revenue path. Blocked by Phase B (need items and quotas for checkout). This phase includes the BYOG adapter pattern — the key architectural differentiator from Pretix. Priority adapters: manual/bank transfer → Pix → Stripe.

4. **Phase D — Pricing & Engagement (Stories 15-19):** Vouchers, discounts, gift cards, memberships, and waiting list. Pricing mechanisms that modify the checkout flow. Blocked by Phase C (need working checkout to apply pricing). These features can be developed somewhat in parallel since they're independent of each other.

5. **Phase E — Check-in (Stories 20-23):** Check-in, lists/gates, device provisioning, and offline sync. The event-day experience. Blocked by Phase C (need confirmed orders to check in). Can be developed in parallel with Phase D.

6. **Phase F — Venue & Finance (Stories 24-26):** Seating plans, tax rules, and invoicing. Specialized features with moderate complexity. Seating blocked by Phase C; invoicing blocked by Phase C + tax rules. Can start in parallel with Phases D/E for tax rules.

7. **Phase G — Communication & Output (Stories 27-29):** Email system, PDF generation, and reporting. Cross-cutting features that enhance existing workflows. Blocked by Phase C (need orders for email, PDFs, and reports). Email is critical path — needed for ticket delivery.

8. **Phase H — Platform & Integration (Stories 30-36):** Custom domains, widget, audit logging, REST API, webhooks, OAuth/OIDC, and multi-language. Platform extensibility layer. Audit logging (Story 32) and multi-language (Story 36) have no blockers and can start early. REST API and webhooks are blocked by core entities existing. Widget blocked by payment processing.

### Stories Table

| # | Phase | Story | File |
|---|-------|-------|------|
| 1 | A | As a platform admin, I want to create and manage organizations, so that multiple groups can use the platform independently | `stories/story-001-multi-organization-support.md` |
| 2 | A | As an organization admin, I want to manage teams and permissions, so that I can control who has access to what | `stories/story-002-team-and-permission-management.md` |
| 3 | A | As an attendee, I want to create an account and manage my profile, so that I can track my orders across events | `stories/story-003-customer-accounts.md` |
| 4 | A | As a user, I want to enable two-factor authentication, so that my account is more secure | `stories/story-004-two-factor-authentication.md` |
| 5 | B | As an organizer, I want to create and manage events, so that I can sell tickets for my events | `stories/story-005-event-creation-and-management.md` |
| 6 | B | As an organizer, I want to create sub-events for event series, so that I can manage recurring events with shared settings | `stories/story-006-sub-events.md` |
| 7 | B | As an organizer, I want to configure items, variations, categories, and bundles, so that I can offer diverse ticket types and merchandise | `stories/story-007-item-and-product-catalog.md` |
| 8 | B | As an organizer, I want to define quotas shared across items, so that I can control total availability accurately | `stories/story-008-quotas-and-availability.md` |
| 9 | B | As an organizer, I want to add custom questions to my event, so that I can collect specific attendee information | `stories/story-009-custom-attendee-questions.md` |
| 10 | C | As an attendee, I want to browse events, select tickets, and complete checkout, so that I can attend events | `stories/story-010-ticket-purchase-and-cart.md` |
| 11 | C | As an organization admin, I want to configure my own payment provider, so that I can receive payments through my preferred gateway | `stories/story-011-byog-payment-provider-configuration.md` |
| 12 | C | As an attendee, I want to pay using the organization's configured gateway, so that I can complete my purchase with my preferred payment method | `stories/story-012-byog-payment-processing.md` |
| 13 | C | As an organizer, I want to view, search, and manage orders, so that I can handle attendee requests and issues | `stories/story-013-order-management.md` |
| 14 | C | As an organizer, I want to configure and apply fees to orders, so that I can cover service or handling costs | `stories/story-014-order-fees.md` |
| 15 | D | As an organizer, I want to create and manage voucher codes, so that I can offer promotions and special access | `stories/story-015-vouchers.md` |
| 16 | D | As an organizer, I want to create automatic discount rules, so that attendees get the best price without needing a code | `stories/story-016-discounts.md` |
| 17 | D | As an organizer, I want to issue and manage gift cards, so that attendees can use stored value across my events | `stories/story-017-gift-cards.md` |
| 18 | D | As an organizer, I want to create membership programs, so that I can offer recurring benefits to loyal attendees | `stories/story-018-memberships.md` |
| 19 | D | As an attendee, I want to join a waiting list for sold-out tickets, so that I can be notified when availability returns | `stories/story-019-waiting-list.md` |
| 20 | E | As a check-in operator, I want to scan QR codes and search attendees, so that I can validate entry at events | `stories/story-020-check-in.md` |
| 21 | E | As an organizer, I want to configure check-in lists and gates, so that I can control entry at different venue points | `stories/story-021-check-in-lists-and-gates.md` |
| 22 | E | As an organizer, I want to provision check-in devices, so that volunteers can check in attendees using their phones | `stories/story-022-device-provisioning.md` |
| 23 | E | As a check-in device, I want to sync data for offline use, so that check-in works even with poor connectivity | `stories/story-023-data-synchronization-offline-check-in.md` |
| 24 | F | As an organizer, I want to upload seating plans and let attendees choose seats, so that I can manage seated events | `stories/story-024-seating-plans.md` |
| 25 | F | As an organizer, I want to configure tax rules, so that prices and invoices reflect correct tax calculations | `stories/story-025-tax-rules.md` |
| 26 | F | As an organizer, I want invoices generated automatically for orders, so that I have proper financial records | `stories/story-026-invoicing.md` |
| 27 | G | As an organizer, I want the system to send transactional and bulk emails, so that attendees stay informed | `stories/story-027-email-and-notification-system.md` |
| 28 | G | As an organizer, I want to generate PDF tickets and badges, so that attendees have printable entry passes | `stories/story-028-badge-and-ticket-pdf-generation.md` |
| 29 | G | As an organizer, I want to view reports and export data, so that I can analyze event performance | `stories/story-029-reporting-and-data-export.md` |
| 30 | H | As an organization admin, I want to configure a custom domain, so that my event pages use my own branding | `stories/story-030-multi-domain-support.md` |
| 31 | H | As an organizer, I want to embed a ticket widget on external websites, so that attendees can buy tickets without leaving my site | `stories/story-031-embeddable-ticket-widget.md` |
| 32 | H | As an organizer, I want all changes logged in an audit trail, so that I can track who changed what and when | `stories/story-032-audit-logging.md` |
| 33 | H | As a developer, I want a comprehensive REST API, so that I can integrate external systems with the platform | `stories/story-033-rest-api.md` |
| 34 | H | As an organizer, I want to configure webhooks, so that external systems are notified of platform events | `stories/story-034-webhooks.md` |
| 35 | H | As a developer, I want the platform to act as an OAuth/OIDC provider, so that third-party apps can authenticate users | `stories/story-035-oauth-oidc-provider.md` |
| 36 | H | As an organizer, I want the platform available in multiple languages, so that attendees and organizers can use it in their preferred language | `stories/story-036-multi-language-support.md` |

### Critical Path

The critical path for a minimum viable paid event is: **Phase A → Phase B → Phase C → Story 27 (email for ticket delivery) → Story 28 (PDF ticket generation)**. This enables: create org → configure event → set up payment → sell tickets → deliver tickets via email. All other features enhance this core flow but are not required for first paid event.

---

## 3. Consolidated Acceptance Criteria

### Foundation & Authentication
- [S1] Platform admin can create, edit, list, and delete organizations with unique identifiers and isolated data
- [S1] Deleting an organization requires typing a confirmation phrase
- [S2] Organization admin can invite members by email, assign roles (admin, event manager, check-in operator), and configure granular permissions scoped to events
- [S2] Removing a team member revokes sessions; last admin cannot be removed
- [S3] Attendees can register with email/password (optional), or purchase as guests with unique order links
- [S3] Authenticated users see cross-org order history; LGPD data export and deletion supported
- [S4] Users can enable TOTP, WebAuthn/FIDO2, and generate recovery codes; orgs can mandate 2FA for team members

### Event Management
- [S5] Organizers create events (draft → published → completed) with name, dates, venue, branding; cloneable
- [S5] Events require at least one ticket type to publish
- [S6] Events support sub-events with inherited catalog, overridable pricing/quotas, independent publishing
- [S6] Parent catalog changes propagate unless sub-event has explicit override
- [S7] Items have variations, categories, bundles, add-ons, min/max per order, voucher-gated visibility
- [S8] Shared quotas across items/variations; atomic reservation prevents overselling; real-time updates within 2 seconds
- [S9] Custom questions (12 types) scoped to items; configurable built-in fields; conditional visibility

### Purchase & Payment
- [S10] Attendees browse published events, select items, fill attendee info + custom questions, see pricing summary
- [S10] Cart reservations: 15 min (instant), 30 min (redirect), 3 days (bank transfer); 7-day hard max if payment in-flight
- [S10] One voucher per order; auto-discounts can stack with voucher (configurable); pricing order: membership → discount → voucher → gift card
- [S11] BYOG: admins configure providers (manual → Pix → Stripe initially), enter credentials (encrypted, last-4 shown), validate via sandbox/test mode, rotate keys without downtime
- [S11] Only org admins access credentials; session revocation on admin removal
- [S12] Inline payment for Stripe/Pix; redirect for PayPal/Mercado Pago; async confirmation for Pix/boleto/bank transfer
- [S12] Late payment after reservation expiry + sold-out triggers automatic refund + notification
- [S12] Webhook routing via org-specific token; payload validated against org credentials
- [S13] Searchable/filterable order list; order detail with audit history; resend tickets, modify orders (locks attendee edits), cancel/refund with confirmation
- [S13] Manual order creation; partial refunds supported
- [S14] Fee types: service, shipping, cancellation, custom (fixed or percentage); auto-apply via rules; visible at checkout

### Pricing & Engagement
- [S15] Vouchers: individual or bulk, discount/custom price/reveal items/reserve quota; usage limits, expiry, item scoping, tags
- [S16] Automatic discounts: condition-based, best-discount wins, stackable with vouchers (configurable)
- [S17] Gift cards: manual or purchasable, cross-event within org, partial redemption, refund restores balance (even if expired)
- [S18] Memberships: types with validity periods, benefits (discounts, access, priority); sold or granted; validated at checkout
- [S19] Waiting list: FIFO, auto-voucher on availability, configurable purchase window (default 24h)

### Check-in
- [S20] QR scan or name/email search; validate ticket (event, list, not checked in, not cancelled); clear success/error; annul check-in
- [S20] Real-time count within 2 seconds; web check-in requires connectivity
- [S21] Multiple check-in lists per event with item/variation/time filters; gates assigned to lists; search and scan flows
- [S22] Device provisioning via initialization token; status reporting; org-scoped; revocable with confirmation
- [S23] Download data for offline use (scoped to assigned lists); incremental sync; conflict resolution favors earliest timestamp

### Venue & Finance
- [S24] Upload predefined seating layout; map seats to items/quotas; attendee seat selection at checkout; manual assign/reassign
- [S25] Tax rules: rates, names, conditions (country, item type); inclusive or additive; multiple rules per item; shown at checkout
- [S26] Auto-generate invoices on payment; manual generation; credit notes on refund/cancel; sequential gap-free numbering; immutable; PDF download

### Communication & Output
- [S27] Transactional emails (confirmation, reminder, ticket, waiting list); customizable templates per event with preview; bulk send to filtered groups; async mail queue with retry
- [S28] PDF tickets with QR codes + branding; downloadable; predefined badge templates with configurable fields; bulk badge generation
- [S29] Sales summary, attendance report, financial overview; CSV/Excel export; scheduled exports (email or stored, 30-day retention, 100MB max)

### Platform & Integration
- [S30] Custom domain per org; DNS instructions; auto-SSL provisioning
- [S31] Embeddable widget; inline flow for Stripe/Pix, redirect for PayPal/Mercado Pago; responsive; event branding
- [S32] Immutable audit log: actor, timestamp, entity, description; system actions logged; filterable by event/entity/time/actor
- [S33] REST API: all entities, API token + OAuth auth, pagination/filtering/ordering, rate limiting, backward compatibility
- [S34] Webhooks: register URLs for events, signed payloads, retry with backoff, delivery history visible
- [S35] OAuth/OIDC provider: register apps with redirect URIs + scopes, authorization code flow, token refresh, scope control
- [S36] PT-BR + EN; auto-detect language; translatable event content with fallback; extensible via translation files

---

## 4. Consolidated Test Plan

| Source | Tier 1 | Tier 2 | Total |
|--------|--------|--------|-------|
| S1 — Multi-Organization Support | 5 | 4 | 9 |
| S2 — Team and Permission Management | 6 | 5 | 11 |
| S3 — Customer Accounts | 5 | 5 | 10 |
| S4 — Two-Factor Authentication | 4 | 5 | 9 |
| S5 — Event Creation and Management | 5 | 5 | 10 |
| S6 — Sub-Events | 5 | 4 | 9 |
| S7 — Item and Product Catalog | 6 | 5 | 11 |
| S8 — Quotas and Availability | 4 | 5 | 9 |
| S9 — Custom Attendee Questions | 4 | 5 | 9 |
| S10 — Ticket Purchase and Cart | 7 | 6 | 13 |
| S11 — BYOG Configuration | 6 | 6 | 12 |
| S12 — BYOG Payment Processing | 5 | 6 | 11 |
| S13 — Order Management | 6 | 6 | 12 |
| S14 — Order Fees | 3 | 5 | 8 |
| S15 — Vouchers | 5 | 6 | 11 |
| S16 — Discounts | 4 | 5 | 9 |
| S17 — Gift Cards | 5 | 6 | 11 |
| S18 — Memberships | 4 | 5 | 9 |
| S19 — Waiting List | 4 | 5 | 9 |
| S20 — Check-in | 5 | 6 | 11 |
| S21 — Check-in Lists and Gates | 4 | 4 | 8 |
| S22 — Device Provisioning | 4 | 4 | 8 |
| S23 — Data Sync (Offline) | 4 | 5 | 9 |
| S24 — Seating Plans | 5 | 5 | 10 |
| S25 — Tax Rules | 4 | 5 | 9 |
| S26 — Invoicing | 4 | 5 | 9 |
| S27 — Email and Notifications | 5 | 5 | 10 |
| S28 — Badge and Ticket PDF | 4 | 4 | 8 |
| S29 — Reporting and Export | 5 | 5 | 10 |
| S30 — Multi-Domain Support | 3 | 5 | 8 |
| S31 — Embeddable Widget | 4 | 4 | 8 |
| S32 — Audit Logging | 3 | 4 | 7 |
| S33 — REST API | 5 | 5 | 10 |
| S34 — Webhooks | 4 | 5 | 9 |
| S35 — OAuth/OIDC Provider | 4 | 5 | 9 |
| S36 — Multi-Language Support | 3 | 4 | 7 |
| **TOTAL** | **~163** | **~178** | **~341** |

**Key Tier 1 coverage:** Happy path for every AC — organization CRUD, team invitation flow, full checkout lifecycle, payment via each BYOG adapter type, order management actions, check-in scan/search, all pricing mechanisms, PDF/badge generation, API CRUD for all entities.

**Key Tier 2 coverage:** Concurrency (simultaneous last-ticket reservation, concurrent seat selection, parallel check-in on same ticket), race conditions (late async payment after reservation expiry), security (cross-org data access, credential handling, webhook validation), boundaries (quota exhaustion, max export size, bulk generation limits), error states (invalid QR codes, expired vouchers, gateway failures, SMTP unavailable), empty states (no orders, no events, empty waiting list).

> Full Gherkin scenarios are in each story's inline Test Plan section.

---

## 5. Elixir/Phoenix Architecture Guide

This section provides Elixir-specific architectural patterns for the migration. It is informed by Phoenix, Ecto, OTP, and Oban best practices.

### 5.1 Phoenix Contexts (Bounded Contexts)

Organize the application into contexts following DDD principles. Each context owns its schemas, changesets, and business logic. Cross-context references use IDs, not associations.

**Proposed contexts:**

| Context | Responsibility | Key Entities |
|---------|---------------|--------------|
| `Ingressos.Accounts` | User registration, authentication, 2FA, OAuth/OIDC | User, CustomerProfile, AuthToken |
| `Ingressos.Organizations` | Multi-org management, teams, permissions, branding | Organization, Team, TeamMember, Permission |
| `Ingressos.Events` | Event lifecycle, sub-events, venue details | Event, SubEvent, EventSettings |
| `Ingressos.Catalog` | Items, variations, categories, bundles, add-ons, custom questions | Item, ItemVariation, ItemCategory, ItemBundle, Question |
| `Ingressos.Quotas` | Quota management, availability tracking | Quota, QuotaItem |
| `Ingressos.Orders` | Cart, checkout, order lifecycle, fees | Order, OrderPosition, OrderFee, CartReservation |
| `Ingressos.Payments` | BYOG configuration, payment processing, refunds, gift cards | PaymentProvider, Payment, Refund, GiftCard, GiftCardTransaction |
| `Ingressos.Pricing` | Vouchers, discounts, memberships, pricing pipeline | Voucher, VoucherTag, Discount, Membership, MembershipType |
| `Ingressos.CheckIn` | Check-in operations, lists, gates, device sync | CheckIn, CheckInList, Gate, Device |
| `Ingressos.Seating` | Seating plans, seat assignments | SeatingPlan, Seat, SeatAssignment |
| `Ingressos.Finance` | Tax rules, invoicing | TaxRule, Invoice |
| `Ingressos.Notifications` | Email templates, mail queue, bulk messaging | EmailTemplate, MailJob |
| `Ingressos.Exports` | Reporting, data export, PDF generation, scheduled exports | ExportConfig, ScheduledExport |
| `Ingressos.Audit` | Immutable audit logging | AuditLog |
| `Ingressos.Webhooks` | Webhook registration, delivery, retry | WebhookEndpoint, WebhookDelivery |
| `Ingressos.Integrations` | REST API, widget, multi-domain | ApiToken, WidgetConfig, CustomDomain |

**Cross-context rule:** Contexts reference each other by ID only. For example, `Orders` stores `event_id` and `organization_id` as plain fields, NOT as `belongs_to` associations to `Events` or `Organizations` schemas. Query through context functions:

```elixir
# CORRECT: Query through context
event = Events.get_event!(event_id)

# WRONG: Cross-context belongs_to
schema "orders" do
  belongs_to :event, Ingressos.Events.Event  # DON'T
end
```

### 5.2 Ecto & Multi-Tenancy

**Composite foreign keys for organization scoping.** Every tenant-scoped entity carries `organization_id`. Use composite foreign keys to enforce isolation at the database level:

```elixir
# In migrations
add :event_id, references(:events, with: [organization_id: :organization_id], match: :full)
```

**Automatic query scoping with `prepare_query/3`.** Use a custom Repo callback to ensure all queries are scoped to the current organization. Raise if `organization_id` is missing:

```elixir
def prepare_query(_operation, query, opts) do
  if org_id = opts[:org_id] do
    {from(q in query, where: q.organization_id == ^org_id), opts}
  else
    raise "organization_id required for multi-tenant queries"
  end
end
```

**Multiple changesets per schema.** Different operations need different validations — don't use a single changeset:

```elixir
# Event schema
def creation_changeset(event, attrs)    # name, dates, venue required
def publish_changeset(event, attrs)     # validates has items
def branding_changeset(event, attrs)    # logo, banner, colors only
```

**Embedded schemas for forms/validation.** Use `embedded_schema` for checkout forms, payment configuration forms, and other validation-only structures that don't map directly to a table.

### 5.3 Phoenix LiveView Architecture

**The Iron Law: NO database queries in `mount/3`.** Mount is called twice (HTTP + WebSocket). All data loading goes in `handle_params/3`:

```elixir
# Event page LiveView
def mount(_params, _session, socket) do
  # Setup only — no queries
  {:ok, assign(socket, loading: true)}
end

def handle_params(%{"event_id" => id}, _uri, socket) do
  # Data loading here — called once per navigation
  event = Events.get_published_event!(id)
  items = Catalog.list_available_items(event.id)
  {:noreply, assign(socket, event: event, items: items, loading: false)}
end
```

**Scoped PubSub topics.** In a multi-tenant app, ALL PubSub topics must include the organization scope to prevent data leaks:

```elixir
# CORRECT: Scoped topic
Phoenix.PubSub.subscribe(Ingressos.PubSub, "quotas:org:#{org_id}:event:#{event_id}")

# WRONG: Unscoped topic — data leak across orgs
Phoenix.PubSub.subscribe(Ingressos.PubSub, "quotas:event:#{event_id}")
```

**Real-time updates (within 2 seconds).** Use PubSub broadcasts for:
- **Quota availability**: Broadcast on every reservation/purchase/cancellation. Event pages subscribe and update in real time.
- **Check-in counts**: Broadcast on every check-in/annul. Dashboard LiveViews subscribe.
- **Order status**: Broadcast on payment confirmation. Order management LiveViews subscribe.

```elixir
# After a successful purchase
Phoenix.PubSub.broadcast(Ingressos.PubSub,
  "quotas:org:#{org_id}:event:#{event_id}",
  {:quota_updated, %{item_id: item_id, available: new_count}})
```

**assign_async for non-critical data.** Use `assign_async/3` for data that can load after the page renders (e.g., reports, statistics, audit logs).

**Components hierarchy:**
- **Functional components**: Display-only (ticket card, order row, seat map cell)
- **LiveComponents**: Own state + events (checkout form, seat selector, voucher input)
- **LiveViews**: Full pages with URL ownership (event page, dashboard, order list)

**Webhook raw body.** For BYOG payment webhooks, read the raw body BEFORE Plug.Parsers to verify signatures:

```elixir
# In a custom Plug, not in the general pipeline
{:ok, body, conn} = Plug.Conn.read_body(conn)
verify_webhook_signature!(conn, body, provider)
```

### 5.4 OTP Patterns

**The Iron Law: GenServer is a bottleneck by design.** Don't reach for GenServer by default. Use the abstraction decision tree:

**Cart Reservation System — ETS + GenServer pattern:**
- A GenServer manages cart reservation state but writes to an ETS table with `:read_concurrency`
- Reads (checking if a seat/quota is reserved) bypass the GenServer entirely via ETS lookups
- Writes (creating/expiring reservations) serialize through the GenServer
- The GenServer uses `Process.send_after/3` for reservation expiry timers
- On expiry, broadcast via PubSub to update availability in real time

```elixir
# Reservation check — fast, concurrent ETS read (no GenServer bottleneck)
def reserved?(event_id, item_id) do
  case :ets.lookup(:cart_reservations, {event_id, item_id}) do
    [{_, count}] when count > 0 -> true
    _ -> false
  end
end

# Reserve — serialized through GenServer for atomicity
def reserve(event_id, item_id, quantity) do
  GenServer.call(ReservationServer, {:reserve, event_id, item_id, quantity})
end
```

**Quota atomicity — Database-level locking, not GenServer:**
- Use `SELECT ... FOR UPDATE` via Ecto for atomic quota checks during purchase
- Don't serialize all purchases through a single GenServer — that would bottleneck the entire platform
- Database row-level locks provide concurrency with correctness

```elixir
# Atomic quota check + decrement in a transaction
Repo.transaction(fn ->
  quota = Repo.one!(from q in Quota, where: q.id == ^quota_id, lock: "FOR UPDATE")
  if quota.available >= quantity do
    Quota.changeset(quota, %{available: quota.available - quantity}) |> Repo.update!()
  else
    Repo.rollback(:sold_out)
  end
end)
```

**External polling with GenServer + PubSub:** For async payment status checks (Pix, boleto), use a single GenServer that polls the payment provider and broadcasts status updates — NOT one LiveView polling per connected user.

**Supervision tree:**

```
Ingressos.Application
├── Ingressos.Repo (Ecto)
├── Ingressos.PubSub (Phoenix.PubSub)
├── IngressosWeb.Endpoint (Phoenix)
├── Ingressos.CartReservationSupervisor (DynamicSupervisor)
│   └── Ingressos.CartReservation (GenServer per active cart — short-lived)
├── {Oban, oban_config()}
├── Ingressos.DeviceRegistry (Registry for provisioned devices)
└── Ingressos.PaymentPollerSupervisor (DynamicSupervisor)
    └── Ingressos.PaymentPoller (GenServer per pending async payment)
```

**Strategy reasoning:**
- `:one_for_one` at the top level — services are independent
- `DynamicSupervisor` for carts and payment pollers — created on demand, short-lived
- `Registry` for device tracking — named dynamic processes without atom creation

**Task.Supervisor for concurrent operations:** Use `Task.Supervisor.async_nolink/2` for:
- Bulk badge PDF generation
- Bulk email sending
- Data export file generation
- Waiting list offer distribution

### 5.5 Oban for Background Jobs

**Use Oban (not Broadway, not bare GenServer) for all background jobs.** The platform needs database-persisted, retryable jobs with visibility.

**Queue design:**

| Queue | Concurrency | Jobs |
|-------|-------------|------|
| `:default` | 10 | General-purpose |
| `:mail` | 5 | Transactional and bulk emails |
| `:pdf` | 3 | Ticket and badge PDF generation |
| `:exports` | 2 | CSV/Excel data exports (memory-intensive) |
| `:payments` | 5 | Async payment confirmation polling, refund processing |
| `:webhooks` | 10 | Webhook delivery with retry |
| `:scheduled` | 2 | Scheduled exports, waiting list offers, reservation expiry cleanup |

**Key job patterns:**

**Email delivery — let it crash:**
```elixir
defmodule Ingressos.Workers.SendEmail do
  use Oban.Worker, queue: :mail, max_attempts: 5

  @impl true
  def perform(%Oban.Job{args: %{"template" => template, "to" => to, "data" => data}}) do
    # String keys! JSON serialization converts atoms to strings
    Ingressos.Mailer.deliver!(template, to, data)
    :ok
  end
end
```

**Async payment polling — snooze pattern:**
```elixir
defmodule Ingressos.Workers.PollPayment do
  use Oban.Worker, queue: :payments, max_attempts: 100

  def perform(%Oban.Job{args: %{"payment_id" => id, "provider" => provider}}) do
    case Payments.check_status(id, provider) do
      {:confirmed, details} -> Payments.confirm!(id, details)
      {:failed, reason} -> {:error, reason}
      :pending -> {:snooze, 30}  # Check again in 30 seconds
    end
  end
end
```

**Webhook delivery — simple chaining, unique jobs:**
```elixir
defmodule Ingressos.Workers.DeliverWebhook do
  use Oban.Worker,
    queue: :webhooks,
    max_attempts: 5,
    unique: [period: 60, keys: ["endpoint_id", "event_type", "entity_id"]]

  def perform(%Oban.Job{args: %{"endpoint_id" => eid, "payload" => payload}}) do
    case Webhooks.deliver(eid, payload) do
      {:ok, _response} -> :ok
      {:error, :timeout} -> {:error, :timeout}  # Oban retries with backoff
      {:error, :not_found} -> {:cancel, :endpoint_removed}  # Don't retry
    end
  end
end
```

**Bulk operations — chunking, not one-job-per-item:**
```elixir
# For sending waiting list offers to 1000 people
waiting_entries
|> Enum.chunk_every(50)
|> Enum.each(fn chunk ->
  ids = Enum.map(chunk, & &1.id)
  Ingressos.Workers.SendWaitingListOffers.new(%{entry_ids: ids})
  |> Oban.insert()
end)
```

**Scheduled exports — Oban cron:**
```elixir
# In Oban config
config :ingressos, Oban,
  plugins: [
    {Oban.Plugins.Cron, crontab: [
      {"0 * * * *", Ingressos.Workers.ProcessScheduledExports}
    ]}
  ]
```

### 5.6 BYOG Payment Adapter — Behaviour Pattern

Use a **Behaviour** (not Protocol, not GenServer) for payment provider adapters. Behaviours are the simplest correct abstraction — module polymorphism with upfront contract:

```elixir
defmodule Ingressos.Payments.Adapter do
  @doc "Validate provider credentials without charging"
  @callback validate_credentials(config :: map()) ::
    {:ok, :valid} | {:error, String.t()}

  @doc "Create a payment intent/charge"
  @callback create_payment(config :: map(), amount :: integer(), currency :: String.t(), metadata :: map()) ::
    {:ok, payment_ref :: String.t()} | {:redirect, url :: String.t()} | {:error, String.t()}

  @doc "Process a refund"
  @callback refund(config :: map(), payment_ref :: String.t(), amount :: integer()) ::
    {:ok, refund_ref :: String.t()} | {:error, String.t()}

  @doc "Parse and validate an incoming webhook payload"
  @callback parse_webhook(config :: map(), raw_body :: binary(), headers :: map()) ::
    {:ok, event :: map()} | {:error, :invalid_signature}

  @doc "Return supported payment methods for this provider"
  @callback payment_methods(config :: map()) :: [atom()]
end
```

**Adapter implementations:**

```elixir
defmodule Ingressos.Payments.Adapters.Manual do
  @behaviour Ingressos.Payments.Adapter
  # Built-in, no external API. Organizer manually confirms payments.
end

defmodule Ingressos.Payments.Adapters.Pix do
  @behaviour Ingressos.Payments.Adapter
  # Async payment — returns QR code, confirmation via webhook
end

defmodule Ingressos.Payments.Adapters.Stripe do
  @behaviour Ingressos.Payments.Adapter
  # Inline + redirect, sync + async confirmation
end
```

**Routing to the correct adapter:**

```elixir
defmodule Ingressos.Payments do
  def adapter_for(provider_type) do
    case provider_type do
      "manual" -> Ingressos.Payments.Adapters.Manual
      "pix" -> Ingressos.Payments.Adapters.Pix
      "stripe" -> Ingressos.Payments.Adapters.Stripe
    end
  end

  def create_payment(provider, amount, currency, metadata) do
    adapter = adapter_for(provider.type)
    adapter.create_payment(provider.config, amount, currency, metadata)
  end
end
```

### 5.7 Testing Strategy

**Async tests by default.** Avoid global state:
- Pass organization scope explicitly (not via `Application.put_env`)
- Use Ecto sandbox for database isolation
- Use `Mox` for payment adapter mocking with explicit allowances

```elixir
# Define mock in test_helper.exs
Mox.defmock(Ingressos.Payments.AdapterMock, for: Ingressos.Payments.Adapter)

# In test — async: true
test "processes payment", %{org: org} do
  Ingressos.Payments.AdapterMock
  |> expect(:create_payment, fn _config, 5000, "BRL", _meta ->
    {:ok, "pay_123"}
  end)

  assert {:ok, order} = Orders.complete_checkout(org, cart, adapter: AdapterMock)
end
```

**Oban testing:** Use `Oban.Testing` helpers. Don't use inline mode for workflow tests — they need database interaction.

**LiveView testing:** Use `Phoenix.LiveViewTest` for integration tests of real-time flows (checkout, check-in, quota updates).

### 5.8 Deployment on Fly.io

- **Single release** with `mix release` — no separate Celery/Redis needed
- **Oban replaces Celery** — jobs stored in PostgreSQL, no Redis dependency
- **Phoenix PubSub replaces Redis pub/sub** — single-node PubSub is sufficient for initial deployment; switch to `Phoenix.PubSub.PG2` or Redis adapter if clustering
- **LiveView replaces JavaScript polling** — persistent WebSocket connections for real-time updates
- **OTP supervision replaces Supervisor(d)** — process management is built into the BEAM
- **Consider `POOL_SIZE`** carefully — Fly.io shared-cpu-2x with 2GB RAM. Start with `pool_size: 10` for Repo, tune based on connection usage

---

## 6. Constraints, Decisions & Risks

**Constraints & Assumptions** — See PRD Sections 5 and 6. Key constraints for architecture:

- **Single deployable application** on Fly.io (GRU region), 2GB RAM shared-cpu-2x. The BEAM VM must handle web requests, real-time connections, background jobs (email, PDF generation, scheduled exports), and payment webhook processing within this envelope.
- **PostgreSQL** as primary database (carried over from current stack). Multi-tenant data isolation must be enforced at the query level — all entities scoped to organization.
- **Real-time = within 2 seconds** for all live-updating features (quotas, check-in counts, dashboard updates). This defines the Phoenix PubSub/Channel architecture requirements.
- **BYOG adapter pattern** replaces Pretix's plugin system for payments. Each adapter implements a common interface (charge, refund, validate credentials, parse webhook). Adapters for manual/bank transfer, Pix, and Stripe required at launch.
- **Credential security**: Payment credentials encrypted at rest, never fully displayed, rotation without downtime. This affects storage design and secrets management.
- **WCAG 2.1 AA** for attendee-facing pages. Keyboard-navigable organizer panel.
- **LGPD compliance**: Data export and account deletion for customers.
- **Greenfield rebuild** — no schema migration from Pretix. Data migration is a separate workstream.

**Key Decisions** — See PRD Decisions Log (19 decisions). Decisions with architectural impact:

| # | Decision | Architect Implication |
|---|----------|---------------------|
| 1 | Variable cart reservation by payment method (15m/30m/3d, 7d hard max) | Reservation system needs configurable TTLs per payment method, with extension logic for in-flight payments. Consider GenServer or ETS-based timers. |
| 3 | Late async payment → auto-refund when quota exhausted | Payment confirmation handler must check quota state atomically and trigger refund through the original adapter. Requires transactional safety. |
| 4 | Webhook routing via org-specific token + credential validation | Webhook endpoint design: single endpoint with org token in URL path. Middleware must validate payload against org's stored provider credentials before dispatching. |
| 7 | Pricing evaluation order: membership → discounts → voucher → gift card | Cart calculation pipeline must enforce deterministic ordering. Gift card deduction is always last (applied to monetary total, not to item prices). |
| 8 | Seating plan v1: upload-only, no visual editor | Seating layout needs a structured data format (JSON/CSV). Interactive SVG rendering for attendee seat selection at checkout. No editor component needed in v1. |
| 10 | BYOG adapter priority: manual → Pix → Stripe | Adapter interface must be designed before any implementation. Manual adapter validates the interface design; Pix adds async payment complexity; Stripe adds redirect + inline complexity. |
| 11 | Real-time = within 2 seconds | PubSub architecture must broadcast quota changes, check-in events, and order status updates. LiveView subscriptions for dashboards and event pages. |
| 12 | Offline check-in only via provisioned devices, not web | Device sync API needs incremental download (delta sync by timestamp), offline queue with conflict resolution (earliest timestamp wins), and batch upload on reconnect. |
| 13 | Bank transfer reconciliation: OFX + configurable CSV | File parser needs pluggable format support. OFX parser for Brazilian banks, CSV with user-defined column mapping. Matching algorithm for payment → order association. |
| 18 | Concurrent order modification: organizer locks attendee edits | Optimistic or pessimistic locking on orders. When an organizer begins editing, the order enters a "locked" state visible to the attendee with a clear message. |

**Open Risks** — Unresolved findings from the PRD that may influence technical choices:

- **Data migration strategy**: Not yet decided whether to migrate historical data or start fresh. This affects schema design (must accommodate legacy IDs if migrating) and timeline.
- **Pretix Droid compatibility**: Not yet decided if the device API must be backward-compatible with existing Pretix Droid app. This constrains the check-in API design.
- **Notification channels**: WhatsApp/SMS not yet decided. If yes, affects the notification system architecture (multi-channel dispatch).
- **BYOG adapter contribution model**: Community contribution process for new adapters not yet defined. Affects adapter isolation/sandboxing design.
- **Widget technology**: LiveView vs standalone JS widget not yet decided. LiveView requires persistent connection; JS widget is more embeddable but duplicates frontend logic.
- **Invoice fiscal requirements**: Specific Brazilian fiscal format TBD with legal review. May require integration with government systems (NFS-e).

---

## 6. Story Assumptions

| Story | Assumption |
|-------|-----------|
| S3 | Password requirements follow OWASP guidelines (min 8 chars, no specific complexity beyond length) |
| S5 | Visual branding assets (logo, banner) have reasonable file size limits enforced by the platform |
| S6 | Parent event's catalog must exist before sub-events can be created |
| S7 | Prices are displayed in the organizer's configured currency |
| S9 | File upload questions are subject to platform-wide storage limits; conditional visibility may be deferred |
| S10 | Reservation durations are configurable per event; QR codes are unique per ticket position, not per order |
| S11 | Manual/bank transfer provider is built-in (no external credentials); webhook endpoints auto-provisioned; session revocation includes API tokens |
| S12 | Payment provider SDKs handle PCI compliance; platform never stores raw card numbers; refund timing depends on provider |
| S13 | Partial refunds supported only if gateway supports them; manual orders can be complimentary or paid |
| S14 | Cancellation fees deducted from refunds; fee rules evaluated at checkout time (not retroactive); percentage fees on pre-fee subtotal |
| S15 | Voucher codes unique within event scope; checkout flow integrates voucher entry |
| S16 | Discount evaluation occurs during cart calculation in real time |
| S17 | Gift card codes unique across platform (not just within org) to prevent cross-org collisions |
| S18 | Customer account required to hold a membership (persistent identity needed) |
| S19 | One ticket offered per waiting list entry; configurable offer window defaults to 24h |
| S20 | Multi-entry is a per-list configuration; QR codes encode a unique ticket identifier |
| S21 | Unlimited check-in lists/gates per event; time restrictions use event timezone; gates need at least one list |
| S22 | Initialization tokens expire in 24h (configurable); device linked to one org; revocation preserves historical check-in records |
| S23 | Devices store synced data securely on local storage; conflict resolution per check-in list; large syncs warn on cellular |
| S24 | v1 upload-only (no visual editor); seat reservations aligned with cart expiration; layout format TBD (JSON/CSV) |
| S26 | Brazilian fiscal format TBD with legal review; invoice numbering gap-free per org |
| S28 | v1 predefined badge templates (no visual editor); QR codes encode ticket identifier; bulk generation may be async |
| S29 | Stored exports retained 30 days, max 100MB, larger exports split |
| S30 | One custom domain per org; auto-SSL renewal; removing domain doesn't break default-domain links |
| S31 | Widget loads asynchronously (non-blocking); cross-origin-safe; styling from event branding only |
| S32 | Audit logs retained indefinitely; no one can modify/delete entries; high-frequency read-only actions not logged |
| S33 | API docs auto-generated; rate limits configurable per token type; initial version is v1 |
| S34 | Webhook endpoints must use HTTPS; signing secret generated per webhook; max 5 retries (configurable); 10s timeout |
| S35 | OIDC discovery endpoint; authorization codes single-use (10 min expiry); app review is manual |
| S36 | PT-BR is default language; date/time/currency formatting adapts to locale; new languages added via translation files only |

---

## 7. References

- **PRD:** `10-product/prd.md`
- **Stories:**
  - `stories/story-001-multi-organization-support.md`
  - `stories/story-002-team-and-permission-management.md`
  - `stories/story-003-customer-accounts.md`
  - `stories/story-004-two-factor-authentication.md`
  - `stories/story-005-event-creation-and-management.md`
  - `stories/story-006-sub-events.md`
  - `stories/story-007-item-and-product-catalog.md`
  - `stories/story-008-quotas-and-availability.md`
  - `stories/story-009-custom-attendee-questions.md`
  - `stories/story-010-ticket-purchase-and-cart.md`
  - `stories/story-011-byog-payment-provider-configuration.md`
  - `stories/story-012-byog-payment-processing.md`
  - `stories/story-013-order-management.md`
  - `stories/story-014-order-fees.md`
  - `stories/story-015-vouchers.md`
  - `stories/story-016-discounts.md`
  - `stories/story-017-gift-cards.md`
  - `stories/story-018-memberships.md`
  - `stories/story-019-waiting-list.md`
  - `stories/story-020-check-in.md`
  - `stories/story-021-check-in-lists-and-gates.md`
  - `stories/story-022-device-provisioning.md`
  - `stories/story-023-data-synchronization-offline-check-in.md`
  - `stories/story-024-seating-plans.md`
  - `stories/story-025-tax-rules.md`
  - `stories/story-026-invoicing.md`
  - `stories/story-027-email-and-notification-system.md`
  - `stories/story-028-badge-and-ticket-pdf-generation.md`
  - `stories/story-029-reporting-and-data-export.md`
  - `stories/story-030-multi-domain-support.md`
  - `stories/story-031-embeddable-ticket-widget.md`
  - `stories/story-032-audit-logging.md`
  - `stories/story-033-rest-api.md`
  - `stories/story-034-webhooks.md`
  - `stories/story-035-oauth-oidc-provider.md`
  - `stories/story-036-multi-language-support.md`
- **GitHub Issues:** [devsnorte/ingressos issues with label `agentic-workflow`](https://github.com/devsnorte/ingressos/issues?q=label%3Aagentic-workflow)
