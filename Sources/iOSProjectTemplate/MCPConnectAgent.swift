import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - MCPConnectAgent

/// Interfaces with the MCP (Model Context Protocol) agent to create Jira bugs
/// from crash reports automatically.
public struct MCPConnectAgent {

    // MARK: - Configuration

    public struct Configuration {
        /// Base URL of the MCP server (e.g. "https://mcp.example.com")
        public let serverURL: URL
        /// Bearer token for authentication
        public let authToken: String
        /// Jira project key (e.g. "IOS")
        public let jiraProjectKey: String
        /// Jira issue type (default: "Bug")
        public let issueType: String

        public init(
            serverURL: URL,
            authToken: String,
            jiraProjectKey: String,
            issueType: String = "Bug"
        ) {
            self.serverURL = serverURL
            self.authToken = authToken
            self.jiraProjectKey = jiraProjectKey
            self.issueType = issueType
        }
    }

    // MARK: - Jira Bug payload

    public struct JiraBug: Encodable {
        public let projectKey: String
        public let summary: String
        public let description: String
        public let issueType: String
        public let priority: String
        public let labels: [String]

        public init(
            projectKey: String,
            summary: String,
            description: String,
            issueType: String = "Bug",
            priority: String = "High",
            labels: [String] = []
        ) {
            self.projectKey = projectKey
            self.summary = summary
            self.description = description
            self.issueType = issueType
            self.priority = priority
            self.labels = labels
        }
    }

    // MARK: - Result

    public struct JiraBugResult {
        public let issueKey: String
        public let issueURL: String
        public let summary: String
    }

    // MARK: - Stored configuration

    private let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    // MARK: - Public API

    /// Build a `JiraBug` from a `CrashInfo` and submit it to the MCP agent.
    /// - Returns: A `JiraBugResult` on success.
    /// - Throws: An error if the network call fails or the server returns a non-2xx status.
    @discardableResult
    public func createJiraBug(from crashInfo: CrashInfo) async throws -> JiraBugResult {
        let bug = JiraBug(
            projectKey: configuration.jiraProjectKey,
            summary: "[\(crashInfo.appVersion)] Crash – \(crashInfo.signalName): \(crashInfo.reason)",
            description: crashInfo.description,
            issueType: configuration.issueType,
            priority: "High",
            labels: ["crash", "auto-generated", crashInfo.signalName.lowercased()]
        )
        return try await submitBug(bug)
    }

    /// Submit an arbitrary `JiraBug` to the MCP agent.
    @discardableResult
    public func submitBug(_ bug: JiraBug) async throws -> JiraBugResult {
        let endpoint = configuration.serverURL
            .appendingPathComponent("mcp")
            .appendingPathComponent("jira")
            .appendingPathComponent("create-issue")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(bug)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPConnectError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw MCPConnectError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        // Decode minimal fields the MCP agent echoes back
        struct ResponsePayload: Decodable {
            let issueKey: String
            let issueURL: String
        }
        let payload = try JSONDecoder().decode(ResponsePayload.self, from: data)
        let result = JiraBugResult(
            issueKey: payload.issueKey,
            issueURL: payload.issueURL,
            summary: bug.summary
        )
        print("🐛  Jira bug created: \(result.issueKey) — \(result.issueURL)")
        return result
    }

    // MARK: - Dry-run (no network)

    /// Simulate bug creation without hitting the network. Useful for testing.
    public func dryRunCreateJiraBug(from crashInfo: CrashInfo) -> JiraBugResult {
        let fakeKey = "\(configuration.jiraProjectKey)-\(Int.random(in: 1000...9999))"
        let result = JiraBugResult(
            issueKey: fakeKey,
            issueURL: "https://jira.example.com/browse/\(fakeKey)",
            summary: "[\(crashInfo.appVersion)] Crash – \(crashInfo.signalName): \(crashInfo.reason)"
        )
        print("🐛  [DRY RUN] Jira bug would be created: \(result.issueKey) — \(result.issueURL)")
        return result
    }
}

// MARK: - MCPConnectError

public enum MCPConnectError: Error, CustomStringConvertible {
    case invalidResponse
    case httpError(statusCode: Int, body: String)

    public var description: String {
        switch self {
        case .invalidResponse:
            return "MCPConnectAgent: Received an invalid (non-HTTP) response."
        case let .httpError(code, body):
            return "MCPConnectAgent: HTTP \(code) — \(body)"
        }
    }
}
