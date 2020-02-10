//
//  CustomDecodable.swift
//  fusion
//
//  Created by Eren Kabakci on 2/11/20.
//  Copyright © 2020 Eren Kabakci. All rights reserved.
//

import Foundation

public protocol CustomDecodable: AnyObject {
  var jsonDecoder: JSONDecoder { get }
  func decode<T: Decodable>(data: Data, type _: T.Type) throws -> T
}

extension CustomDecodable {
  public func decode<T>(data: Data, type _: T.Type) throws -> T where T : Decodable {
    do {
        return try jsonDecoder.decode(T.self, from: data)
    } catch {
      throw NetworkError.parsingFailure
    }
  }
}
