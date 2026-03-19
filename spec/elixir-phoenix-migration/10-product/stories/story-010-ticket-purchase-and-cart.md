---
id: story-010
title: Ticket Purchase and Cart
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-007-item-and-product-catalog
  - story-008-quotas-and-availability
---

# Story 010: Ticket Purchase and Cart

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-010                                  |
| **Title**      | Ticket Purchase and Cart                   |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-007-item-and-product-catalog, story-008-quotas-and-availability |

## Summary

As an attendee, I want to browse events, select tickets, and complete checkout, so that I can attend events

## Description

### Context

This story covers the full ticket purchasing flow from browsing published events through completing checkout and receiving tickets. It depends on the item catalog (story-007) for product/ticket type definitions and quotas (story-008) for availability tracking.

### User Value

Attendees need a seamless, reliable way to find events, choose tickets, and purchase them. The checkout experience must handle real-time availability, temporary reservations, and multiple payment timelines while keeping the attendee informed at every step.

### Approach

The purchasing flow is broken into three phases: browsing and selection, checkout (with reservation and payment), and order confirmation. Reservations ensure fair access to limited inventory, with durations that adapt to the chosen payment method. Sell-out scenarios are handled gracefully with clear messaging.

## Acceptance Criteria

### 1. Browsing and Selection

1. **Browse Events**: Attendees can view published events with details, dates, and available ticket types.
2. **Select Items**: Attendees can select ticket types, variations, and quantities and add them to a cart.

### 2. Checkout Flow

3. **Attendee Info**: System collects attendee information (name, email) and custom question answers per ticket position.
4. **Pricing Summary**: Cart displays itemized totals with applicable discounts, taxes, and fees before payment.
5. **Cart Reservation**: Selected items are reserved temporarily. Reservation duration depends on payment method: 15 minutes for instant methods, 30 minutes for redirect-based, up to 3 days for bank transfer/boleto. Hard max 7 days if payment is in-flight.

### 3. Order Confirmation

6. **Confirmation**: Upon successful payment, the order is confirmed and a ticket with unique QR code is delivered via email.
7. **Sell-Out Handling**: If items sell out during checkout, the attendee is informed and affected reservations are released.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Ticket Purchase and Cart

  Scenario: AC1 — Browse published events
    Given there are published events with available tickets
    When I navigate to the events listing page
    Then I see each event with its name, date, location, and available ticket types
    And only published events are visible

  Scenario: AC2 — Select tickets and add to cart
    Given I am viewing an event with multiple ticket types and variations
    When I select a ticket type, choose a variation, and set a quantity of 2
    And I add them to my cart
    Then my cart shows 2 tickets of the selected type and variation
    And the cart total reflects the correct price

  Scenario: AC3 — Provide attendee information during checkout
    Given I have 2 tickets in my cart and I proceed to checkout
    When I am prompted for attendee information
    Then I see fields for name, email, and any custom questions for each ticket position
    And I must complete all required fields before continuing

  Scenario: AC4 — View pricing summary before payment
    Given I have items in my cart with applicable discounts and fees
    When I view the checkout summary
    Then I see an itemized breakdown showing subtotal, discounts, taxes, fees, and total
    And the total matches the sum of all line items

  Scenario: AC5 — Cart reservation with adaptive duration
    Given I have selected tickets and started checkout
    When I choose credit card as my payment method
    Then my selected items are reserved for 15 minutes
    And a countdown timer is visible showing the remaining reservation time

  Scenario: AC6 — Receive confirmation and ticket after payment
    Given I have completed payment for my order
    When the payment is confirmed
    Then I see an order confirmation page with a summary of my purchase
    And I receive an email with my tickets, each containing a unique QR code

  Scenario: AC7 — Informed when items sell out during checkout
    Given I am in the checkout flow for the last available ticket
    And another attendee completes purchase of that ticket before me
    When I attempt to proceed with payment
    Then I see a message indicating the selected items are no longer available
    And my reservation is released
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Checkout with expired reservation
    Given I started checkout and my 15-minute reservation has expired
    When I attempt to complete payment
    Then I see a message that my reservation has expired
    And I am returned to the event page to re-select tickets

  Scenario: Concurrent checkout for last ticket
    Given there is exactly 1 ticket remaining for an event
    And two attendees add that ticket to their carts simultaneously
    When both attempt to complete checkout
    Then only one attendee successfully completes the purchase
    And the other attendee is informed the ticket is no longer available

  Scenario: Empty cart submission
    Given my cart contains no items
    When I attempt to proceed to checkout
    Then I see a message indicating my cart is empty
    And I am not allowed to enter the checkout flow

  Scenario: All items removed from cart mid-flow
    Given I am in the checkout flow with items in my cart
    And all my items become unavailable due to sell-out
    When I attempt to proceed to the next checkout step
    Then I see a message that all items have been removed
    And I am redirected to the events listing

  Scenario: Payment method change mid-checkout
    Given I am in checkout and initially selected credit card with a 15-minute reservation
    When I change my payment method to bank transfer
    Then my reservation duration is extended to 3 days
    And the checkout flow updates to reflect the new payment method

  Scenario: Cart with mixed free and paid items
    Given I add a free ticket and a paid ticket to my cart
    When I proceed to checkout
    Then I see both items in the pricing summary
    And the free item shows a zero amount
    And I am still required to complete payment for the paid item
```

## Assumptions

- Events must be in "published" status to appear in the attendee-facing listing.
- Reservation durations are configurable per event by organizers but default to the values specified in AC5.
- QR codes are unique per ticket position, not per order.
