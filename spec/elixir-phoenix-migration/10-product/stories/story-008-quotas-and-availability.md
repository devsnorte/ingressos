---
id: story-008
title: Quotas and Availability
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-007-item-and-product-catalog
---

# Story 008: Quotas and Availability

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-008                                  |
| **Title**      | Quotas and Availability                    |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-007-item-and-product-catalog         |

## Summary

As an organizer, I want to define quotas shared across items, so that I can control total availability accurately

## Description

### Context

Venues have fixed capacities and organizers often sell multiple ticket tiers that share the same physical space. Quotas allow organizers to cap total sales across multiple items so that the venue capacity is never exceeded.

### User Value

Organizers gain precise control over availability. Shared quotas ensure that selling out one ticket tier correctly reduces availability across related tiers. Attendees see real-time availability and are never oversold.

### Approach

Provide a quota management interface where organizers define named quota groups, assign items and variations to them, and see real-time availability. The platform handles concurrent reservations atomically to prevent overselling.

## Acceptance Criteria

### 1. Quota Configuration

1. **Shared Quotas**: Organizer can create quota groups spanning multiple items and variations (e.g., 100 seats shared between "Early Bird" and "Regular").
2. **Multiple Quotas**: An item can belong to multiple quota groups simultaneously.

### 2. Real-Time Availability

3. **Live Updates**: Availability updates within 2 seconds as tickets are sold or reserved. Sold-out items show as unavailable.
4. **Atomic Reservation**: When two attendees attempt to reserve the last available ticket simultaneously, the first reservation wins; the other sees "sold out" and is offered the waiting list.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Quotas and Availability

  Scenario: AC1 — Create a shared quota group
    Given I am logged in as an organizer
    And I have an event with items "Early Bird" and "Regular Admission"
    When I create a quota group named "General Seating"
    And I set the capacity to 100
    And I assign both "Early Bird" and "Regular Admission" to this quota
    And I save the quota
    Then the "General Seating" quota appears with a capacity of 100
    And both items show as sharing this quota

  Scenario: AC2 — Assign an item to multiple quota groups
    Given I am logged in as an organizer
    And I have a quota "General Seating" with capacity 100
    And I have a quota "VIP Area" with capacity 20
    And I have an item "VIP Pass"
    When I assign "VIP Pass" to both "General Seating" and "VIP Area"
    And I save the configuration
    Then "VIP Pass" shows as belonging to both quota groups
    And selling a "VIP Pass" reduces availability in both quotas

  Scenario: AC3 — Availability updates in real time
    Given the event "Tech Conference 2026" is published
    And the "General Seating" quota has 100 seats with 99 sold
    When an attendee purchases the last ticket
    Then within 2 seconds, other attendees viewing the event see the item as "Sold Out"

  Scenario: AC4 — Atomic reservation prevents overselling
    Given the "General Seating" quota has exactly 1 seat remaining
    When two attendees attempt to reserve that seat at the same time
    Then one attendee successfully completes the reservation
    And the other attendee sees a "Sold Out" message
    And is offered the option to join the waiting list
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Quota exhaustion during checkout
    Given an attendee has added a ticket to their cart
    And the quota is exhausted by other purchases while they are checking out
    When they attempt to complete the purchase
    Then they see a message that the item is no longer available
    And the item is removed from their cart

  Scenario: Concurrent reservation race condition
    Given a quota has 5 remaining seats
    And 10 attendees attempt to reserve simultaneously
    When all requests are processed
    Then exactly 5 reservations succeed
    And exactly 5 attendees receive a "Sold Out" response
    And the quota shows 0 remaining

  Scenario: Quota shared between sub-events
    Given a series event has a shared quota of 200 across all sub-events
    And "Session 1" has sold 150 tickets
    When an attendee views "Session 2"
    Then they see 50 tickets available

  Scenario: Increase quota after sell-out
    Given a quota "General Seating" has sold out at 100 seats
    When the organizer increases the quota to 120
    Then 20 additional seats become available
    And previously sold-out items show as available again

  Scenario: Zero-quota item
    Given an organizer creates a quota group with capacity 0
    When an attendee views the associated items
    Then the items show as "Sold Out" immediately
```

## Assumptions

- The item and product catalog (story 007) is already in place.
- The waiting list feature is available as a separate capability but is referenced here for the user flow.
