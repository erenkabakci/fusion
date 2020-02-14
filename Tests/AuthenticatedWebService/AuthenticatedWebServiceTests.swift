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
          self.session.result = ((encodedData, 200), nil)
        }
      }).store(in: &subscriptions)
  }

  func test_givenAuthenticatedWebService_whenAuthorizationHeaderSchemeBasic_shouldAppendBasicHeader() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    webService = AuthenticatedWebService(urlSession: session,
                                         tokenProvider: tokenProvider,
                                         authorizationHeaderScheme: .basic)
    session.result = ((Data(), 200), nil)
    tokenProvider.accessToken.value = "someToken"

    _ = webService.execute(urlRequest: request).sink(receiveCompletion: { _ in }, receiveValue: { _ in })

    XCTAssertEqual(session.finalUrlRequest?.allHTTPHeaderFields?["Authorization"], "Basic someToken")
  }

  func test_givenAuthenticatedWebService_whenAuthorizationHeaderSchemeBearer_shouldAppendBearerHeader() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    webService = AuthenticatedWebService(urlSession: session,
                                         tokenProvider: tokenProvider,
                                         authorizationHeaderScheme: .bearer)

    let encodedJSON = try! encoder.encode(["name": "value"])
    session.result = ((encodedJSON, 200), nil)
    tokenProvider.accessToken.value = "someToken"

    _ = webService.execute(urlRequest: request).sink(receiveCompletion: { _ in }, receiveValue: { (_: SampleResponse) in })

    XCTAssertEqual(session.finalUrlRequest?.allHTTPHeaderFields?["Authorization"], "Bearer someToken")
  }

  func test_givenAuthenticatedWebService_whenParallelRequestsFired_thenShouldNotRaceForTokenRefresh() {
    let testScheduler = TestScheduler(initialClock: 0)
    let request = URLRequest(url: URL(string: "foo.com")!)
    let expectation1 = self.expectation(description: "authentication stream test expectation1")
    let expectation2 = self.expectation(description: "authentication stream test expectation2")

    testScheduler.schedule(after: 100) {
      // Mimicking successful api response but no token case
      self.session.result = ((Data(), 200), nil)

      self.webService.execute(urlRequest: request)
        .sink(receiveCompletion: {
          if case let .failure(error as NetworkError) = $0 {
            XCTAssertEqual(error, NetworkError.unauthorized)
            XCTAssertEqual(self.tokenProvider.methodCallStack, [])
          }
        },
              receiveValue: { _ in
                XCTFail("No value should be received")
        })
        .store(in: &self.subscriptions)
      self.session.result = ((Data(), 401), nil)
    }

    testScheduler.schedule(after: 200) {
      // Demonstrate two parallel requests not racing each other to refresh the token
      self.tokenProvider.accessToken.value = "invalidToken"

      self.webService.execute(urlRequest: request)
        .sink(receiveCompletion: {
          if case .finished = $0 {
            expectation1.fulfill()
          }
          else {
            XCTFail("should not receive failure since the token is refreshed")
          }
        },
              receiveValue: { _ in
                XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()"])
        })
        .store(in: &self.subscriptions)

      self.webService.execute(urlRequest: request)
        .sink(receiveCompletion: {
          if case .finished = $0 {
            expectation2.fulfill()
          } else {
            XCTFail("should not receive failure since the token is refreshed")
          }
        },
              receiveValue: { (_: SampleResponse) in
                // Reissuing is called only once even though there are two parallel calls
                XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()"])
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
      (200, .input("invalidToken")),
      (200, .input(nil)),
      (200, .input("newToken"))]

    XCTAssertEqual(expected, subscriber.recordedOutput)
  }

  func test_givenAuthenticatedWebService_whenContinousRequestsFired_thenShouldNotRaceForTokenRefresh() {
    let testScheduler = TestScheduler(initialClock: 0)
    let request = URLRequest(url: URL(string: "foo.com")!)
    let expectation1 = self.expectation(description: "authentication stream test expectation1")
    let expectation2 = self.expectation(description: "authentication stream test expectation2")

    testScheduler.schedule(after: 100) {
      self.tokenProvider.accessToken.value = "invalidToken"
      self.session.result = ((Data(), 401), nil)
    }

    testScheduler.schedule(after: 200) {
      self.webService.execute(urlRequest: request)
        .sink(receiveCompletion: {
          if case .finished = $0 {
            expectation1.fulfill()
          } else {
            XCTFail("should not receive failure since the token is refreshed")
          }
        },
              receiveValue: { (_: SampleResponse) in
                // Reissuing is called only once even though there are two parallel calls
                XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()"])
        })
        .store(in: &self.subscriptions)
    }

    testScheduler.schedule(after: 220) {
      // Demonstrate two consecutive requests not racing each other to refresh the token
      self.tokenProvider.accessToken.value = "invalidToken2"

      self.webService.execute(urlRequest: request)
        .sink(receiveCompletion: {
          if case .finished = $0 {
            expectation2.fulfill()
          }
          else {
            XCTFail("should not receive failure since the token is refreshed")
          }
        },
              receiveValue: { _ in
                XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()"])
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
      (100, .input("invalidToken")),
      (200, .input(nil)),
      (200, .input("newToken")),
      (220, .input("invalidToken2")),]

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
  var accessToken: CurrentValueSubject<String?, Never> = CurrentValueSubject(nil)
  var refreshToken: CurrentValueSubject<String?, Never> = CurrentValueSubject(nil)

  func reissueAccessToken() {
    accessToken.send("newToken")
    methodCallStack.append(#function)
  }

  func invalidateAccessToken() {
    accessToken.send(nil)
    methodCallStack.append(#function)
  }

  func invalidateRefreshToken() {
    methodCallStack.append(#function)
  }
}
