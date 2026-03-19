---
id: story-022
title: Device Provisioning
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-001-multi-organization-support
  - story-020-check-in
---

# Story 022: Device Provisioning

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-022                                  |
| **Title**      | Device Provisioning                        |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-001-multi-organization-support, story-020-check-in |

## Summary

As an organizer, I want to provision check-in devices, so that volunteers can check in attendees using their phones

## Description

### Context

This story covers how organizers set up and manage the devices that volunteers and staff use for check-in at events. It depends on multi-organization support (story-001) because devices are scoped to organizations, and on check-in (story-020) because provisioned devices run the check-in flow.

### User Value

Organizers need a simple, secure way to turn volunteers' personal phones and tablets into check-in devices. The provisioning process must be straightforward enough for non-technical volunteers, while giving organizers full visibility and control over which devices have access to event data.

### Approach

Organizers generate initialization tokens that volunteers use to set up their devices. Once provisioned, devices appear in a management dashboard where organizers can monitor status, see last sync times, and revoke access when needed. All device access is scoped to a single organization for security.

## Acceptance Criteria

### 1. Device Setup

1. **Initialize Device**: Organizer generates an initialization token. The token can be used to set up a check-in device (phone or tablet).
2. **Device Status**: Provisioned devices report their status and last sync time. Organizers see a list of all provisioned devices.

### 2. Device Management

3. **Revoke Access**: Organizer can revoke device access with explicit confirmation.
4. **Organization Scope**: Devices are scoped to an organization — they can only access that organization's events and data.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Device Provisioning

  Scenario: AC1 — Generate a token and initialize a check-in device
    Given I am an organizer for the organization "DevsNorte"
    When I navigate to the device management area
    And I generate a new initialization token
    Then I see a token displayed that I can share with a volunteer
    When a volunteer opens the check-in app on their phone
    And enters the initialization token
    Then the device is provisioned and linked to "DevsNorte"
    And the device appears in my list of provisioned devices

  Scenario: AC2 — View provisioned device status and last sync time
    Given I am an organizer for the organization "DevsNorte"
    And there are 3 provisioned devices linked to my organization
    When I navigate to the device management area
    Then I see a list of all 3 provisioned devices
    And each device shows its current status and last sync time

  Scenario: AC3 — Revoke device access with confirmation
    Given I am an organizer for the organization "DevsNorte"
    And a device "Volunteer Phone 1" is provisioned and active
    When I choose to revoke access for "Volunteer Phone 1"
    Then I see a confirmation prompt asking me to confirm the revocation
    When I confirm the revocation
    Then "Volunteer Phone 1" is marked as revoked
    And the device can no longer access event data or perform check-ins

  Scenario: AC4 — Device access is scoped to its organization
    Given a device is provisioned for the organization "DevsNorte"
    And another organization "TechGroup" also has events
    When the device attempts to access event data
    Then it can only see events belonging to "DevsNorte"
    And it cannot access any data from "TechGroup"
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Expired initialization token
    Given I am an organizer and I generated an initialization token 25 hours ago
    And the token has expired
    When a volunteer attempts to use the expired token to provision a device
    Then the device setup fails with a message indicating the token has expired
    And the device is not provisioned

  Scenario: Revoked device attempting to sync
    Given a device "Volunteer Phone 1" was previously provisioned for "DevsNorte"
    And the organizer has revoked its access
    When "Volunteer Phone 1" attempts to sync event data
    Then the sync request is rejected
    And the device sees a message indicating its access has been revoked

  Scenario: Provision device without organizer permission
    Given I am a team member with "View Only" permissions in the organization "DevsNorte"
    When I attempt to generate an initialization token
    Then I see a message indicating I do not have permission to provision devices

  Scenario: Device from another organization attempting access
    Given a device is provisioned for "TechGroup"
    When the device attempts to access check-in data for a "DevsNorte" event
    Then the request is denied
    And the device sees an authorization error
```

## Assumptions

- Initialization tokens have a configurable expiration period (default 24 hours).
- A device can only be linked to one organization at a time.
- Revoking a device does not delete historical check-in records made by that device.
