import SwiftUI

/// Tabbed content for a selected store: Out of Stock (hourly heatmap) and Daily Sales (charts and summary).
///
/// Shown after the user taps a store tile in ``HomeView``. Uses ``OutOfStockEventsView`` and ``DailySalesView``
/// with the store’s ``StorePerformanceItem/storeCode``.
struct ContentView: View {
    /// The store chosen from the dashboard; used for navigation title and passed to child tabs.
    let selectedStore: StorePerformanceItem
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            OutOfStockEventsView(storeCode: selectedStore.storeCode)
                .tabItem { Label("Out of Stock", systemImage: "exclamationmark.triangle") }
                .tag(0)

            DailySalesView(storeCode: selectedStore.storeCode)
                .tabItem { Label("Daily Sales", systemImage: "chart.bar.doc.horizontal") }
                .tag(1)
        }
        .navigationTitle(selectedStore.storeCode)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .tabBar)
    }
}
