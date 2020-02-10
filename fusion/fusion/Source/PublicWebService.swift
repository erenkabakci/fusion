//
//  PublicWebService.swift
//  fusion
//
//  Created by Eren Kabakci on 2/10/20.
//  Copyright © 2020 Eren Kabakci. All rights reserved.
//

import Combine
import Foundation

open class PublicWebService: WebServiceExecutable, StatusCodeResolvable, CustomDecodable {
  public let jsonDecoder: JSONDecoder = JSONDecoder()
  private let session: SessionPublisherProtocol
  open var subscriptions = Set<AnyCancellable>()

  public init(urlSession: SessionPublisherProtocol = URLSession(configuration: URLSessionConfiguration.ephemeral,
                                                                delegate: nil,
                                                                delegateQueue: nil)) {
    session = urlSession
  }

  public func execute<T>(urlRequest: URLRequest) -> AnyPublisher<T, NetworkError> where T : Decodable {
    Deferred {
      Future { [weak self] promise in
        guard let self = `self` else {
          promise(.failure(NetworkError.unknown))
          return
        }

        self.session.dataTaskPublisher(for: urlRequest)
          .tryMap {
            guard let httpResponse = $0.response as? HTTPURLResponse else {
              throw NetworkError.unknown
            }
            try self.mapHttpResponseCodes(httpResponse: httpResponse)
            return try self.decode(data: $0.data, type: T.self)
        }
        .sink(receiveCompletion: { (completion: Subscribers.Completion<Error>) in
          if case let .failure(networkError as NetworkError) = completion {
            promise(.failure(networkError))
          }
        },
              receiveValue: { promise(.success($0)) })
          .store(in: &self.subscriptions)
      }
    }.eraseToAnyPublisher()
  }

  public func execute(urlRequest: URLRequest) -> AnyPublisher<Void, NetworkError> {
    Deferred {
      Future { [weak self] promise in
        guard let self = `self` else {
          promise(.failure(NetworkError.unknown))
          return
        }

        self.session.dataTaskPublisher(for: urlRequest)
          .tryMap {
            guard let httpResponse = $0.response as? HTTPURLResponse else {
              throw NetworkError.unknown
            }
            try self.mapHttpResponseCodes(httpResponse: httpResponse)
            return
        }
        .sink(receiveCompletion: { (completion: Subscribers.Completion<Error>) in
          if case let .failure(networkError as NetworkError) = completion {
            promise(.failure(networkError))
          }
        },
              receiveValue: { promise(.success($0)) })
          .store(in: &self.subscriptions)
      }
    }.eraseToAnyPublisher()
  }

  public func mapHttpResponseCodes(httpResponse: HTTPURLResponse) throws {
    switch httpResponse.statusCode {
      case 200 ... 299:
        break
      case 401:
        throw NetworkError.unauthorized
      case 403:
        throw NetworkError.forbidden
      default:
        throw NetworkError.generic(httpResponse.statusCode)
    }
  }

  public func decode<T>(data: Data, type _: T.Type) throws -> T where T : Decodable {
    do {
      return try jsonDecoder.decode(T.self, from: data)
    } catch {
      throw NetworkError.parsingFailure
    }
  }
}
