---
id: story-018
title: Memberships
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-001-multi-organization-support
  - story-003-customer-accounts
---

# Story 018: Memberships

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-018                                  |
| **Title**      | Memberships                                |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-001-multi-organization-support, story-003-customer-accounts |

## Summary

As an organizer, I want to create membership programs, so that I can offer recurring benefits to loyal attendees

## Description

### Context

Membership programs allow organizers to build lasting relationships with their community. Members can receive automatic discounts, access to restricted ticket types, and priority purchasing. Memberships tie into the broader pricing and access control system, sitting at the top of the pricing evaluation chain.

### User Value

Organizers can reward loyal attendees with ongoing benefits, driving repeat attendance and community engagement. Attendees enjoy a streamlined experience where their membership perks are applied automatically at checkout, along with visibility into their active memberships and benefits.

### Approach

Provide a membership type configuration interface for organizers, with options to sell memberships as purchasable items or grant them manually. During checkout, membership benefits are evaluated first in the pricing chain (before automatic discounts, vouchers, and gift cards). Members can view and manage their memberships from their customer account.

## Acceptance Criteria

### 1. Membership Configuration

1. **Create Membership Types**: Organizer defines membership types with validity periods and benefits (automatic discounts, access to restricted items, priority access).
2. **Grant or Sell**: Memberships can be sold as items during checkout or granted manually by organizers.

### 2. Membership Benefits

3. **Checkout Validation**: During checkout, membership benefits are automatically validated and applied (first in pricing evaluation order: membership, then auto-discounts, then voucher, then gift card).
4. **Member Account View**: Attendees can view active memberships, validity dates, and benefits in their customer account.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Memberships

  Scenario: AC1 — Create a membership type with benefits
    Given I am logged in as an organizer
    When I navigate to the membership management page
    And I create a new membership type "Gold Member"
    And I set the validity period to 12 months
    And I add a benefit of "15% automatic discount on all tickets"
    And I add a benefit of "access to VIP ticket types"
    And I save the membership type
    Then "Gold Member" appears in my membership types list
    And it shows a 12-month validity and the configured benefits

  Scenario: AC2 — Sell membership during checkout
    Given I am an attendee checking out for an event
    And the organizer offers a "Gold Member" membership for purchase at $99
    When I add the "Gold Member" membership to my cart
    And I complete the purchase
    Then I receive a confirmation that my "Gold Member" membership is active
    And the membership is valid for 12 months from the purchase date

  Scenario: AC2b — Grant membership manually
    Given I am logged in as an organizer
    And an attendee "jane@example.com" has a customer account
    When I navigate to the membership management page
    And I grant a "Gold Member" membership to "jane@example.com"
    Then the attendee's account shows an active "Gold Member" membership
    And the membership validity period starts from the grant date

  Scenario: AC3 — Membership benefits applied at checkout
    Given I am an attendee with an active "Gold Member" membership
    And "Gold Member" provides a 15% discount on all tickets
    When I add a "Conference Pass" priced at $200 to my cart
    Then I see a 15% membership discount applied automatically
    And the discount appears before any other promotions in the pricing breakdown
    And my total reflects the membership pricing

  Scenario: AC4 — View memberships in customer account
    Given I am logged in as an attendee with a customer account
    And I have an active "Gold Member" membership
    When I navigate to my account memberships page
    Then I see "Gold Member" listed as active
    And I see the validity start and end dates
    And I see the list of benefits associated with the membership
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Expired membership at checkout
    Given I am an attendee with an expired "Gold Member" membership
    When I add a "Conference Pass" to my cart and proceed to checkout
    Then no membership discount is applied
    And I see a notice that my "Gold Member" membership has expired

  Scenario: Membership from another organization
    Given I am an attendee with a "Gold Member" membership from "TechOrg"
    And I am checking out for an event by "OtherOrg"
    When I proceed to checkout
    Then no membership benefits from "TechOrg" are applied
    And only benefits from "OtherOrg" memberships are considered

  Scenario: Overlapping membership types
    Given I am an attendee with both "Gold Member" and "Silver Member" memberships active
    And "Gold Member" provides 15% off and "Silver Member" provides 10% off
    When I add a ticket to my cart
    Then the best membership benefit (15% off) is applied
    And the lesser benefit does not stack

  Scenario: Membership purchased as guest without account
    Given I am checking out as a guest without a customer account
    And the organizer offers a "Gold Member" membership for purchase
    When I try to add the membership to my cart
    Then I see a message that a customer account is required to purchase a membership
    And I am prompted to create an account or log in

  Scenario: Membership benefit on a sold-out item
    Given I am an attendee with a "Gold Member" membership
    And "Gold Member" grants access to restricted "VIP Pass" tickets
    And "VIP Pass" is sold out
    When I try to add "VIP Pass" to my cart
    Then I see a message that "VIP Pass" is sold out
    And the membership access benefit does not override availability
```

## Assumptions

- Multi-organization support (story 001) and customer accounts (story 003) are in place.
- Membership benefits are evaluated first in the pricing chain, before automatic discounts, vouchers, and gift cards.
- A customer account is required to hold a membership, since membership state must be tied to a persistent identity.
