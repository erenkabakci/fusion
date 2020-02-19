//
//  AsyncTokenRefreshTests.swift
//  fusionTests
//
//  Created by Eren Kabakci on 19.02.20.
//  Copyright © 2020 Eren Kabakci. All rights reserved.
//

import Combine
import XCTest
import EntwineTest
@testable import fusion

class AsyncTokenRefreshTests: XCTestCase {
    private var session: MockAuthenticatedServiceSession!
    private var tokenProvider: MockTokenProvider!
    private var webService: AuthenticatedWebService!
    private var subscriptions = Set<AnyCancellable>()
    private let encoder = JSONEncoder()

    override func setUp() {
        super.setUp()
        session = MockAuthenticatedServiceSession()
        tokenProvider = MockTokenProvider()
        webService = AuthenticatedWebService(urlSession: session,
                                             tokenProvider: tokenProvider)

        let encodedData = try! self.encoder.encode(["id": "value"])
        tokenProvider.accessToken
            .sink(receiveValue: {
                if $0 == "newToken" {
                    print("Change session response to 200")
                    self.session.result = ((encodedData, 200), nil)
                }
            }).store(in: &subscriptions)
    }

    func test_givenAuthenticatedWebService_whenParallelRequests_andTokenRefreshAttempts_thenShouldWaitForTokenRefreshing() {
        let request = URLRequest(url: URL(string: "foo.com")!)
        let expectation1 = self.expectation(description: "parallel reqeust test has failed")
        let expectation2 = self.expectation(description: "parallel reqeust test has failed")

        tokenProvider.accessToken.send("invalidToken")
        session.result = ((Data(), 401), nil)

        DispatchQueue.global(qos: .default).async {
            print("Request 1 started")
            self.webService.execute(urlRequest: request)
                .sink(receiveCompletion: {
                    if case .finished = $0 {
                        expectation1.fulfill()
                        print("Request 1 finished")
                    }
                    else {
                        XCTFail("should not receive failure since the token is refreshed")
                    }
                },
                      receiveValue: { _ in
                        print("Request 1 received value")
                        XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()", "invalidateAccessToken()", "reissueAccessToken()"])
                })
                .store(in: &self.subscriptions)
        }

        DispatchQueue.global(qos: .default).async {
            print("Request 2 started")
            self.webService.execute(urlRequest: request)
                .sink(receiveCompletion: {
                    if case .finished = $0 {
                        print("Request 2 finished")
                        expectation2.fulfill()
                    }
                    else {
                        XCTFail("should not receive failure since the token is refreshed")
                    }
                },
                      receiveValue: { (_: SampleResponse) in
                        print("Request 2 received value")
                        XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()", "invalidateAccessToken()", "reissueAccessToken()"])
                })
                .store(in: &self.subscriptions)
        }
        
        waitForExpectations(timeout: 5)
    }

    func test_givenAuthenticatedWebService_whenContinuousRequests_andTokenRefreshAttempts_thenShouldWaitForTokenRefreshing() {
        let request = URLRequest(url: URL(string: "foo.com")!)
        let expectation1 = self.expectation(description: "parallel reqeust test has failed")
        let expectation2 = self.expectation(description: "parallel reqeust test has failed")

        tokenProvider.accessToken.send("invalidToken")
        session.result = ((Data(), 401), nil)

        DispatchQueue.global(qos: .default).async {
            print("Request 1 started")
            self.webService.execute(urlRequest: request)
                .sink(receiveCompletion: {
                    if case .finished = $0 {
                        expectation1.fulfill()
                        print("Request 1 finished")
                    }
                    else {
                        XCTFail("should not receive failure since the token is refreshed")
                    }
                },
                      receiveValue: { _ in
                        print("Request 1 received value")
                        XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()"])
                })
                .store(in: &self.subscriptions)
        }

        DispatchQueue.global(qos: .default).async {
            sleep(1)
            print("Request 2 started")
            self.webService.execute(urlRequest: request)
                .sink(receiveCompletion: {
                    if case .finished = $0 {
                        print("Request 2 finished")
                        expectation2.fulfill()
                    }
                    else {
                        XCTFail("should not receive failure since the token is refreshed")
                    }
                },
                      receiveValue: { (_: SampleResponse) in
                        print("Request 2 received value")
                        XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()"])
                })
                .store(in: &self.subscriptions)
        }

        waitForExpectations(timeout: 5)
    }
}

private class MockAuthenticatedServiceSession: MockSession {
    override func dataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        return super.dataTaskPublisher(for: request)
    }
}

private class MockTokenProvider: AuthenticationTokenProvidable {
    private(set) var methodCallStack = [String]()
    var accessToken: CurrentValueSubject<String?, Never> = CurrentValueSubject(nil)
    var refreshToken: CurrentValueSubject<String?, Never> = CurrentValueSubject(nil)

    func reissueAccessToken() -> AnyPublisher<Never, Error> {
        let asyncRefreshStream = PassthroughSubject<Never, Error>()

        // replicate a slow & asnyc token refresh
        DispatchQueue.global(qos: .default).async {
            sleep(2)
            self.accessToken.send("newToken")
            asyncRefreshStream.send(completion: .finished)
            self.methodCallStack.append(#function)
        }

        return asyncRefreshStream.eraseToAnyPublisher()
    }

    func invalidateAccessToken() {
        accessToken.send(nil)
        methodCallStack.append(#function)
    }

    func invalidateRefreshToken() {
        methodCallStack.append(#function)
    }
}
