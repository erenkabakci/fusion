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

open class AuthenticatedWebService: PublicWebService {
  private let authenticationQueue = DispatchQueue(label: "authentication.queue", attributes: .concurrent)
  private let tokenProvider: AuthenticationTokenProvidable
  
  init(urlSession: SessionPublisherProtocol = URLSession(configuration: URLSessionConfiguration.ephemeral,
                                                         delegate: nil,
                                                         delegateQueue: nil),
       tokenProvider: AuthenticationTokenProvidable) {
    self.tokenProvider = tokenProvider
    super.init(urlSession: urlSession)
  }
  
  override public func execute<T>(urlRequest: URLRequest) -> AnyPublisher<T, NetworkError> where T : Decodable {
    var urlRequest = urlRequest
    var currentAccessToken: String?
    
    authenticationQueue.sync {
      currentAccessToken = self.tokenProvider.accessToken.value
    }
    
    guard let accessToken = currentAccessToken else {
      return Fail<T, NetworkError>(error: NetworkError.unauthorized).eraseToAnyPublisher()
    }
    
    urlRequest.addValue(accessToken, forHTTPHeaderField: "Authorization")
    
    return super.execute(urlRequest: urlRequest)
      .catch { error -> AnyPublisher<T, NetworkError> in
        if error == .unauthorized {
          self.authenticationQueue.sync(flags: .barrier) {
            self.tokenProvider.invalidateAccessToken()
            self.tokenProvider.reissueAccessToken()
          }
          return self.execute(urlRequest: urlRequest)
            .delay(for: 0.5, scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
        }
        return Fail<T, NetworkError>(error: error).eraseToAnyPublisher()
    }.eraseToAnyPublisher()
  }
  
  
  override public func execute(urlRequest: URLRequest) -> AnyPublisher<Void, NetworkError> {
    var urlRequest = urlRequest
    var currentAccessToken: String?
    
    authenticationQueue.sync {
      currentAccessToken = self.tokenProvider.accessToken.value
    }
    
    guard let accessToken = currentAccessToken else {
      return Fail<Void, NetworkError>(error: NetworkError.unauthorized).eraseToAnyPublisher()
    }
    
    urlRequest.addValue(accessToken, forHTTPHeaderField: "Authorization")
    
    return super.execute(urlRequest: urlRequest)
      .catch { error -> AnyPublisher<Void, NetworkError> in
        if error == .unauthorized {
          self.authenticationQueue.sync(flags: .barrier) {
            self.tokenProvider.invalidateAccessToken()
            self.tokenProvider.reissueAccessToken()
          }
          return self.execute(urlRequest: urlRequest)
            .delay(for: 0.5, scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
        }
        return Fail<Void, NetworkError>(error: error).eraseToAnyPublisher()
    }.eraseToAnyPublisher()
  }
}