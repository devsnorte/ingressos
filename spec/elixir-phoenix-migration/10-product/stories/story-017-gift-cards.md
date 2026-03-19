---
id: story-017
title: Gift Cards
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-001-multi-organization-support
  - story-010-ticket-purchase-and-cart
---

# Story 017: Gift Cards

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-017                                  |
| **Title**      | Gift Cards                                 |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-001-multi-organization-support, story-010-ticket-purchase-and-cart |

## Summary

As an organizer, I want to issue and manage gift cards, so that attendees can use stored value across my events

## Description

### Context

Gift cards provide a stored-value payment method that works across an organization's events. They can be created manually by organizers (for promotions or giveaways) or sold as purchasable items during checkout. Gift cards add a flexible payment option that encourages repeat attendance and simplifies group purchasing.

### User Value

Organizers gain an additional revenue and marketing tool — gift cards can be sold, gifted, or used as prizes. Attendees benefit from a convenient way to pay for tickets across multiple events, and partial redemption means unused balance is never lost.

### Approach

Provide gift card creation and management for organizers, and integrate gift card redemption into the checkout flow. Gift cards work at the organization level, so a card purchased for one event can be used at any event by the same organization. Balance tracking, partial redemption, and refund restoration are handled transparently.

## Acceptance Criteria

### 1. Gift Card Creation

1. **Manual Creation**: Organizer can create gift cards manually with unique codes and monetary balance.
2. **Purchasable Gift Cards**: Gift cards can be sold as items during checkout. On purchase, the system generates the card with the paid balance.

### 2. Gift Card Usage

3. **Redeem at Checkout**: Attendees can enter a gift card code during checkout. Balance is deducted from the order total. Partial redemption is supported — remaining balance stays on the card.
4. **Cross-Event**: Gift cards work across all of an organization's events.

### 3. Gift Card Management

5. **Refund Restoration**: When an order paid with a gift card is refunded, the balance is restored — even if the card has expired (expiry is extended or a replacement card is issued).

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Gift Cards

  Scenario: AC1 — Manually create a gift card
    Given I am logged in as an organizer
    When I navigate to the gift card management page
    And I create a new gift card with code "GIFT-100" and balance of $100
    And I save the gift card
    Then the gift card "GIFT-100" appears in my gift card list
    And it shows a balance of $100

  Scenario: AC2 — Purchase a gift card during checkout
    Given I am an attendee checking out for an event
    And the organizer has a "$50 Gift Card" available for purchase
    When I add the "$50 Gift Card" to my cart
    And I complete the purchase
    Then I receive a unique gift card code
    And the gift card has a balance of $50

  Scenario: AC3 — Redeem gift card at checkout with partial balance
    Given I am an attendee checking out for an event
    And I have a gift card "GIFT-100" with a balance of $100
    And my order total is $75
    When I enter the gift card code "GIFT-100" at checkout
    And I complete the purchase
    Then $75 is deducted from the gift card
    And the remaining balance on "GIFT-100" is $25
    And my order is confirmed as paid

  Scenario: AC4 — Use gift card across different events
    Given I am an attendee with a gift card "GIFT-100" with $50 remaining balance
    And the gift card was issued by "TechOrg"
    And "TechOrg" has another event "Summer Meetup"
    When I check out for "Summer Meetup"
    And I enter the gift card code "GIFT-100"
    Then the gift card balance is applied to the order
    And the gift card works across this organization's events

  Scenario: AC5 — Refund restores gift card balance
    Given I am an organizer
    And an attendee paid for an order using gift card "GIFT-100"
    And $75 was deducted from the gift card for that order
    When I process a refund for that order
    Then the gift card "GIFT-100" balance is restored by $75
    And if the gift card had expired, its expiry is extended or a replacement card is issued
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Redeem gift card with zero balance
    Given I am an attendee checking out for an event
    And I have a gift card "GIFT-EMPTY" with a balance of $0
    When I enter the gift card code "GIFT-EMPTY"
    Then I see a message that the gift card has no remaining balance
    And no amount is applied to the order

  Scenario: Redeem an expired gift card
    Given I am an attendee checking out for an event
    And I have a gift card "GIFT-OLD" that has expired
    When I enter the gift card code "GIFT-OLD"
    Then I see a message that the gift card has expired
    And no amount is applied to the order

  Scenario: Use gift card from another organization
    Given I am an attendee checking out for an event by "TechOrg"
    And I have a gift card issued by "OtherOrg"
    When I enter the gift card code at checkout
    Then I see a message that the gift card is not valid for this event
    And no amount is applied

  Scenario: Partial refund with mixed payment — gift card and gateway
    Given I am an organizer
    And an attendee paid $50 via gift card and $25 via payment gateway
    When I process a partial refund of $30
    Then the refund is applied proportionally or to the appropriate payment method
    And the gift card balance is partially restored accordingly

  Scenario: Top up an existing gift card
    Given I am logged in as an organizer
    And a gift card "GIFT-100" exists with a balance of $25
    When I add $50 to the gift card balance
    Then the gift card "GIFT-100" shows a balance of $75

  Scenario: Negative balance prevention
    Given I am an attendee checking out for an event
    And I have a gift card "GIFT-SMALL" with a balance of $10
    And my order total is $50
    When I enter the gift card code "GIFT-SMALL"
    Then $10 is applied from the gift card
    And I am prompted to pay the remaining $40 via another payment method
    And the gift card balance does not go below $0
```

## Assumptions

- Multi-organization support (story 001) and the ticket purchase and cart flow (story 010) are in place.
- Gift cards are scoped to a single organization and work across all that organization's events.
- Gift card codes are unique across the platform to prevent cross-organization collisions.
