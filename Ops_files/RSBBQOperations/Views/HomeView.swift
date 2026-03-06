import SwiftUI

let backgroundGradient = LinearGradient(
    colors: [Color.gray, Color.black],
    startPoint: .top, endPoint: .bottom
)

private func storeLogoImageName(storeCode: String) -> String {
    let sanitized = storeCode
        .replacingOccurrences(of: " ", with: "_")
        .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    return "StoreLogo_\(sanitized.isEmpty ? storeCode : sanitized)"
}

/// A single store tile in the dashboard grid: shows the store logo and optional out-of-stock badge.
private struct StoreTileView: View {
    let storeCode: String
    /// Number of recent out-of-stock events; `nil` while loading.
    let outOfStockCount: Int?

    private var logoImageName: String { storeLogoImageName(storeCode: storeCode) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background {
            // Logo behind the tile; doesn't affect tile size (grid + aspectRatio do)
            Image(logoImageName)
                .resizable()
                .scaledToFill()
                .clipped()
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Dashboard showing a grid of store tiles; tapping a store opens ``ContentView`` with Out of Stock and Daily Sales tabs.
///
/// Loads the store list from ``APIService/storePerformance()`` and optionally fetches recent out-of-stock
/// counts per store. Supports pull-to-refresh.
struct HomeView: View {
    @State private var stores: [StorePerformanceItem] = []
    @State private var outOfStockCounts: [String: Int] = [:]
    @State private var loading = true
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if loading { ProgressView() }
                else if let msg = errorMessage { Text(msg).foregroundStyle(.red) }
                else { storeGrid }
            }
            .navigationTitle("Landmarks")
            .refreshable { await loadStoresAndCounts() }
            .task { await loadStoresAndCounts() }
            .background(backgroundGradient)
        }
    }

    private var storeGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(stores, id: \.storeCode) { store in
                    NavigationLink(destination: ContentView(selectedStore: store)) {
                        StoreTileView(
                            storeCode: store.storeCode,
                            outOfStockCount: outOfStockCounts[store.storeCode]
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func loadStoresAndCounts() async {
        loading = true
        errorMessage = nil
        outOfStockCounts = [:]
        do {
            stores = try await APIService.shared.storePerformance()
            await withTaskGroup(of: (String, Int).self) { group in
                for store in stores {
                    group.addTask {
                        let count = (try? await APIService.shared.outOfStockItems(storeCode: store.storeCode, hours: 6))?.count ?? 0
                        return (store.storeCode, count)
                    }
                }
                for await (code, count) in group {
                    outOfStockCounts[code] = count
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}

