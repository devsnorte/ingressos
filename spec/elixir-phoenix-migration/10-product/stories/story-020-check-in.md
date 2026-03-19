---
id: story-020
title: Check-in
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-010-ticket-purchase-and-cart
---

# Story 020: Check-in

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-020                                  |
| **Title**      | Check-in                                   |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-010-ticket-purchase-and-cart          |

## Summary

As a check-in operator, I want to scan QR codes and search attendees, so that I can validate entry at events

## Description

### Context

This story covers the core check-in experience used by operators at event venues. It depends on ticket purchase (story-010) because attendees must have valid tickets before they can be checked in. Check-in is the primary gate-keeping action that ensures only valid ticket holders enter an event.

### User Value

Check-in operators need a fast, reliable way to validate attendees at event entry points. Whether scanning a QR code or searching by name/email, the operator must receive immediate, unambiguous feedback — success or a clear error — so that lines move quickly and only authorized attendees are admitted.

### Approach

The check-in flow supports two primary methods: QR code scanning for speed and name/email search for fallback. Each check-in is validated against ticket status, event association, and check-in list rules. Real-time counts keep organizers informed of attendance progress.

## Acceptance Criteria

### 1. Check-in Methods

1. **QR Code Scan**: Operator scans an attendee's QR code. System validates the ticket (correct event/sub-event, correct check-in list, not already checked in, not cancelled) and shows a clear success or error indicator with attendee details.
2. **Name/Email Search**: Operator can search by name or email to find and check in attendees manually.

### 2. Check-in Behavior

3. **Single Entry**: Each ticket can only be checked in once per check-in list, unless multi-entry is enabled.
4. **Annul Check-in**: Operators can reverse (annul) a check-in if it was done by mistake.
5. **Real-Time Count**: Check-in count updates within 2 seconds on the organizer's dashboard.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Check-in

  Scenario: AC1 — Scan a valid QR code to check in an attendee
    Given I am a check-in operator for the event "Tech Conference"
    And an attendee "Jane Doe" holds a valid ticket with a QR code
    And the ticket is assigned to my check-in list
    When I scan the attendee's QR code
    Then I see a success indicator confirming the check-in
    And I see the attendee's name "Jane Doe" and ticket details
    And the ticket is marked as checked in

  Scenario: AC2 — Search by name or email to check in an attendee
    Given I am a check-in operator for the event "Tech Conference"
    And an attendee "John Smith" with email "john@example.com" holds a valid ticket
    When I search for "John Smith" in the check-in search field
    Then I see "John Smith" in the search results with ticket details
    When I select "John Smith" and confirm the check-in
    Then I see a success indicator confirming the check-in
    And the ticket is marked as checked in

  Scenario: AC3 — Prevent duplicate check-in on the same list
    Given I am a check-in operator for the event "Tech Conference"
    And an attendee "Jane Doe" has already been checked in on my check-in list
    And multi-entry is not enabled for this list
    When I scan "Jane Doe"'s QR code again
    Then I see an error indicator stating the attendee is already checked in
    And no duplicate check-in record is created

  Scenario: AC4 — Annul a check-in
    Given I am a check-in operator for the event "Tech Conference"
    And I have just checked in "Jane Doe"
    When I choose to annul the check-in for "Jane Doe"
    And I confirm the annulment
    Then the check-in is reversed
    And "Jane Doe" appears as not checked in on the list
    And "Jane Doe" can be checked in again

  Scenario: AC5 — Real-time check-in count on organizer dashboard
    Given I am an organizer viewing the dashboard for "Tech Conference"
    And the current check-in count is 50
    When a check-in operator checks in a new attendee
    Then within 2 seconds the check-in count on my dashboard updates to 51
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Scan an already checked-in ticket
    Given an attendee "Jane Doe" was checked in 10 minutes ago
    And multi-entry is not enabled
    When I scan "Jane Doe"'s QR code
    Then I see an error indicator with the message "Already checked in"
    And I see the time of the original check-in

  Scenario: Scan a cancelled ticket
    Given an attendee "Bob Lee" had a ticket that was cancelled
    When I scan "Bob Lee"'s QR code
    Then I see an error indicator with the message "Ticket cancelled"
    And no check-in is recorded

  Scenario: Scan a ticket for the wrong event
    Given I am operating check-in for "Tech Conference"
    And "Alice Wang" holds a ticket for a different event "Music Festival"
    When I scan "Alice Wang"'s QR code
    Then I see an error indicator stating the ticket is not valid for this event

  Scenario: Scan an invalid QR code
    Given I am a check-in operator for "Tech Conference"
    When I scan a QR code that does not correspond to any ticket
    Then I see an error indicator with the message "Invalid ticket"

  Scenario: Check-in with slow network connection
    Given I am a check-in operator and the network is degraded
    When I scan a valid attendee QR code
    Then the system attempts to validate the check-in
    And if the response takes more than 5 seconds, I see a loading indicator
    And the check-in eventually completes or shows a connectivity error

  Scenario: Concurrent check-in of the same ticket on two devices
    Given two operators scan the same attendee's QR code at nearly the same time
    When both check-in requests reach the system
    Then only one check-in is recorded
    And the second device sees an "Already checked in" message
```

## Assumptions

- Check-in operators are authenticated and assigned to specific check-in lists before the event begins.
- Multi-entry mode is a per-list configuration set by the organizer.
- QR codes encode a unique ticket identifier that the system can look up.
