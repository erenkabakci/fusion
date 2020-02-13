//
//  PublicWebServiceStreamTests.swift
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

class PublicWebServiceStreamTests: XCTestCase {
  private var session: MockSession!
  private var webService: PublicWebService!
  private var subscriptions = Set<AnyCancellable>()
  
  override func setUp() {
    super.setUp()
    session = MockSession()
    webService = PublicWebService(urlSession: session)
  }
  
  // Tests `Deferred` Future usage in the webService
  func test_givenRequest_whenFails_andTerminates_thenShouldBeRetriable() {
    let urlRequest = URLRequest(url: URL(string: "foo.com")!)
    let execution: AnyPublisher<Void, Error> = webService.execute(urlRequest: urlRequest)
    var callStack = [String]()
    let expectation = self.expectation(description: "retriable test failed")
    
    session.result = ((Data(), 400), nil)
    
    execution.retry(1).sink(receiveCompletion: { completion in
      if case .failure = completion {
        callStack.append("receivedFailure")
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)", "dataTaskPublisher(for:)"])
        XCTAssertEqual(callStack, ["receivedFailure"])
        expectation.fulfill()
      } else {
        XCTFail("Should not get a finished in completion")
      }
    }, receiveValue: { _ in
    XCTFail("Should not get a value")
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
  
  func test_givenRequest_whenReceivesValue_thenShouldTerminate() {
    let urlRequest = URLRequest(url: URL(string: "foo.com")!)
    let execution: AnyPublisher<Void, Error> = webService.execute(urlRequest: urlRequest)
    var callStack = [String]()
    let expectation = self.expectation(description: "retriable test failed")
    
    session.result = ((Data(), 200), nil)
    
    execution.sink(receiveCompletion: { completion in
      if case .finished = completion {
        callStack.append("receivedFinished")
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
        XCTAssertEqual(callStack, ["receivedValue", "receivedFinished"])
        expectation.fulfill()
      } else {
        XCTFail("Should not get a failure in completion")
      }
    }, receiveValue: { _ in
      callStack.append("receivedValue")
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
}
