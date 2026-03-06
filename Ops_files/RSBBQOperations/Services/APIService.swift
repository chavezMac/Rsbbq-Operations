import Foundation
import Combine
// MARK: - Config
/// API base URL and build-time configuration.
///
/// The base URL is read from the app's Info.plist key `APIBaseURL`, set at build time
/// via xcconfig (Config.xcconfig or Secrets.xcconfig). All API requests use this URL.
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

/// Manages JWT authentication state for the app and coordinates with ``APIService``.
///
/// When the user signs in successfully, the token is stored and set on ``APIService/shared`` so that
/// subsequent API calls include the `Authorization: Bearer` header. Use ``logout()`` to clear the token.
@MainActor
final class AuthManager: ObservableObject {
    /// The current JWT; `nil` when the user is not logged in.
    @Published var token: String?
    /// `true` when a token is present and the user is considered authenticated.
    var isAuthenticated: Bool { token != nil }

    /// Authenticates with the Operations API and stores the returned JWT.
    /// - Throws: ``APIError/loginFailed`` if the server returns a non-200 response.
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

    /// Clears the stored token and the shared API client’s auth header.
    func logout() {
        token = nil
        APIService.shared.authToken = nil
    }
}

/// Payload sent to `POST /api/login` for authentication.
struct LoginRequest: Encodable { let username: String; let password: String }

/// Response from `POST /api/login` containing the JWT to use for subsequent requests.
struct LoginResponse: Decodable { let token: String }

/// A single out-of-stock event or item record from the `/api/out-of-stock` endpoint.
///
/// Maps from the API’s row format (e.g. `stock_status_id`, `store_code`, `item_id`, `item_name`,
/// `date`, `status_datetime`, `status`) and is used by ``OutOfStockEventsView`` and related logic.
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

/// Aggregated daily sales totals for one store from the `/api/daily-sales` endpoint.
///
/// Includes catering vs. non-catering amounts and order counts. Used by ``DailySalesView`` for
/// charts and the summary table.
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

/// A store entry used for the dashboard tiles and for passing the selected store into ``ContentView``.
///
/// The ``storeCode`` is the unique identifier and is used when calling store-specific APIs (e.g. out-of-stock, daily sales).
struct StorePerformanceItem: Identifiable, Hashable {
    var id: String { storeCode }
    /// Unique store identifier used in API queries (e.g. out-of-stock, daily sales).
    let storeCode: String
    /// Optional display string for the tile; currently unused, reserved for future metrics.
    var displayMetrics: String { "" }
}

/// Orders for one store broken down by dining option (e.g. Dine-in, Takeout, Delivery).
///
/// Returned by `/api/daily-sales-by-dining-option` and used in ``DailySalesView`` for the
/// “Orders by Category” chart and the categories summary table.
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

/// Shared HTTP client for the RSBBQ Operations API.
///
/// Use ``APIService/shared`` for all API calls. Set ``authToken`` (usually via ``AuthManager``) so that
/// authenticated endpoints receive the `Authorization: Bearer` header. Endpoints include store performance,
/// daily sales, daily sales by category, time-window stock status, and out-of-stock events.
final class APIService {
    static let shared = APIService()
    private init() {}

    /// Set by AuthManager on login; cleared on logout. Used for Daily Summary and other authenticated endpoints.
    var authToken: String?

    /// Fetches the list of stores for the dashboard tiles (GET /api/store-performance).
    /// - Returns: One ``StorePerformanceItem`` per store.
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

    /// Fetches orders by dining option for one store and date range (GET /api/daily-sales-by-dining-option).
    /// - Parameters:
    ///   - storeCode: The store to query.
    ///   - startDate: Start date in YYYY-MM-DD format.
    ///   - endDate: End date in YYYY-MM-DD format.
    /// - Returns: One ``DailySalesCategories`` per (store, dining option) with order count.
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

/// Errors returned by ``APIService`` and ``AuthManager`` when API calls fail.
enum APIError: LocalizedError {
    /// Login failed (e.g. invalid credentials or non-200 from POST /api/login).
    case loginFailed
    /// An API request failed; `statusCode` is the HTTP status when available.
    case requestFailed(statusCode: Int?)
    var errorDescription: String? {
        switch self {
        case .loginFailed: return "Login failed"
        case .requestFailed(let code): return code.map { "Request failed (\($0))" } ?? "Request failed"
        }
    }
}

