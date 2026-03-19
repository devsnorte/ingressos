---
id: story-026
title: Invoicing
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-010-ticket-purchase-and-cart
  - story-025-tax-rules
---

# Story 026: Invoicing

| Field          | Value                                                          |
|----------------|----------------------------------------------------------------|
| **ID**         | story-026                                                      |
| **Title**      | Invoicing                                                      |
| **Parent Epic**| TBD                                                            |
| **Fix Version**| TBD                                                            |
| **Status**     | Draft                                                          |
| **Priority**   | High                                                           |
| **Labels**     | agentic-workflow                                               |
| **Blocked by** | story-010-ticket-purchase-and-cart, story-025-tax-rules        |

## Summary

As an organizer, I want invoices generated automatically for orders, so that I have proper financial records

## Description

### Context

Proper invoicing is essential for financial compliance and record-keeping. Organizers need invoices that include all required information — organization details, attendee details, line items, and tax breakdowns. In many jurisdictions, invoices must have sequential numbering and cannot be modified after issuance, with corrections handled through credit notes.

### User Value

Organizers receive automatic invoice generation upon payment, eliminating manual bookkeeping. Sequential numbering ensures audit-ready records. Credit notes for cancellations and refunds maintain a complete financial trail. The immutability of invoices ensures compliance with accounting standards.

### Approach

Automatically generate invoices when orders are paid, with sequential numbering scoped to the organization. Provide manual trigger options for edge cases. Generate credit notes automatically for refunds and cancellations. Enforce immutability — once generated, invoices cannot be edited; corrections produce new documents.

## Acceptance Criteria

### 1. Invoice Generation

1. **Auto-Generate**: Invoices are generated automatically when an order is paid, with sequential numbering, organization details, attendee details, line items, and tax breakdowns.
2. **Manual Generation**: Organizers can manually trigger invoice generation for orders.
3. **Credit Notes**: Cancellation invoices (credit notes) are automatically generated when orders are refunded or cancelled.

### 2. Invoice Rules

4. **Immutable**: Invoices cannot be modified after generation — corrections produce new documents. Invoice numbers are sequential and gap-free within an organization.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Invoicing

  Scenario: AC1 — Invoice auto-generated on payment
    Given I am an organizer with a configured event
    And an attendee completes a ticket purchase and payment is confirmed
    When I view the order details
    Then an invoice has been automatically generated
    And it contains a sequential invoice number
    And it includes the organization name and details
    And it includes the attendee name and details
    And it lists all purchased items as line items
    And it shows the tax breakdown

  Scenario: AC2 — Organizer manually generates an invoice
    Given I am logged in as an organizer
    And I have a completed order that does not yet have an invoice
    When I open the order details
    And I click the option to generate an invoice
    Then an invoice is created for that order
    And it receives the next sequential invoice number

  Scenario: AC3 — Credit note generated on cancellation
    Given I am logged in as an organizer
    And I have a paid order with an existing invoice
    When I cancel and refund the order
    Then a credit note is automatically generated
    And it references the original invoice
    And it reflects the refunded amount

  Scenario: AC4 — Invoices are immutable with sequential numbering
    Given I am logged in as an organizer
    And an invoice has been generated for an order
    When I view the invoice
    Then there is no option to edit or modify it
    And the invoice number follows the previous invoice's number without gaps
    When I need to correct the invoice
    Then I must generate a new corrective document
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Invoice for a free order
    Given an attendee completes a free ticket order
    When I view the order details
    Then an invoice is generated with a total of $0.00
    And it still contains all required fields and a valid invoice number

  Scenario: Invoice number gap on concurrent order payments
    Given two orders are paid at nearly the same time
    When invoices are generated for both orders
    Then each invoice receives a unique sequential number
    And there are no gaps in the invoice number sequence

  Scenario: Invoice after partial refund
    Given I am logged in as an organizer
    And I have a paid order with multiple items and an existing invoice
    When I issue a partial refund for one item
    Then a credit note is generated for the refunded item only
    And the original invoice remains unchanged

  Scenario: Invoice with multiple tax rules
    Given an order contains items with different tax rules applied
    When the invoice is generated
    Then each tax rule appears as a separate line in the tax breakdown
    And the totals correctly reflect all applicable taxes

  Scenario: PDF download of an invoice
    Given I am logged in as an organizer
    And an invoice has been generated for an order
    When I click the download option for the invoice
    Then a PDF file is downloaded
    And it contains all the invoice details in a printable format
```

## Assumptions

- Invoices must meet Brazilian fiscal requirements — specific format TBD with legal review.
- Invoice numbering is scoped per organization and is gap-free within that scope.
- The tax rules from story 025 are in place before invoice generation can include tax breakdowns.
