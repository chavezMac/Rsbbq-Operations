import SwiftUI

// MARK: - Pacific time formatting
private func statusDatetimeInPST(_ raw: String) -> String? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = iso.date(from: raw)
    if date == nil {
        iso.formatOptions = [.withInternetDateTime]
        date = iso.date(from: raw)
    }
    if date == nil {
        let mysql = DateFormatter()
        mysql.dateFormat = "yyyy-MM-dd HH:mm:ss"
        mysql.timeZone = TimeZone(identifier: "UTC")
        date = mysql.date(from: raw)
    }
    guard let d = date else { return nil }
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    let abbr = formatter.timeZone.abbreviation(for: d) ?? "PT"
    formatter.dateFormat = "M/d/yy, h:mm a '\(abbr)'"
    return formatter.string(from: d)
}



// MARK: - Out-of-stock daily trends (heatmap-style table like web DailyTrends)

/// One row in the hourly stock heatmap: an item name and its status per time window (time_window_id → status).
private struct TimeWindowRow: Identifiable {
    let id = UUID()
    let itemName: String
    /// Maps time_window_id to status (e.g. IN_STOCK, OUT_OF_STOCK).
    let timeWindows: [String: String]
}

/// Hourly stock status heatmap for one store and date: items vs. 30-minute time windows (11am–9pm PST).
///
/// Uses ``APIService/timeWindows(days:storeCode:date:)`` to load data and displays a table with color-coded
/// status (in stock, out of stock, no data). The store is fixed from the selected tile in ``ContentView``.
struct OutOfStockEventsView: View {
    /// Store from the selected tile (passed by ContentView); user cannot change it here.
    let storeCode: String
    @State private var selectedDate = Date()
    @State private var rows: [TimeWindowRow] = []
    @State private var loading = true
    @State private var errorMessage: String?

    // Time window ids and labels (30-minute intervals 11am–9pm)
    private let timeWindowIds: [String] = [
        "1","2","3","4","5","6","7","8","9","10",
        "11","12","13","14","15","16","17","18","19","20"
    ]
    private let timeWindowLabels: [String: String] = [
        "1": "11–11:30a","2": "11:30–12p","3": "12–12:30p","4": "12:30–1p",
        "5": "1–1:30p","6": "1:30–2p","7": "2–2:30p","8": "2:30–3p",
        "9": "3–3:30p","10": "3:30–4p","11": "4–4:30p","12": "4:30–5p",
        "13": "5–5:30p","14": "5:30–6p","15": "6–6:30p","16": "6:30–7p",
        "17": "7–7:30p","18": "7:30–8p","19": "8–8:30p","20": "8:30–9p"
    ]

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("Loading time window data…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let msg = errorMessage {
                    Text(msg)
                        .foregroundStyle(.red)
                        .padding()
                } else if rows.isEmpty {
                    VStack(spacing: 12) {
                        controls
                        Text("No data available for the selected store and date")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    .padding(.horizontal)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        controls
                        table
                        legend
                    }
                    .padding(.horizontal)
                    
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                backgroundGradient.ignoresSafeArea()
            )
            .navigationTitle("Hourly Stock Status")
            .navigationBarTitleDisplayMode(.inline)
            .task { await initialLoad() }
            .refreshable { await reload() }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hourly Inventory Stock Status")
                .font(.headline)
            HStack(spacing: 16) {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .onChange(of: selectedDate) { _, _ in
                        Task { await loadRows() }
                    }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var table: some View {
        HStack(alignment: .top, spacing: 0) {
            // Fixed left column: item names
            VStack(alignment: .leading, spacing: 0) {
                Text("Item")
                    .font(.caption.weight(.semibold))
                    .frame(width: 100, alignment: .leading)
                    .padding(.vertical, 6)
                ForEach(rows) { row in
                    Text(row.itemName)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(width: 100, alignment: .leading)
                        .frame(height: 28)
                        .padding(.vertical, 2)
                }
            }

            // Scrollable right side: time-window heatmap
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 4) {
                        ForEach(timeWindowIds, id: \.self) { twId in
                            Text(timeWindowLabels[twId] ?? twId)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .frame(width: 72)
                        }
                    }
                    .padding(.vertical, 6)

                    // Data rows
                    ForEach(rows) { row in
                        HStack(spacing: 4) {
                            ForEach(timeWindowIds, id: \.self) { twId in
                                let status = row.timeWindows[twId]
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(color(for: status).opacity(status == nil ? 0.08 : 0.25))
                                    if let status = status {
                                        Circle()
                                            .fill(color(for: status))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .frame(width: 72, height: 24)
                            }
                        }
                        .frame(height: 28)
                        .padding(.vertical, 2)
                    }
                }
                .frame(minWidth: CGFloat(timeWindowIds.count) * 72)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle().fill(color(for: "IN_STOCK")).frame(width: 10, height: 10)
                Text("In Stock").font(.caption).foregroundStyle(Color.white)
            }
            HStack(spacing: 4) {
                Circle().fill(color(for: "OUT_OF_STOCK")).frame(width: 10, height: 10)
                Text("Out of Stock").font(.caption).foregroundStyle(Color.white)
            }
            HStack(spacing: 4) {
                Circle().fill(Color.gray.opacity(0.4)).frame(width: 10, height: 10)
                Text("No Data").font(.caption).foregroundStyle(Color.white)
            }
        }
        .padding(.horizontal, 4)
    }

    private func color(for status: String?) -> Color {
        switch status {
        case "OUT_OF_STOCK": return .red
        case "IN_STOCK": return .green
        default: return .gray
        }
    }

    // MARK: - Loading

    private func initialLoad() async {
        loading = true
        errorMessage = nil
        await loadRows()
    }

    private func reload() async {
        errorMessage = nil
        await loadRows()
    }

    private func loadRows() async {
        guard !storeCode.isEmpty else {
            rows = []
            loading = false
            return
        }
        loading = true
        errorMessage = nil
        let dateString = dateString(from: selectedDate)
        do {
            let raw = try await APIService.shared.timeWindows(days: 1, storeCode: storeCode, date: dateString)
            // Group by item_name and time_window_id (OUT_OF_STOCK takes precedence)
            var itemMap: [String: [String: String]] = [:]  // itemName → (twId → status)
            for record in raw {
                let itemName = (record["item_name"] as? String) ?? (record["item_id"] as? String) ?? "Unknown"
                let twId = String(describing: record["time_window_id"] ?? "")
                let status = record["status"] as? String
                if itemMap[itemName] == nil {
                    itemMap[itemName] = [:]
                }
                if let status = status {
                    let existing = itemMap[itemName]![twId]
                    if existing == nil || status == "OUT_OF_STOCK" {
                        itemMap[itemName]![twId] = status
                    }
                }
            }
            rows = itemMap.map { key, value in
                TimeWindowRow(itemName: key, timeWindows: value)
            }
            .sorted { $0.itemName < $1.itemName }
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }

    private func dateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
