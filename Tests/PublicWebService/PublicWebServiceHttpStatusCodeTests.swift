//
//  PublicWebServiceHttpStatusCodeTests.swift
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

class PublicWebServiceHttpStatusCodeTests: XCTestCase {
  private var session: MockSession!
  private var webService: PublicWebService!
  private var subscriptions = Set<AnyCancellable>()
  private let encoder = JSONEncoder()
  
  override func setUp() {
    super.setUp()
    session = MockSession()
    webService = PublicWebService(urlSession: session)
  }
  
  // MARK: Success Cases
  
  func test_givenTypedResponse_whenValidData_andStatusCode200_thenParsesSuccesfully() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    let encodedObject = try! encoder.encode(["id": "value"])
    session.result = ((encodedObject, 200), nil)
    
    let execution: AnyPublisher<SampleResponse, NetworkError> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "200 test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        XCTFail("Should not return error. \(error)")
      }
    }, receiveValue: {
      XCTAssertEqual($0.id, "value")
      XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
      expectation.fulfill()
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
  
  func test_givenEmptyResponse_whenValidData_andStatusCode200_thenParsesSuccesfully() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    let encodedObject = try! encoder.encode(["id": "value"])
    session.result = ((encodedObject, 200), nil)
    
    let execution: AnyPublisher<Void, NetworkError> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "200 test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        XCTFail("Should not return error. \(error)")
      }
    }, receiveValue: {
      XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
      expectation.fulfill()
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
    
  func test_givenTypedResponse_whenValidData_andStatusCode209_thenParsesSuccesfully() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    let encodedObject = try! encoder.encode(["id": "value"])
    session.result = ((encodedObject, 209), nil)
    
    let execution: AnyPublisher<SampleResponse, NetworkError> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "209 test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        XCTFail("Should not return error. \(error)")
      }
    }, receiveValue: {
      XCTAssertEqual($0.id, "value")
      XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
      expectation.fulfill()
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
  
  func test_givenEmptyResponse_whenValidData_andStatusCode209_thenParsesSuccesfully() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    let encodedObject = try! encoder.encode(["id": "value"])
    session.result = ((encodedObject, 209), nil)
    
    let execution: AnyPublisher<Void, NetworkError> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "209 test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        XCTFail("Should not return error. \(error)")
      }
    }, receiveValue: {
      XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
      expectation.fulfill()
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
  
  // MARK: Failure Cases
  
  func test_givenTypedResponse_whenStatusCode401_thenThrowsUnauthorized() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    session.result = ((Data(), 401), nil)
    
    let execution: AnyPublisher<SampleResponse, NetworkError> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "Unauthorized test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        XCTAssertEqual(error, NetworkError.unauthorized)
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
        expectation.fulfill()
      }
    }, receiveValue: { _ in
      XCTFail("Should not return value")
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
  
  func test_givenEmptyResponse_whenStatusCode401_thenThrowsUnauthorized() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    session.result = ((Data(), 401), nil)
    
    let execution: AnyPublisher<Void, NetworkError> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "Unauthorized test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        XCTAssertEqual(error, NetworkError.unauthorized)
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
        expectation.fulfill()
      }
    }, receiveValue: { _ in
      XCTFail("Should not return value")
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
  
  func test_givenTypedResponse_whenStatusCode403_thenThrowsForbidden() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    session.result = ((Data(), 403), nil)
    
    let execution: AnyPublisher<SampleResponse, NetworkError> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "Unauthorized test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        XCTAssertEqual(error, NetworkError.forbidden)
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
        expectation.fulfill()
      }
    }, receiveValue: { _ in
      XCTFail("Should not return value")
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
  
  func test_givenEmptyResponse_whenStatusCode403_thenThrowsForbidden() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    session.result = ((Data(), 403), nil)
    
    let execution: AnyPublisher<Void, NetworkError> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "Unauthorized test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        XCTAssertEqual(error, NetworkError.forbidden)
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
        expectation.fulfill()
      }
    }, receiveValue: { _ in
      XCTFail("Should not return value")
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
  
  func test_givenTypedResponse_whenOtherStatusCode_thenThrowsGenericError() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    session.result = ((Data(), 501), nil)
    
    let execution: AnyPublisher<SampleResponse, NetworkError> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "Generic error with status code test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        XCTAssertEqual(error, NetworkError.generic(501))
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
        expectation.fulfill()
      }
    }, receiveValue: { _ in
      XCTFail("Should not return value")
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
  
  func test_givenEmptyResponse_whenOtherStatusCode_thenThrowsGenericError() {
    let request = URLRequest(url: URL(string: "foo.com")!)
    session.result = ((Data(), 503), nil)
    
    let execution: AnyPublisher<SampleResponse, NetworkError> = webService.execute(urlRequest: request)
    let expectation = self.expectation(description: "Generic error with status code test failed")
    
    execution.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        XCTAssertEqual(error, NetworkError.generic(503))
        XCTAssertEqual(self.session.methodCallStack, ["dataTaskPublisher(for:)"])
        expectation.fulfill()
      }
    }, receiveValue: { _ in
      XCTFail("Should not return value")
    }).store(in: &subscriptions)
    
    waitForExpectations(timeout: 0.5)
  }
}
