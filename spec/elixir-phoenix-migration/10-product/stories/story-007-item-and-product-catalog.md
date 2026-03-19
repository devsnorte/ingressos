---
id: story-007
title: Item and Product Catalog
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-005-event-creation-and-management
---

# Story 007: Item and Product Catalog

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-007                                  |
| **Title**      | Item and Product Catalog                   |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-005-event-creation-and-management    |

## Summary

As an organizer, I want to configure items, variations, categories, and bundles, so that I can offer diverse ticket types and merchandise

## Description

### Context

Events typically offer more than a single ticket type. Organizers need to create a rich catalog of items including ticket tiers, merchandise, and add-ons, organized into categories for easy browsing by attendees.

### User Value

Organizers can offer attendees a variety of purchasing options -- from basic admission to VIP bundles with merchandise. Variations allow a single item to come in different sizes or options, and categories keep the storefront organized.

### Approach

Provide a catalog management interface where organizers can create items with variations, group them into categories, build bundles, designate add-ons, and set visibility rules including voucher requirements and quantity limits.

## Acceptance Criteria

### 1. Item Management

1. **Create Items**: Organizer can create items (tickets, merchandise, add-ons) with name, description, price, and available quantity.
2. **Item Variations**: Items can have variations (e.g., "T-shirt" with S/M/L/XL), each with its own price and stock.
3. **Categories**: Items can be organized into named categories for display grouping.

### 2. Advanced Configuration

4. **Bundles**: Multiple items can be bundled together at a combined price.
5. **Add-ons**: Items can be designated as add-ons attached to primary ticket types, offered during checkout.
6. **Visibility Rules**: Items can require a voucher to be visible or purchasable. Items can have min/max quantities per order.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Item and Product Catalog

  Scenario: AC1 — Create an item with basic details
    Given I am logged in as an organizer
    And I have an event "Tech Conference 2026"
    When I navigate to the item catalog for "Tech Conference 2026"
    And I create a new item with name "General Admission"
    And I set the description to "Full access to all sessions"
    And I set the price to "R$ 150,00"
    And I set the available quantity to 500
    And I save the item
    Then "General Admission" appears in the event's item catalog
    And it shows the correct price and quantity

  Scenario: AC2 — Create item variations
    Given I am logged in as an organizer
    And I have an event with an item "Conference T-shirt"
    When I add variations: "S" at "R$ 40,00" with stock 50, "M" at "R$ 40,00" with stock 100, "L" at "R$ 45,00" with stock 80, "XL" at "R$ 45,00" with stock 40
    And I save the item
    Then "Conference T-shirt" shows 4 variations with their respective prices and stock levels

  Scenario: AC3 — Organize items into categories
    Given I am logged in as an organizer
    And I have an event with items "General Admission", "VIP Pass", and "Conference T-shirt"
    When I create a category called "Tickets"
    And I assign "General Admission" and "VIP Pass" to "Tickets"
    And I create a category called "Merchandise"
    And I assign "Conference T-shirt" to "Merchandise"
    Then the catalog displays items grouped under "Tickets" and "Merchandise"

  Scenario: AC4 — Create a bundle of items
    Given I am logged in as an organizer
    And I have items "VIP Pass" at "R$ 300,00" and "Conference T-shirt" at "R$ 40,00"
    When I create a bundle called "VIP Package"
    And I include "VIP Pass" and "Conference T-shirt"
    And I set the bundle price to "R$ 310,00"
    And I save the bundle
    Then "VIP Package" appears in the catalog at "R$ 310,00"
    And it shows the included items

  Scenario: AC5 — Designate an item as an add-on
    Given I am logged in as an organizer
    And I have a ticket item "General Admission"
    And I have an item "Parking Pass"
    When I designate "Parking Pass" as an add-on for "General Admission"
    And I save the configuration
    Then when an attendee adds "General Admission" to their cart
    They are offered "Parking Pass" as an optional add-on during checkout

  Scenario: AC6 — Configure visibility rules on an item
    Given I am logged in as an organizer
    And I have an item "Early Bird Ticket"
    When I set "Early Bird Ticket" to require a voucher to be visible
    And I set a minimum quantity of 1 and maximum quantity of 5 per order
    And I save the configuration
    Then "Early Bird Ticket" is hidden from the public catalog
    And when an attendee enters a valid voucher, they can see and purchase it
    And they can only add between 1 and 5 of this item to their cart
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Cannot create item with negative price
    Given I am logged in as an organizer
    When I try to create an item with a price of "-R$ 10,00"
    Then I see a validation error indicating the price must be zero or positive
    And the item is not created

  Scenario: Variation with zero stock
    Given I am logged in as an organizer
    And I have an item with a variation "XXL" with stock set to 0
    When an attendee views the item
    Then the "XXL" variation shows as unavailable

  Scenario: Bundle containing a deleted item
    Given I am logged in as an organizer
    And I have a bundle "VIP Package" that includes "Conference T-shirt"
    When I delete "Conference T-shirt" from the catalog
    Then I see a warning that "VIP Package" references this item
    And I must confirm or update the bundle before the deletion proceeds

  Scenario: Add-on without a parent item
    Given I am logged in as an organizer
    And I have an item "Parking Pass" designated as an add-on
    When the parent ticket item it was attached to is removed
    Then "Parking Pass" is flagged as unattached
    And I see a notification to reassign or convert it to a standalone item

  Scenario: Empty catalog
    Given I am logged in as an organizer
    And my event has no items configured
    When I navigate to the item catalog
    Then I see an empty state message guiding me to create my first item
```

## Assumptions

- Event creation (story 005) is already in place.
- Prices are displayed in the organizer's configured currency.
