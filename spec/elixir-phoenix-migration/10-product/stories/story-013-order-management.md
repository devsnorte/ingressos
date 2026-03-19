---
id: story-013
title: Order Management
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-010-ticket-purchase-and-cart
---

# Story 013: Order Management

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-013                                  |
| **Title**      | Order Management                           |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-010-ticket-purchase-and-cart         |

## Summary

As an organizer, I want to view, search, and manage orders, so that I can handle attendee requests and issues

## Description

### Context

Once attendees purchase tickets (story-010), organizers need tools to manage those orders. This story covers the organizer-facing order management capabilities including browsing, searching, modifying, cancelling, refunding, and manually creating orders.

### User Value

Organizers need visibility into all orders and the ability to act on them. Whether handling a refund request, upgrading an attendee, resolving a duplicate, or creating a complimentary ticket, the order management interface is essential for day-to-day event operations.

### Approach

The order management interface provides a searchable, filterable list of all orders for the organizer's events. Each order can be drilled into for full details and actions. Destructive actions require confirmation to prevent mistakes. Manual order creation supports walk-up sales and complimentary tickets.

## Acceptance Criteria

### 1. Order Browsing

1. **Order List**: Organizer sees a searchable, filterable list of orders with status (pending, paid, expired, cancelled, refunded), attendee details, and ticket types.
2. **Order Detail**: Clicking an order shows full details including payment info, attendee answers, fees, and audit history.

### 2. Order Actions

3. **Resend Tickets**: Organizer can resend ticket emails for confirmed orders.
4. **Modify Order**: Organizer can modify attendee information and change order positions (upgrade/downgrade). During modification, the order is locked for attendee-side edits.
5. **Cancel and Refund**: Organizer can cancel orders (releasing quota back to pool) and initiate full or partial refunds through the original gateway. All destructive actions require explicit confirmation.
6. **Manual Order Creation**: Organizer can create orders manually (e.g., for walk-up sales or comps).

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Order Management

  Scenario: AC1 — Search and filter orders
    Given I am logged in as an organizer with existing orders
    When I navigate to the order management page
    Then I see a list of orders showing status, attendee name, email, and ticket type
    And I can search by attendee name or email
    And I can filter by order status

  Scenario: AC2 — View order details
    Given I am on the order list and I see an order for "Maria Silva"
    When I click on that order
    Then I see full details including payment method, amount, fees, attendee answers, and audit history
    And I see a timeline of all status changes

  Scenario: AC3 — Resend ticket email
    Given I am viewing a confirmed order
    When I click the resend tickets button
    Then the ticket email is sent again to the attendee's email address
    And I see a confirmation that the email was sent

  Scenario: AC4 — Modify order with attendee lock
    Given I am viewing a confirmed order for an attendee
    When I edit the attendee name and upgrade the ticket type
    And I save the changes
    Then the order reflects the updated information
    And during my modification, the attendee cannot edit the order from their side

  Scenario: AC5 — Cancel order with refund and confirmation
    Given I am viewing a paid order
    When I choose to cancel the order
    Then I am asked to confirm the cancellation
    And I can choose full or partial refund
    When I confirm the cancellation
    Then the order status changes to cancelled
    And the refund is initiated through the original payment gateway
    And the ticket quota is released back to the available pool

  Scenario: AC6 — Create a manual order
    Given I am on the order management page
    When I create a new manual order for a walk-up attendee
    And I select a ticket type and enter the attendee's information
    And I confirm the manual order
    Then a new order is created with a "paid" or "comp" status
    And the attendee receives their ticket via email
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Refund on expired gateway credentials
    Given I am viewing a paid order and the payment provider credentials have expired
    When I attempt to initiate a refund
    Then I see an error indicating the payment provider credentials need to be updated
    And the order remains in its current status

  Scenario: Cancel order for already checked-in attendee
    Given an attendee has already checked in with their ticket
    When I attempt to cancel their order
    Then I see a warning that the attendee has already checked in
    And I must provide additional confirmation to proceed

  Scenario: Modify order while attendee is editing
    Given an attendee is currently editing their order details
    When I as the organizer begin modifying the same order
    Then the attendee's editing session is locked
    And the attendee sees a message that the order is being modified by the organizer

  Scenario: Search with no results
    Given I am on the order management page
    When I search for an attendee name that does not match any orders
    Then I see an empty state message indicating no orders match the search
    And I am offered the option to clear the search filters

  Scenario: Partial refund exceeding paid amount
    Given I am viewing a paid order with a total of $50
    When I attempt to issue a partial refund of $75
    Then I see a validation error that the refund amount exceeds the paid amount
    And the refund is not processed

  Scenario: Organizer viewing another organization's orders
    Given I am logged in as an organizer for Organization A
    When I attempt to access orders belonging to Organization B
    Then I am denied access
    And I see no data from Organization B
```

## Assumptions

- Audit history records all changes to an order, including who made the change and when.
- Partial refunds are supported only if the payment gateway supports them.
- Manual orders can be created as complimentary (no payment) or as paid (with manual payment confirmation).
