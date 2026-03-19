---
id: story-030
title: Multi-Domain Support
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: medium
blocked_by:
  - story-001-multi-organization-support
---

# Story 030: Multi-Domain Support

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-030                                  |
| **Title**      | Multi-Domain Support                       |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | Medium                                     |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-001-multi-organization-support       |

## Summary

As an organization admin, I want to configure a custom domain, so that my event pages use my own branding

## Description

### Context

Organizations hosting events on the platform may want their event pages to appear under their own domain (e.g., tickets.mycompany.com) rather than the platform's default domain. This story enables custom domain configuration with automatic SSL provisioning. It depends on multi-organization support (story-001) being in place so that domains are scoped to organizations.

### User Value

A custom domain reinforces the organization's brand identity and builds trust with attendees. Visitors see a familiar URL, which increases confidence in the purchase flow and reduces the perception of being redirected to an unknown third-party site.

### Approach

The admin configures a custom domain through the organization settings. The platform provides DNS instructions (typically a CNAME record), validates that DNS is properly configured, and automatically provisions an SSL certificate. Until DNS propagation is complete, the system shows a clear status indicator so the admin knows the domain is not yet active.

## Acceptance Criteria

### 1. Domain Configuration

1. **Custom Domain**: Organization admin can configure a custom domain name for their event pages.
2. **DNS Instructions**: System provides clear DNS configuration instructions for the admin.
3. **SSL Provisioning**: SSL certificates are automatically provisioned for configured custom domains.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Multi-Domain Support

  Scenario: AC1 — Configure a custom domain
    Given I am an organization admin on the organization settings page
    When I enter a custom domain name "tickets.mycompany.com"
    And I save the domain configuration
    Then the custom domain "tickets.mycompany.com" is listed as pending verification
    And my event pages will be accessible via "tickets.mycompany.com" once DNS is verified

  Scenario: AC2 — View DNS configuration instructions
    Given I have configured a custom domain "tickets.mycompany.com"
    When I view the domain configuration details
    Then I see clear DNS instructions including the record type, name, and target value
    And I see the current DNS verification status

  Scenario: AC3 — Automatic SSL provisioning
    Given I have configured a custom domain "tickets.mycompany.com"
    And DNS records are correctly pointing to the platform
    When the system verifies the DNS configuration
    Then an SSL certificate is automatically provisioned for "tickets.mycompany.com"
    And the domain status changes to "active"
    And event pages are served securely over HTTPS on the custom domain
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Invalid domain format
    Given I am an organization admin on the domain configuration page
    When I enter an invalid domain format "not a domain!!"
    And I attempt to save the configuration
    Then I see a validation error indicating the domain format is invalid
    And the domain is not saved

  Scenario: DNS not yet propagated
    Given I have configured a custom domain "tickets.mycompany.com"
    And DNS records have not yet been updated
    When I check the domain status
    Then I see a status of "pending DNS verification"
    And I see a message explaining that DNS propagation can take up to 48 hours

  Scenario: Domain already used by another organization
    Given another organization has already configured "tickets.popular.com"
    When I attempt to configure "tickets.popular.com" for my organization
    Then I see an error indicating the domain is already in use
    And the domain is not saved

  Scenario: SSL provisioning failure
    Given I have configured a custom domain with valid DNS
    And SSL certificate provisioning fails due to an external issue
    When I view the domain status
    Then I see a status indicating SSL provisioning failed
    And I see instructions to retry or contact support

  Scenario: Remove custom domain
    Given I have an active custom domain "tickets.mycompany.com"
    When I remove the custom domain from my organization settings
    Then the domain is no longer listed in my configuration
    And event pages are no longer accessible via "tickets.mycompany.com"
    And event pages remain accessible via the platform's default domain
```

## Assumptions

- Each organization can configure at most one custom domain at a time.
- The platform handles SSL certificate renewal automatically before expiration.
- Removing a custom domain does not affect existing links shared via the default platform domain.
