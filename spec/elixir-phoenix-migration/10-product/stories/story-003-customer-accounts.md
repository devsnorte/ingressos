---
id: story-003
title: Customer Accounts
status: draft
priority: high
blocked_by: [story-001]
---

# Story 003: Customer Accounts

| Field        | Value                                      |
|--------------|--------------------------------------------|
| **ID**       | story-003                                  |
| **Title**    | Customer Accounts                          |
| **Status**   | Draft                                      |
| **Priority** | High                                       |
| **Blocked by** | story-001-multi-organization-support     |

## Summary

As an attendee, I want to create an account and manage my profile, so that I can track my orders across events

## Description

Attendees should be able to optionally create accounts to track their order history and manage their profile across multiple events and organizations. Guest checkout must also be supported for attendees who do not want to register. All account features must comply with LGPD data protection requirements.

## Acceptance Criteria

### 1. Account Creation

1. **Registration**: Attendees can create an account with email and password. Email verification is required.
2. **Optional Accounts**: Account creation is optional — attendees can purchase tickets as guests.
3. **Guest Order Access**: Guest purchasers can access their specific order via a unique link sent by email.

### 2. Account Features

4. **Order History**: Authenticated attendees can view their order history across all organizations and events, download tickets, and see upcoming events.
5. **LGPD Compliance**: Customers can request a full data export and account deletion.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Customer Accounts

  Scenario: AC1 — Register a new account with email verification
    Given I am on the registration page
    When I fill in my email and a valid password
    And I submit the registration form
    Then I see a message asking me to verify my email
    And I receive a verification email
    When I click the verification link
    Then my account is activated and I can log in

  Scenario: AC2 — Purchase tickets as a guest
    Given I am not logged in and do not have an account
    When I select tickets for an event
    And I complete the purchase providing only my email
    Then my order is confirmed
    And I am not required to create an account

  Scenario: AC3 — Access guest order via unique link
    Given I purchased tickets as a guest
    When I open the unique order link from my confirmation email
    Then I see my order details including tickets and event information

  Scenario: AC4 — View order history as an authenticated attendee
    Given I am logged in as an attendee
    And I have purchased tickets for 3 different events across 2 organizations
    When I navigate to my order history
    Then I see all 3 orders with event names, dates, and statuses
    And I can download my tickets for each order
    And I can see my upcoming events

  Scenario: AC5 — Request data export and account deletion
    Given I am logged in as an attendee
    When I navigate to my privacy settings
    And I request a full data export
    Then I receive a downloadable file with all my personal data
    When I request account deletion
    And I confirm the deletion
    Then my account and personal data are removed from the platform
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Duplicate email registration
    Given an account with "already@example.com" already exists
    When I try to register with "already@example.com"
    Then I see an error indicating the email is already in use
    And no duplicate account is created

  Scenario: Invalid password during registration
    Given I am on the registration page
    When I fill in my email and a password shorter than 8 characters
    And I submit the registration form
    Then I see a validation error about password requirements

  Scenario: Expired verification link
    Given I registered but did not verify my email within the allowed time
    When I click the expired verification link
    Then I see a message that the link has expired
    And I am offered the option to resend the verification email

  Scenario: Data export with no orders
    Given I am logged in as an attendee with no order history
    When I request a full data export
    Then I receive a file containing only my profile information

  Scenario: Account deletion with active orders
    Given I am logged in as an attendee
    And I have orders for upcoming events
    When I request account deletion
    Then I am informed about the impact on my active orders
    And I must explicitly confirm before deletion proceeds
```

## Assumptions

Assumed password requirements follow OWASP guidelines (min 8 chars, no specific complexity rules beyond length).
