//
//  main.swift
//  Antiphony
//
//  Created by Mafalda on 1/6/23.
//

import ArgumentParser
import Foundation

#if os(macOS) || os(iOS)
import os.log
#else
import FoundationNetworking
import Logging
#endif

import Flower
import Gardener
import InternetProtocols
import Net


struct AntiphonyCommandLine: ParsableCommand
{
    static let configuration = CommandConfiguration(
        commandName: "antiphony",
        subcommands: [New.self, Run.self]
    )
    
    static let clientConfigURL = URL(fileURLWithPath: File.currentDirectory()).appendingPathComponent("persona-client.json")
    static let serverConfigURL = URL(fileURLWithPath: File.homeDirectory().path).appendingPathComponent("persona-server.json")
    
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
            let antiphony = Antiphony()
            let keychainDirectoryURL = File.homeDirectory().appendingPathComponent(".antiphony-server")
            let keychainLabel = "Antiphony.KeyAgreement"
            
            try antiphony.generateNew(name: name, port: port, serverConfigURL: serverConfigURL, clientConfigURL: clientConfigURL, keychainURL: keychainDirectoryURL, keychainLabel: keychainLabel)
        }
    }
}

extension AntiphonyCommandLine
{
    struct Run: ParsableCommand
    {
        func handleMessage(address: IPv4Address, flowerConnection: Flower.FlowerConnection) throws {
            print("Test")
        }
        
        mutating func run() throws
        {
            let antiphony = Antiphony()
            try antiphony.startListening(serverConfigURL: serverConfigURL, loggerLabel: loggerLabel)
        }
    }
}

class ServerHandler: Antiphony
{
    override func handleParsedMessage(address: IPv4Address, message: Message, packet: Packet, conduit: Conduit) throws
    {
        print("AntiphonyCLI ServerHandler.handleParsedMessage")
        
        switch message
        {
            case .UDPDataV4(_, _):
                print("* Antiphony received a UPDataV4 type message")

//                try self.udpProxy.processLocalPacket(conduit, packet)

            case .UDPDataV6(_, _):
                print("* Antiphony received a UDPDataV6 type message. This is not currently supported.")
                throw AntiphonyError.unsupportedParsedMessage(message)
                
            case .TCPOpenV4(_, _), .TCPData(_, _), .TCPClose(_):
                print("* Antiphony received a TCP message: \(message)")
                
                // TODO: Expose as API for UI code
//                AsyncAwaitThrowingEffectSynchronizer.sync
//                {
//                    try await self.tcpProxy.processUpstreamPacket(conduit, packet)
//                }
                
            default:
                throw AntiphonyError.unsupportedParsedMessage(message)
        }
    }
}

AntiphonyCommandLine.main()
