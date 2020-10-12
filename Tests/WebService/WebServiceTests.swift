//
//  WebServiceTests.swift
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

import XCTest
import Combine
@testable import fusion

class WebServiceTests: XCTestCase {
  private var session: MockSession!
  private var webService: WebService!
  private var subscriptions = Set<AnyCancellable>()
  private let encoder = JSONEncoder()

  override func setUpWithError() throws {
    super.setUp()
    session = MockSession()
    webService = WebService(urlSession: session)
  }

  func test_givenResponse_whenAdditionalHttpHeaders_thenAppendedAsDefault() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    webService.defaultHttpHeaders = ["key1": "value1", "key2": "value2"]

    _ = webService.execute(urlRequest: request)
      .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

    XCTAssertEqual(webService.defaultHttpHeaders, session.finalUrlRequest?.allHTTPHeaderFields)
    XCTAssertEqual(session.methodCallStack, ["dataTaskPublisher(request:)"])
  }

  func test_givenResponse_whenURLError_thenBubblesUpError() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    session.result = (nil, URLError(.timedOut))

    let expectation = self.expectation(description: "URLError test failed")

    webService.execute(urlRequest: request)
      .sink(receiveCompletion: { completion in
        if case let .failure(error as URLError) = completion {
          XCTAssertEqual(error, URLError(.timedOut))
          XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(request:)"])
          expectation.fulfill()
        }
      }, receiveValue: { _ in
        XCTFail("Should not return value")
      }).store(in: &subscriptions)

    waitForExpectations(timeout: 0.5)
  }

  func test_givenDeferredRequest_whenRetried_shouldExecuteAgain() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    session.result = (nil, URLError(.cancelled))

    let expectation = self.expectation(description: "Retriable execution test failed")

    webService.execute(urlRequest: request)
      .handleEvents(receiveCompletion: { (completion) in
        if case .failure = completion {
          self.session.result = ((Data(), 200), nil)
        }
      })
      .retry(1)
      .sink(receiveCompletion: { completion in
        if case .failure = completion {
          XCTFail("Should not fail after data before the retry")
        }
      }, receiveValue: { _ in
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(request:)", "dataTaskPublisher(request:)"])
        expectation.fulfill()
      })
      .store(in: &subscriptions)

    waitForExpectations(timeout: 0.5)
  }
}
