---
id: story-021
title: Check-in Lists and Gates
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-005-event-creation-and-management
  - story-020-check-in
---

# Story 021: Check-in Lists and Gates

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-021                                  |
| **Title**      | Check-in Lists and Gates                   |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-005-event-creation-and-management, story-020-check-in |

## Summary

As an organizer, I want to configure check-in lists and gates, so that I can control entry at different venue points

## Description

### Context

This story covers the configuration layer that organizers use to control how and where attendees are checked in. It builds on event management (story-005) for the event structure and check-in (story-020) for the operational check-in flow. Check-in lists define which tickets are valid for a given entry context, and gates map those lists to physical entry points.

### User Value

Organizers running events at venues with multiple entry points need fine-grained control over who can enter where and when. Check-in lists allow filtering by ticket type, variation, and time window, while gates map these lists to physical locations so that operators at each door know exactly which attendees they should admit.

### Approach

Organizers configure check-in lists with rules about which ticket types and variations are included, along with optional time restrictions. Gates are then created to represent physical entry points and are linked to one or more check-in lists. At runtime, operators at each gate see only the attendees valid for their assigned lists.

## Acceptance Criteria

### 1. Check-in Lists

1. **Create Lists**: Organizer can create multiple check-in lists per event with configurable rules (included items/variations, time restrictions).
2. **Multi-List Tickets**: A ticket position can appear on multiple check-in lists.

### 2. Gates

3. **Define Gates**: Gates represent physical entry points assigned to specific check-in lists, controlling which tickets are valid at each gate.
4. **Dual Flow**: The system supports both search-based and scan-based check-in flows at each gate.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Check-in Lists and Gates

  Scenario: AC1 — Create a check-in list with configurable rules
    Given I am an organizer for the event "Tech Conference"
    When I navigate to the check-in configuration area
    And I create a new check-in list named "VIP Entrance"
    And I configure it to include only "VIP Pass" ticket types
    And I set a time restriction from 08:00 to 10:00
    And I save the check-in list
    Then the list "VIP Entrance" appears in the event's check-in lists
    And it shows the included items and time restriction

  Scenario: AC2 — A ticket appears on multiple check-in lists
    Given I am an organizer for the event "Tech Conference"
    And I have a check-in list "Main Hall" that includes "General Admission" tickets
    And I have a check-in list "Workshop Room" that also includes "General Admission" tickets
    When an attendee holds a "General Admission" ticket
    Then that attendee's ticket appears on both the "Main Hall" and "Workshop Room" check-in lists
    And the attendee can be checked in independently on each list

  Scenario: AC3 — Define a gate with assigned check-in lists
    Given I am an organizer for the event "Tech Conference"
    And I have check-in lists "VIP Entrance" and "General Entrance"
    When I create a gate named "North Door"
    And I assign the "General Entrance" check-in list to it
    And I save the gate
    Then the gate "North Door" appears in the event's gate configuration
    And it shows "General Entrance" as its assigned check-in list
    And operators at "North Door" only see attendees from the "General Entrance" list

  Scenario: AC4 — Both search and scan check-in at a gate
    Given I am a check-in operator assigned to the gate "North Door"
    And "North Door" is linked to the "General Entrance" check-in list
    When I scan a valid "General Admission" attendee's QR code
    Then the attendee is checked in successfully
    When I search for another attendee by name on the "General Entrance" list
    Then I can find and check in that attendee as well
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Check-in list with no included items
    Given I am an organizer for the event "Tech Conference"
    When I create a check-in list "Empty List" without selecting any ticket types
    Then I see a validation message indicating at least one item must be included
    And the list is not saved

  Scenario: Gate with no assigned check-in lists
    Given I am an organizer for the event "Tech Conference"
    When I create a gate "Side Door" without assigning any check-in lists
    Then I see a validation message indicating at least one check-in list must be assigned
    And the gate is not saved

  Scenario: Time-restricted list outside its active window
    Given I am a check-in operator for the event "Tech Conference"
    And the "VIP Entrance" list is restricted to 08:00–10:00
    And the current time is 11:00
    When I attempt to check in a VIP attendee on the "VIP Entrance" list
    Then I see a message indicating the check-in list is not active at this time
    And no check-in is recorded

  Scenario: Ticket valid on one list but not another
    Given I am a check-in operator at the gate "VIP Door"
    And "VIP Door" is linked only to the "VIP Entrance" check-in list
    And an attendee holds a "General Admission" ticket not included in the "VIP Entrance" list
    When I scan the attendee's QR code at "VIP Door"
    Then I see an error indicating the ticket is not valid for this entry point
    And no check-in is recorded
```

## Assumptions

- Each event can have an unlimited number of check-in lists and gates.
- Time restrictions on check-in lists use the event's configured timezone.
- A gate must have at least one check-in list assigned to be operational.
