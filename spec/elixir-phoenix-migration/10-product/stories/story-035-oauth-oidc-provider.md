---
id: story-035
title: OAuth/OIDC Provider
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: medium
blocked_by:
  - story-003-customer-accounts
---

# Story 035: OAuth/OIDC Provider

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-035                                  |
| **Title**      | OAuth/OIDC Provider                        |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | Medium                                     |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-003-customer-accounts                |

## Summary

As a developer, I want the platform to act as an OAuth/OIDC provider, so that third-party apps can authenticate users

## Description

### Context

Third-party applications built around the platform ecosystem need a way to authenticate users and access their data with consent. This story makes the platform an OAuth 2.0 / OpenID Connect provider, allowing external apps to authenticate platform users. It depends on customer accounts (story-003) so that there are user identities to authenticate against.

### User Value

Developers can build third-party applications that leverage existing platform user accounts for authentication, eliminating the need for users to create separate credentials. Users benefit from a single sign-on experience across the platform and its ecosystem of integrations.

### Approach

Organizers register OAuth applications with redirect URIs and allowed scopes. Registered applications go through a review process before activation. The platform supports the standard OAuth 2.0 authorization code flow with token expiration and refresh. Scopes control the level of data access granted to each application.

## Acceptance Criteria

### 1. Application Registration

1. **Register App**: Organizers can register OAuth applications with redirect URIs and configure allowed scopes.
2. **Approval Flow**: Registered applications are reviewed before activation.

### 2. Auth Flows

3. **Standard Flows**: System supports standard OAuth 2.0 authorization code flow with token expiration and refresh.
4. **Scope Control**: Scopes control what data third-party applications can access (e.g., read profile, read orders).

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: OAuth/OIDC Provider

  Scenario: AC1 — Register an OAuth application
    Given I am an organizer on the developer settings page
    When I register a new OAuth application with name "My Event App"
    And I configure the redirect URI as "https://myapp.com/callback"
    And I select the scopes "read:profile" and "read:orders"
    And I submit the registration
    Then the application is created with a client ID and client secret
    And the application status shows as "pending review"

  Scenario: AC2 — Application review before activation
    Given an OAuth application "My Event App" has been registered and is pending review
    When an administrator reviews and approves the application
    Then the application status changes to "active"
    And the application can now be used for OAuth authorization flows

  Scenario: AC3 — Authorization code flow with token lifecycle
    Given an active OAuth application "My Event App"
    And a user navigates to the authorization endpoint with the correct client ID and redirect URI
    When the user grants consent to the requested scopes
    Then the user is redirected to the redirect URI with an authorization code
    And the application can exchange the code for an access token and refresh token
    And the access token expires after the configured duration
    And the refresh token can be used to obtain a new access token

  Scenario: AC4 — Scope-based access control
    Given an OAuth application has been granted the "read:profile" scope
    When the application uses the access token to request the user's profile
    Then the request succeeds and returns profile information
    And when the application attempts to access order data without the "read:orders" scope
    Then the request is denied with a 403 Forbidden response
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Invalid redirect URI
    Given I am registering a new OAuth application
    When I enter a redirect URI that does not match the registered URIs
    And a user attempts to authorize the application
    Then the authorization is rejected with an error indicating an invalid redirect URI
    And the user is not redirected

  Scenario: Expired token refresh
    Given an application has an expired access token and a valid refresh token
    When the application requests a new access token using the refresh token
    Then a new access token is issued
    And the old access token remains invalid

  Scenario: Revoked application access
    Given a user has previously granted access to an OAuth application
    When the user revokes the application's access from their account settings
    Then the application's existing tokens are invalidated
    And subsequent API requests with those tokens return 401 Unauthorized

  Scenario: Scope escalation attempt
    Given an OAuth application was granted "read:profile" scope
    When the application attempts to request a token with "write:events" scope
    Then the request is denied
    And the application only retains its originally granted scopes

  Scenario: Concurrent token requests
    Given an OAuth application makes multiple simultaneous token exchange requests with the same authorization code
    When the requests are processed
    Then only one request succeeds and returns tokens
    And the remaining requests are rejected because the authorization code has been consumed
```

## Assumptions

- The platform implements the OpenID Connect discovery endpoint for automatic client configuration.
- Authorization codes are single-use and expire after a short duration (e.g., 10 minutes).
- Refresh tokens can be revoked individually or all at once per application.
- The review process for new applications is manual; automated approval may be added in the future.
