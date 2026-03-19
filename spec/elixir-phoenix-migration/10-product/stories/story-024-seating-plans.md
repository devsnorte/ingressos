---
id: story-024
title: Seating Plans
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-007-item-and-product-catalog
  - story-010-ticket-purchase-and-cart
---

# Story 024: Seating Plans

| Field          | Value                                                          |
|----------------|----------------------------------------------------------------|
| **ID**         | story-024                                                      |
| **Title**      | Seating Plans                                                  |
| **Parent Epic**| TBD                                                            |
| **Fix Version**| TBD                                                            |
| **Status**     | Draft                                                          |
| **Priority**   | High                                                           |
| **Labels**     | agentic-workflow                                               |
| **Blocked by** | story-007-item-and-product-catalog, story-010-ticket-purchase-and-cart |

## Summary

As an organizer, I want to upload seating plans and let attendees choose seats, so that I can manage seated events

## Description

### Context

Seated events such as theater performances, conferences with assigned seating, and gala dinners require organizers to manage venue layouts with specific seat assignments. Attendees expect to see available seats and choose their preferred location during the ticket purchase process.

### User Value

Organizers gain the ability to manage seated events end-to-end — uploading venue layouts, mapping seats to ticket types, and reusing plans across multiple sub-events. Attendees enjoy a transparent seat selection experience during checkout, seeing exactly which seats are available and choosing their preferred spots. Organizers retain manual control for special cases like VIP reassignments.

### Approach

Provide an interface for organizers to upload predefined venue layouts that define zones, rows, and individual seats. Seats are linked to ticket types and availability quotas. During checkout, attendees view the seating plan and select from available seats, which are temporarily reserved. Organizers can also manually assign or reassign seats for existing orders.

## Acceptance Criteria

### 1. Seating Configuration

1. **Upload Layout**: Organizer uploads a predefined venue layout with named zones, rows, and individual seats.
2. **Map Seats**: Seats are mapped to items/variations and quotas.
3. **Reuse Plans**: Seating plans can be reused across sub-events.

### 2. Attendee Experience

4. **Select Seat**: During checkout, attendees see the seating plan and can select specific available seats. Selected seats are reserved during the checkout flow.
5. **Manual Assignment**: Organizers can manually assign or reassign seats for existing orders.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Seating Plans

  Scenario: AC1 — Upload a venue seating layout
    Given I am logged in as an organizer
    And I have an event for a seated venue
    When I navigate to the seating plan settings
    And I upload a predefined venue layout file
    Then the system displays the layout with named zones, rows, and individual seats
    And I can see the total seat count for the venue

  Scenario: AC2 — Map seats to ticket types and quotas
    Given I am logged in as an organizer
    And I have uploaded a seating layout with zones "Orchestra" and "Balcony"
    When I select the "Orchestra" zone
    And I map it to the "Premium Ticket" item
    And I select the "Balcony" zone
    And I map it to the "Standard Ticket" item
    And I save the seat mapping
    Then each zone shows its associated ticket type
    And the available quota reflects the number of seats in each zone

  Scenario: AC3 — Reuse a seating plan across sub-events
    Given I am logged in as an organizer
    And I have a seating plan configured for a venue
    And I have multiple sub-events for the same venue
    When I create a new sub-event
    And I select the existing seating plan to reuse
    Then the new sub-event uses the same layout and seat configuration
    And seat availability is tracked independently for each sub-event

  Scenario: AC4 — Attendee selects a seat during checkout
    Given I am an attendee purchasing a ticket for a seated event
    When I proceed to the seat selection step
    Then I see the seating plan with available and unavailable seats clearly distinguished
    When I select an available seat in row "A", seat "5"
    Then the seat is marked as reserved for my session
    And I can proceed to payment with that seat assigned to my order

  Scenario: AC5 — Organizer manually assigns a seat
    Given I am logged in as an organizer
    And I have an existing order without a seat assignment
    When I open the order details
    And I choose to assign a seat manually
    And I select row "B", seat "12"
    And I confirm the assignment
    Then the order shows seat "B-12" as assigned
    And that seat is no longer available for other attendees
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Attempt to select an already-reserved seat
    Given I am an attendee on the seat selection step
    And seat "A-3" has been reserved by another attendee
    When I try to select seat "A-3"
    Then I see a message that the seat is no longer available
    And I am prompted to choose a different seat

  Scenario: Upload an invalid layout format
    Given I am logged in as an organizer
    When I try to upload a file in an unsupported format
    Then I see a validation error explaining the accepted formats
    And the upload is rejected

  Scenario: Two attendees select the same seat simultaneously
    Given two attendees are viewing the seating plan at the same time
    And both attempt to select seat "C-7"
    When the first attendee confirms the selection
    Then the first attendee's reservation is accepted
    And the second attendee sees a message that the seat is no longer available

  Scenario: Reassign a seat for a checked-in attendee
    Given I am logged in as an organizer
    And an attendee has already checked in with seat "D-1"
    When I attempt to reassign that attendee to seat "D-2"
    Then I see a warning that the attendee has already checked in
    And I can confirm or cancel the reassignment

  Scenario: Seat on a cancelled order becomes available
    Given an attendee had seat "E-10" reserved in a completed order
    When the order is cancelled
    Then seat "E-10" becomes available for other attendees on the seating plan
```

## Assumptions

- v1 supports uploading predefined layouts; interactive visual editor is a follow-up feature.
- Seat reservations during checkout have a time limit aligned with the cart expiration window.
- The seating plan file format will be defined during implementation (e.g., JSON or CSV with zone/row/seat structure).
