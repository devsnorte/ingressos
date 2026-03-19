---
id: story-004
title: Two-Factor Authentication
status: draft
priority: medium
blocked_by: [story-003]
---

# Story 004: Two-Factor Authentication

| Field        | Value                                      |
|--------------|--------------------------------------------|
| **ID**       | story-004                                  |
| **Title**    | Two-Factor Authentication                  |
| **Status**   | Draft                                      |
| **Priority** | Medium                                     |
| **Blocked by** | story-003-customer-accounts              |

## Summary

As a user, I want to enable two-factor authentication, so that my account is more secure

## Description

Users should be able to strengthen their account security by enabling two-factor authentication. The platform supports TOTP (authenticator apps) and WebAuthn/FIDO2 (hardware security keys). Recovery codes are provided as a fallback. Organization admins can require 2FA for all team members.

## Acceptance Criteria

### 1. 2FA Setup

1. **TOTP Support**: Users can enable time-based one-time passwords via authenticator apps. A QR code and manual key are shown during setup.
2. **WebAuthn/FIDO2**: Users can register hardware security keys as a second factor.
3. **Recovery Codes**: During 2FA setup, the system generates recovery codes shown once. Users must acknowledge they have saved them.

### 2. 2FA Enforcement

4. **Org Requirement**: Organization admins can require 2FA for all team members. Members without 2FA are prompted to set it up on next login.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Two-Factor Authentication

  Scenario: AC1 — Enable TOTP via authenticator app
    Given I am logged in as a user
    When I navigate to my security settings
    And I choose to enable two-factor authentication via authenticator app
    Then I see a QR code and a manual setup key
    When I enter a valid code from my authenticator app
    Then 2FA via TOTP is enabled on my account

  Scenario: AC2 — Register a hardware security key
    Given I am logged in as a user
    When I navigate to my security settings
    And I choose to add a hardware security key
    And I follow the prompts to register my key
    Then the security key is registered as a second factor on my account

  Scenario: AC3 — Receive and acknowledge recovery codes
    Given I am logged in as a user
    And I am completing 2FA setup
    When the system shows me a set of recovery codes
    Then I see a clear message that these codes are shown only once
    And I must confirm I have saved the codes before setup is finalized

  Scenario: AC4 — Organization admin requires 2FA for team
    Given I am logged in as an organization admin for "DevsNorte"
    When I enable the "require 2FA" setting for the organization
    Then all team members without 2FA are prompted to set it up on their next login
    And members cannot access organization resources until 2FA is enabled
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Invalid TOTP code during setup
    Given I am setting up TOTP for my account
    When I enter an incorrect code from my authenticator app
    Then I see an error indicating the code is invalid
    And 2FA is not enabled

  Scenario: Expired TOTP code
    Given I have 2FA enabled via TOTP
    When I attempt to log in with a code that has already expired
    Then I see an error indicating the code is no longer valid
    And I am prompted to enter a current code

  Scenario: All recovery codes used
    Given I have used all of my recovery codes
    When I attempt to log in using a recovery code
    Then I see a message that no recovery codes remain
    And I am directed to contact support or use another 2FA method

  Scenario: Lost 2FA requiring admin recovery
    Given I have lost access to my authenticator app and recovery codes
    When I contact my organization admin for account recovery
    Then the admin can initiate a supervised 2FA reset for my account

  Scenario: Enabling multiple 2FA methods simultaneously
    Given I have TOTP enabled on my account
    When I also register a hardware security key
    Then both methods are available for login
    And I can choose which method to use when prompted for 2FA
```

## Assumptions

None.
