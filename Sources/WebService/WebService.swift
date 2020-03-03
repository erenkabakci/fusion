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

open class WebService:
  WebServiceExecutable,
  HttpHeaderModifiable,
  RawResponseRepresentable,
  StatusCodeResolvable,
CustomDecodable{
  public var defaultHttpHeaders: [String : String] = [:]
  public let jsonDecoder: JSONDecoder = JSONDecoder()
  private let session: SessionPublisherProtocol
  @ThreadSafe open var subscriptions = Set<AnyCancellable>()
  
  public init(urlSession: SessionPublisherProtocol = URLSession(configuration: URLSessionConfiguration.ephemeral,
                                                                delegate: nil,
                                                                delegateQueue: nil)) {
    session = urlSession
  }

  public func rawResponse(urlRequest: URLRequest) -> AnyPublisher<(data: Data, response: HTTPURLResponse), Error> {
    session.dataTaskPublisher(for: urlRequest)
      .flatMap { output -> AnyPublisher<(data: Data, response: HTTPURLResponse), Error> in
        guard let httpResponse = output.response as? HTTPURLResponse else {
          return Fail(error: NetworkError.unknown).eraseToAnyPublisher()
        }
        return CurrentValueSubject((output.data, httpResponse)).eraseToAnyPublisher()
    }.eraseToAnyPublisher()
  }
  
  public func execute<T>(urlRequest: URLRequest) -> AnyPublisher<T, Error> where T : Decodable {
    Deferred {
      Future { [weak self] promise in
        guard let self = self else {
          promise(.failure(NetworkError.unknown))
          return
        }

        var urlRequest = urlRequest
        urlRequest.appendAdditionalHeaders(headers: self.defaultHttpHeaders)
        
        self.rawResponse(urlRequest: urlRequest)
          .tryMap {
            try self.mapHttpResponseCodes(output: $0)

            if let data = $0.data as? T {
              return data
            }
            return try self.decode(data: $0.data, type: T.self)
        }
        .sink(receiveCompletion: {
          if case let .failure(error) = $0 {
            promise(.failure(error))
          }
        },
              receiveValue: { promise(.success($0)) })
          .store(in: &self.subscriptions)
      }
    }.eraseToAnyPublisher()
  }
  
  public func execute(urlRequest: URLRequest) -> AnyPublisher<Void, Error> {
    Deferred {
      Future { [weak self] promise in
        guard let self = self else {
          promise(.failure(NetworkError.unknown))
          return
        }
        
        var urlRequest = urlRequest
        urlRequest.appendAdditionalHeaders(headers: self.defaultHttpHeaders)
        
        self.rawResponse(urlRequest: urlRequest)
          .tryMap {
            try self.mapHttpResponseCodes(output: $0)
            return
        }
        .sink(receiveCompletion: {
          if case let .failure(error) = $0 {
            promise(.failure(error))
          }
        },
              receiveValue: { promise(.success($0)) })
          .store(in: &self.subscriptions)
      }
    }.eraseToAnyPublisher()
  }

  open func mapHttpResponseCodes(output: (data:Data, response: HTTPURLResponse)) throws {
    switch output.response.statusCode {
    case 200 ... 399:
      break
    case 401:
      throw NetworkError.unauthorized
    case 403:
      throw NetworkError.forbidden
    default:
      throw NetworkError.generic(output.response.statusCode)
    }
  }

  open func decode<T>(data: Data, type _: T.Type) throws -> T where T : Decodable {
    do {
      return try jsonDecoder.decode(T.self, from: data)
    } catch {
      throw NetworkError.parsingFailure
    }
  }
}

private extension URLRequest {
  mutating func appendAdditionalHeaders(headers: [String : String]) {
    for (key, value) in headers {
      self.setValue(value, forHTTPHeaderField: key)
    }
  }
}
