//
//  Publisher+HTTPStatusCodeMappingTests.swift
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

class Publisher_HTTPStatusCodeMappingTests: XCTestCase {

  override func setUpWithError() throws {
    try super.setUpWithError()
  }

  func test_givenRawResponseStream_when2xxAnd3xx_andDefaultHTTPStatusCodeMapping_thenReturnsMappedChainableResponse() throws {
    let publisher1 = CurrentValueSubject<(data: Data, response: HTTPURLResponse), Error>(
      (data: Data(),
       response: HTTPURLResponse(url: URL(string: "foo.com")!,
                                 statusCode: 205,
                                 httpVersion: nil,
                                 headerFields: nil)!))

    let publisher2 = CurrentValueSubject<(data: Data, response: HTTPURLResponse), Error>(
      (data: Data(),
       response: HTTPURLResponse(url: URL(string: "foo.com")!,
                                 statusCode: 310,
                                 httpVersion: nil,
                                 headerFields: nil)!))
    _ = publisher1
      .mapHTTPStatusCodes()
      .sink {
        if case .failure = $0 {
          XCTFail("Should not complete with error")
        }
      } receiveValue: { value in
              XCTAssert(value.data == Data())
              XCTAssert(value.response.statusCode == 205)
      }

    _ = publisher2
      .mapHTTPStatusCodes()
      .sink {
        if case .failure = $0 {
          XCTFail("Should not complete with error")
        }
      } receiveValue: { value in
              XCTAssert(value.data == Data())
              XCTAssert(value.response.statusCode == 310)
      }
  }

  func test_givenRawResponseStream_when401_andDefaultHTTPStatusCodeMapping_thenReturnsMappedChainableResponse_andUnauthorized() throws {
    let publisher = CurrentValueSubject<(data: Data, response: HTTPURLResponse), Error>(
      (data: Data(),
       response: HTTPURLResponse(url: URL(string: "foo.com")!,
                                 statusCode: 401,
                                 httpVersion: nil,
                                 headerFields: nil)!))

    _ = publisher
      .mapHTTPStatusCodes()
      .sink {
        if case let .failure(error as FusionError) = $0 {
          if case let FusionError.unauthorized(metadata: metadata) = error {
            XCTAssert(metadata?.url == URL(string: "foo.com")!)
            XCTAssert(metadata?.statusCode == 401)
          }
        } else {
            XCTFail("Should not finish without an error")
        }
      } receiveValue: { value in
          XCTFail("Should not receive value")
      }
  }

  func test_givenRawResponseStream_when403_andDefaultHTTPStatusCodeMapping_thenReturnsMappedChainableResponse_andForbidden() throws {
    let publisher = CurrentValueSubject<(data: Data, response: HTTPURLResponse), Error>(
      (data: Data(),
       response: HTTPURLResponse(url: URL(string: "foo.com")!,
                                 statusCode: 403,
                                 httpVersion: nil,
                                 headerFields: nil)!))

    _ = publisher
      .mapHTTPStatusCodes()
      .sink {
        if case let .failure(error as FusionError) = $0 {
          if case let FusionError.forbidden(metadata: metadata) = error {
            XCTAssert(metadata?.url == URL(string: "foo.com")!)
            XCTAssert(metadata?.statusCode == 403)
          }
        } else {
            XCTFail("Should not finish without an error")
        }
      } receiveValue: { value in
          XCTFail("Should not receive value")
      }
  }

  func test_givenRawResponseStream_when4xxAnd5xx_andDefaultHTTPStatusCodeMapping_thenReturnsMappedChainableResponse_andGenericError() throws {
    let publisher1 = CurrentValueSubject<(data: Data, response: HTTPURLResponse), Error>(
      (data: Data(),
       response: HTTPURLResponse(url: URL(string: "foo.com")!,
                                 statusCode: 450,
                                 httpVersion: nil,
                                 headerFields: nil)!))

    let publisher2 = CurrentValueSubject<(data: Data, response: HTTPURLResponse), Error>(
      (data: Data(),
       response: HTTPURLResponse(url: URL(string: "foo.com")!,
                                 statusCode: 503,
                                 httpVersion: nil,
                                 headerFields: nil)!))

    _ = publisher1
      .mapHTTPStatusCodes()
      .sink {
        if case let .failure(error as FusionError) = $0 {
          if case let FusionError.generic(metadata: metadata) = error {
            XCTAssert(metadata.url == URL(string: "foo.com")!)
            XCTAssert(metadata.statusCode == 450)
          }
        } else {
            XCTFail("Should not finish without an error")
        }
      } receiveValue: { value in
          XCTFail("Should not receive value")
      }

    _ = publisher2
      .mapHTTPStatusCodes()
      .sink {
        if case let .failure(error as FusionError) = $0 {
          if case let FusionError.generic(metadata: metadata) = error {
            XCTAssert(metadata.url == URL(string: "foo.com")!)
            XCTAssert(metadata.statusCode == 503)
          }
        } else {
            XCTFail("Should not finish without an error")
        }
      } receiveValue: { value in
          XCTFail("Should not receive value")
      }
  }

  func test_givenRawResponseStream_whenCustomHTTPStatusCodeMapping_thenReturnsMappedChainableResponse() throws {
    let publisher = CurrentValueSubject<(data: Data, response: HTTPURLResponse), Error>(
      (data: Data(),
       response: HTTPURLResponse(url: URL(string: "foo.com")!,
                                 statusCode: 403,
                                 httpVersion: nil,
                                 headerFields: nil)!))

    _ = publisher
      .mapHTTPStatusCodes(condition: { response in
        throw FusionError.corruptMetaData
      })
      .sink {
        if case .failure = $0 {
          XCTAssert(true)
        } else {
            XCTFail("Should not finish without an error")
        }
      } receiveValue: { value in
          XCTFail("Should not receive value")
      }
  }
}
