//
//  Publisher+WebService.swift
//  fusion
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

public extension Publisher where Self.Output == (data: Data, response: HTTPURLResponse) {
  static var defaultStatusCodeMapping: ((HTTPURLResponse) throws -> Void) {
    return { response in
      switch response.statusCode {
        case 200 ... 399:
          break
        case 401:
          throw FusionError.unauthorized(metadata: response)
        case 403:
          throw FusionError.forbidden(metadata: response)
        default:
          throw FusionError.generic(metadata: response)
      }
    }
  }

  func mapHTTPStatusCodes(condition: @escaping ((HTTPURLResponse) throws -> Void) = defaultStatusCodeMapping) -> AnyPublisher<(data: Data, response: HTTPURLResponse), Error> {
    tryMap {
      try condition($0.response)
      return $0
    }
    .eraseToAnyPublisher()
  }

  func decode<T>(using decoder: JSONDecoder) -> AnyPublisher<ResponseCarrier<T>, Error> where T : Decodable {
    tryMap {
      guard let data = $0.data as? T else {
        return ResponseCarrier(body: try decoder.decode(T.self, from: $0.data), metadata: $0.response)
      }
      return ResponseCarrier(body: data, metadata: $0.response)
      }
    .eraseToAnyPublisher()
  }
}

public extension AnyPublisher where Self.Output: ResponseCarrierProtocol {
  func flatten() -> AnyPublisher<Output.T, Error> {
    tryMap{ $0.body }.eraseToAnyPublisher()
  }
}
