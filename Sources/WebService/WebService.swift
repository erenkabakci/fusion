//
//  WebService.swift
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

public class WebService: WebServiceExecutable, HttpHeaderModifiable {
  public var defaultHttpHeaders: [String : String] = [:]
  public let jsonDecoder: JSONDecoder = JSONDecoder()
  private let session: SessionPublisherProtocol

  public init(urlSession: SessionPublisherProtocol = URLSession(configuration: URLSessionConfiguration.ephemeral,
                                                                delegate: nil,
                                                                delegateQueue: nil)) {
    session = urlSession
  }

  public func execute(urlRequest: URLRequest) -> AnyPublisher<(data: Data, response: HTTPURLResponse), Error> {
    var urlRequest = urlRequest
    urlRequest.appendAdditionalHeaders(headers: self.defaultHttpHeaders)

    return Deferred {
      Future { promise in
        _ = self.session.dataTaskPublisher(request: urlRequest)
          .sink(receiveCompletion: {
            if case let .failure(error) = $0 {
              promise(.failure(error))
            }
          },
                receiveValue: { value in
                  guard let httpUrlResponse = value.response as? HTTPURLResponse else {
                    promise(.failure(FusionError.corruptMetaData))
                    return
                  }
                  promise(.success((value.data, httpUrlResponse)))
          })
      }
    }
    .receive(on: DispatchQueue.main)
    .eraseToAnyPublisher()
  }
}

private extension URLRequest {
  mutating func appendAdditionalHeaders(headers: [String : String]) {
    for (key, value) in headers {
      self.setValue(value, forHTTPHeaderField: key)
    }
  }
}
