---
id: story-019
title: Waiting List
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-008-quotas-and-availability
  - story-015-vouchers
---

# Story 019: Waiting List

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-019                                  |
| **Title**      | Waiting List                               |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-008-quotas-and-availability, story-015-vouchers |

## Summary

As an attendee, I want to join a waiting list for sold-out tickets, so that I can be notified when availability returns

## Description

### Context

When popular ticket types sell out, potential attendees are left with no path to purchase. A waiting list captures that demand and provides a fair, first-come-first-served mechanism for distributing tickets that become available through cancellations or quota increases.

### User Value

Attendees get a second chance at sold-out tickets without having to constantly check back. They receive a time-limited offer when their turn comes, ensuring a fair and orderly process. Organizers benefit from capturing unmet demand and maximizing ticket sales through automatic redistribution.

### Approach

Provide a waiting list option on sold-out ticket types. When availability returns, the system automatically sends a voucher to the next person in line, giving them a time-limited window to complete their purchase. Organizers have full visibility and control over waiting list entries.

## Acceptance Criteria

### 1. Joining the List

1. **Join Waiting List**: When a ticket type is sold out, attendees can request to join the waiting list for a specific item and variation.
2. **FIFO Order**: Waiting list position is first-come, first-served.

### 2. Offers

3. **Automatic Offers**: When tickets become available (cancellation or quota increase), the system sends a voucher to the next person with a time-limited purchase window (configurable, default 24 hours).
4. **List Management**: Organizers can view, manage, and clear waiting list entries.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Waiting List

  Scenario: AC1 — Join the waiting list for a sold-out ticket
    Given I am an attendee viewing an event
    And the "General Admission" ticket type is sold out
    When I click "Join Waiting List" for "General Admission"
    And I provide my email address
    Then I see a confirmation that I have been added to the waiting list
    And I receive an email confirming my waiting list position

  Scenario: AC2 — Waiting list is first-come, first-served
    Given the "General Admission" ticket is sold out
    When "Alice" joins the waiting list at 10:00 AM
    And "Bob" joins the waiting list at 10:15 AM
    And "Carol" joins the waiting list at 10:30 AM
    Then Alice is in position 1
    And Bob is in position 2
    And Carol is in position 3

  Scenario: AC3 — Automatic offer when ticket becomes available
    Given "Alice" is first on the waiting list for "General Admission"
    And "Bob" is second on the waiting list
    When a "General Admission" ticket becomes available due to a cancellation
    Then Alice receives a voucher via email
    And the voucher grants access to purchase one "General Admission" ticket
    And Alice has 24 hours to complete the purchase
    And Bob does not yet receive an offer

  Scenario: AC4 — Organizer manages waiting list entries
    Given I am logged in as an organizer
    And the "General Admission" waiting list has 15 entries
    When I navigate to the waiting list management page
    Then I see all 15 entries with their positions and email addresses
    And I can remove individual entries
    And I can clear the entire waiting list
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Attempt to join waiting list for an available item
    Given I am an attendee viewing an event
    And the "General Admission" ticket type is still available
    When I look at the "General Admission" section
    Then I see the option to purchase, not to join a waiting list
    And no waiting list option is displayed

  Scenario: Offer expires unused
    Given "Alice" received a waiting list voucher for "General Admission"
    And the voucher has a 24-hour purchase window
    When 24 hours pass without Alice completing the purchase
    Then the voucher expires
    And the next person on the waiting list ("Bob") receives a new voucher
    And Alice is removed from the waiting list

  Scenario: Multiple people on list and only one ticket available
    Given "Alice", "Bob", and "Carol" are on the waiting list
    And one "General Admission" ticket becomes available
    When the system processes the availability
    Then only Alice receives a voucher
    And Bob and Carol remain on the waiting list in their positions
    And no additional tickets are reserved beyond the one offered to Alice

  Scenario: Remove self from waiting list
    Given I am an attendee on the waiting list for "General Admission"
    When I click "Leave Waiting List" from my confirmation email or account
    Then I am removed from the waiting list
    And all people behind me move up one position
    And I see a confirmation that I have been removed

  Scenario: Waiting list when event is cancelled
    Given there are 10 people on the waiting list for "General Admission"
    And the organizer cancels the event
    When the event is marked as cancelled
    Then all waiting list entries are cleared
    And all waiting list members receive a notification that the event has been cancelled
```

## Assumptions

- Quotas and availability (story 008) are in place to detect when tickets become available.
- Vouchers (story 015) are in place, as the waiting list offer mechanism uses voucher codes.
- The configurable time window for offers defaults to 24 hours but can be adjusted by the organizer per event.
- Only one ticket is offered per waiting list entry; attendees who want multiple tickets need multiple entries or can adjust their request.
