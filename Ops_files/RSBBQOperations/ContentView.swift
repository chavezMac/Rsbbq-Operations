import SwiftUI

struct ContentView: View {
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
