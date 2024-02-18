//
//  main.swift
//  Antiphony
//
//  Created by Mafalda on 1/6/23.
//

import ArgumentParser
import Foundation

#if os(macOS)
import os.log
#else
import FoundationNetworking
import Logging
#endif

import Antiphony
import Gardener
import Net


struct AntiphonyCommandLine: ParsableCommand
{
    static let configuration = CommandConfiguration(
        commandName: "antiphony",
        subcommands: [New.self, Run.self]
    )
    
    static let clientConfigURL =  File.homeDirectory().appendingPathComponent("antiphony-client.json")
    static let serverConfigURL = URL(fileURLWithPath: File.homeDirectory().path).appendingPathComponent("antiphony-server.json")
    static let loggerLabel = "org.OperatorFoundation.AntiphonyLogger"
}

extension AntiphonyCommandLine
{
    struct New: ParsableCommand
    {
        @Argument(help: "Human-readable name for your server to use in invites")
        var name: String

        @Argument(help: "Port on which to run the server")
        var port: Int
        
        mutating public func run() throws
        {
            let keychainDirectoryURL = File.homeDirectory().appendingPathComponent(".antiphony-server")
            let keychainLabel = "Antiphony.KeyAgreement"
            
            try Antiphony.generateNew(name: name, port: port, serverConfigURL: serverConfigURL, clientConfigURL: clientConfigURL, keychainURL: keychainDirectoryURL, keychainLabel: keychainLabel)
        }
    }
}

extension AntiphonyCommandLine
{
    struct Run: ParsableCommand
    {        
        mutating func run() throws
        {
            let customAntiphony = try CustomAntiphony(serverConfigURL: serverConfigURL, loggerLabel: loggerLabel)
            
            guard let newListener = customAntiphony.listener else
            {
                throw AntiphonyError.failedToCreateListener
            }
            
            let antiphonyLogic = AntiphonyDemo()
            let demoServer = AntiphonyDemoServer(listener: newListener, handler: antiphonyLogic)
            
            // If you want custom shutdown behavior then you need to update your antiphony subclass with your new server
            customAntiphony.antiphonyServer = demoServer
            customAntiphony.wait()
        }
    }
}

AntiphonyCommandLine.main()
