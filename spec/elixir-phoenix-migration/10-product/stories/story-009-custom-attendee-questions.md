---
id: story-009
title: Custom Attendee Questions
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-007-item-and-product-catalog
---

# Story 009: Custom Attendee Questions

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-009                                  |
| **Title**      | Custom Attendee Questions                  |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-007-item-and-product-catalog         |

## Summary

As an organizer, I want to add custom questions to my event, so that I can collect specific attendee information

## Description

### Context

Organizers often need to collect information beyond the standard name and email -- dietary preferences, T-shirt sizes, accessibility needs, company affiliation, and more. Custom questions allow organizers to tailor the checkout experience to their event's requirements.

### User Value

Organizers can gather all necessary attendee data at the point of purchase, reducing the need for follow-up surveys. Attendees complete everything in one flow, and organizers receive structured, actionable data.

### Approach

Provide a question builder where organizers create questions of various types, mark them as required or optional, and scope them to specific items. Built-in attendee fields are also configurable per event so organizers control which standard fields are shown.

## Acceptance Criteria

### 1. Question Configuration

1. **Question Types**: Organizer can create questions of types: text, multi-line text, number, yes/no, single choice, multiple choice, file upload, date, time, phone number, and country.
2. **Required/Optional**: Each question can be marked as required or optional.
3. **Item Scoping**: Questions can be scoped to specific items (only shown when that item is in the cart).

### 2. Built-in Fields

4. **Configurable Fields**: Built-in attendee fields (name, email, company, etc.) are configurable per event -- organizers choose which to show and require.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Custom Attendee Questions

  Scenario: AC1 — Create questions of various types
    Given I am logged in as an organizer
    And I have an event "Tech Conference 2026"
    When I navigate to the attendee questions settings
    And I create a text question "What is your job title?"
    And I create a single choice question "Dietary preference" with options "Regular", "Vegetarian", "Vegan"
    And I create a yes/no question "Do you need wheelchair accessibility?"
    And I create a file upload question "Upload your professional photo"
    And I create a date question "What is your date of birth?"
    And I create a phone number question "Contact phone number"
    And I create a country question "Country of residence"
    And I save the questions
    Then all questions appear in the event's question list with their correct types

  Scenario: AC2 — Mark questions as required or optional
    Given I am logged in as an organizer
    And I have a question "What is your job title?"
    When I mark the question as required
    And I save the configuration
    Then during checkout, the attendee must answer this question before proceeding
    When I change the question to optional
    Then during checkout, the attendee can skip this question

  Scenario: AC3 — Scope questions to specific items
    Given I am logged in as an organizer
    And I have items "General Admission" and "VIP Pass"
    And I have a question "T-shirt size" scoped to "VIP Pass" only
    When an attendee adds "General Admission" to their cart
    Then they do not see the "T-shirt size" question during checkout
    When an attendee adds "VIP Pass" to their cart
    Then they see the "T-shirt size" question during checkout

  Scenario: AC4 — Configure built-in attendee fields
    Given I am logged in as an organizer
    And I have an event "Tech Conference 2026"
    When I navigate to the attendee fields configuration
    And I enable the "Company" field and mark it as required
    And I hide the "Phone" field
    And I save the configuration
    Then during checkout, attendees see and must fill in the "Company" field
    And the "Phone" field is not displayed
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Conditional visibility based on other answers
    Given I am logged in as an organizer
    And I have a yes/no question "Do you have dietary restrictions?"
    And I have a text question "Please describe your restrictions" that is only shown when the answer is "Yes"
    When an attendee answers "No" to the dietary question
    Then they do not see the follow-up question
    When an attendee answers "Yes"
    Then the follow-up question appears

  Scenario: File upload size limit
    Given an attendee is answering a file upload question
    When they attempt to upload a file larger than the allowed limit
    Then they see an error message indicating the maximum file size
    And the upload is rejected

  Scenario: Required question left blank
    Given an attendee is checking out
    And there is a required question "Emergency contact name"
    When the attendee leaves the field blank and attempts to proceed
    Then they see a validation error on the required question
    And they cannot complete checkout until it is answered

  Scenario: Question with no answer choices
    Given I am logged in as an organizer
    When I try to create a single choice question without adding any options
    Then I see a validation error indicating at least one option is required
    And the question is not saved

  Scenario: Special characters in answers
    Given an attendee is answering a text question
    When they enter text with special characters like accents, emojis, and symbols
    And they submit the form
    Then the answer is saved correctly with all special characters preserved
```

## Assumptions

- The item and product catalog (story 007) is already in place.
- File upload questions are subject to platform-wide storage limits.
- Conditional question visibility (Tier 2) may be delivered in a later iteration.
