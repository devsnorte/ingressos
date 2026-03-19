---
id: story-016
title: Discounts
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-007-item-and-product-catalog
---

# Story 016: Discounts

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-016                                  |
| **Title**      | Discounts                                  |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-007-item-and-product-catalog         |

## Summary

As an organizer, I want to create automatic discount rules, so that attendees get the best price without needing a code

## Description

### Context

Not all promotions require a code. Organizers often want pricing rules that apply automatically based on what an attendee is buying — for example, "buy 3 or more tickets and get 10% off" or "add a workshop to your conference pass and save $25." Automatic discounts create a seamless buying experience.

### User Value

Attendees benefit from the best available price without needing to hunt for promo codes. Organizers can incentivize specific purchasing behaviors (larger orders, item bundles) through rules that apply transparently at checkout.

### Approach

Provide a discount rules interface where organizers define conditions (item combinations, quantity thresholds) and effects (fixed or percentage off). During checkout, all matching rules are evaluated and the most favorable discount for the attendee is applied automatically.

## Acceptance Criteria

### 1. Discount Rules

1. **Create Discount**: Organizer can create automatic discount rules based on conditions (item combinations, quantity thresholds) with fixed amount or percentage off.
2. **Item Scoping**: Discounts apply to specific items or combinations.

### 2. Discount Application

3. **Automatic Application**: Discounts apply automatically when conditions are met — no code required.
4. **Best Discount**: When multiple rules match, the system applies the best discount for the attendee.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Discounts

  Scenario: AC1 — Create an automatic discount rule
    Given I am logged in as an organizer
    And I have an event with ticket types "General Admission" and "Workshop Add-on"
    When I navigate to the discount rules page
    And I create a new discount rule named "Bulk Discount"
    And I set the condition to "quantity of 3 or more"
    And I set the effect to "10% off"
    And I save the rule
    Then the discount rule "Bulk Discount" appears in my discount rules list
    And it shows "10% off when 3 or more purchased"

  Scenario: AC2 — Scope discount to specific items
    Given I am logged in as an organizer
    And I have an event with ticket types "Conference Pass" and "Workshop Add-on"
    When I create a discount rule named "Bundle Deal"
    And I set the condition to "Conference Pass and Workshop Add-on purchased together"
    And I set the effect to "$25 off"
    And I scope the discount to "Conference Pass" and "Workshop Add-on"
    And I save the rule
    Then the discount rule shows it applies only to the selected item combination

  Scenario: AC3 — Discount applies automatically at checkout
    Given I am an attendee checking out for an event
    And a discount rule "Bulk Discount" grants 10% off for 3 or more tickets
    When I add 3 "General Admission" tickets to my cart
    Then I see a 10% discount applied automatically to my order total
    And no voucher code entry is required

  Scenario: AC4 — Best discount is applied when multiple rules match
    Given I am an attendee checking out for an event
    And a discount rule "Bulk 3" grants 10% off for 3 or more tickets
    And a discount rule "Bulk 5" grants 20% off for 5 or more tickets
    When I add 5 "General Admission" tickets to my cart
    Then I see the 20% discount applied
    And the 10% discount is not applied
    And the order summary shows I am getting the best available price
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Discount that would reduce price below zero
    Given I am an attendee checking out for an event
    And a discount rule grants a fixed $50 off
    And the ticket price is $30
    When the discount is applied
    Then the ticket price is reduced to $0
    And the price does not go below zero

  Scenario: Overlapping discount rules with same value
    Given I am an attendee checking out for an event
    And two discount rules both grant 15% off with different conditions
    And both conditions are met by my cart
    When the discounts are evaluated
    Then only one 15% discount is applied
    And I see which discount rule was applied in the order summary

  Scenario: Discount on a free item
    Given I am an attendee checking out for an event
    And a "Free Community Pass" has a price of $0
    And a discount rule grants 10% off
    When I add the "Free Community Pass" to my cart
    Then no discount line appears for the free item
    And the total remains $0

  Scenario: Discount and voucher stacking when stacking is disabled
    Given I am an attendee checking out for an event
    And a discount rule grants 10% off for 3 or more tickets
    And I have a voucher code "EXTRA5" for 5% off
    And the organizer has disabled discount-voucher stacking
    When I add 3 tickets and apply voucher "EXTRA5"
    Then only the better of the two discounts is applied
    And a message explains that stacking is not available

  Scenario: Conditions not met for discount
    Given I am an attendee checking out for an event
    And a discount rule "Bulk Discount" requires 3 or more tickets
    When I add only 2 "General Admission" tickets to my cart
    Then no automatic discount is applied
    And the order total reflects the full price for 2 tickets
```

## Assumptions

- The item and product catalog (story 007) is in place so that discount rules can reference specific items and variations.
- Discount evaluation occurs during cart calculation and updates in real time as items are added or removed.
- The pricing evaluation order is: membership benefits, then automatic discounts, then voucher, then gift card.
