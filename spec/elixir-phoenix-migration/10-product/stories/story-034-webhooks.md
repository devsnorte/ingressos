---
id: story-034
title: Webhooks
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: medium
blocked_by:
  - story-033-rest-api
---

# Story 034: Webhooks

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-034                                  |
| **Title**      | Webhooks                                   |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | Medium                                     |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-033-rest-api                         |

## Summary

As an organizer, I want to configure webhooks, so that external systems are notified of platform events

## Description

### Context

Organizers and developers often need external systems (CRMs, marketing tools, custom dashboards) to react in real time to platform events such as new orders or check-ins. This story introduces webhook configuration so the platform can push notifications to external endpoints. It depends on the REST API (story-033) because webhook payloads reference API resource formats.

### User Value

Webhooks enable real-time integration without polling. Organizers can connect the platform to their existing tools and workflows, receiving instant notifications when important events occur (e.g., a ticket is sold, an attendee checks in).

### Approach

Organizers register webhook endpoints through the platform settings, selecting which event types trigger notifications. Payloads are signed for authenticity verification. Failed deliveries are retried with exponential backoff, and delivery history is visible for troubleshooting.

## Acceptance Criteria

### 1. Webhook Configuration

1. **Register Endpoint**: Organizer registers webhook URLs that receive notifications for specific events (order placed, order paid, check-in, etc.).
2. **Signed Payloads**: Webhook payloads are signed so receivers can verify authenticity.

### 2. Delivery

3. **Retry Logic**: Failed deliveries are retried with exponential backoff.
4. **Delivery History**: Delivery history and status (success, failed, pending retry) are visible to the organizer.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Webhooks

  Scenario: AC1 — Register a webhook endpoint
    Given I am an organizer on the webhook settings page
    When I enter a webhook URL "https://myapp.com/hooks"
    And I select the event types "order.placed" and "checkin.completed"
    And I save the webhook configuration
    Then the webhook is registered and listed in my webhook settings
    And it shows the selected event types

  Scenario: AC2 — Webhook payloads are signed
    Given I have a registered webhook endpoint
    When a subscribed event occurs (e.g., an order is placed)
    Then the webhook delivery includes a signature header
    And the receiver can verify the payload authenticity using the shared secret

  Scenario: AC3 — Failed deliveries are retried
    Given I have a registered webhook endpoint that is temporarily unavailable
    When a subscribed event triggers a webhook delivery
    And the initial delivery attempt fails
    Then the system retries the delivery with increasing delays between attempts
    And the delivery status shows as "pending retry"

  Scenario: AC4 — View delivery history
    Given I have a registered webhook with past deliveries
    When I navigate to the webhook delivery history
    Then I see a list of deliveries with their status (success, failed, pending retry)
    And I can see the timestamp, event type, and response status for each delivery
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Webhook endpoint timeout
    Given I have a registered webhook endpoint that takes too long to respond
    When a delivery is attempted
    Then the delivery is marked as failed due to timeout
    And the system schedules a retry according to the backoff policy

  Scenario: Invalid URL registration
    Given I am on the webhook settings page
    When I enter an invalid URL "not-a-url"
    And I attempt to save the webhook
    Then I see a validation error indicating the URL is invalid
    And the webhook is not saved

  Scenario: All retries exhausted
    Given a webhook delivery has failed all retry attempts
    When I view the delivery history
    Then the delivery status shows as "failed"
    And I see how many retry attempts were made
    And no further retries are scheduled for that delivery

  Scenario: Webhook for event in different organization
    Given I have a webhook registered for my organization
    When an event occurs in a different organization
    Then my webhook is not triggered
    And no delivery is recorded for my webhook

  Scenario: Concurrent events triggering same webhook
    Given I have a webhook registered for "order.placed"
    When multiple orders are placed simultaneously
    Then each order triggers a separate webhook delivery
    And all deliveries are recorded independently in the delivery history
```

## Assumptions

- Webhook endpoints must use HTTPS for security.
- The shared secret for payload signing is generated when the webhook is created and can be rotated by the organizer.
- The maximum number of retry attempts is configurable with a sensible default (e.g., 5 attempts).
- Webhook deliveries time out after a configurable threshold (e.g., 10 seconds).
