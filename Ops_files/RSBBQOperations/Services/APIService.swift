import Foundation
import Combine
// MARK: - Config
// Base URL is set at build time via xcconfig → Info.plist key "APIBaseURL".
// Use Config.xcconfig (placeholder) or Secrets.xcconfig (real URL, gitignored) as the project’s base configuration.
enum APIConfig {
    static var baseURL: String {
        let url = (Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String) ?? ""
        #if DEBUG
        if _baseURLPrintOnce {
            _baseURLPrintOnce = false
            print("API Base URL: \(url.isEmpty ? "(not set)" : url)")
        }
        #endif
        return url
    }
    #if DEBUG
    private static var _baseURLPrintOnce = true
    #endif
}

// MARK: - Auth
@MainActor
final class AuthManager: ObservableObject {
    @Published var token: String?
    var isAuthenticated: Bool { token != nil }

    func login(username: String, password: String) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/api/login")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(LoginRequest(username: username, password: password))
        let (data, res) = try await URLSession.shared.data(for: req)
        guard (res as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.loginFailed }
        let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)
        token = decoded.token
        APIService.shared.authToken = decoded.token
    }

    func logout() {
        token = nil
        APIService.shared.authToken = nil
    }
}

struct LoginRequest: Encodable { let username: String; let password: String }
struct LoginResponse: Decodable { let token: String }

/// Maps to v_out_of_stock_events: stock_status_id, store_code, item_id, item_name, date, status_datetime, status, etc.
struct OutOfStockItem: Identifiable {
    let id: String
    let productName: String?
    let itemId: String?
    let storeCode: String?
    let statusDatetime: String?
    let status: String?
    let date: String?
    init(from row: [String: Any]) {
        let numId = row["stock_status_id"] as? NSNumber
        self.id = numId.map { String(describing: $0) } ?? (row["item_id"] as? String) ?? UUID().uuidString
        self.productName = row["item_name"] as? String ?? row["product_name"] as? String ?? row["name"] as? String
        self.itemId = row["item_id"] as? String
        self.storeCode = row["store_code"] as? String
        self.statusDatetime = row["status_datetime"] as? String
        self.status = row["status"] as? String
        self.date = row["date"] as? String
    }
}

/// Per-store daily sales summary (aggregated from /api/daily-sales).
struct DailySalesSummary: Identifiable {
    var id: String { storeCode }
    let storeCode: String
    let cateringAmount: Double
    let nonCateringAmount: Double
    let totalAmount: Double
    let cateringOrders: Int
    let nonCateringOrders: Int
    let totalOrders: Int
}

/// Minimal store performance model used for store tiles and navigation.
struct StorePerformanceItem: Identifiable, Hashable {
    var id: String { storeCode }
    let storeCode: String
    var displayMetrics: String { "" }
}

// Per-store daily sales by dining option (e.g. Dine-in, Takeout, Delivery).
struct DailySalesCategories: Identifiable {
    var id: String { "\(storeCode)|\(diningOptionName)" }
    let storeCode: String
    let diningOptionName: String
    let orderCount: Int

    init(storeCode: String, diningOptionName: String, orderCount: Int) {
        self.storeCode = storeCode
        self.diningOptionName = diningOptionName
        self.orderCount = orderCount
    }

    init?(from row: [String: Any]) {
        guard let store = row["store_code"] as? String ?? (row["storeCode"] as? String),
              let name = row["dining_option_name"] as? String ?? (row["diningOptionName"] as? String) else { return nil }
        self.storeCode = store
        self.diningOptionName = name
        self.orderCount = parseInteger(row["order_count"] ?? row["orderCount"])
    }
}

/// Parse API value that may be NSNumber or String (e.g. MySQL decimal(10,2) serialized as "1234.56").
private func parseDecimal(_ value: Any?) -> Double {
    if let n = value as? NSNumber { return n.doubleValue }
    if let s = value as? String, let d = Double(s) { return d }
    return 0
}

private func parseInteger(_ value: Any?) -> Int {
    if let n = value as? NSNumber { return n.intValue }
    if let s = value as? String, let i = Int(s) { return i }
    return 0
}

// MARK: - API Client
final class APIService {
    static let shared = APIService()
    private init() {}

    /// Set by AuthManager on login; cleared on logout. Used for Daily Summary and other authenticated endpoints.
    var authToken: String?

    /// Store performance list used to build store tiles / selection.
    func storePerformance() async throws -> [StorePerformanceItem] {
        let url = URL(string: "\(APIConfig.baseURL)/api/store-performance")!
        let data = try await performGET(url: url)
        let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return raw.compactMap { row in
            guard let code = row["store_code"] as? String else { return nil }
            return StorePerformanceItem(storeCode: code)
        }
    }

    /// Daily sales for a date range. Backend: GET /api/daily-sales?store=...&startDate=...&endDate=... (dates as YYYY-MM-DD)
    /// Returns one summary per store (aggregated). Pass storeCode nil for all stores.
    func dailySales(storeCode: String?, startDate: String, endDate: String) async throws -> [DailySalesSummary] {
        var components = URLComponents(string: "\(APIConfig.baseURL)/api/daily-sales")!
        var queryItems = [
            URLQueryItem(name: "startDate", value: startDate),
            URLQueryItem(name: "endDate", value: endDate)
        ]
        if let store = storeCode, !store.isEmpty { queryItems.append(URLQueryItem(name: "store", value: store)) }
        components.queryItems = queryItems
        let url = components.url!
        let data = try await performGET(url: url)
        let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        var byStore: [String: (cateringAmount: Double, nonCateringAmount: Double, totalAmount: Double, cateringOrders: Int, nonCateringOrders: Int, totalOrders: Int)] = [:]
        for row in raw {
            guard let store = row["store_code"] as? String else { continue }
            if byStore[store] == nil {
                byStore[store] = (0, 0, 0, 0, 0, 0)
            }
            var v = byStore[store]!
            v.cateringAmount += parseDecimal(row["catering_amount"])
            v.nonCateringAmount += parseDecimal(row["non_catering_amount"])
            v.totalAmount += parseDecimal(row["total_amount"])
            v.cateringOrders += parseInteger(row["catering_orders"])
            v.nonCateringOrders += parseInteger(row["non_catering_orders"])
            v.totalOrders += parseInteger(row["total_orders"])
            byStore[store] = v
        }
        return byStore.sorted { ($0.value.totalAmount) > ($1.value.totalAmount) }.map { store, v in
            DailySalesSummary(
                storeCode: store,
                cateringAmount: v.cateringAmount,
                nonCateringAmount: v.nonCateringAmount,
                totalAmount: v.totalAmount,
                cateringOrders: v.cateringOrders,
                nonCateringOrders: v.nonCateringOrders,
                totalOrders: v.totalOrders
            )
        }
    }

    func dailySalesCategories(storeCode: String, startDate: String, endDate: String) async throws -> [DailySalesCategories] {
        var components = URLComponents(string: "\(APIConfig.baseURL)/api/daily-sales-by-dining-option")!
        var queryItems = [URLQueryItem(name: "store", value: storeCode), URLQueryItem(name: "startDate", value: startDate), URLQueryItem(name: "endDate", value: endDate)]
        components.queryItems = queryItems
        let url = components.url!
        let data = try await performGET(url: url)
        let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return raw.compactMap { row in
            DailySalesCategories(from: row)
        }
    }

    /// Time-window stock status for a single day. Backend: GET /api/time-windows?days=1&store=...&date=YYYY-MM-DD
    /// Returns raw records so the view can group by item and time_window_id like the web DailyTrends component.
    func timeWindows(days: Int = 1, storeCode: String, date: String) async throws -> [[String: Any]] {
        var components = URLComponents(string: "\(APIConfig.baseURL)/api/time-windows")!
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "days", value: String(days))]
        if !storeCode.isEmpty {
            queryItems.append(URLQueryItem(name: "store", value: storeCode))
        }
        if !date.isEmpty {
            queryItems.append(URLQueryItem(name: "date", value: date))
        }
        components.queryItems = queryItems
        let url = components.url!
        let data = try await performGET(url: url)
        let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return raw
    }

    /// Out-of-stock events for a store. Use either hours (preset) or start/end (custom range).
    /// Backend: GET /api/out-of-stock?store=...&hours=... OR ?store=...&start_datetime=...&end_datetime=... (ISO8601)
    func outOfStockItems(storeCode: String, hours: Int? = 24, startDate: Date? = nil, endDate: Date? = nil) async throws -> [OutOfStockItem] {
        var components = URLComponents(string: "\(APIConfig.baseURL)/api/out-of-stock")!
        var queryItems = [URLQueryItem(name: "store", value: storeCode)]
        if let start = startDate, let end = endDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            queryItems.append(URLQueryItem(name: "start_datetime", value: formatter.string(from: start)))
            queryItems.append(URLQueryItem(name: "end_datetime", value: formatter.string(from: end)))
        } else {
            queryItems.append(URLQueryItem(name: "hours", value: String(hours ?? 24)))
        }
        components.queryItems = queryItems
        let url = components.url!
        let data = try await performGET(url: url)
        let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return raw.compactMap { row in
            OutOfStockItem(from: row)
        }
    }

    private func performGET(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        if let t = authToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (data, res) = try await URLSession.shared.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw APIError.requestFailed(statusCode: nil) }
        guard http.statusCode == 200 else { throw APIError.requestFailed(statusCode: http.statusCode) }
        return data
    }
}

enum APIError: LocalizedError {
    case loginFailed
    case requestFailed(statusCode: Int?)
    var errorDescription: String? {
        switch self {
        case .loginFailed: return "Login failed"
        case .requestFailed(let code): return code.map { "Request failed (\($0))" } ?? "Request failed"
        }
    }
}

