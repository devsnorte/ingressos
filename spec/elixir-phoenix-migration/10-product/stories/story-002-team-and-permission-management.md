---
id: story-002
title: Team and Permission Management
status: draft
priority: high
blocked_by: [story-001]
---

# Story 002: Team and Permission Management

| Field        | Value                                      |
|--------------|--------------------------------------------|
| **ID**       | story-002                                  |
| **Title**    | Team and Permission Management             |
| **Status**   | Draft                                      |
| **Priority** | High                                       |
| **Blocked by** | story-001-multi-organization-support     |

## Summary

As an organization admin, I want to manage teams and permissions, so that I can control who has access to what

## Description

Organization administrators need the ability to invite team members, assign roles, and configure granular permissions. This ensures that each member of an organization sees and does only what they are authorized to, supporting delegation of responsibilities across events.

## Acceptance Criteria

### 1. Team Member Invitation

1. **Invite by Email**: Organization admin can invite team members by email. Invitee receives an email with a join link.
2. **Assign Role**: When inviting, admin assigns a role (admin, event manager, check-in operator) that determines default permissions.

### 2. Permission Configuration

3. **Granular Permissions**: Admin can configure per-team permissions: access to events, orders, vouchers, reports, and settings. Permissions can be scoped to specific events.
4. **View-Only Mode**: Permissions support read-only access (e.g., "can view orders but not modify them").

### 3. Team Maintenance

5. **Remove Member**: Removing a team member requires confirmation and immediately revokes their active sessions.
6. **Last Admin Protection**: The system prevents removing the last admin from an organization.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Team and Permission Management

  Scenario: AC1 — Invite a team member by email
    Given I am logged in as an organization admin for "DevsNorte"
    When I navigate to the team management page
    And I invite "new-member@example.com" to join the team
    Then I see a confirmation that the invitation was sent
    And the invitee receives an email with a join link

  Scenario: AC2 — Assign a role during invitation
    Given I am logged in as an organization admin for "DevsNorte"
    When I invite "manager@example.com" with the role "event manager"
    Then the invitation is sent with the "event manager" role
    And when the invitee accepts, they have event manager permissions by default

  Scenario: AC3 — Configure granular permissions
    Given I am logged in as an organization admin for "DevsNorte"
    And "member@example.com" is a team member
    When I configure their permissions to access only "TechConf 2026" events and orders
    And I save the permission changes
    Then the member can only see "TechConf 2026" events and orders
    And they cannot access other events or settings

  Scenario: AC4 — Set view-only permission
    Given I am logged in as an organization admin for "DevsNorte"
    And "viewer@example.com" is a team member
    When I set their orders permission to "view only"
    And I save the permission changes
    Then the member can view orders but cannot modify or cancel them

  Scenario: AC5 — Remove a team member
    Given I am logged in as an organization admin for "DevsNorte"
    And "leaving@example.com" is a team member with an active session
    When I choose to remove "leaving@example.com"
    And I confirm the removal
    Then the member is removed from the team
    And their active sessions are immediately terminated

  Scenario: AC6 — Prevent removing the last admin
    Given I am logged in as the only admin of "DevsNorte"
    When I try to remove myself from the organization
    Then I see an error indicating I cannot remove the last admin
    And I remain a member of the organization
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Invite an already-existing user
    Given I am logged in as an organization admin for "DevsNorte"
    And "existing@example.com" is already a team member
    When I try to invite "existing@example.com" again
    Then I see a message indicating this person is already a member

  Scenario: Invite with an invalid email
    Given I am logged in as an organization admin for "DevsNorte"
    When I try to invite "not-an-email" to join the team
    Then I see a validation error on the email field
    And no invitation is sent

  Scenario: Remove last admin is blocked
    Given "DevsNorte" has exactly one admin
    When any action attempts to remove or demote the last admin
    Then the action is rejected with a clear explanation

  Scenario: Permission denied for unauthorized action
    Given "limited@example.com" has view-only access to orders
    When they attempt to cancel an order
    Then they see a "permission denied" message
    And the order remains unchanged

  Scenario: Concurrent permission change
    Given two admins are editing permissions for the same member simultaneously
    When both submit changes at the same time
    Then only the last saved change takes effect
    And the other admin sees a notification that the permissions were updated
```

## Assumptions

None.
