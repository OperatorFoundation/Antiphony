//
//  main.swift
//  
//
//  Created by Mafalda on 1/31/23.
//

import ArgumentParser
import Foundation
import Logging

import Antiphony
import Chord
import Gardener
import TransmissionAsync


struct AntiphonyDemoClientCommandLine: ParsableCommand
{
    static let configuration = CommandConfiguration(
        commandName: "antiphonyclient",
        subcommands: [Echo.self]
    )
    
    static let clientConfigURL = File.homeDirectory().appendingPathComponent("antiphony-client.json")
    static let loggerLabel = "org.OperatorFoundation.AntiphonyDemoClientLogger"
}

extension AntiphonyDemoClientCommandLine
{
    struct Echo: ParsableCommand
    {
        @Argument(help: "The echo message to send to the server.")
        var message: String
        
        mutating public func run() throws
        {
            guard let config = ClientConfig(url: clientConfigURL) else
            {
                throw AntiphonyError.invalidConfigFile
            }
            
            let connection = try AsyncAwaitThrowingSynchronizer<AsyncConnection>.sync
            {
                let newConnection = try await AsyncTcpSocketConnection(config.host, config.port, Logger(label: loggerLabel))
                return newConnection
            }
            
            let antiphonyClient = AntiphonyDemoClient(connection: connection)

            
            let echoResponse = try antiphonyClient.echo(message: message)
            print("Server responded with: \(echoResponse)")
        }
    }
}

AntiphonyDemoClientCommandLine.main()
