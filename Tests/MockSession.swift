//
//  MockSession.swift
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
import Foundation
@testable import fusion

open class MockSession: SessionPublisherProtocol {
  public typealias StatusCode = Int
  open var result: ((Data, StatusCode)?, URLError?)?
  private(set) var methodCallStack: [String] = []
  private(set) var finalUrlRequest: URLRequest?
  
  public func dataTaskPublisher(for urlRequest: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
    methodCallStack.append(#function)
    finalUrlRequest = urlRequest
    return Deferred {
      Future<(data: Data, response: URLResponse), Error> { promise in
        usleep(20)
        if let successResponse = self.result?.0 {
          promise(.success((successResponse.0,
                            HTTPURLResponse(url: URL(string: "foo.com")!,
                                            statusCode: successResponse.1,
                                            httpVersion: nil,
                                            headerFields: nil)!)))
        } else if let errorResponse = self.result?.1 {
          promise(.failure(NetworkError.urlError(errorResponse)))
        }
      }
    }.eraseToAnyPublisher()
  }
}
