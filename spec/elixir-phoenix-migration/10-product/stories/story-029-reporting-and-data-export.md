---
id: story-029
title: Reporting and Data Export
feature: elixir-phoenix-migration
type: story
parent-prd: 10-product/prd.md
status: draft
priority: high
blocked_by:
  - story-010-ticket-purchase-and-cart
---

# Story 029: Reporting and Data Export

| Field          | Value                                      |
|----------------|--------------------------------------------|
| **ID**         | story-029                                  |
| **Title**      | Reporting and Data Export                   |
| **Parent Epic**| TBD                                        |
| **Fix Version**| TBD                                        |
| **Status**     | Draft                                      |
| **Priority**   | High                                       |
| **Labels**     | agentic-workflow                           |
| **Blocked by** | story-010-ticket-purchase-and-cart         |

## Summary

As an organizer, I want to view reports and export data, so that I can analyze event performance

## Description

### Context

Organizers need visibility into how their events are performing — from ticket sales and revenue to check-in rates. They also need the ability to export raw data for external analysis, accounting, or compliance purposes. A reporting and export system gives organizers the tools to make data-driven decisions and maintain proper records.

### User Value

Organizers gain at-a-glance insights through sales summaries, attendance reports, and financial overviews — all accessible from the event dashboard. When deeper analysis is needed, data can be exported in standard formats (CSV, Excel) for use in spreadsheets or accounting tools. Scheduled exports automate routine data pulls, saving time for recurring reporting needs.

### Approach

Provide built-in report views for sales, attendance, and financials within the organizer dashboard. Offer on-demand data exports in CSV and Excel formats for orders, attendee lists, and check-in logs. Support scheduled recurring exports delivered via email or stored for download, with retention and size limits.

## Acceptance Criteria

### 1. Reports

1. **Sales Summary**: Organizer views total revenue, tickets sold by type, and sales over time.
2. **Attendance Report**: Organizer views checked-in vs. total sold, with breakdown by check-in list.
3. **Financial Overview**: Revenue, fees, refunds, and net totals.

### 2. Exports

4. **Export Formats**: Order data, attendee lists, and check-in logs can be exported in CSV and Excel formats.
5. **Scheduled Exports**: Organizers can configure recurring exports delivered via email or stored for download. Stored files are retained for 30 days, max 100MB per file, larger exports split.

## Test Plan

### Tier 1 — Acceptance Tests (one per AC)

```gherkin
Feature: Reporting and Data Export

  Scenario: AC1 — View sales summary report
    Given I am logged in as an organizer
    And my event has completed ticket sales
    When I navigate to the reports section
    And I select "Sales Summary"
    Then I see the total revenue for the event
    And I see a breakdown of tickets sold by type
    And I see a chart or table showing sales over time

  Scenario: AC2 — View attendance report
    Given I am logged in as an organizer
    And my event has check-in lists with recorded check-ins
    When I navigate to the reports section
    And I select "Attendance Report"
    Then I see the number of checked-in attendees versus total tickets sold
    And I see a breakdown by each check-in list

  Scenario: AC3 — View financial overview
    Given I am logged in as an organizer
    And my event has completed orders including some refunds
    When I navigate to the reports section
    And I select "Financial Overview"
    Then I see the total revenue
    And I see the total fees
    And I see the total refunds
    And I see the net total

  Scenario: AC4 — Export data in CSV and Excel formats
    Given I am logged in as an organizer
    And my event has orders and attendee data
    When I navigate to the export section
    And I select "Order Data" for export
    And I choose CSV format
    And I click export
    Then a CSV file is downloaded containing order data
    When I choose Excel format and export again
    Then an Excel file is downloaded containing the same order data

  Scenario: AC5 — Configure a scheduled recurring export
    Given I am logged in as an organizer
    When I navigate to the export section
    And I configure a recurring export of attendee lists
    And I set the schedule to weekly
    And I choose delivery via email
    And I save the schedule
    Then the scheduled export appears in my export settings
    And I receive the export file via email on the configured schedule
```

### Tier 2 — Edge Case & Negative Tests

```gherkin
  Scenario: Report for an event with no orders
    Given I am logged in as an organizer
    And my event has no orders yet
    When I view the sales summary report
    Then I see zeroes for revenue and tickets sold
    And the report displays a message indicating no sales data is available

  Scenario: Export with date range filter
    Given I am logged in as an organizer
    And my event has orders spanning several weeks
    When I export order data with a date range filter
    Then the exported file contains only orders within the specified date range

  Scenario: Scheduled export failure notification
    Given I have a scheduled recurring export configured
    And the export fails due to a system error
    When the scheduled export time passes
    Then I receive a notification that the export failed
    And I can retry the export manually

  Scenario: Export exceeding file size limit
    Given I am logged in as an organizer
    And my event has a large volume of data exceeding 100MB
    When I export the data
    Then the export is split into multiple files under 100MB each
    And all files are available for download

  Scenario: Report scoped to user permissions
    Given I am logged in as a team member with limited permissions
    When I attempt to view the financial overview report
    Then I only see data for events and organizations I have access to
    And restricted data is not visible
```
