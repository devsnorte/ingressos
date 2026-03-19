---
id: story-005
title: Event Creation and Management
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-001-multi-organization-support
  - story-002-team-and-permission-management
---

# Story 005: Event Creation and Management

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-005                                  |
| **Title**      | Event Creation and Management              |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-001-multi-organization-support, story-002-team-and-permission-management |

## Summary

As an organizer, I want to create and manage events, so that I can sell tickets for my events

## Description

### Context

Organizers need a way to create events and manage their lifecycle. This is the core workflow that enables the ticket-selling platform to function. Events serve as the container for all ticket types, attendee information, and sales data.

### User Value

Organizers can set up events with all necessary details (name, description, dates, venue, branding), publish them when ready, and make changes as needed. The draft-to-published workflow ensures events are fully configured before becoming visible to attendees.

### Approach

Provide a straightforward event creation and management interface that guides organizers through setup, enforces readiness checks before publishing, and allows cloning for repeat events.

## Acceptance Criteria

### 1. Event Creation

1. **Create Event**: Organizer can create an event with name, description, dates, venue, and visual branding (logo, banner, colors). Event starts in draft status.
2. **Publish Event**: Events can only be published when they have at least one ticket type configured.
3. **Clone Event**: Organizer can clone an existing event to create a new one with the same configuration.

### 2. Event Management

4. **Edit Event**: Organizer can modify all event details. Changes to published events take effect immediately.
5. **Event Status**: Events transition through draft, published, and completed states. Only published events are visible to attendees.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Event Creation and Management

  Scenario: AC1 — Create a new event in draft status
    Given I am logged in as an organizer
    And I belong to an organization
    When I navigate to the event creation page
    And I fill in the event name "Tech Conference 2026"
    And I fill in the description "Annual technology conference"
    And I set the start date to "2026-06-15" and end date to "2026-06-16"
    And I set the venue to "Convention Center"
    And I upload a logo and banner image
    And I choose brand colors
    And I submit the form
    Then I see a confirmation that the event was created
    And the event appears in my events list with status "Draft"

  Scenario: AC2 — Publish event only when ticket type exists
    Given I am logged in as an organizer
    And I have a draft event "Tech Conference 2026"
    And the event has at least one ticket type configured
    When I click "Publish"
    Then the event status changes to "Published"
    And the event becomes visible to attendees

  Scenario: AC3 — Clone an existing event
    Given I am logged in as an organizer
    And I have an event "Tech Conference 2026" with full configuration
    When I choose to clone the event
    And I provide a new name "Tech Conference 2027"
    Then a new draft event is created with the same description, venue, branding, and ticket configuration
    And the cloned event appears in my events list with status "Draft"

  Scenario: AC4 — Edit a published event
    Given I am logged in as an organizer
    And I have a published event "Tech Conference 2026"
    When I edit the event description to "Updated annual technology conference"
    And I save the changes
    Then the updated description is visible to attendees immediately

  Scenario: AC5 — Event status lifecycle
    Given I am logged in as an organizer
    And I have a draft event "Tech Conference 2026"
    When I publish the event
    Then the event status is "Published"
    And attendees can see the event in the public listing
    When the event end date passes
    Then the event status transitions to "Completed"
    And the event is no longer shown as available for purchase
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Cannot create event without required fields
    Given I am logged in as an organizer
    When I try to create an event without filling in the name
    Then I see a validation error indicating the name is required
    And the event is not created

  Scenario: Cannot publish event with no ticket types
    Given I am logged in as an organizer
    And I have a draft event with no ticket types configured
    When I attempt to publish the event
    Then I see an error message indicating at least one ticket type is required
    And the event remains in draft status

  Scenario: Edit event that has existing orders
    Given I am logged in as an organizer
    And I have a published event with existing ticket orders
    When I edit the event name
    And I save the changes
    Then the event name is updated
    And existing orders still reference the correct event

  Scenario: Concurrent event editing
    Given two organizers are editing the same event simultaneously
    When the first organizer saves their changes
    And the second organizer attempts to save their changes
    Then the second organizer is notified of a conflict
    And is given the option to review and merge changes

  Scenario: Empty events list
    Given I am logged in as an organizer
    And my organization has no events
    When I navigate to the events list
    Then I see an empty state message encouraging me to create my first event
```

## Assumptions

- Organizations and team permissions (stories 001 and 002) are already in place.
- Visual branding assets (logo, banner) have reasonable file size limits enforced by the platform.
