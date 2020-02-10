//
//  PublicWebService.swift
//  fusion
//
//  Created by Eren Kabakci on 2/10/20.
//  Copyright © 2020 Eren Kabakci. All rights reserved.
//

import Combine
import Foundation

public protocol WebServiceExecutable: AnyObject {
  func execute<T: Decodable>(urlRequest: URLRequest) -> AnyPublisher<T, NetworkError>
  func execute(urlRequest: URLRequest) -> AnyPublisher<Void, NetworkError>
}
