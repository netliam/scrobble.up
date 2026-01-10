//
//  HTTPHelper.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/6/26.
//

import Foundation

enum HTTPError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized request"
        case .rateLimited:
            return "Rate limited - please try again later"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

/// HTTP methods supported by the helper
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

/// A helper class for making HTTP requests
final class HTTPHelper {
    /// Shared singleton instance
    static let shared = HTTPHelper()
    
    /// User agent string for requests
    let userAgent: String
    
    /// URL session for making requests
    let session: URLSession
    
    /// Maximum number of retry attempts for TLS errors
    private let maxRetries = 3
    
    /// Creates an HTTPHelper with custom configuration
    init(userAgent: String, session: URLSession = .shared) {
        self.userAgent = userAgent
        self.session = session
    }
    
    /// Private initializer for singleton
    private init() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ScrobbleUp"
        self.userAgent = "\(appName)/\(appVersion)"
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        // Enable TLS 1.2 minimum for better compatibility
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        self.session = URLSession(configuration: configuration)
    }
    
    /// Helper to check if an error is a TLS error that should be retried
    private func isTLSError(_ error: Error) -> Bool {
        let nsError = error as NSError
        // Check for TLS-related errors
        if nsError.domain == NSURLErrorDomain {
            return nsError.code == NSURLErrorSecureConnectionFailed ||  // -1200
                   nsError.code == NSURLErrorServerCertificateUntrusted || // -1202
                   nsError.code == NSURLErrorClientCertificateRejected     // -1205
        }
        return false
    }
    
    /// Performs a request with retry logic for TLS errors
    private func performWithRetry<T>(
        maxAttempts: Int = 3,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Only retry on TLS errors
                guard isTLSError(error), attempt < maxAttempts else {
                    throw error
                }
                
                // Exponential backoff: 0.5s, 1s, 2s
                let delay = TimeInterval(0.5 * pow(2.0, Double(attempt - 1)))
                print("TLS error on attempt \(attempt)/\(maxAttempts), retrying in \(delay)s...")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? HTTPError.invalidResponse
    }
    
    /// Performs a GET request
    func get(url: URL, headers: [String: String]? = nil) async throws -> Data {
        return try await performWithRetry {
            var request = URLRequest(url: url)
            request.httpMethod = HTTPMethod.get.rawValue
            request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            headers?.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            let (data, response) = try await self.session.data(for: request)
            try self.handleResponse(response)
            return data
        }
    }
    
    /// Performs a POST request
    func post(url: URL, body: Data?, headers: [String: String]? = nil) async throws -> Data {
        return try await performWithRetry {
            var request = URLRequest(url: url)
            request.httpMethod = HTTPMethod.post.rawValue
            request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = body
            
            headers?.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            let (data, response) = try await self.session.data(for: request)
            try self.handleResponse(response)
            return data
        }
    }
    
    /// Performs a GET request and decodes the response as JSON dictionary
    func getJSON(url: URL, headers: [String: String]? = nil) async throws -> [String: Any] {
        let data = try await get(url: url, headers: headers)
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw HTTPError.invalidResponse
            }
            return json
        } catch let error as HTTPError {
            throw error
        } catch {
            throw HTTPError.decodingError(error)
        }
    }
    
    /// Performs a POST request with a JSON body
    func postJSON(url: URL, json: [String: Any], headers: [String: String]? = nil) async throws -> Data {
        var requestHeaders = headers ?? [:]
        requestHeaders["Content-Type"] = "application/json"
        
        let body: Data
        do {
            body = try JSONSerialization.data(withJSONObject: json)
        } catch {
            throw HTTPError.decodingError(error)
        }
        
        return try await post(url: url, body: body, headers: requestHeaders)
    }
    
    /// Performs a GET request and returns both data and response for custom status handling
    func getRaw(url: URL, headers: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        return (data, httpResponse)
    }
    
    /// Handles the HTTP response and throws appropriate errors
    private func handleResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw HTTPError.unauthorized
        case 429:
            throw HTTPError.rateLimited
        default:
            throw HTTPError.httpError(
                statusCode: httpResponse.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }
    }
}
