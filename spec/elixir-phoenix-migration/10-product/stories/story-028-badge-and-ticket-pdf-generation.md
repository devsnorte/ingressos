---
id: story-028
title: Badge and Ticket PDF Generation
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-010-ticket-purchase-and-cart
---

# Story 028: Badge and Ticket PDF Generation

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-028                                  |
| **Title**      | Badge and Ticket PDF Generation            |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-010-ticket-purchase-and-cart         |

## Summary

As an organizer, I want to generate PDF tickets and badges, so that attendees have printable entry passes

## Description

### Context

Attendees need a tangible artifact — whether digital or printed — to present at event entry. PDF tickets with QR codes serve as the primary entry verification method. For larger or multi-day events, printed name badges streamline check-in and improve the attendee experience. Organizers need tools to generate both at scale.

### User Value

Attendees receive professional PDF tickets with unique QR codes immediately upon order confirmation, ready for digital display or printing. Organizers can configure badge layouts to match their event branding and generate badges in bulk for efficient printing. The QR code on each ticket ensures fast, reliable check-in at the venue.

### Approach

Automatically generate PDF tickets with unique QR codes when orders are confirmed. Provide attendees with download access from their order page and via email. Offer organizers predefined badge templates with configurable fields (logo, text, attendee data) and a bulk generation tool for printing batches.

## Acceptance Criteria

### 1. Ticket PDFs

1. **Auto-Generate Tickets**: System generates PDF tickets with unique QR codes, attendee information, and event branding on order confirmation.
2. **Download**: Attendees can download their ticket PDFs from their order page or email.

### 2. Badges

3. **Badge Templates**: Organizers configure badge layouts by selecting predefined templates and customizing fields (logo, text, attendee data).
4. **Bulk Generation**: Organizers can generate badges in bulk for printing.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Badge and Ticket PDF Generation

  Scenario: AC1 — PDF ticket auto-generated on order confirmation
    Given an attendee completes a ticket purchase
    When the order is confirmed
    Then a PDF ticket is generated for each ticket in the order
    And each PDF contains a unique QR code
    And each PDF displays the attendee name and event details
    And each PDF includes the event branding

  Scenario: AC2 — Attendee downloads ticket PDF
    Given I am an attendee with a confirmed order
    When I visit my order page
    Then I see a download link for my ticket PDF
    When I click the download link
    Then the PDF file is downloaded to my device
    And the ticket PDF is also available via the order confirmation email

  Scenario: AC3 — Organizer configures a badge template
    Given I am logged in as an organizer
    When I navigate to the badge configuration settings
    And I select a predefined badge template
    And I upload my event logo
    And I customize the displayed fields to include attendee name, ticket type, and company
    And I save the badge configuration
    Then the badge template shows a preview with the selected layout and fields

  Scenario: AC4 — Organizer generates badges in bulk
    Given I am logged in as an organizer
    And I have a configured badge template
    And my event has confirmed attendees
    When I navigate to the bulk badge generation page
    And I select all attendees
    And I click generate badges
    Then the system generates a badge PDF for each selected attendee
    And I can download the combined badge file for printing
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: PDF ticket with special characters and accents
    Given an attendee named "Jose da Silva" has a confirmed order
    When the PDF ticket is generated
    Then the attendee name with accents renders correctly on the PDF
    And no encoding errors appear in the document

  Scenario: Bulk badge generation for a large event
    Given I am logged in as an organizer
    And my event has over 1000 confirmed attendees
    When I generate badges in bulk for all attendees
    Then the system processes the generation without timing out
    And I receive a notification when the badges are ready for download

  Scenario: Ticket PDF with missing attendee information
    Given an attendee has a confirmed order but has not provided all optional profile fields
    When the PDF ticket is generated
    Then the ticket is generated successfully with available information
    And missing optional fields are omitted gracefully without blank placeholders

  Scenario: QR code uniqueness validation
    Given multiple tickets are generated across different orders
    When I examine the QR codes on the generated PDFs
    Then each QR code is unique
    And no two tickets share the same QR code value
```

## Assumptions

- v1 uses predefined badge templates with configurable fields. Visual drag-and-drop editor is a follow-up feature.
- QR codes encode a unique ticket identifier that can be scanned by the check-in system.
- Bulk badge generation may be asynchronous for large attendee counts, with a notification when complete.
