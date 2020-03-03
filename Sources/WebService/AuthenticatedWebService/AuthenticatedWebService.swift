//
//  AuthenticatedWebService.swift
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

public enum AuthorizationHeaderScheme: String {
  case basic = "Basic "
  case bearer = "Bearer "
  case none = ""
}

public struct AuthenticatedWebServiceConfiguration {
  let authorizationHeaderScheme: AuthorizationHeaderScheme
  let refreshTriggerErrors: [Error]

  public init(authorizationHeaderScheme: AuthorizationHeaderScheme = .none,
              refreshTriggerErrors: [Error] = [NetworkError.unauthorized]) {
    self.authorizationHeaderScheme = authorizationHeaderScheme
    self.refreshTriggerErrors = refreshTriggerErrors
  }
}

open class AuthenticatedWebService: WebService {
  private let authenticationQueue = DispatchQueue(label: "authentication.queue")
  private let tokenProvider: AuthenticationTokenProvidable
  private let configuration: AuthenticatedWebServiceConfiguration

  public init(urlSession: SessionPublisherProtocol = URLSession(configuration: URLSessionConfiguration.ephemeral,
                                                                delegate: nil,
                                                                delegateQueue: nil),
              tokenProvider: AuthenticationTokenProvidable,
              configuration: AuthenticatedWebServiceConfiguration = AuthenticatedWebServiceConfiguration()) {
    self.tokenProvider = tokenProvider
    self.configuration = configuration
    super.init(urlSession: urlSession)
  }
  
  override public func execute<T>(urlRequest: URLRequest) -> AnyPublisher<T, Error> where T : Decodable {
    var urlRequest = urlRequest
    var currentAccessToken: String?

    authenticationQueue.sync {
      currentAccessToken = self.tokenProvider.accessToken.value
    }
    
    guard let accessToken = currentAccessToken else {
      return Fail<T, Error>(error: NetworkError.unauthorized).eraseToAnyPublisher()
    }
    
    urlRequest.setValue(self.configuration.authorizationHeaderScheme.rawValue + accessToken, forHTTPHeaderField: "Authorization")
    
    return super.execute(urlRequest: urlRequest)
      .catch { [weak self] error -> AnyPublisher<T, Error> in
        guard let self = self else {
          return Fail<T, Error>(error: NetworkError.unknown).eraseToAnyPublisher()
        }

        if self.configuration.refreshTriggerErrors.contains(where: { return $0.reflectedString == error.reflectedString }){
          self.retrySynchronizedTokenRefresh()

          return self.execute(urlRequest: urlRequest)
            .delay(for: 0.2, scheduler: self.authenticationQueue)
            .eraseToAnyPublisher()
        }
        return Fail<T, Error>(error: error).eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }
  
  
  override public func execute(urlRequest: URLRequest) -> AnyPublisher<Void, Error> {
    var urlRequest = urlRequest
    var currentAccessToken: String?

    authenticationQueue.sync {
      currentAccessToken = self.tokenProvider.accessToken.value
    }

    guard let accessToken = currentAccessToken else {
      return Fail<Void, Error>(error: NetworkError.unauthorized).eraseToAnyPublisher()
    }
    
    urlRequest.setValue(self.configuration.authorizationHeaderScheme.rawValue + accessToken, forHTTPHeaderField: "Authorization")
    
    return super.execute(urlRequest: urlRequest)
      .catch { [weak self] error -> AnyPublisher<Void, Error> in
        guard let self = self else {
          return Fail<Void, Error>(error: NetworkError.unknown).eraseToAnyPublisher()
        }

        if self.configuration.refreshTriggerErrors.contains(where: { return $0.reflectedString == error.reflectedString }){
          self.retrySynchronizedTokenRefresh()

          return self.execute(urlRequest: urlRequest)
            .delay(for: 0.2, scheduler: self.authenticationQueue)
            .eraseToAnyPublisher()
        }
        return Fail<Void, Error>(error: error).eraseToAnyPublisher()
    }.eraseToAnyPublisher()
  }

  private func retrySynchronizedTokenRefresh() {
    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()

    authenticationQueue.sync(flags: .barrier) {
      self.tokenProvider.invalidateAccessToken()
      self.tokenProvider.reissueAccessToken()
        .sink(receiveCompletion: { _ in
          dispatchGroup.leave()
        },
              receiveValue: { _ in })
        .store(in: &self.subscriptions)
      dispatchGroup.wait()
    }
  }
}

public extension Error {
  var reflectedString: String {
    return String(reflecting: self)
  }
}
