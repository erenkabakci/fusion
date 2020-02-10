//
//  SessionPublisherProtocol.swift
//  fusion
//
//  Created by Eren Kabakci on 2/10/20.
//  Copyright © 2020 Eren Kabakci. All rights reserved.
//

import Combine
import Foundation

public protocol SessionPublisherProtocol: AnyObject {
  func dataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), NetworkError>
}

extension URLSession: SessionPublisherProtocol {
  public func dataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), NetworkError> {
    self.dataTaskPublisher(for: request)
    .receive(on: DispatchQueue.main)
    .mapError { NetworkError.urlError($0) }
    .eraseToAnyPublisher()
  }
}
