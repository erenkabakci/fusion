//
//  Publisher+DecodableTests.swift
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

class Publisher_DecodableTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUpWithError() throws {
    try super.setUpWithError()
  }

  func test_givenRawResponseStream_whenDecodedIntoCodable_thenShouldWrapResponseIntoCarrier() throws {
    let publisher = CurrentValueSubject<(data: Data, response: HTTPURLResponse), Error>(
      (data: try encoder.encode(["id": "foo"]),
       response: HTTPURLResponse(url: URL(string: "foo.com")!,
                                 statusCode: 205,
                                 httpVersion: nil,
                                 headerFields: nil)!))

    _ = publisher
      .decode(using: JSONDecoder())
      .sink {
        if case .failure = $0 {
          XCTFail("Should not complete with error")
        }
      } receiveValue: { (value: ResponseCarrier<SampleResponse>) in
        XCTAssertEqual(value.body, SampleResponse(id: "foo"))
        XCTAssertEqual(value.metadata.statusCode, 205 )
      }
  }

  func test_givenRawResponseStream_whenParsedAsData_thenShouldWrapResponseIntoCarrier() throws {
    let publisher = CurrentValueSubject<(data: Data, response: HTTPURLResponse), Error>(
      (data: try encoder.encode(["id": "foo"]),
       response: HTTPURLResponse(url: URL(string: "foo.com")!,
                                 statusCode: 399,
                                 httpVersion: nil,
                                 headerFields: nil)!))

    _ = publisher
      .decode(using: JSONDecoder())
      .sink {
        if case .failure = $0 {
          XCTFail("Should not complete with error")
        }
      } receiveValue: { (value: ResponseCarrier<Data>) in
        XCTAssertEqual(value.body, try! self.encoder.encode(["id": "foo"]))
        XCTAssertNotEqual(value.body, Data())
        XCTAssertEqual(value.metadata.statusCode, 399 )
      }
  }

  func test_givenRawResponseStream_whenDecoded_andFlattened_thenShouldReturnTypeOnly() throws {
    let publisher = CurrentValueSubject<(data: Data, response: HTTPURLResponse), Error>(
      (data: try encoder.encode(["id": "foo"]),
       response: HTTPURLResponse(url: URL(string: "foo.com")!,
                                 statusCode: 200,
                                 httpVersion: nil,
                                 headerFields: nil)!))

    _ = publisher
      .decode(using: JSONDecoder())
      .flatten()
      .sink {
        if case .failure = $0 {
          XCTFail("Should not complete with error")
        }
      } receiveValue: { (value: SampleResponse) in
        XCTAssertEqual(value, SampleResponse(id: "foo"))
      }
  }
}
