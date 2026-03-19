---
id: story-033
title: REST API
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-001-multi-organization-support
  - story-005-event-creation-and-management
  - story-010-ticket-purchase-and-cart
---

# Story 033: REST API

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-033                                  |
| **Title**      | REST API                                   |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-001-multi-organization-support, story-005-event-creation-and-management, story-010-ticket-purchase-and-cart |

## Summary

As a developer, I want a comprehensive REST API, so that I can integrate external systems with the platform

## Description

### Context

Third-party developers and organizers with custom tooling need programmatic access to the platform's capabilities. This story provides a comprehensive REST API covering all major entities. It depends on organizations (story-001), events (story-005), and ticket purchasing (story-010) being in place so that the API has meaningful resources to expose.

### User Value

A well-documented, stable API enables developers to build integrations, automate workflows, and create custom experiences on top of the platform. This extends the platform's reach beyond its own UI and empowers organizers with technical teams to tailor the system to their needs.

### Approach

The API follows REST conventions with consistent resource naming, standard HTTP methods, and JSON responses. Authentication is handled via API tokens and OAuth tokens. List endpoints support pagination, filtering, and ordering. Rate limiting protects against abuse. The API is versioned to maintain backward compatibility.

## Acceptance Criteria

### 1. API Coverage

1. **Full Entity Access**: API covers all major entities: organizations, events, sub-events, items, orders, vouchers, check-in, customers, gift cards, and invoices.
2. **Authentication**: API supports authentication via API tokens and OAuth tokens.

### 2. API Features

3. **Query Capabilities**: API supports pagination, filtering, and ordering on list endpoints.
4. **Rate Limiting**: Rate limiting is applied to prevent abuse, with clear error responses when limits are exceeded.
5. **Backward Compatibility**: The API maintains backward compatibility within major versions.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: REST API

  Scenario: AC1 — Access all major entities via API
    Given I am an authenticated developer with a valid API token
    When I make requests to list organizations, events, sub-events, items, orders, vouchers, check-in records, customers, gift cards, and invoices
    Then each request returns the expected data in a consistent JSON format
    And I can create, read, update, and delete resources where permitted

  Scenario: AC2 — Authenticate with API token and OAuth token
    Given I have a valid API token
    When I include the token in the authorization header of my request
    Then the request is authenticated and I receive a successful response
    And when I use a valid OAuth token the request is also authenticated successfully

  Scenario: AC3 — Paginate, filter, and order list results
    Given there are multiple events in my organization
    When I request the events list with pagination parameters (page, per_page)
    Then I receive the correct page of results with pagination metadata
    And when I add a filter parameter the results are filtered accordingly
    And when I add an ordering parameter the results are sorted as specified

  Scenario: AC4 — Rate limiting with clear error response
    Given I am an authenticated developer
    When I exceed the API rate limit by sending too many requests in a short period
    Then I receive a 429 Too Many Requests response
    And the response includes a message indicating the rate limit was exceeded
    And the response includes headers showing when I can retry

  Scenario: AC5 — Backward compatibility within major version
    Given I am using API version 1
    And new fields have been added to the event resource in a recent update
    When I make a request to the events endpoint using version 1
    Then I receive the new fields alongside the existing ones
    And no previously existing fields have been removed or renamed
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Unauthenticated request
    Given I make an API request without any authentication token
    When the request is processed
    Then I receive a 401 Unauthorized response
    And the response body includes an error message explaining authentication is required

  Scenario: Token with insufficient scope
    Given I have an API token with read-only scope
    When I attempt to create a new event via the API
    Then I receive a 403 Forbidden response
    And the response indicates the token lacks the required scope

  Scenario: Rate limit exceeded
    Given I have already exceeded the rate limit
    When I send another request
    Then I receive a 429 response with a Retry-After header
    And after waiting the indicated time my next request succeeds

  Scenario: Paginate beyond last page
    Given there are 25 events and I request page 5 with 10 per page
    When the request is processed
    Then I receive an empty results list
    And the pagination metadata indicates there are no more pages

  Scenario: Filter with invalid parameters
    Given I make an API request with an unrecognized filter parameter
    When the request is processed
    Then I receive a 400 Bad Request response
    And the response body describes which parameters are invalid
```

## Assumptions

- API documentation is auto-generated and kept in sync with the implementation.
- Rate limits are configurable per token type (e.g., higher limits for OAuth apps vs. personal tokens).
- The initial API version is v1; breaking changes require a new major version.
