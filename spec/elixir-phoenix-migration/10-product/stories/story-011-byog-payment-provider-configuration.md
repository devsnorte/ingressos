---
id: story-011
title: "BYOG — Payment Provider Configuration"
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-001-multi-organization-support
---

# Story 011: BYOG — Payment Provider Configuration

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-011                                  |
| **Title**      | BYOG — Payment Provider Configuration      |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-001-multi-organization-support       |

## Summary

As an organization admin, I want to configure my own payment provider, so that I can receive payments through my preferred gateway

## Description

### Context

BYOG (Bring Your Own Gateway) allows each organization to connect their own payment processing accounts. This story covers the configuration and management of payment provider credentials at the organization level. It depends on multi-organization support (story-001) for the organizational context.

### User Value

Organization admins need control over how payments are processed. By connecting their own payment provider, they receive funds directly, choose their preferred gateway, and maintain their existing merchant relationships. Secure credential management and validation ensure reliable payment processing.

### Approach

Admins configure payment providers through a settings panel within their organization. The system supports multiple providers per organization, with credential validation before activation. Credential rotation is designed for zero-downtime updates, and access is restricted to organization admins only.

## Acceptance Criteria

### 1. Provider Selection

1. **Supported Providers**: System shows available payment providers. Initial release: Manual/bank transfer (built-in), Pix, and Stripe.
2. **Enter Credentials**: Admin enters provider-specific credentials (API keys, webhook secrets). Credentials are never shown in full after entry (only last 4 characters).

### 2. Validation and Management

3. **Test Configuration**: Admin can validate the configuration using the provider's sandbox/test mode. For providers without test mode, the system validates via a read-only API call. Clear pass/fail result with error details.
4. **Credential Rotation**: Admin can update API keys without downtime — old credentials remain active until new ones are validated.
5. **Multiple Providers**: Multiple providers can be configured per organization, with one set as default per event.
6. **Access Control**: Only organization admins can view, add, edit, or remove payment credentials. Removing an admin revokes their sessions immediately.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: BYOG — Payment Provider Configuration

  Scenario: AC1 — View available payment providers
    Given I am logged in as an organization admin
    When I navigate to payment provider settings
    Then I see a list of available providers including Manual/bank transfer, Pix, and Stripe

  Scenario: AC2 — Enter and mask credentials
    Given I am on the Stripe provider configuration page
    When I enter my API key and webhook secret
    And I save the configuration
    Then I see the credentials masked, showing only the last 4 characters
    And the full credentials are not retrievable from the interface

  Scenario: AC3 — Validate provider configuration
    Given I have entered Stripe credentials for my organization
    When I click the test configuration button
    Then I see a clear pass or fail result
    And if it fails, I see specific error details explaining the issue

  Scenario: AC4 — Rotate credentials without downtime
    Given my organization has an active Stripe configuration processing payments
    When I enter new API credentials and save
    Then the system validates the new credentials before activating them
    And the old credentials remain active until validation succeeds

  Scenario: AC5 — Configure multiple providers with per-event default
    Given my organization has Stripe and Pix configured
    When I set Pix as the default provider for a specific event
    Then that event uses Pix as its primary payment method
    And other events continue to use the organization-level default

  Scenario: AC6 — Restrict credential access to admins only
    Given I am logged in as a team member without admin privileges
    When I navigate to the organization settings area
    Then I do not see the payment provider configuration section
    And I cannot access the payment credentials through any means
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Invalid credentials rejected
    Given I am configuring a Stripe provider for my organization
    When I enter invalid API credentials and save
    Then I see a validation error indicating the credentials are invalid
    And the provider is not activated

  Scenario: Test mode unavailable for provider
    Given I am configuring a provider that does not support sandbox mode
    When I click the test configuration button
    Then the system performs a read-only validation call
    And I see a pass or fail result based on that call

  Scenario: Non-admin attempts to configure a provider
    Given I am logged in as a team member with editor role
    When I attempt to access the payment provider configuration
    Then I am denied access with a permission error message

  Scenario: Remove last payment provider with active paid events
    Given my organization has only one payment provider configured
    And there are active paid events using that provider
    When I attempt to remove the provider
    Then I see a warning that active paid events depend on this provider
    And the removal is blocked until events are updated or deactivated

  Scenario: Credential rotation failure
    Given I am rotating API credentials for an active provider
    When I enter new credentials that fail validation
    Then the old credentials remain active and unchanged
    And I see an error message about the new credentials
    And no payment processing is interrupted

  Scenario: Concurrent credential updates by two admins
    Given two organization admins open the Stripe configuration simultaneously
    And both modify the API key at the same time
    When both submit their changes
    Then only one update succeeds
    And the other admin sees a message that the configuration was changed
```

## Assumptions

- The "Manual/bank transfer" provider is built-in and does not require external credentials.
- Webhook endpoints are automatically provisioned when a provider is configured.
- Session revocation on admin removal applies to all active sessions, including API tokens.
