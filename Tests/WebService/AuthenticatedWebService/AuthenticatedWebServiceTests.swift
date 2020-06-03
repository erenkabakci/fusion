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
import EntwineTest
@testable import fusion

class AuthenticatedWebServiceTests: XCTestCase {
  private var session: MockAuthenticatedServiceSession!
  private var tokenProvider: MockTokenProvider!
  private var webService: AuthenticatedWebService!
  private var subscriptions: Set<AnyCancellable>!
  private var encoder = JSONEncoder()

  override func setUp() {
    super.setUp()
    subscriptions = Set<AnyCancellable>()
    session = MockAuthenticatedServiceSession()
    tokenProvider = MockTokenProvider()
    webService = AuthenticatedWebService(urlSession: session,
                                         tokenProvider: tokenProvider)

    let encodedData = try! self.encoder.encode(["id": "value"])
    tokenProvider.accessToken
      .sink(receiveValue: {
        if $0 == "newToken" {
          self.session.result = ((encodedData, 200), nil)
        }
      }).store(in: &subscriptions)
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

  func test_givenAuthenticatedWebService_whenTimeoutWithInitialTokenlessState_andHavingInvalidToken_thenNextRequestShouldRefreshTokenOnce() {
    let testScheduler = TestScheduler(initialClock: 0)
    let request = URLRequest(url: URL(string: "foo.com")!, timeoutInterval: 10)
    let expectation1 = self.expectation(description: "authentication stream test expectation1")
    let expectation2 = self.expectation(description: "authentication stream test expectation2")

    testScheduler.schedule(after: 200) {
      DispatchQueue.global().asyncAfter(deadline: .now(), execute: {
        print("initial tokenless state")
        // Mimicking successful api response but no token case
        self.session.result = ((Data(), 200), nil)

        // First call should fail since there is no access token yet
        self.webService.execute(urlRequest: request)
          .receive(on: DispatchQueue.main)
          .sink(receiveCompletion: {
            if case let .failure(error as NetworkError) = $0 {
              XCTAssertEqual(error, NetworkError.timeout)
              XCTAssertEqual(self.tokenProvider.methodCallStack, [])
              expectation1.fulfill()
            }
          },
                receiveValue: { _ in
                  XCTFail("No value should be received")
          })
          .store(in: &self.subscriptions)
        self.session.result = ((Data(), 401), nil)
      })
    }
    // given second call, has an invalid token
    testScheduler.schedule(after: 400) {
      DispatchQueue.global().asyncAfter(deadline: .now() + 12, execute: {
        // Demonstrate two parallel requests not racing each other to refresh the token
        print("invalid token is set")
        self.tokenProvider.accessToken.value = "invalidToken"

        self.webService.execute(urlRequest: request)
          .receive(on: DispatchQueue.main)
          .sink(receiveCompletion: {
            if case .failure = $0 {
              XCTFail("should not receive failure since the token is refreshed")
            }
          },
                receiveValue: { _ in
                  XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()"])
                  expectation2.fulfill()
          })
          .store(in: &self.subscriptions)
      })
    }

    let subscriber = testScheduler.createTestableSubscriber(String?.self, Never.self)
    self.tokenProvider.accessToken.subscribe(subscriber)

    testScheduler.resume()

    waitForExpectations(timeout: 15)

    let expected: TestSequence<String?, Never> = [
      (0, .subscription),
      (0, .input(nil)),
      (400, .input("invalidToken")),
      (400, .input(nil)),
      (400, .input("newToken"))]

    XCTAssertEqual(expected, subscriber.recordedOutput)
  }

  func test_givenAuthenticatedWebService_whenContinousRequestsFired_thenShouldNotRaceForTokenRefresh() {
    let testScheduler = TestScheduler(initialClock: 0)
    let request = URLRequest(url: URL(string: "foo.com")!)
    let expectation3 = self.expectation(description: "authentication stream test expectation3")
    let expectation4 = self.expectation(description: "authentication stream test expectation4")

    testScheduler.schedule(after: 100) {
      self.tokenProvider.accessToken.value = "invalidToken"
      self.session.result = ((Data(), 401), nil)
    }

    // first call should refresh the token with a valid one and override the previously set invalid token
    testScheduler.schedule(after: 200) {
      DispatchQueue.global().asyncAfter(deadline: .now(), execute: {
      self.webService.execute(urlRequest: request)
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: {
          if case .failure = $0 {
            XCTFail("should not receive failure since the token is refreshed")
          }
        },
              receiveValue: { (_: SampleResponse) in
                // Reissuing is called only once even though there are two parallel calls
                XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()"])
                expectation3.fulfill()
                fireRequest2()
        })
        .store(in: &self.subscriptions)
      })
    }

    // second call should execute normally even if it has an invalid token, since the previous call is already refreshing the token for this one as well
    func fireRequest2() {
      DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: {
        // Demonstrate two consecutive requests not racing each other to refresh the token
        self.tokenProvider.accessToken.value = "invalidToken2"

        self.webService.execute(urlRequest: request)
          .receive(on: DispatchQueue.main)
          .sink(receiveCompletion: {
            if case .failure = $0 {
              XCTFail("should not receive failure since the token is refreshed")
            }
          },
                receiveValue: { _ in
                  XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()"])
                  expectation4.fulfill()
          })
          .store(in: &self.subscriptions)
      })
    }

    let subscriber = testScheduler.createTestableSubscriber(String?.self, Never.self)
    self.tokenProvider.accessToken.subscribe(subscriber)

    testScheduler.resume()

    waitForExpectations(timeout: 10)

    let expected: TestSequence<String?, Never> = [
      (0, .subscription),
      (0, .input(nil)),
      (100, .input("invalidToken")),
      (200, .input(nil)),
      (200, .input("newToken")),
      (200, .input("invalidToken2"))]

    XCTAssertEqual(expected, subscriber.recordedOutput)
  }

  func test_givenAuthenticatedWebService_whenRefreshTriggerErrorsDontMatch_thenShouldNotAttemptTokenRefresh() {
    let testScheduler = TestScheduler(initialClock: 0)
    let request = URLRequest(url: URL(string: "foo.com")!)
    let expectation1 = self.expectation(description: "authentication stream test expectation1")

    // AuthenticatedWebService triggers token refresh, if the thrown error `Network.unauthorized` is matching
    // to the provided `refreshTriggerErrors: [Error]` in the configuration body below
    webService = AuthenticatedWebService(urlSession: session,
                                         tokenProvider: tokenProvider,
                                         configuration: AuthenticatedWebServiceConfiguration(authorizationHeaderScheme: .basic,
                                                                                             refreshTriggerErrors: [NetworkError.corruptUrl]))
    self.session.result = ((Data(), 401), nil)

    testScheduler.schedule(after: 100) {
      self.tokenProvider.accessToken.value = "invalidToken"

      self.webService.execute(urlRequest: request)
        .sink(receiveCompletion: {
          if case let .failure(error as NetworkError) = $0 {
            XCTAssertEqual(error, NetworkError.unauthorized)
            XCTAssertEqual(self.tokenProvider.methodCallStack, [])
            expectation1.fulfill()
          }
        },
              receiveValue: { _ in
                XCTFail("No value should be received")
        })
        .store(in: &self.subscriptions)
    }

    let subscriber = testScheduler.createTestableSubscriber(String?.self, Never.self)
    self.tokenProvider.accessToken.subscribe(subscriber)

    testScheduler.resume()

    waitForExpectations(timeout: 2)

    let expected: TestSequence<String?, Never> = [
      (0, .subscription),
      (0, .input(nil)),
      (100, .input("invalidToken"))]

    XCTAssertEqual(expected, subscriber.recordedOutput)
  }
}

private class MockAuthenticatedServiceSession: MockSession {
  override func dataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
    // Replicate slow execution
    usleep(50)
    return super.dataTaskPublisher(for: request)
  }
}

private class MockTokenProvider: AuthenticationTokenProvidable {
  private(set) var methodCallStack = [String]()
  var accessToken: CurrentValueSubject<AccessToken?, Never> = CurrentValueSubject(nil)
  var refreshToken: CurrentValueSubject<RefreshToken?, Never> = CurrentValueSubject(nil)

  func reissueAccessToken() -> AnyPublisher<AccessToken, Error> {
    self.accessToken.send("newToken")
    self.methodCallStack.append(#function)

    return Deferred {
      Future <AccessToken, Error> { promise in
        promise(.success("newToken"))
      }
    }.eraseToAnyPublisher()
  }

  func invalidateAccessToken() {
    accessToken.send(nil)
    methodCallStack.append(#function)
  }

  func invalidateRefreshToken() {
    methodCallStack.append(#function)
  }
}
