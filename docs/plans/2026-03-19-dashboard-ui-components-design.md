# Dashboard UI Components Design

**Date:** 2026-03-19
**Reference:** https://dribbble.com/shots/26670205-Manage-Event-Dashboard-UI
**Branch:** feat/ui-dashboard-components

## Summary

Build isolated Phoenix function components for an event management dashboard layout inspired by the Dribbble design. Layout shell + core primitives approach — theme the existing daisyUI components via CSS variables, add new layout and navigation components.

## Components

| Component | Type | Purpose |
|-----------|------|---------|
| `dashboard_layout/1` | Function | Shell: sidebar + content area, drawer on mobile |
| `sidebar/1` | Function | Logo, org-scoped nav items, active state |
| `sidebar_item/1` | Function | Icon + label + optional badge, pink accent bar |
| `breadcrumb/1` | Function | Path trail from `{label, path}` tuples |
| `step_tabs/1` | Function | Horizontal icon+label steps with underline |
| `page_header/1` | Function | Title + subtitle + action buttons slot |
| `item_card/1` | Function | Slot-based row card (leading/content/trailing) |
| `date_badge/1` | Function | Pink circular month+day display |
| `progress_bar/1` | Function | "Step N of M" with fill bar |

## Theme

Override daisyUI theme in `daisyui-theme.js` with "pretex" theme:
- Primary: Rose `#E11D48`
- Base-100: White `#FFFFFF`
- Base-200: Light gray `#F8F9FB`
- Base-content: Dark navy `#1E293B`
- Custom utilities: `sidebar-item-active`, `date-badge`

## Layout

- daisyUI `drawer` with `lg:drawer-open` for responsive sidebar
- Sidebar always visible on desktop, overlay on mobile via hamburger toggle
- Content area: `bg-base-200`, max-w-6xl, p-6/p-8
- Sidebar: org-scoped nav, active detection via `String.starts_with?/2`

## Constraints

- All function components — no internal state, no LiveComponents
- Variant props for styling — no class merging
- No queries in components — data passed from LiveView handle_params
- Active nav detection: pure string comparison, no JS
