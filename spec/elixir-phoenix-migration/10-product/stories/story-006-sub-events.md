---
id: story-006
title: Sub-Events (Event Series)
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-005-event-creation-and-management
---

# Story 006: Sub-Events (Event Series)

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-006                                  |
| **Title**      | Sub-Events (Event Series)                  |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-005-event-creation-and-management    |

## Summary

As an organizer, I want to create sub-events for event series, so that I can manage recurring events with shared settings

## Description

### Context

Many events recur on different dates or have multiple sessions within a series. Organizers need the ability to manage these as related sub-events under a single parent, sharing configuration while allowing per-date overrides.

### User Value

Organizers save time by configuring shared settings once at the parent level and only overriding what differs per date. Attendees see a clear list of available dates and can pick the session that works for them.

### Approach

Allow organizers to enable an event series mode on any event, then create sub-events that inherit the parent's catalog and settings but can override specific values like dates, capacity, and pricing.

## Acceptance Criteria

### 1. Sub-Event Creation

1. **Enable Series**: Organizer can enable the event series feature on an event, allowing creation of sub-events.
2. **Create Sub-Event**: Each sub-event has its own dates, capacity, and can override parent pricing and quotas.
3. **Catalog Inheritance**: Sub-events inherit the parent's item catalog. Changes to the parent propagate unless the sub-event has explicitly overridden that setting.

### 2. Sub-Event Management

4. **Independent Publishing**: Each sub-event can be individually published or hidden.
5. **Attendee View**: Attendees see a list of available dates and select the sub-event they want to attend.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Sub-Events (Event Series)

  Scenario: AC1 — Enable event series feature
    Given I am logged in as an organizer
    And I have an event "Workshop Series"
    When I navigate to the event settings
    And I enable the event series feature
    Then I see the option to create sub-events
    And the event is marked as a series

  Scenario: AC2 — Create a sub-event with its own dates and capacity
    Given I am logged in as an organizer
    And I have a series event "Workshop Series"
    When I create a sub-event with the name "Session 1"
    And I set the date to "2026-07-01"
    And I set the capacity to 50
    And I override the price to "R$ 75,00"
    Then the sub-event "Session 1" appears under "Workshop Series"
    And it shows its own date, capacity, and price

  Scenario: AC3 — Sub-event inherits parent catalog changes
    Given I am logged in as an organizer
    And I have a series event "Workshop Series" with a ticket item "General Admission"
    And I have a sub-event "Session 1" that has not overridden any settings
    When I change the "General Admission" price to "R$ 100,00" on the parent event
    Then the sub-event "Session 1" also shows "General Admission" at "R$ 100,00"

  Scenario: AC4 — Independently publish a sub-event
    Given I am logged in as an organizer
    And I have a series event "Workshop Series" with sub-events "Session 1" and "Session 2"
    When I publish "Session 1" and keep "Session 2" hidden
    Then attendees can see "Session 1" on the public event page
    And "Session 2" is not visible to attendees

  Scenario: AC5 — Attendee selects a sub-event from available dates
    Given the series event "Workshop Series" is published
    And it has published sub-events on "2026-07-01" and "2026-07-08"
    When I visit the "Workshop Series" event page as an attendee
    Then I see a list of available dates: "2026-07-01" and "2026-07-08"
    When I select "2026-07-01"
    Then I see the ticket options for that specific session
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Remove item from parent with existing sub-event orders
    Given I am logged in as an organizer
    And a sub-event "Session 1" has orders for the item "General Admission"
    When I remove "General Admission" from the parent event
    Then I see a warning that sub-events have existing orders for this item
    And I must confirm before the item is removed

  Scenario: Add item to parent propagates to sub-events
    Given I am logged in as an organizer
    And I have a series event with sub-events that have not overridden the catalog
    When I add a new item "VIP Upgrade" to the parent event
    Then all non-overridden sub-events also show "VIP Upgrade" as available

  Scenario: Override then un-override a sub-event setting
    Given I am logged in as an organizer
    And a sub-event "Session 1" has overridden the price for "General Admission"
    When I remove the price override on "Session 1"
    Then "Session 1" reverts to the parent event's price for "General Admission"

  Scenario: Empty sub-event list
    Given I am logged in as an organizer
    And I have a series event "Workshop Series" with no sub-events
    When I view the sub-events list
    Then I see an empty state message encouraging me to create the first session
```

## Assumptions

- Event creation and management (story 005) is already in place.
- The parent event's catalog must exist before sub-events can be created.
