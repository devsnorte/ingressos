---
id: story-032
title: Audit Logging
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: medium
blocked_by:
  - story-001-multi-organization-support
---

# Story 032: Audit Logging

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-032                                  |
| **Title**      | Audit Logging                              |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | Medium                                     |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-001-multi-organization-support       |

## Summary

As an organizer, I want all changes logged in an audit trail, so that I can track who changed what and when

## Description

### Context

As organizations grow and multiple team members manage events, it becomes critical to have a record of who made what changes and when. This story introduces comprehensive audit logging across all significant platform actions. It depends on multi-organization support (story-001) to scope logs to the correct organization.

### User Value

Audit logs give organizers accountability and transparency. When something goes wrong (e.g., a ticket type was accidentally deleted or a discount was changed), the audit trail shows exactly who made the change and when, enabling quick diagnosis and resolution.

### Approach

All significant user and system actions are automatically recorded with the actor, timestamp, affected entity, and a human-readable description. Organizers can browse and filter these logs within their organization's dashboard. Logs are immutable once written.

## Acceptance Criteria

### 1. Logging

1. **Automatic Logging**: All significant actions (event changes, order modifications, team changes, settings changes) are automatically logged with actor, timestamp, affected entity, and description.
2. **System Actions**: System-triggered actions (e.g., automatic reservation expiration, scheduled tasks) are also logged.

### 2. Viewing

3. **Browse Logs**: Organizers can browse the audit log filtered by event, entity type, time range, or actor. Logs are scoped to the organization.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Audit Logging

  Scenario: AC1 — Automatic logging of user actions
    Given I am an organizer managing an event
    When I change the event's name from "Tech Meetup" to "Tech Summit"
    And I navigate to the audit log
    Then I see an entry showing my name as the actor
    And the entry shows the timestamp of the change
    And the entry identifies the event as the affected entity
    And the entry describes the change as a name update

  Scenario: AC2 — System actions are logged
    Given an attendee's cart reservation has expired
    When the system automatically releases the reservation
    And I view the audit log
    Then I see an entry with the actor identified as "System"
    And the entry describes the automatic reservation expiration
    And the entry includes the timestamp and affected order

  Scenario: AC3 — Browse and filter audit logs
    Given there are multiple audit log entries across different events and actors
    When I navigate to the audit log page
    Then I can filter entries by event, entity type, time range, or actor
    And I only see entries belonging to my organization
    And entries are displayed in reverse chronological order
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Audit log for deleted entity
    Given I deleted an event that had prior audit log entries
    When I view the audit log and filter by that event
    Then I still see all historical log entries for the deleted event
    And the entries indicate the entity has been deleted

  Scenario: Log with system actor vs user actor
    Given there are log entries from both user actions and system actions
    When I filter the audit log by actor type "System"
    Then I only see entries triggered by automated system processes
    And when I filter by a specific user I only see that user's actions

  Scenario: Filter with no results
    Given I am viewing the audit log
    When I apply filters that match no entries (e.g., a future date range)
    Then I see a message indicating no audit log entries match the filters
    And I can clear the filters to see all entries

  Scenario: Audit log immutability
    Given an audit log entry has been created for a past action
    When any user attempts to modify or delete the audit log entry
    Then the entry remains unchanged
    And no option to edit or delete log entries is available in the interface
```

## Assumptions

- Audit logs are retained indefinitely and are not subject to automatic deletion.
- The audit log is read-only for all users; no one can modify or delete entries.
- High-frequency actions (e.g., individual page views) are not logged to avoid noise; only significant state-changing actions are recorded.
