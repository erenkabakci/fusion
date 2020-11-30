//
//  AuthenticatedWebServiceTests.swift
//  fusionTests
//
//  Copyright (c) 2020 Eren Kabakçı
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Combine
import XCTest
@testable import fusion

class AuthenticatedWebServiceTests: XCTestCase {
  private var session: MockAuthenticatedServiceSession!
  private var tokenProvider: MockTokenProvider!
  private var webService: AuthenticatedWebService!
  private var encoder = JSONEncoder()
  private var subscriptions = Set<AnyCancellable>()

  override func setUpWithError() throws {
    try super.setUpWithError()
    session = MockAuthenticatedServiceSession()
    tokenProvider = MockTokenProvider()
    webService = AuthenticatedWebService(urlSession: session,
                                         tokenProvider: tokenProvider)
    subscriptions = Set<AnyCancellable>()
  }

  func test_givenAuthenticatedWebService_whenAuthorizationHeaderSchemeNone_shouldAppendNoTokenPrefixHeader() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    webService = AuthenticatedWebService(urlSession: session,
                                         tokenProvider: tokenProvider)
    session.result = ((Data(), 200), nil)
    tokenProvider.accessToken.value = "someToken"
    let expectation = self.expectation(description: "No authorization header scheme test has failed")

    webService.execute(urlRequest: request)
      .sink(receiveCompletion: { _ in },
            receiveValue: { _ in
              XCTAssertEqual(self.session.finalUrlRequest?.allHTTPHeaderFields?["Authorization"], "someToken")
              expectation.fulfill()
            })
      .store(in: &subscriptions)

    waitForExpectations(timeout: 0.5)
  }

  func test_givenAuthenticatedWebService_whenAuthorizationHeaderSchemeBasic_shouldAppendBasicHeader() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    webService = AuthenticatedWebService(urlSession: session,
                                         tokenProvider: tokenProvider,
                                         configuration: AuthenticatedWebServiceConfiguration(authorizationHeaderScheme: .basic))
    session.result = ((Data(), 200), nil)
    tokenProvider.accessToken.value = "someToken"
    let expectation = self.expectation(description: "Basic authorization header scheme test has failed")

    webService.execute(urlRequest: request)
      .sink(receiveCompletion: { _ in },
            receiveValue: { _ in
              XCTAssertEqual(self.session.finalUrlRequest?.allHTTPHeaderFields?["Authorization"], "Basic someToken")
              expectation.fulfill()
            })
      .store(in: &subscriptions)

    waitForExpectations(timeout: 0.5)
  }

  func test_givenAuthenticatedWebService_whenAuthorizationHeaderSchemeBearer_shouldAppendBearerHeader() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    webService = AuthenticatedWebService(urlSession: session,
                                         tokenProvider: tokenProvider,
                                         configuration: AuthenticatedWebServiceConfiguration(authorizationHeaderScheme: .bearer))

    let encodedJSON = try! encoder.encode(["name": "value"])
    session.result = ((encodedJSON, 200), nil)
    tokenProvider.accessToken.value = "someToken"
    let expectation = self.expectation(description: "Bearer authorization header scheme test has failed")

    webService.execute(urlRequest: request)
      .sink(receiveCompletion: { _ in },
            receiveValue: { _ in
              XCTAssertEqual(self.session.finalUrlRequest?.allHTTPHeaderFields?["Authorization"], "Bearer someToken")
              expectation.fulfill()
            })
      .store(in: &subscriptions)

    waitForExpectations(timeout: 0.5)
  }

  func test_givenAuthenticatedWebService_whenNoAccessTokenPresent_thenShouldFailWithoutRetrying() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    let expectation = self.expectation(description: "No access token case faced an unexpected request retry")

    session.result = ((Data(), 200), nil)

    webService.execute(urlRequest: request)
      .mapHTTPStatusCodes()
      .sink(receiveCompletion: { if case let .failure(error as FusionError) = $0  {
        XCTAssertEqual(self.tokenProvider.methodCallStack, [])
        XCTAssertEqual(self.session.methodCallStack, [])
        XCTAssertEqual(error, .unauthorized())
        expectation.fulfill()
      } },
      receiveValue: { _ in
        XCTFail()
      })
      .store(in: &subscriptions)

    waitForExpectations(timeout: 0.5)
  }

  func test_givenAuthenticatedWebService_whenSimultaneousRequestsFired_thenShouldNotRaceForTokenRefresh() {
    func tokenRefreshedOnlyOnceOrLess() -> Bool {
      return tokenProvider.methodCallStack.filter { $0 == "reissueAccessToken" }.count <= 1 &&
        tokenProvider.methodCallStack.filter { $0 == "invalidateAccessToken" }.count <= 1
    }

    let request = URLRequest(url: URL(string: "foo.com")!)
    let expectation1 = self.expectation(description: "Simultaneous call-1 didn't finish with a refreshed value")
    let expectation2 = self.expectation(description: "Simultaneous call-2 didn't finish with a refreshed value")
    let expectation3 = self.expectation(description: "Simultaneous call-3 didn't finish with a refreshed value")

    // Initial state for the token provider and calls are returning 401
    session.result = ((Data(), 401), nil)
    tokenProvider.accessToken.value = "invalidToken"

    // After the first retry with the refresh token, new access token is issued and the calls start returning 2xx
    tokenProvider.accessToken
      .sink(receiveValue: {
        if $0 == "newToken" {
          self.session.result = ((Data(), 200), nil)
        }
      })
      .store(in: &subscriptions)

    webService.execute(urlRequest: request)
      .mapHTTPStatusCodes()
      .sink(receiveCompletion: {
        if case .failure = $0  {
          XCTFail("Did not refresh the access token and retried the call")
        } else {
          expectation1.fulfill()
        }
      },
      receiveValue: { _ in
        XCTAssertTrue(tokenRefreshedOnlyOnceOrLess())
      })
      .store(in: &subscriptions)

    webService.execute(urlRequest: request)
      .mapHTTPStatusCodes()
      .sink(receiveCompletion: {
        if case .failure = $0  {
          XCTFail("Did not refresh the access token and retried the call")
        } else {
          expectation2.fulfill()
        }
      },
      receiveValue: { _ in
        XCTAssertTrue(tokenRefreshedOnlyOnceOrLess())
      })
      .store(in: &subscriptions)

    webService.execute(urlRequest: request)
      .mapHTTPStatusCodes()
      .sink(receiveCompletion: {
        if case .failure = $0  {
          XCTFail("Did not refresh the access token and retried the call")
        } else {
          expectation3.fulfill()
        }
      },
      receiveValue: { _ in
        XCTAssertTrue(tokenRefreshedOnlyOnceOrLess())
      })
      .store(in: &subscriptions)

    waitForExpectations(timeout: 2)
  }

  func test_givenAuthenticatedWebService_whenConsecutiveRequestsFired_thenShouldRefreshOnlyOnce() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    let expectation1 = self.expectation(description: "Consecutive call-1 didn't finish with a refreshed value")
    let expectation2 = self.expectation(description: "Consecutive call-2 didn't finish with a refreshed value")
    let expectation3 = self.expectation(description: "Consecutive call-3 didn't finish with a refreshed value")

    // Initial state for the token provider and calls are returning 401
    session.result = ((Data(), 401), nil)
    tokenProvider.accessToken.value = "invalidToken"

    // After the first retry with the refresh token, new access token is issued and the calls start returning 2xx
    tokenProvider.accessToken
      .sink(receiveValue: {
        if $0 == "newToken" {
          self.session.result = ((Data(), 200), nil)
        }
      })
      .store(in: &subscriptions)

    webService.execute(urlRequest: request)
      .mapHTTPStatusCodes()
      .sink(receiveCompletion: {
        if case .failure = $0  {
          XCTFail("Did not refresh the access token and retried the call")
        } else {
          expectation1.fulfill()

          self.webService.execute(urlRequest: request)
            .mapHTTPStatusCodes()
            .sink(receiveCompletion: {
              if case .failure = $0  {
                XCTFail("Should not fail with a valid refreshed token response")
              } else {
                expectation2.fulfill()

                self.webService.execute(urlRequest: request)
                  .mapHTTPStatusCodes()
                  .sink(receiveCompletion: {
                    if case .failure = $0  {
                      XCTFail("Should not fail with a valid refreshed token response")
                    } else {
                      expectation3.fulfill()
                    }
                  },
                  receiveValue: { _ in
                    XCTAssertEqual(self.tokenProvider.methodCallStack, ["reissueAccessToken()", "invalidateAccessToken()"])
                    XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(request:)",
                                                                  "dataTaskPublisher(request:)",
                                                                  "dataTaskPublisher(request:)",
                                                                  "dataTaskPublisher(request:)"])
                  })
                  .store(in: &self.subscriptions)
              }
            },
            receiveValue: { _ in
              XCTAssertEqual(self.tokenProvider.methodCallStack, ["reissueAccessToken()", "invalidateAccessToken()"])
              XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(request:)",
                                                            "dataTaskPublisher(request:)",
                                                            "dataTaskPublisher(request:)"])
            })
            .store(in: &self.subscriptions)
        }
      },
      receiveValue: { _ in
        XCTAssertEqual(self.tokenProvider.methodCallStack, ["reissueAccessToken()", "invalidateAccessToken()"])
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(request:)",
                                                      "dataTaskPublisher(request:)"])
      })
      .store(in: &subscriptions)

    waitForExpectations(timeout: 0.5)
  }

  func test_givenAuthenticatedWebService_whenTokenIsNotRefreshed_thenShouldRefreshOnlyOnce_andFail() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    let expectation = self.expectation(description: "Refresh token failed to refresh but didn't result in error")

    tokenProvider.accessToken.value = "invalidToken"
    tokenProvider.tokenRefreshShouldFail = true
    session.result = ((Data(), 403), nil)

    webService.execute(urlRequest: request)
      .mapHTTPStatusCodes()
      .sink(receiveCompletion: { if case let .failure(error as FusionError) = $0  {
        XCTAssertEqual(self.tokenProvider.methodCallStack, ["reissueAccessToken()", "invalidateAccessToken()"])
        XCTAssertNil(self.tokenProvider.accessToken.value)
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(request:)"])
        XCTAssertEqual(error, .unauthorized())
        expectation.fulfill()
      } },
      receiveValue: { _ in
        XCTFail()
      })
      .store(in: &subscriptions)

    waitForExpectations(timeout: 0.5)
  }

  func test_givenAuthenticatedWebService_whenRefreshTriggerErrorsDontMatch_thenShouldNotAttemptTokenRefresh() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    let expectation = self.expectation(description: "No access token case faced an unexpected request retry")

    tokenProvider.accessToken.value = "validToken"
    session.result = ((Data(), 405), nil)

    webService.execute(urlRequest: request)
      .mapHTTPStatusCodes()
      .sink(receiveCompletion: { if case let .failure(error as FusionError) = $0,
                                    case let .generic(metadata: metadata) = error {
        XCTAssertEqual(self.tokenProvider.methodCallStack, [])
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(request:)"])
        XCTAssertEqual(error, .generic(metadata: metadata))
        expectation.fulfill()
      } },
      receiveValue: { _ in
        XCTFail()
      })
      .store(in: &subscriptions)

    waitForExpectations(timeout: 0.5)
  }
}

private class MockAuthenticatedServiceSession: MockSession {
  override func dataTaskPublisher(request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
    return super.dataTaskPublisher(request: request)
  }
}

private class MockTokenProvider: AuthenticationTokenProvidable {
  private let queue = DispatchQueue(label: "serialMethodCallStack.queue")
  private(set) var methodCallStack = [String]()
  var tokenRefreshShouldFail = false
  let accessToken: CurrentValueSubject<AccessToken?, Never> = CurrentValueSubject(nil)
  let refreshToken: CurrentValueSubject<RefreshToken?, Never> = CurrentValueSubject(nil)

  func reissueAccessToken() -> AnyPublisher<AccessToken, Error> {
    queue.async {
      self.methodCallStack.append(#function)
    }

    return Deferred {
      Future <AccessToken, Error> { promise in
        return self.tokenRefreshShouldFail ?
          promise(.failure(FusionError.unauthorized(metadata: nil))) :
        promise(.success("newToken"))
      }
    }
    .eraseToAnyPublisher()
  }

  func invalidateAccessToken() {
    accessToken.send(nil)
    queue.async {
      self.methodCallStack.append(#function)
    }
  }

  func invalidateRefreshToken() {
    queue.async {
      self.methodCallStack.append(#function)
    }
  }
}
