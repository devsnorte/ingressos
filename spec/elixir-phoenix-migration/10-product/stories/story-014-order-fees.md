---
id: story-014
title: Order Fees
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: medium
blocked_by:
  - story-010-ticket-purchase-and-cart
---

# Story 014: Order Fees

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-014                                  |
| **Title**      | Order Fees                                 |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | Medium                                     |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-010-ticket-purchase-and-cart         |

## Summary

As an organizer, I want to configure and apply fees to orders, so that I can cover service or handling costs

## Description

### Context

Order fees complement the ticket purchasing flow (story-010) by allowing organizers to define additional charges. Fees can be fixed or percentage-based, applied automatically or manually, and must be fully transparent to attendees during checkout.

### User Value

Organizers often need to pass on service charges, handling fees, or other costs to attendees. A flexible fee system lets organizers cover operational costs while maintaining transparency. Attendees benefit from seeing all fees clearly before payment, avoiding surprises.

### Approach

Fees are configured at the event or organization level and can be set as fixed amounts or percentages. Automatic fee rules apply fees based on configurable conditions. All fees are displayed to the attendee in the checkout pricing summary, ensuring full transparency before payment.

## Acceptance Criteria

### 1. Fee Configuration

1. **Fee Types**: System supports service fees, shipping fees, cancellation fees, and custom fees as fixed amounts or percentages.
2. **Automatic Fees**: Fees can be configured to apply automatically based on rules (e.g., service fee on all orders).

### 2. Fee Visibility

3. **Checkout Display**: All fees are itemized and visible to the attendee during checkout before payment.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Order Fees

  Scenario: AC1 — Configure different fee types
    Given I am logged in as an organizer managing an event
    When I navigate to the fee configuration settings
    Then I can create a service fee as a fixed amount
    And I can create a handling fee as a percentage of the order total
    And I can define custom fee types with a name and description

  Scenario: AC2 — Set up automatic fee rules
    Given I am configuring fees for my event
    When I create a rule to apply a service fee automatically to all orders
    And I save the rule
    Then the service fee is automatically added to every new order for that event

  Scenario: AC3 — Attendee sees all fees itemized at checkout
    Given an event has a 5% service fee and a $2.00 handling fee configured
    And I am an attendee purchasing a $100 ticket
    When I view the checkout pricing summary
    Then I see the ticket price of $100.00
    And I see the service fee of $5.00
    And I see the handling fee of $2.00
    And I see the total of $107.00
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Negative fee amount rejected
    Given I am configuring a new fee for my event
    When I enter a negative amount for the fee
    Then I see a validation error that fee amounts must be zero or positive
    And the fee is not saved

  Scenario: Percentage fee on zero-value order
    Given an event has a 10% service fee configured
    And an attendee is checking out with only free tickets
    When the pricing summary is calculated
    Then the service fee shows as $0.00
    And the total remains $0.00

  Scenario: Fee added after payment
    Given an attendee has already completed payment for an order
    When the organizer adds a new fee rule to the event
    Then the new fee does not apply to the already-paid order
    And the new fee only applies to future orders

  Scenario: Fee included in refund calculation
    Given an order was placed with a $100 ticket and a $5 service fee
    And the organizer initiates a full refund
    When the refund is processed
    Then the refund amount includes the full $105
    And the attendee sees the refund covers the ticket price and fees

  Scenario: Multiple overlapping fee rules
    Given an event has two automatic fee rules that both apply to the same order
    When an attendee proceeds to checkout
    Then both fees are applied and itemized separately
    And the total reflects the cumulative effect of all applicable fees
```

## Assumptions

- Cancellation fees are deducted from refund amounts when applicable, as configured by the organizer.
- Fee rules are evaluated at checkout time; changes to rules do not retroactively affect existing orders.
- Percentage-based fees are calculated on the pre-fee subtotal, not compounded on other fees.
