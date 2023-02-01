//
//  AntiphonyDemoServer.swift
//
//
//  Created by Clockwork on Jan 31, 2023.
//

import Foundation

import AntiphonyDemo
import TransmissionTypes

public class AntiphonyDemoServer
{
    let listener: TransmissionTypes.Listener
    let handler: AntiphonyDemo

    var running: Bool = true

    public init(listener: TransmissionTypes.Listener, handler: AntiphonyDemo)
    {
        self.listener = listener
        self.handler = handler

        Task
        {
            self.acceptLoop()
        }
    }

    public func shutdown()
    {
        self.running = false
    }

    func acceptLoop()
    {
        while self.running
        {
            do
            {
                let connection = try self.listener.accept()

                Task
                {
                    self.handleConnection(connection)
                }
            }
            catch
            {
                print(error)
                self.running = false
                return
            }
        }
    }

    func handleConnection(_ connection: TransmissionTypes.Connection)
    {
        while self.running
        {
            do
            {
                guard let requestData = connection.readWithLengthPrefix(prefixSizeInBits: 64) else
                {
                    throw AntiphonyDemoServerError.readFailed
                }

                let decoder = JSONDecoder()
                let request = try decoder.decode(AntiphonyDemoRequest.self, from: requestData)
                switch request
                {
                    case .echo(let value):
                        let result = self.handler.echo(message: value.message)
                        let response = AntiphonyDemoResponse.echo(result)
                        let encoder = JSONEncoder()
                        let responseData = try encoder.encode(response)
                        guard connection.writeWithLengthPrefix(data: responseData, prefixSizeInBits: 64) else
                        {
                            throw AntiphonyDemoServerError.writeFailed
                        }
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
