---
id: story-025
title: Tax Rules
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-001-multi-organization-support
---

# Story 025: Tax Rules

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-025                                  |
| **Title**      | Tax Rules                                  |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-001-multi-organization-support       |

## Summary

As an organizer, I want to configure tax rules, so that prices and invoices reflect correct tax calculations

## Description

### Context

Event ticketing in many jurisdictions requires proper tax handling. Organizers must comply with local tax regulations, which may involve different tax rates, inclusive vs. additive pricing models, and multiple tax rules applying to a single item. Proper tax configuration ensures financial compliance and transparent pricing for attendees.

### User Value

Organizers can set up tax rules that match their local requirements, choosing between tax-inclusive and tax-additive pricing. Attendees see transparent price breakdowns during checkout, building trust and meeting legal requirements. The system handles the complexity of applying multiple tax rules, so organizers do not need to manually calculate taxes.

### Approach

Provide a tax rule configuration interface at the organization level where organizers define tax rules with names, rates, and applicability conditions. Each rule can be set as inclusive or additive. Multiple rules can be associated with items. During checkout, the system calculates and displays tax amounts as line items in the price breakdown.

## Acceptance Criteria

### 1. Tax Configuration

1. **Define Tax Rules**: Organizer can define tax rules with rates, names, and applicability conditions (country, item type).
2. **Inclusive vs Additive**: Tax can be configured as inclusive (price includes tax) or additive (tax added on top).
3. **Multiple Rules**: Multiple tax rules can apply to a single item.

### 2. Tax Display

4. **Checkout Visibility**: Tax calculations are shown to the attendee during checkout as line items in the price breakdown.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Tax Rules

  Scenario: AC1 — Define a tax rule with rate and applicability
    Given I am logged in as an organizer
    When I navigate to the tax rules settings
    And I create a new tax rule named "ISS" with a rate of 5%
    And I set the applicability to country "Brazil" and item type "Ticket"
    And I save the tax rule
    Then the tax rule "ISS" appears in my tax rules list
    And it shows a rate of 5% applicable to tickets in Brazil

  Scenario: AC2 — Configure inclusive vs additive tax
    Given I am logged in as an organizer
    And I have a tax rule "VAT" with a rate of 10%
    When I edit the tax rule
    And I set the pricing mode to "inclusive"
    And I save the changes
    Then the tax rule shows "inclusive" pricing mode
    When I set the pricing mode to "additive"
    And I save the changes
    Then the tax rule shows "additive" pricing mode

  Scenario: AC3 — Apply multiple tax rules to a single item
    Given I am logged in as an organizer
    And I have tax rules "Federal Tax" at 5% and "State Tax" at 3%
    When I assign both tax rules to the "General Admission" ticket
    And I save the configuration
    Then the "General Admission" ticket shows both tax rules applied
    And the combined tax effect is reflected in the price calculation

  Scenario: AC4 — Tax breakdown visible during checkout
    Given I am an attendee purchasing a ticket for an event
    And the ticket has a base price of $100
    And an additive tax rule "Service Tax" at 8% is applied
    When I view the checkout price breakdown
    Then I see the base price of $100
    And I see a line item "Service Tax" of $8.00
    And the total shows $108.00
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Conflicting tax rules on the same item
    Given I am logged in as an organizer
    And I have an inclusive tax rule and an additive tax rule
    When I assign both to the same item
    Then each tax rule is calculated according to its own mode
    And the final price reflects both calculations correctly

  Scenario: Tax rule with 0% rate
    Given I am logged in as an organizer
    When I create a tax rule "Exempt Tax" with a rate of 0%
    And I assign it to an item
    Then the rule is saved successfully
    And no tax amount is added to the item price
    And the 0% tax line appears in the checkout breakdown

  Scenario: Tax applied to a free item
    Given I am an attendee checking out with a free ticket
    And the ticket has a tax rule "Sales Tax" at 10% applied
    When I view the checkout price breakdown
    Then the tax amount shows $0.00
    And the total remains $0.00

  Scenario: Change tax rule with existing orders
    Given I am logged in as an organizer
    And orders have already been placed with the current tax rate of 10%
    When I change the tax rate to 12%
    Then existing orders retain the original 10% tax calculation
    And new orders use the updated 12% rate

  Scenario: Tax calculation with currency rounding
    Given I am an attendee purchasing a ticket priced at $9.99
    And an additive tax rule of 7.5% is applied
    When I view the checkout price breakdown
    Then the tax amount is rounded to the nearest cent
    And the total reflects the correctly rounded amount
```
