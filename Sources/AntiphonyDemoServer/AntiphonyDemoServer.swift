//
//  AntiphonyDemoServer.swift
//
//
//  Created by Clockwork on Jan 31, 2023.
//

import Foundation

import AntiphonyDemo
import TransmissionAsync

public class AntiphonyDemoServer
{
    let listener: AsyncListener
    let handler: AntiphonyDemo

    var running: Bool = true

    public init(listener: AsyncListener, handler: AntiphonyDemo)
    {
        self.listener = listener
        self.handler = handler

        Task
        {
            self.accept()
        }
    }

    public func shutdown()
    {
        self.running = false
    }

    func accept()
    {
        while self.running
        {
            Task
            {
                do
                {
                    let connection = try await self.listener.accept()
                    try await self.handleConnection(connection)
                }
                catch
                {
                    print(error)
                    self.running = false
                    return
                }
            }
        }
    }

    func handleConnection(_ connection: AsyncConnection) async throws
    {
        while self.running
        {
            do
            {
                let requestData = try await connection.readWithLengthPrefix(prefixSizeInBits: 64)

                let decoder = JSONDecoder()
                let request = try decoder.decode(AntiphonyDemoRequest.self, from: requestData)
                switch request
                {
                    case .echo(let value):
                        let result = self.handler.echo(message: value.message)
                        let response = AntiphonyDemoResponse.echo(result)
                        let encoder = JSONEncoder()
                        let responseData = try encoder.encode(response)
                        try await connection.writeWithLengthPrefix(responseData, 64)
                }
            }
            catch
            {
                print(error)
                return
            }
        }
    }
}

public enum AntiphonyDemoServerError: Error
{
    case connectionRefused(String, Int)
    case writeFailed
    case readFailed
    case badReturnType
}
