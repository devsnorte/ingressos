---
id: story-012
title: "BYOG — Payment Processing"
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-010-ticket-purchase-and-cart
  - story-011-byog-payment-provider-configuration
---

# Story 012: BYOG — Payment Processing

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-012                                  |
| **Title**      | BYOG — Payment Processing                  |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-010-ticket-purchase-and-cart, story-011-byog-payment-provider-configuration |

## Summary

As an attendee, I want to pay using the organization's configured gateway, so that I can complete my purchase with my preferred payment method

## Description

### Context

This story handles the runtime payment processing using the organization's configured payment providers (story-011). It builds on the cart and checkout flow (story-010) by connecting the payment step to the actual gateway. Different payment methods have different UX flows (inline, redirect, async) that must be handled seamlessly.

### User Value

Attendees expect a smooth payment experience regardless of which gateway the organizer uses. Whether paying by credit card, Pix, or bank transfer, the attendee should see a clear, familiar flow. Async payment methods need status updates, and edge cases like late payments after sell-out must be handled fairly with automatic refunds.

### Approach

The checkout dynamically presents payment methods based on the organization's configured providers. Inline payments (Stripe, Pix) stay within the platform. Redirect-based methods send the attendee to the provider and handle the return. Async methods track payment status and update orders when confirmation arrives. Late payments for sold-out events trigger automatic refunds.

## Acceptance Criteria

### 1. Payment Flow

1. **Payment Methods**: Checkout shows payment methods available from the organization's configured provider(s).
2. **Inline Payment**: For providers supporting inline payment (Stripe, Pix), the payment flow stays within the platform. Pix shows a QR code; credit card shows a form.
3. **Redirect Payment**: For redirect-based providers (PayPal, Mercado Pago), the attendee is redirected and returns after completion.

### 2. Async and Edge Cases

4. **Async Confirmation**: For async payment methods (Pix, boleto, bank transfer), the system handles delayed confirmations and updates order status accordingly.
5. **Late Payment Handling**: If a reservation expires and quota is exhausted when a late payment arrives, the system automatically initiates a refund and notifies the attendee.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: BYOG — Payment Processing

  Scenario: AC1 — Display available payment methods from configured providers
    Given the organization has Stripe and Pix configured
    When I proceed to the payment step during checkout
    Then I see credit card and Pix as available payment options
    And I do not see payment methods from unconfigured providers

  Scenario: AC2 — Complete inline payment with credit card
    Given I am at the payment step and select credit card
    When the payment form appears within the checkout page
    And I enter valid card details and submit
    Then the payment is processed without leaving the platform
    And I see my order confirmation

  Scenario: AC2b — Complete inline payment with Pix
    Given I am at the payment step and select Pix
    When a QR code is displayed within the checkout page
    And I scan the QR code and complete payment in my banking app
    Then the platform detects the payment confirmation
    And my order status updates to confirmed

  Scenario: AC3 — Complete redirect-based payment
    Given the organization has a redirect-based provider configured
    When I select that payment method and proceed
    Then I am redirected to the payment provider's page
    And after completing payment, I am returned to the platform
    And I see my order confirmation

  Scenario: AC4 — Async payment confirmation updates order status
    Given I completed checkout using bank transfer
    And my order status shows as "awaiting payment"
    When the bank transfer payment is confirmed hours later
    Then my order status automatically updates to "paid"
    And I receive a confirmation email with my tickets

  Scenario: AC5 — Automatic refund on late payment for sold-out event
    Given I selected the last ticket and chose bank transfer
    And my reservation expired while awaiting payment
    And the ticket was purchased by another attendee
    When my late payment is received
    Then the system automatically initiates a refund
    And I receive a notification explaining the situation
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Payment failure and retry
    Given I am at the payment step using credit card
    When my payment is declined
    Then I see an error message indicating the payment failed
    And I can retry with the same or a different payment method
    And my cart reservation is not lost

  Scenario: Payment timeout
    Given I am at the payment step and have submitted payment
    When the payment provider does not respond within the expected time
    Then I see a message that payment is taking longer than expected
    And I am given the option to check status later or retry

  Scenario: Switch payment method mid-flow
    Given I started with credit card payment but it was declined
    When I switch to Pix as my payment method
    Then the checkout updates to show the Pix QR code
    And my reservation duration adjusts accordingly

  Scenario: Double payment submission
    Given I have submitted a credit card payment
    When I click the pay button again before receiving a response
    Then only one payment charge is processed
    And I am not charged twice

  Scenario: Webhook with invalid organization token
    Given the system receives a payment confirmation webhook
    When the webhook signature or organization token is invalid
    Then the webhook is rejected
    And no order status is updated

  Scenario: Refund on late payment for sold-out event
    Given an attendee's reservation expired for a sold-out event
    And the attendee's async payment arrives after the event sold out
    When the system processes the late payment
    Then a full refund is initiated through the original payment method
    And the attendee receives an email explaining the refund and reason
```

## Assumptions

- Payment provider SDKs or APIs handle PCI compliance for credit card data; the platform never stores raw card numbers.
- Webhook endpoints are secured and validate signatures before processing.
- Refund processing times depend on the payment provider and are communicated to the attendee.
