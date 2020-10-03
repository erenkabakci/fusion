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
  let refreshTriggerErrors: [FusionError]

  public init(authorizationHeaderScheme: AuthorizationHeaderScheme = .none,
              refreshTriggerErrors: [FusionError] = [FusionError.unauthorized()]) {
    self.authorizationHeaderScheme = authorizationHeaderScheme
    self.refreshTriggerErrors = refreshTriggerErrors
  }
}

public final class AuthenticatedWebService: WebService {
  private let authenticationQueue = DispatchQueue(label: "com.fusion.authentication.queue")
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

  public override func execute(urlRequest: URLRequest) -> AnyPublisher<(data: Data, response: HTTPURLResponse), Error> {
    var urlRequest = urlRequest

    func appendTokenAndExecute(accessToken: AccessToken) -> AnyPublisher<(data: Data, response: HTTPURLResponse), Error> {
      urlRequest.setValue(self.configuration.authorizationHeaderScheme.rawValue + accessToken, forHTTPHeaderField: "Authorization")
      return super.execute(urlRequest: urlRequest).eraseToAnyPublisher()
    }

    return Deferred {
      self.tokenProvider.accessToken
        .compactMap { $0 }
        .setFailureType(to: Error.self)
        .flatMap { accessToken -> AnyPublisher<(data: Data, response: HTTPURLResponse), Error> in
          return appendTokenAndExecute(accessToken: accessToken)
        }
    }
    .catch { error -> AnyPublisher<(data: Data, response: HTTPURLResponse), Error> in
      if self.configuration.refreshTriggerErrors.contains(where: { return $0 == error as? FusionError }){
        return self.retrySynchronizedTokenRefresh()
          .flatMap {
            appendTokenAndExecute(accessToken: $0)
          }
          .eraseToAnyPublisher()
      }
      return Fail<(data: Data, response: HTTPURLResponse), Error>(error: error).eraseToAnyPublisher()
    }
    .eraseToAnyPublisher()
  }

  private func retrySynchronizedTokenRefresh() -> AnyPublisher<AccessToken, Error> {
    tokenProvider.invalidateAccessToken()
    return tokenProvider.reissueAccessToken().eraseToAnyPublisher()
  }
}
