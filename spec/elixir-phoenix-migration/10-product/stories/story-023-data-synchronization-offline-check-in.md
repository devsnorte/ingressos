---
id: story-023
title: Data Synchronization (Offline Check-in)
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-022-device-provisioning
---

# Story 023: Data Synchronization (Offline Check-in)

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-023                                  |
| **Title**      | Data Synchronization (Offline Check-in)    |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-022-device-provisioning              |

## Summary

As a check-in device, I want to sync data for offline use, so that check-in works even with poor connectivity

## Description

### Context

This story covers the data synchronization mechanism that allows check-in devices to operate without a network connection. It depends on device provisioning (story-022) because only provisioned devices can sync data. Offline capability is critical for venues with poor connectivity.

### User Value

Event venues frequently have unreliable network connectivity, especially when crowded. Check-in operators need to continue validating attendees without interruption. By syncing attendee data beforehand and uploading results when connectivity returns, the check-in experience remains seamless regardless of network conditions.

### Approach

Devices download the data they need (event details, attendee lists, ticket information) before the event or during periods of connectivity. An incremental sync mechanism ensures only changes are transferred after the initial download. When operating offline, check-in results are stored locally and uploaded when connectivity is restored. Conflicts from multiple devices checking in the same ticket offline are resolved by accepting the earliest timestamp.

## Acceptance Criteria

### 1. Data Download

1. **Sync Data**: Devices can download event, item, and attendee data for offline use. Sync data includes only what the device needs for its assigned check-in lists.
2. **Incremental Sync**: Subsequent syncs transfer only changes since the last sync.

### 2. Conflict Resolution

3. **Upload Results**: Devices sync check-in results back to the platform when connectivity is restored.
4. **Conflict Handling**: If the same ticket was checked in on multiple devices while offline, the system accepts the earliest check-in timestamp.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Data Synchronization (Offline Check-in)

  Scenario: AC1 — Download event data for offline use
    Given I have a provisioned check-in device assigned to the "Main Entrance" check-in list
    And the "Main Entrance" list includes 200 attendees
    When I initiate a data sync on the device
    Then the device downloads event details and the 200 attendees on the "Main Entrance" list
    And the device does not download attendees from other check-in lists
    And I see a confirmation that the sync is complete

  Scenario: AC2 — Incremental sync transfers only changes
    Given my device last synced at 09:00 and it is now 10:00
    And 5 new attendees have been added to my check-in list since 09:00
    And 2 existing attendees have been updated
    When I initiate another sync
    Then only the 5 new and 2 updated attendee records are transferred
    And previously synced data remains intact on the device

  Scenario: AC3 — Upload check-in results when connectivity is restored
    Given my device was offline and I checked in 15 attendees locally
    When the device regains network connectivity
    And the device syncs check-in results to the platform
    Then all 15 check-in records appear on the organizer's dashboard
    And each record shows the correct check-in time from when it was performed offline

  Scenario: AC4 — Conflict resolution uses earliest timestamp
    Given two devices were offline at the same time
    And Device A checked in attendee "Jane Doe" at 09:15
    And Device B checked in the same attendee "Jane Doe" at 09:18
    When both devices come online and sync their results
    Then the system records "Jane Doe"'s check-in time as 09:15
    And only one check-in record exists for "Jane Doe" on that check-in list
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Sync with no network connection
    Given my device has no network connectivity
    When I attempt to initiate a data sync
    Then I see a message indicating the device is offline
    And any previously synced data remains available for offline check-in

  Scenario: Sync interrupted mid-transfer
    Given my device is syncing attendee data
    And the network connection drops after 50% of the data is transferred
    When connectivity is restored and I sync again
    Then the sync resumes and completes without duplicating already-transferred records
    And the device has the full dataset after the second sync

  Scenario: Conflict with different timestamps across multiple devices
    Given three devices were offline simultaneously
    And Device A checked in "Bob Lee" at 14:02
    And Device B checked in "Bob Lee" at 14:05
    And Device C checked in "Bob Lee" at 14:01
    When all three devices sync their results
    Then the system records "Bob Lee"'s check-in time as 14:01 from Device C
    And only one check-in record exists for "Bob Lee"

  Scenario: Sync a large event dataset
    Given my check-in list includes 10,000 attendees
    When I initiate the initial data sync
    Then the sync completes within a reasonable time
    And I see a progress indicator during the download
    And all 10,000 attendee records are available for offline check-in

  Scenario: Stale data after event changes
    Given my device last synced at 08:00
    And the organizer removed 3 ticket types from my check-in list at 08:30
    When I sync again at 09:00
    Then the removed attendees no longer appear on my device's check-in list
    And any check-ins I performed for those removed attendees while offline are flagged for organizer review
```

## Assumptions

- Devices store synced data securely on the local device storage.
- The platform tracks the last sync timestamp per device to enable incremental sync.
- Conflict resolution applies per check-in list — a ticket checked in on different lists is not considered a conflict.
- Large dataset syncs may require Wi-Fi; the device warns the operator if syncing over cellular with a large dataset.
