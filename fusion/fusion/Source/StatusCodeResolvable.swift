//
//  StatusCodeResolvable.swift
//  fusion
//
//  Created by Eren Kabakci on 2/11/20.
//  Copyright © 2020 Eren Kabakci. All rights reserved.
//

import Foundation

public protocol StatusCodeResolvable: AnyObject {
  func mapHttpResponseCodes(httpResponse: HTTPURLResponse) throws
}

extension StatusCodeResolvable {
  func mapHttpResponseCodes(httpResponse: HTTPURLResponse) throws {
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
}
