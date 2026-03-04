# RSBBQ Operations iOS

Native iPhone app (Swift, SwiftUI) for multi-store operations: login, store dashboard, hourly out-of-stock heatmap, and daily sales with Catering vs. Non-Catering charts and category breakdown.

## Features

- **Login** — JWT-authenticated access to the Operations API.
- **Store dashboard** — Grid of store tiles; tap a store to open its detail.
- **Out of Stock** — Hourly stock status heatmap by date (PST), fixed store from the selected tile.
- **Daily Sales** — Date range, swipeable charts (Sales Amount, Order Count, Orders by Category), summary table, and categories summary table (orders per dining option).

## Requirements

- Xcode 15+ (Swift 5, SwiftUI)
- iOS 16+
- Access to the RSBBQ Operations API (base URL set at build time)

## Getting started

1. **Clone and open**
   - Clone the repo and open `RSBBQOperations.xcodeproj` in Xcode (e.g. `Ops_files/RSBBQOperations.xcodeproj` from the repo root).

2. **API base URL**
   - The app reads the base URL from the **Info.plist** key `APIBaseURL`, which is set at build time from your xcconfig.
   - **Option A (recommended for local dev):** Create **Secrets.xcconfig** (add it to `.gitignore`). Set:
     ```text
     API_BASE_URL = https://your-api.run.app
     INFOPLIST_KEY_APIBaseURL = $(API_BASE_URL)
     ```
     In Xcode: **Project → Info → Configurations** → for **Debug** and **Release**, set “Based on” to **Secrets.xcconfig**.
   - **Option B:** The project uses **Config.xcconfig** by default. Edit `API_BASE_URL` there (and do not commit the real URL if the repo is public).
   - If `APIBaseURL` is missing or empty, API calls will fail (no fallback).

3. **Run**
   - Select a simulator or device and press **Run** (⌘R).

## API

Base URL is configured via xcconfig → `APIBaseURL` in Info.plist (see `APIConfig` in `Services/APIService.swift`).

Endpoints used:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/login` | JWT login |
| GET | `/api/store-performance` | Store list for dashboard tiles |
| GET | `/api/daily-sales` | Daily sales summary (date range, optional store) |
| GET | `/api/daily-sales-categories` | Orders by dining option (per store, date range) |
| GET | `/api/time-windows` | Hourly stock status for Out of Stock heatmap |

## Project structure

```text
Ops/
├── README.md
├── .gitignore              # e.g. Secrets.xcconfig
└── Ops_files/
    ├── RSBBQOperations.xcodeproj
    └── RSBBQOperations/
        ├── RSBBQOperationsApp.swift   # @main
        ├── ContentView.swift          # Tabs after store selection
        ├── Config.xcconfig           # Default build config (placeholder URL)
        ├── Secrets.xcconfig          # Local only; set API_BASE_URL (gitignored)
        ├── Info.plist
        ├── Login/
        │   └── LoginView.swift
        ├── Views/
        │   ├── HomeView.swift        # Store tiles
        │   ├── OutOfStockEventsView.swift
        │   └── DailySalesView.swift
        └── Services/
            └── APIService.swift      # Auth, config, API client
```

## License

Private / internal use.
