# RSBBQ Operations

Native iOS app (Swift, SwiftUI) for multi-store operations: JWT login, store dashboard, hourly out-of-stock heatmap, and daily sales with Catering vs. Non-Catering charts and category breakdown. This overview is for developers who will maintain or extend the project.

## What this app does

- **Login** — JWT-authenticated access to the RSBBQ Operations API (GCP). Token is stored in ``AuthManager`` and sent as `Authorization: Bearer` on all subsequent requests.
- **Store dashboard** — ``HomeView`` shows a grid of store tiles from ``APIService/storePerformance()``; tapping a store opens ``ContentView`` with two tabs.
- **Out of Stock** — ``OutOfStockEventsView`` shows an hourly stock-status heatmap (PST) for the selected store and date, using ``APIService/timeWindows(days:storeCode:date:)`` and ``APIService/outOfStockItems(storeCode:hours:startDate:endDate:)``.
- **Daily Sales** — ``DailySalesView`` provides a date range, swipeable bar charts (sales amount, order count, orders by category), and summary tables. Data comes from ``APIService/dailySales(storeCode:startDate:endDate:)`` and ``APIService/dailySalesCategories(storeCode:startDate:endDate:)``.

## Where to start

| Concern | Where to look |
|--------|----------------|
| App entry and auth gate | ``RSBBQOperationsApp``, ``AuthManager`` |
| API base URL and config | ``APIConfig``, `Config.xcconfig` / `Secrets.xcconfig` (see repo README) |
| All API calls and models | ``APIService``, ``Services/APIService.swift`` |
| Login UI | ``LoginView`` |
| Dashboard and store selection | ``HomeView``, ``ContentView``, ``StorePerformanceItem`` |
| Out-of-stock heatmap | ``OutOfStockEventsView``, ``OutOfStockItem`` |
| Daily sales charts and tables | ``DailySalesView``, ``DailySalesSummary``, ``DailySalesCategories`` |

The repo **README** has full setup (clone, xcconfig, API URL, run). Use **Product → Build Documentation** (⌃⌘D) in Xcode to preview this doc; the same content is published to GitHub Pages via the workflow in `.github/workflows/docc.yml`.

## Architecture in brief

- **Single app target**; no separate frameworks. SwiftUI views and ``APIService`` (singleton) with ``AuthManager`` as an `@EnvironmentObject` for login state.
- **API** — REST, JSON. Base URL from ``APIConfig`` (Info.plist `APIBaseURL`). Responses are parsed in ``APIService`` with robust handling for decimal/string values from the backend.
- **Navigation** — `NavigationStack` from ``HomeView``; ``ContentView`` is the destination for a selected ``StorePerformanceItem`` and hosts the Out of Stock and Daily Sales tabs.

## Topics

### For new developers

- ``RSBBQOperationsApp``
    — Entry point and auth-based root view.
- ``AuthManager`` 
    — Login, logout, and token used by ``APIService``.
- ``APIService`` 
    — Shared HTTP client and all endpoint methods.

### UI and flows

- ``HomeView`` 
    — Store tiles and navigation to ``ContentView``.
- ``ContentView`` 
    — Tab container for ``OutOfStockEventsView`` and ``DailySalesView``.
- ``LoginView`` 
    — Sign-in form and error display.
- ``OutOfStockEventsView`` 
    — Hourly heatmap for one store/date.
- ``DailySalesView`` 
    — Date range, charts, and summary tables.

### Data models

- ``StorePerformanceItem`` 
    — Store for dashboard and tab context.
- ``DailySalesSummary`` 
    — Per-store daily sales totals.
- ``DailySalesCategories``  
    — Orders by dining option.
- ``OutOfStockItem`` 
    — Single out-of-stock event record.

### API reference

Use the sidebar to browse all types and symbols in this module.
