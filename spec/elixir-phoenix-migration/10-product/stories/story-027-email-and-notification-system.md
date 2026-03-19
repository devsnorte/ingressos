---
id: story-027
title: Email and Notification System
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-005-event-creation-and-management
  - story-010-ticket-purchase-and-cart
---

# Story 027: Email and Notification System

| Field          | Value                                                                    |
|----------------|--------------------------------------------------------------------------|
| **ID**         | story-027                                                                |
| **Title**      | Email and Notification System                                            |
| **Parent Epic**| TBD                                                                      |
| **Fix Version**| TBD                                                                      |
| **Status**     | Draft                                                                    |
| **Priority**   | High                                                                     |
| **Labels**     | agentic-workflow                                                         |
| **Blocked by** | story-005-event-creation-and-management, story-010-ticket-purchase-and-cart |

## Summary

As an organizer, I want the system to send transactional and bulk emails, so that attendees stay informed

## Description

### Context

Communication with attendees is critical throughout the event lifecycle — from order confirmation and payment reminders to event-day logistics. A reliable email system ensures attendees receive timely, relevant information while giving organizers the flexibility to customize messaging and reach specific audience segments.

### User Value

Attendees receive automatic notifications at key moments (order confirmed, ticket ready for download, event reminder), reducing support inquiries and improving the event experience. Organizers can customize email templates to match their brand and send targeted bulk communications to specific attendee groups. Reliable delivery with retry logic ensures messages reach their destination.

### Approach

Implement an asynchronous email system that sends transactional emails triggered by system events and supports organizer-initiated bulk messaging. Organizers can customize templates per event and preview them. Emails are queued and processed with retry logic and exponential backoff for failed deliveries. Email sending requires a configured SMTP provider.

## Acceptance Criteria

### 1. Transactional Emails

1. **Event-Triggered**: System automatically sends emails for: order confirmation, payment reminder, ticket download, event reminder, and waiting list offers.
2. **Customizable Templates**: Organizers can customize email templates per event and preview them before activating.

### 2. Bulk Messaging

3. **Bulk Send**: Organizers can send bulk emails to all attendees or filtered groups.

### 3. Delivery Management

4. **Mail Queue**: Emails are sent asynchronously with retry logic for failed deliveries and exponential backoff.
5. **SMTP Required**: Email sending requires a configured SMTP provider.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Email and Notification System

  Scenario: AC1 — Transactional email sent on order confirmation
    Given an attendee completes a ticket purchase
    When the payment is confirmed
    Then the attendee receives an order confirmation email
    And the email contains the order details and event information

  Scenario: AC1b — Payment reminder email sent for pending orders
    Given an attendee has a pending order awaiting payment
    And the payment deadline is approaching
    When the reminder schedule is triggered
    Then the attendee receives a payment reminder email
    And the email contains payment instructions and deadline

  Scenario: AC1c — Event reminder email sent before the event
    Given an attendee has a confirmed ticket for an upcoming event
    When the event reminder schedule is triggered
    Then the attendee receives an event reminder email
    And the email contains the event date, time, and venue details

  Scenario: AC2 — Organizer customizes and previews email template
    Given I am logged in as an organizer
    And I have an event configured
    When I navigate to the email template settings for the event
    And I customize the order confirmation template with a custom header and message
    And I click preview
    Then I see a preview of the email with sample data populated
    When I save the template
    Then future order confirmation emails for this event use the customized template

  Scenario: AC3 — Organizer sends bulk email to attendees
    Given I am logged in as an organizer
    And my event has attendees with confirmed orders
    When I navigate to the bulk email feature
    And I compose a message with subject "Important Update"
    And I select "All attendees" as the recipients
    And I send the bulk email
    Then the email is queued for delivery to all attendees
    And I see a confirmation with the number of recipients

  Scenario: AC4 — Failed email is retried with exponential backoff
    Given an email delivery fails on the first attempt
    When the mail queue processes the failed email
    Then it retries delivery after a delay
    And subsequent retries use increasing intervals
    And the email is eventually delivered or marked as permanently failed

  Scenario: AC5 — Email requires SMTP configuration
    Given I am logged in as an organizer
    And no SMTP provider is configured
    When I attempt to send an email
    Then I see a message indicating that an SMTP provider must be configured
    And no email is sent
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Email to an invalid attendee address
    Given an attendee has an invalid email address on file
    When a transactional email is triggered for that attendee
    Then the delivery fails and is recorded
    And the organizer can see the failed delivery in the email log

  Scenario: Bulk send to an empty attendee list
    Given I am logged in as an organizer
    And I filter attendees by a group with no members
    When I attempt to send a bulk email to the filtered group
    Then I see a message that there are no recipients matching the filter
    And no email is queued

  Scenario: Template preview with placeholder data
    Given I am logged in as an organizer
    When I preview an email template
    Then placeholder fields like attendee name and order number are filled with sample data
    And the preview accurately represents the final email appearance

  Scenario: SMTP provider becomes unavailable during sending
    Given emails are queued for delivery
    And the SMTP provider becomes unreachable
    When the mail queue attempts to send
    Then the emails are marked for retry
    And the system does not lose any queued emails

  Scenario: Duplicate email prevention on retry
    Given an email was sent but the delivery confirmation was lost
    When the system retries the same email
    Then the attendee does not receive duplicate emails
```
