import XCTest
import Foundation
import CheckUpdate

final class CheckUpdateTests: XCTestCase {
    private func client() -> CheckUpdate {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LookupStub.self]
        return CheckUpdate(session: URLSession(configuration: configuration))
    }

    func testPublicResult() {
        let url = URL(string: "https://apps.apple.com/app/id1")!
        let result = LatestAppStoreVersion(version: "2.0", minimumOsVersion: "15.0", upgradeURL: url)
        XCTAssertEqual(result.version, "2.0")
        XCTAssertEqual(result.minimumOsVersion, "15.0")
        XCTAssertEqual(result.upgradeURL, url)
    }

    func testSuccessfulLookup() async throws {
        let result = try await client().getLatestAvailableVersion(for: "1")
        XCTAssertEqual(result?.version, "2.0")
        XCTAssertEqual(result?.minimumOsVersion, "15.0")
    }

    func testQueryValueCannotInjectASecondParameter() async throws {
        let result = try await client().getLatestAvailableVersion(for: "1&country=bad")
        XCTAssertEqual(result?.version, "2.0")
    }

    func testEmptyLookup() async throws {
        let result = try await client().getLatestAvailableVersion(for: "empty")
        XCTAssertNil(result)
    }

    func testHTTPError() async {
        do {
            _ = try await client().getLatestAvailableVersion(for: "http-error")
            XCTFail("Expected HTTP failure")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }

    func testMalformedJSON() async {
        do {
            _ = try await client().getLatestAvailableVersion(for: "malformed")
            XCTFail("Expected decode failure")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testUnsafeUpgradeURL() async {
        do {
            _ = try await client().getLatestAvailableVersion(for: "unsafe")
            XCTFail("Expected unsafe URL rejection")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badURL)
        }
    }

    @MainActor
    func testCancellationBeforeRequest() async {
        let task = Task { try await CheckUpdate().getLatestAvailableVersion(for: "1") }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled)
        }
    }
}

private final class LookupStub: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems ?? []
        let id = items.first(where: { $0.name == "id" })?.value ?? ""
        let status = id == "http-error" || items.count != 1 ? 500 : 200
        let upgradeURL = id == "unsafe" ? "javascript:alert(1)" : "https://apps.apple.com/app/id1"
        let body: String
        if id == "malformed" { body = "not-json" }
        else if id == "empty" { body = "{\"results\":[]}" }
        else { body = "{\"results\":[{\"version\":\"2.0\",\"minimumOsVersion\":\"15.0\",\"trackViewUrl\":\"\(upgradeURL)\"}]}" }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
