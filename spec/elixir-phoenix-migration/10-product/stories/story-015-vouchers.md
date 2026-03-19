---
id: story-015
title: Vouchers
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-007-item-and-product-catalog
---

# Story 015: Vouchers

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-015                                  |
| **Title**      | Vouchers                                   |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-007-item-and-product-catalog         |

## Summary

As an organizer, I want to create and manage voucher codes, so that I can offer promotions and special access

## Description

### Context

Organizers frequently need promotional tools to drive ticket sales, reward partners, or provide special access to certain attendee groups. Voucher codes are a flexible mechanism that can serve multiple purposes: discounts, hidden item reveals, quota reservations, and access to restricted items.

### User Value

Organizers can create targeted promotions using voucher codes with a variety of effects — from simple percentage discounts to unlocking hidden ticket types. Bulk generation saves time for large campaigns, and usage limits with expiration dates give organizers full control over how promotions are used.

### Approach

Provide a voucher management interface where organizers can create individual codes or generate batches, configure the voucher effect (discount, reveal, reserve, access), set usage rules, and organize vouchers with tags. Attendees enter a single voucher code at checkout, and the system enforces all configured rules.

## Acceptance Criteria

### 1. Voucher Creation

1. **Create Voucher**: Organizer can create individual voucher codes with: fixed or percentage discount, custom price, reveal hidden items, reserve quota, or grant access to restricted items.
2. **Bulk Generation**: Organizer can bulk-generate voucher batches with configurable prefixes and code formats.
3. **Voucher Tags**: Vouchers can be grouped into tags for organizational purposes.

### 2. Voucher Rules

4. **Usage Limits**: Vouchers can have total usage limits and per-code usage limits, plus expiration dates. Can be scoped to specific items, variations, or quotas.
5. **Single Voucher Per Order**: Only one voucher can be applied per order. Automatic discounts can stack with a voucher unless the organizer disables stacking.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Vouchers

  Scenario: AC1 — Create a voucher code with discount effect
    Given I am logged in as an organizer
    And I have an event with at least one ticket type
    When I navigate to the voucher management page
    And I create a new voucher with code "SAVE20"
    And I set the effect to "percentage discount" of 20%
    And I save the voucher
    Then the voucher "SAVE20" appears in my voucher list
    And it shows "20% discount" as the effect

  Scenario: AC1b — Create a voucher that reveals hidden items
    Given I am logged in as an organizer
    And I have an event with a hidden ticket type "VIP Early Access"
    When I create a new voucher with code "REVEALSECRET"
    And I set the effect to "reveal hidden items"
    And I select "VIP Early Access" as the revealed item
    And I save the voucher
    Then the voucher "REVEALSECRET" appears in my voucher list
    And it shows that it reveals the "VIP Early Access" item

  Scenario: AC2 — Bulk-generate voucher codes
    Given I am logged in as an organizer
    And I have an event with at least one ticket type
    When I navigate to the voucher management page
    And I choose to bulk-generate vouchers
    And I set the prefix to "PROMO"
    And I set the quantity to 50
    And I set the effect to "fixed discount" of $10
    And I generate the batch
    Then 50 voucher codes appear in my voucher list
    And each code starts with "PROMO"
    And each has a "$10 discount" effect

  Scenario: AC3 — Organize vouchers with tags
    Given I am logged in as an organizer
    And I have several voucher codes created
    When I assign the tag "Partner Campaign" to selected vouchers
    Then those vouchers display the "Partner Campaign" tag
    And I can filter the voucher list by the "Partner Campaign" tag

  Scenario: AC4 — Voucher with usage limits and expiration
    Given I am logged in as an organizer
    When I create a voucher with code "LIMITED50"
    And I set the total usage limit to 100
    And I set the per-code usage limit to 1
    And I set the expiration date to "2026-12-31"
    And I scope it to the "General Admission" ticket type
    And I save the voucher
    Then the voucher shows a total usage limit of 100
    And the voucher shows it expires on "2026-12-31"
    And the voucher only applies to "General Admission"

  Scenario: AC5 — Only one voucher per order
    Given I am an attendee checking out for an event
    And I have applied voucher code "SAVE20"
    When I try to apply a second voucher code "EXTRA10"
    Then I see a message that only one voucher can be applied per order
    And the second voucher is not applied
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Apply an expired voucher
    Given I am an attendee checking out for an event
    And the voucher "EXPIRED01" has an expiration date in the past
    When I enter the voucher code "EXPIRED01"
    Then I see a message that the voucher has expired
    And no discount is applied

  Scenario: Apply a fully-used voucher
    Given I am an attendee checking out for an event
    And the voucher "USED100" has reached its total usage limit
    When I enter the voucher code "USED100"
    Then I see a message that the voucher is no longer available
    And no discount is applied

  Scenario: Case-insensitive voucher code entry
    Given I am an attendee checking out for an event
    And a valid voucher "SAVE20" exists
    When I enter the code "save20" in lowercase
    Then the voucher is recognized and applied correctly

  Scenario: Attempt to create a duplicate voucher code
    Given I am logged in as an organizer
    And a voucher with code "SAVE20" already exists
    When I try to create another voucher with code "SAVE20"
    Then I see a validation error indicating the code already exists
    And the duplicate voucher is not created

  Scenario: Apply voucher to a sold-out item
    Given I am an attendee checking out for an event
    And the "General Admission" ticket is sold out
    And the voucher "SAVE20" is scoped to "General Admission"
    When I enter the voucher code "SAVE20"
    Then I see a message that the voucher cannot be applied because the item is unavailable

  Scenario: Bulk generate with prefix that causes duplicate codes
    Given I am logged in as an organizer
    And voucher codes starting with "PROMO" already exist
    When I bulk-generate vouchers with the prefix "PROMO"
    Then the system generates unique codes that do not collide with existing ones
    And no duplicate codes are created
```

## Assumptions

- The item and product catalog (story 007) is in place, providing the items, variations, and quotas that vouchers reference.
- Voucher codes are unique within an event's scope.
- The checkout flow will integrate voucher code entry as part of the order process.
