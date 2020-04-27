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
    subscriptions = Set<AnyCancellable>()
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

  func test_givenAuthenticatedWebService_whenContinuousRequests_andTokenRefreshAttempts_thenShouldWaitForTokenRefreshing() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    let expectation1 = self.expectation(description: "parallel request test has failed")
    let expectation2 = self.expectation(description: "parallel request test has failed")

    tokenProvider.accessToken.send("invalidToken")
    session.result = ((Data(), 401), nil)

    func fireRequest2() {
        print("Request 2 started")
        self.webService.execute(urlRequest: request)
          .subscribe(on: DispatchQueue.global())
        .receive(on: DispatchQueue.main)
          .sink(receiveCompletion: {
            if case .finished = $0 {
              print("Request 2 finished")
            }
            else {
              XCTFail("should not receive failure since the token is refreshed")
            }
          },
                receiveValue: { (_: SampleResponse) in
                  print("Request 2 received value")
                  XCTAssertEqual(self.tokenProvider.methodCallStack, ["invalidateAccessToken()", "reissueAccessToken()"])
                  expectation2.fulfill()
          })
          .store(in: &self.subscriptions)
    }

    DispatchQueue.global().async {
      print("Request 1 started")
      self.webService.execute(urlRequest: request)
        .sink(receiveCompletion: {
          if case .finished = $0 {
            expectation1.fulfill()
            print("Request 1 finished")
            fireRequest2()
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
  var accessToken: CurrentValueSubject<AccessToken?, Never> = CurrentValueSubject(nil)
  var refreshToken: CurrentValueSubject<RefreshToken?, Never> = CurrentValueSubject(nil)

  func reissueAccessToken() -> AnyPublisher<AccessToken, Error> {
    // replicate a slow & asnyc token refresh
      sleep(2)
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
