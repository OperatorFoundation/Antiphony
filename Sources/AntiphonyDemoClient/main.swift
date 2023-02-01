//
//  main.swift
//  
//
//  Created by Mafalda on 1/31/23.
//

import ArgumentParser
import Foundation

import Antiphony
import Gardener
import Transmission


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
            
            guard let connection = TransmissionConnection(host: config.host, port: config.port) else
            {
                throw AntiphonyError.failedToCreateConnection
            }
            
            let antiphonyClient = AntiphonyDemoClient(connection: connection)
            
            let echoResponse = try antiphonyClient.echo(message: message)
            print("Server responded with: \(echoResponse)")
        }
    }
}

AntiphonyDemoClientCommandLine.main()
