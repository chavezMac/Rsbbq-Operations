import SwiftUI
import Charts

private struct ChartPoint: Identifiable {
    let id = UUID()
    let storeCode: String
    let type: String
    let value: Double
    /// Unique x-axis value so Catering and Non-Catering appear side by side (not stacked).
    var xKey: String { "\(storeCode)|\(type)" }
    init(storeCode: String, type: String, value: Double) {
        self.storeCode = storeCode
        self.type = type
        self.value = value
    }
}

/// One aggregated point per category for the Orders by Category chart (avoids duplicate legend entries).
private struct CategoryChartItem: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

struct DailySalesView: View {
    /// When set, only that store's data is shown; when nil, all stores.
    var storeCode: String? = nil
    @State private var salesData: [DailySalesSummary] = []
    @State private var categoriesData: [DailySalesCategories] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var categoriesErrorMessage: String?
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedAmountX: String?
    @State private var selectedOrderX: String?
    @State private var selectedCategoryX: String?

    private var startDateString: String { dateString(from: startDate) }
    private var endDateString: String { dateString(from: endDate) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                controlsSection
                if loading { ProgressView().frame(maxWidth: .infinity).padding() }
                else if let msg = errorMessage { Text(msg).foregroundStyle(.red).padding() }
                else if salesData.isEmpty { Text("No sales data for the selected period").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(40) }
                else {
                    chartSwipeStack
                    summaryTable
                    if !categoriesData.isEmpty {
                        summaryTableCategories
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Daily Sales")
        .refreshable { await load() }
        .task { await load() }
        .background(backgroundGradient)
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Date Range")
                .font(.headline)
            HStack(spacing: 16) {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                DatePicker("End", selection: $endDate, displayedComponents: .date)
                    .labelsHidden()
            }
            .onChange(of: startDate) { _, _ in Task { await load() } }
            .onChange(of: endDate) { _, _ in Task { await load() } }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var amountChartData: [ChartPoint] {
        salesData.flatMap { row in
            [
                ChartPoint(storeCode: row.storeCode, type: "Catering", value: row.cateringAmount),
                ChartPoint(storeCode: row.storeCode, type: "Non-Catering", value: row.nonCateringAmount)
            ]
        }
    }

    private var orderChartData: [ChartPoint] {
        salesData.flatMap { row in
            [
                ChartPoint(storeCode: row.storeCode, type: "Catering", value: Double(row.cateringOrders)),
                ChartPoint(storeCode: row.storeCode, type: "Non-Catering", value: Double(row.nonCateringOrders))
            ]
        }
    }

    /// Swipeable stack: Sales Amount, Order Count, and Categories (by dining option) charts.
    private var chartSwipeStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Swipe: Sales Amount ↔ Order Count ↔ Categories")
                .font(.caption)
                .foregroundStyle(.white)
            TabView {
                salesAmountChartPage
                orderCountChartPage
                categoriesChartPage
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var salesAmountChartPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily Sales")
                    .font(.subheadline.weight(.semibold))
                if let x = selectedAmountX, let point = amountChartData.first(where: { $0.xKey == x }) {
                    Text("\(point.type): \(formatCurrency(point.value))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            Chart(amountChartData) { item in
                BarMark(x: .value("Catering", item.xKey), y: .value("Amount", item.value))
                    .foregroundStyle(by: .value("Type", item.type))
            }
            .chartForegroundStyleScale(["Catering": Color.blue, "Non-Catering": Color.green])
            .chartLegend(position: .top)
            .chartXSelection(value: $selectedAmountX)
            .chartXAxis(.hidden)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }

    private var orderCountChartPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Order Count")
                    .font(.subheadline.weight(.semibold))
                if let x = selectedOrderX, let point = orderChartData.first(where: { $0.xKey == x }) {
                    Text("\(point.type): \(Int(point.value))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            Chart(orderChartData) { item in
                BarMark(x: .value("Store", item.xKey), y: .value("Orders", item.value))
                    .foregroundStyle(by: .value("Type", item.type))
            }
            .chartForegroundStyleScale(["Catering": Color.blue, "Non-Catering": Color.green])
            .chartLegend(position: .top)
            .chartXSelection(value: $selectedOrderX)
//          Future implementation for different order types to be displayed on the graphs
//            .chartXAxis {
//                AxisMarks(values: .automatic) { value in
//                    AxisValueLabel {
//                        if let s = value.as(String.self), let code = s.split(separator: "|").first {
//                            Text(String(code))
//                        } else {
//                            Text("")
//                        }
//                    }
//                }
//            }
            .chartXAxis(.hidden)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }

    /// Aggregated by category (one bar per category) so the chart and legend don’t duplicate.
    private var categoriesChartData: [CategoryChartItem] {
        let grouped = Dictionary(grouping: categoriesData, by: \.diningOptionName)
        return grouped.map { name, items in
            CategoryChartItem(name: name, count: items.reduce(0) { $0 + $1.orderCount })
        }.sorted { $0.name < $1.name }
    }

    private var categoriesChartPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Orders by Category")
                    .font(.subheadline.weight(.semibold))
                if let x = selectedCategoryX, let item = categoriesChartData.first(where: { $0.name == x }) {
                    Text("\(item.name): \(item.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            if categoriesData.isEmpty {
                Text(categoriesErrorMessage ?? "Select a store for category breakdown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(categoriesChartData) { item in
                    BarMark(x: .value("Category", item.name), y: .value("Orders", item.count))
                        .foregroundStyle(by: .value("Category", item.name))
                }
                .chartForegroundStyleScale(
                    domain: categoriesChartData.map(\.name),
                    range: [.blue, .green, .orange, .purple, .pink, .cyan, .mint, .indigo]
                )
                .chartLegend(position: .top)
                .chartXSelection(value: $selectedCategoryX)
                .chartXAxis(.hidden)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
    }

    private var summaryTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    headerRow
                    ForEach(salesData) { row in
                        summaryRow(row)
                    }
                }
                .frame(minWidth: 380)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    /// Column order for category summary (must match categoryHeaderRow and categorySummaryRow).
    private static let categoryColumnNames = ["Online", "Take Out","Call In", "Dine In", "DoorDash Delivery", "DoorDash Takeout", "Toast Delivery", "Uber Eats Del", "Uber Eats TO", "Unknown", "Curbside", "Online Ordering-TO", "e-gift card", "TO", "Grubhub"]
    

    /// One row per store: storeCode + order count per category (derived from categoriesData).
    /// Aggregates by diningOptionName so duplicate keys (e.g. same category across date range) are summed.
    private var categoryTableRows: [(storeCode: String, counts: [String: Int])] {
        let grouped = Dictionary(grouping: categoriesData, by: \.storeCode)
        return grouped.map { storeCode, items in
            let byCategory = Dictionary(grouping: items, by: \.diningOptionName)
            let counts = byCategory.mapValues { $0.reduce(0) { $0 + $1.orderCount } }
            return (storeCode: storeCode, counts: counts)
        }.sorted { $0.storeCode < $1.storeCode }
    }

    /// Category columns to show: only those with at least one non-zero count (omits all-zero columns).
    private var categoryColumnsToShow: [String] {
        let withNonZero = Set(categoryTableRows.flatMap { row in
            row.counts.compactMap { $0.value > 0 ? $0.key : nil }
        })
        return Self.categoryColumnNames.filter { withNonZero.contains($0) }
    }

    private var summaryTableCategories: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories Summary")
                .font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    categoryHeaderRow
                    ForEach(categoryTableRows, id: \.storeCode) { row in
                        categorySummaryRow(storeCode: row.storeCode, counts: row.counts)
                    }
                }
                .frame(minWidth: 620)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("Store").frame(width: 60, alignment: .leading).font(.caption.weight(.semibold))
            Text("Catering $").frame(width: 56, alignment: .trailing).font(.caption.weight(.semibold))
            Text("Non-Cat $").frame(width: 56, alignment: .trailing).font(.caption.weight(.semibold))
            Text("Total $").frame(width: 56, alignment: .trailing).font(.caption.weight(.semibold))
            Text("Cat #").frame(width: 36, alignment: .trailing).font(.caption.weight(.semibold))
            Text("Non #").frame(width: 36, alignment: .trailing).font(.caption.weight(.semibold))
            Text("Total #").frame(width: 40, alignment: .trailing).font(.caption.weight(.semibold))
        }
        .padding(.vertical, 6)
    }
    
    private var categoryHeaderRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("Store").frame(width: 60, alignment: .leading).font(.caption.weight(.semibold))
            ForEach(categoryColumnsToShow, id: \.self) { name in
                Text(name).frame(width: 56, alignment: .trailing).font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
    }

    private func summaryRow(_ row: DailySalesSummary) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(row.storeCode).frame(width: 60, alignment: .leading).font(.caption).lineLimit(1)
            Text(formatCurrency(row.cateringAmount)).frame(width: 56, alignment: .trailing).font(.caption2)
            Text(formatCurrency(row.nonCateringAmount)).frame(width: 56, alignment: .trailing).font(.caption2)
            Text(formatCurrency(row.totalAmount)).frame(width: 56, alignment: .trailing).font(.caption2.weight(.medium))
            Text("\(row.cateringOrders)").frame(width: 36, alignment: .trailing).font(.caption2)
            Text("\(row.nonCateringOrders)").frame(width: 36, alignment: .trailing).font(.caption2)
            Text("\(row.totalOrders)").frame(width: 40, alignment: .trailing).font(.caption2.weight(.medium))
        }
        .padding(.vertical, 4)
    }
    
    private func categorySummaryRow(storeCode: String, counts: [String: Int]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(storeCode).frame(width: 60, alignment: .leading).font(.caption).lineLimit(1)
            ForEach(categoryColumnsToShow, id: \.self) { name in
                Text("\(counts[name] ?? 0)").frame(width: 56, alignment: .trailing).font(.caption2)
            }
        }
        .padding(.vertical, 4)
    }

    private func dateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func load() async {
        loading = true
        errorMessage = nil
        categoriesErrorMessage = nil
        do {
            salesData = try await APIService.shared.dailySales(storeCode: storeCode, startDate: startDateString, endDate: endDateString)
        } catch {
            errorMessage = error.localizedDescription
            loading = false
            return
        }

        // Categories are additive UI; don't fail the whole view if the endpoint is missing (e.g. 404).
        if let code = storeCode, !code.isEmpty {
            do {
                categoriesData = try await APIService.shared.dailySalesCategories(storeCode: code, startDate: startDateString, endDate: endDateString)
            } catch {
                categoriesData = []
                categoriesErrorMessage = "Category breakdown unavailable"
            }
        } else {
            categoriesData = []
        }
        loading = false
    }
}
