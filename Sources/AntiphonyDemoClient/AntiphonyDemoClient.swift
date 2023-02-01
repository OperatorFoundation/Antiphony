//
//  AntiphonyDemoClient.swift
//
//
//  Created by Clockwork on Jan 31, 2023.
//

import Foundation

import AntiphonyDemo
import TransmissionTypes

public class AntiphonyDemoClient
{
    let connection: TransmissionTypes.Connection

    public init(connection: TransmissionTypes.Connection)
    {
        self.connection = connection
    }

    public func echo(message: String) throws -> String
    {
        let message = AntiphonyDemoRequest.echo(Echo(message: message))
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        guard self.connection.writeWithLengthPrefix(data: data, prefixSizeInBits: 64) else
        {
            throw AntiphonyDemoClientError.writeFailed
        }

        guard let responseData = self.connection.readWithLengthPrefix(prefixSizeInBits: 64) else
        {
            throw AntiphonyDemoClientError.readFailed
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
