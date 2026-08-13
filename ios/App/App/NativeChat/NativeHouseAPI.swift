import Foundation

enum NativeHouseAPI {
    static func request(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> Any {
        var request = URLRequest(url: AlcoveAPI.fullURL(path))
        request.httpMethod = method
        request.timeoutInterval = 35
        // House state is live data. Do not let URLSession satisfy a refresh from
        // its local cache even if an intermediary accidentally omits headers.
        if method == "GET" {
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await AlcoveAPI.session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    static func object(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> [String: Any] {
        guard let value = try await request(path, method: method, body: body) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return value
    }

    /// Decode a JSON error body as well as a success body. Use only where
    /// the UI needs the server's actionable hint (for example work delivery 409).
    static func objectIncludingHTTPError(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> [String: Any] {
        var request = URLRequest(url: AlcoveAPI.fullURL(path))
        request.httpMethod = method
        request.timeoutInterval = 35
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, _) = try await AlcoveAPI.session.data(for: request)
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return value
    }

    static func array(
        _ path: String,
        key: String? = nil
    ) async throws -> [[String: Any]] {
        let value = try await request(path)
        if let array = value as? [[String: Any]] { return array }
        if let key, let object = value as? [String: Any],
           let array = object[key] as? [[String: Any]] {
            return array
        }
        return []
    }

    static func post(_ path: String, body: [String: Any] = [:]) async throws {
        _ = try await request(path, method: "POST", body: body)
    }
}

extension Dictionary where Key == String, Value == Any {
    func string(_ keys: String...) -> String {
        for key in keys {
            if let value = self[key] as? String, !value.isEmpty { return value }
            if let value = self[key] as? NSNumber { return value.stringValue }
        }
        return ""
    }

    func int(_ keys: String...) -> Int {
        for key in keys {
            if let value = self[key] as? Int { return value }
            if let value = self[key] as? NSNumber { return value.intValue }
            if let value = self[key] as? String, let parsed = Int(value) { return parsed }
        }
        return 0
    }

    func bool(_ keys: String...) -> Bool {
        for key in keys {
            if let value = self[key] as? Bool { return value }
            if let value = self[key] as? NSNumber { return value.boolValue }
            if let value = self[key] as? String {
                return value == "1" || value.lowercased() == "true"
            }
        }
        return false
    }

    func object(_ key: String) -> [String: Any] {
        self[key] as? [String: Any] ?? [:]
    }

    func array(_ key: String) -> [[String: Any]] {
        self[key] as? [[String: Any]] ?? []
    }
}
