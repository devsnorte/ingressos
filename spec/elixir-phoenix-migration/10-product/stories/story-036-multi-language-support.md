---
id: story-036
title: Multi-Language Support
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: medium
blocked_by: []
---

# Story 036: Multi-Language Support

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-036                                  |
| **Title**      | Multi-Language Support                     |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | Medium                                     |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | (none)                                     |

## Summary

As an organizer, I want the platform available in multiple languages, so that attendees and organizers can use it in their preferred language

## Description

### Context

The platform serves a diverse audience that may speak different languages. This story introduces multi-language support for both the platform interface and event-specific content. It has no dependencies on other stories and can be developed independently.

### User Value

Language barriers reduce usability and can cause attendees to abandon the purchase flow. Supporting multiple languages makes the platform accessible to a wider audience and allows organizers to reach international attendees effectively.

### Approach

The platform supports language selection by users, with auto-detection from browser settings as the default. It ships with Portuguese (BR) and English. Organizers can provide translations for their event content (names, descriptions, custom questions). Untranslated content falls back to the default language.

## Acceptance Criteria

### 1. Platform Localization

1. **Language Selection**: Users can select their preferred language. Platform auto-detects preference from browser settings.
2. **Initial Languages**: Platform ships with Portuguese (BR) and English.

### 2. Event Content Translation

3. **Translatable Content**: Organizers can provide translations for event content (names, descriptions, custom questions) in multiple languages. Untranslated content falls back to the default language.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Multi-Language Support

  Scenario: AC1 — Select preferred language
    Given I am a user visiting the platform
    When I select "English" from the language selector
    Then the platform interface displays in English
    And my preference is remembered for future visits
    And when a new visitor arrives with a browser set to Portuguese
    Then the platform auto-detects and displays in Portuguese (BR)

  Scenario: AC2 — Platform available in Portuguese and English
    Given I am viewing the platform in Portuguese (BR)
    Then all platform navigation, labels, buttons, and messages are displayed in Portuguese
    And when I switch to English
    Then all platform navigation, labels, buttons, and messages are displayed in English

  Scenario: AC3 — Organizer provides event content translations
    Given I am an organizer editing my event
    When I add a Portuguese translation for the event name and description
    And I add an English translation for the event name and description
    Then attendees viewing the event in Portuguese see the Portuguese content
    And attendees viewing the event in English see the English content
    And if a translation is missing the default language content is shown instead
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Switch language mid-session
    Given I am in the middle of a ticket purchase flow in English
    When I switch the platform language to Portuguese
    Then the checkout interface updates to Portuguese
    And my cart contents and progress are preserved
    And all labels, buttons, and messages reflect the new language

  Scenario: Event with partial translations
    Given an organizer has translated the event name to English but not the description
    When an attendee views the event in English
    Then the event name is displayed in English
    And the description falls back to the default language (Portuguese)
    And no error or broken layout is shown

  Scenario: Unsupported language fallback
    Given a visitor's browser is set to a language not supported by the platform (e.g., Japanese)
    When the visitor loads the platform
    Then the platform falls back to the default language
    And the visitor can manually select from the available languages

  Scenario: Email templates in user's language
    Given a user has selected English as their preferred language
    When the user completes a ticket purchase
    Then the confirmation email is sent in English
    And when a user with Portuguese preference completes a purchase
    Then the confirmation email is sent in Portuguese (BR)
```

## Assumptions

- Adding a new language requires adding translation files only -- no code changes.
- Community-contributed translations are accepted via pull requests.
- The default language for the platform is Portuguese (BR).
- Date, time, and currency formatting adapt to the selected language/locale.
