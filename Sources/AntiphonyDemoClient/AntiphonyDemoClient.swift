//
//  AntiphonyDemoClient.swift
//
//
//  Created by Clockwork on Jan 31, 2023.
//

import Foundation

import AntiphonyDemo
import Chord
import TransmissionAsync

public class AntiphonyDemoClient
{
    let connection: AsyncConnection
    

    public init(connection: AsyncConnection)
    {
        self.connection = connection
    }

    public func echo(message: String) throws -> String
    {
        let message = AntiphonyDemoRequest.echo(Echo(message: message))
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        
        let responseData = try AsyncAwaitThrowingSynchronizer<Data>.sync
        {
            let prefixSizeInBits = 64
            try await self.connection.writeWithLengthPrefix(data, prefixSizeInBits)
            return try await self.connection.readWithLengthPrefix(prefixSizeInBits: prefixSizeInBits)
        }
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(AntiphonyDemoResponse.self, from: responseData)
        
        switch response
        {
            case .echo(let value):
                return value
        }
    }
}

public enum AntiphonyDemoClientError: Error
{
    case connectionRefused(String, Int)
    case writeFailed
    case readFailed
    case badReturnType
}
