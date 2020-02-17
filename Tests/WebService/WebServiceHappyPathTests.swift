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

import Combine
import XCTest
@testable import fusion

class WebServiceHappyPathTests: XCTestCase {
  private var session: MockSession!
  private var webService: WebService!
  private var subscriptions = Set<AnyCancellable>()
  private let encoder = JSONEncoder()
  
  override func setUp() {
    super.setUp()
    session = MockSession()
    webService = WebService(urlSession: session)
  }
  
  // MARK: Success Cases
  
  func test_givenTypedResponse_whenAdditionalHttpHeaders_thenAppendedAsDefault() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    webService.defaultHttpHeaders = ["key1": "value1", "key2": "value2"]
    
    let execution: AnyPublisher<SampleResponse, Error> = webService.execute(urlRequest: request)
    _ = execution.sink(receiveCompletion: { _ in }, receiveValue: { _ in })
    
    XCTAssertEqual(webService.defaultHttpHeaders, session.finalUrlRequest?.allHTTPHeaderFields)
    XCTAssertEqual(session.methodCallStack, ["dataTaskPublisher(for:)"])
  }
  
  func test_givenEmptyResponse_wehnAdditionalHttpHeaders_thenAppendedAsDefault() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    webService.defaultHttpHeaders = ["key3": "value3", "key4": "value4"]
    
    let execution: AnyPublisher<Void, Error> = webService.execute(urlRequest: request)
    _ = execution.sink(receiveCompletion: { _ in }, receiveValue: { _ in })
    
    XCTAssertEqual(webService.defaultHttpHeaders, session.finalUrlRequest?.allHTTPHeaderFields)
    XCTAssertEqual(session.methodCallStack, ["dataTaskPublisher(for:)"])
  }
  
  // MARK: Failure Cases
  
  func test_givenTypedResponse_whenURLError_thenFailsWithURLError() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    session.result = (nil, URLError(.timedOut))
    
    let execution: AnyPublisher<SampleResponse, Error> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "URLError test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error as NetworkError) = completion {
        XCTAssertEqual(error, NetworkError.urlError(URLError(.timedOut)))
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
        expectation.fulfill()
      }
    }, receiveValue: { _ in
      XCTFail("Should not return value")
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
  
  func test_givenEmptyResponse_whenURLError_thenFailsWithURLError() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    session.result = (nil, URLError(.timedOut))
    
    let execution: AnyPublisher<Void, Error> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "URLError test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error as NetworkError) = completion {
        XCTAssertEqual(error, NetworkError.urlError(URLError(.timedOut)))
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
        expectation.fulfill()
      }
    }, receiveValue: { _ in
      XCTFail("Should not return value")
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
  
  func test_givenTypedResponse_whenInvalidJSON_thenFailsWithParsingError() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    let encodedJSON = try! encoder.encode(["name": "value"])
    session.result = ((encodedJSON, 201), nil)
    
    let execution: AnyPublisher<SampleResponse, Error> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "URLError test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error as NetworkError) = completion {
        XCTAssertEqual(error, NetworkError.parsingFailure)
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
        expectation.fulfill()
      }
    }, receiveValue: { _ in
      XCTFail("Should not return value")
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
}
