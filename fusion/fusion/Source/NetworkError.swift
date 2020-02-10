//
//  NetworkError.swift
//  fusion
//
//  Created by Eren Kabakci on 2/10/20.
//  Copyright © 2020 Eren Kabakci. All rights reserved.
//

import Foundation

public typealias HttpStatusCode = Int

public enum NetworkError: Error, Equatable {
  case urlError(URLError?)
  case parsingFailure
  case corruptUrl
  case unauthorized
  case forbidden
  case generic(HttpStatusCode)
  case unknown
}
