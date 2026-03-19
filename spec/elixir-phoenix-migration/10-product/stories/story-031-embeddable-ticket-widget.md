---
id: story-031
title: Embeddable Ticket Widget
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: medium
blocked_by:
  - story-010-ticket-purchase-and-cart
  - story-012-byog-payment-processing
---

# Story 031: Embeddable Ticket Widget

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-031                                  |
| **Title**      | Embeddable Ticket Widget                   |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | Medium                                     |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-010-ticket-purchase-and-cart, story-012-byog-payment-processing |

## Summary

As an organizer, I want to embed a ticket widget on external websites, so that attendees can buy tickets without leaving my site

## Description

### Context

Organizers often promote events on their own websites or blogs. Rather than redirecting visitors to the platform, an embeddable widget lets attendees browse tickets and complete purchases directly on the organizer's site. This depends on the ticket purchase flow (story-010) and payment processing (story-012) being functional.

### User Value

Keeping the purchase flow on the organizer's own site reduces friction and drop-off. Attendees stay in a familiar environment, which increases conversion rates and reinforces the organizer's brand.

### Approach

The platform provides a code snippet (e.g., a script tag or iframe embed) that the organizer pastes into their website. The widget renders the ticket selection and checkout flow inline when the payment provider supports it, or redirects the attendee for providers that require it. The widget respects the event's branding and adapts to the host page's width.

## Acceptance Criteria

### 1. Widget Setup

1. **Embed Code**: Organizer copies a provided embed code snippet to place on their external website.
2. **Responsive**: Widget adapts to the host page's width and respects event branding.

### 2. Widget Behavior

3. **Inline Flow**: For providers supporting inline payment (Stripe, Pix), the entire purchase flow stays within the widget.
4. **Redirect Flow**: For redirect-based providers (PayPal, Mercado Pago), the attendee is redirected and returns to the host site after payment.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Embeddable Ticket Widget

  Scenario: AC1 — Copy embed code for an event
    Given I am an organizer viewing my event's settings
    When I navigate to the widget embed section
    Then I see an embed code snippet ready to copy
    And the snippet includes my event's unique identifier

  Scenario: AC2 — Widget is responsive and branded
    Given I have embedded the ticket widget on my external website
    When a visitor views the page on different screen sizes
    Then the widget adjusts its layout to fit the host page's width
    And the widget displays my event's branding (colors, logo)

  Scenario: AC3 — Inline purchase flow within widget
    Given a visitor is viewing the embedded widget for an event with Stripe configured
    When the visitor selects tickets and proceeds to checkout
    Then the entire purchase flow (selection, attendee info, payment, confirmation) occurs within the widget
    And the visitor is never navigated away from the host page

  Scenario: AC4 — Redirect-based purchase flow
    Given a visitor is viewing the embedded widget for an event with PayPal configured
    When the visitor selects tickets and proceeds to payment
    Then the visitor is redirected to PayPal to complete payment
    And after payment the visitor returns to the host page
    And the widget shows the order confirmation
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Widget on HTTP (non-HTTPS) page
    Given I have embedded the ticket widget on an HTTP page
    When a visitor loads the page
    Then the widget displays a warning that a secure connection is recommended
    And the widget still loads but payment functionality may be restricted

  Scenario: Widget with sold-out event
    Given all tickets for the event are sold out
    When a visitor views the embedded widget
    Then the widget displays a sold-out message
    And no ticket selection or checkout options are available

  Scenario: Widget with no payment provider configured
    Given the event has no payment provider configured
    When a visitor views the embedded widget
    Then the widget shows available ticket types
    And if all tickets are free the visitor can complete checkout
    And if paid tickets exist the widget indicates that purchasing is currently unavailable

  Scenario: Widget cross-origin security
    Given the embed code is placed on a domain not owned by the organizer
    When the widget loads
    Then the widget functions correctly regardless of the host domain
    And sensitive payment data is handled securely within the widget's isolated context
```

## Assumptions

- The embed code is a lightweight script tag that loads the widget asynchronously without blocking the host page.
- The widget communicates with the platform via secure, cross-origin-safe mechanisms.
- Widget appearance can be customized through the event's branding settings; no additional widget-specific styling is required.
