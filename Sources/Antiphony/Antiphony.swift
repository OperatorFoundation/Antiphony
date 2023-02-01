//
//  Antiphony.swift
//  Antiphony
//
//  Created by Mafalda on 1/6/23.
//

import Foundation
import Lifecycle
import NIO

#if os(macOS) || os(iOS)
import os.log
#else
import FoundationNetworking
import Logging
#endif

import KeychainCli
import Net
import Simulation
import Spacetime
import Transmission

open class Antiphony
{
    static public func generateNew(name: String, port: Int, serverConfigURL: URL, clientConfigURL: URL, keychainURL: URL, keychainLabel: String) throws
    {
        let ip: String = try Ipify.getPublicIP()
        
        guard let keychain = Keychain(baseDirectory: keychainURL) else
        {
            throw AntiphonyError.couldNotLoadKeychain
        }

        guard let privateKeyKeyAgreement = keychain.generateAndSavePrivateKey(label: keychainLabel, type: KeyType.P256KeyAgreement) else
        {
            throw AntiphonyError.couldNotGeneratePrivateKey
        }

        if let test = TransmissionConnection(host: ip, port: port)
        {
            test.close()

            throw AntiphonyError.portInUse(port)
        }
        
        let serverConfig = ServerConfig(name: name, host: ip, port: port)
        try serverConfig.save(to: serverConfigURL)
        print("Wrote config to \(serverConfigURL.path)")

        let publicKeyKeyAgreement = privateKeyKeyAgreement.publicKey
        let clientConfig = ClientConfig(name: name, host: ip, port: port, serverPublicKey: publicKeyKeyAgreement)
        try clientConfig.save(to: clientConfigURL)
        print("Wrote config to \(clientConfigURL.path)")
    }
    
    private let lock = DispatchSemaphore(value: 0)
    var lifecycle: ServiceLifecycle
    public var listener: Transmission.Listener? = nil
    
    public init(serverConfigURL: URL, loggerLabel: String, capabilities: Capabilities) throws
    {
        guard let config = ServerConfig(url: serverConfigURL) else
        {
            throw AntiphonyError.invalidConfigFile
        }
        
        self.lifecycle = ServiceLifecycle()

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        lifecycle.registerShutdown(label: "eventLoopGroup", .sync(eventLoopGroup.syncShutdownGracefully))
        
        #if os(macOS) || os(iOS)
        let logger = Logger(subsystem: loggerLabel, category: "RunServer")
        #else
        let logger = Logger(label: loggerLabel)
        #endif
        
        let simulation = Simulation(capabilities: capabilities)
        let universe = AntiphonyUniverse(listenAddr: config.host, listenPort: config.port, effects: simulation.effects, events: simulation.events, logger: logger)

        lifecycle.register(label: "antiphony", start: .sync(universe.run), shutdown: .sync(self.shutdown))

        lifecycle.start
        {
            error in

            if let error = error
            {
                print("Failed to start the Antiphony server ☠️: \(error)")
            }
            else
            {
                print("The Antiphony server has started successfully 🚀")
            }
            
            self.lock.signal()
        }
        
        lock.wait()
        
        if let universeListener = universe.listener
        {
            self.listener = universeListener
        }
        else
        {
            throw AntiphonyError.failedToCreateListener
        }
    }
    
    open func shutdown()
    {
        print("Antiphony is shutting down.")
    }
    
    public func wait()
    {
        lifecycle.wait()
    }
}

public enum AntiphonyError: Error
{
    case portInUse(Int)
    case addressPoolAllocationFailed
    case addressStringIsNotIPv4(String)
    case addressDataIsNotIPv4(Data)
    case couldNotLoadKeychain
    case couldNotGeneratePrivateKey
    case failedToCreateListener
    case failedToCreateConnection
    case connectionClosed
    case packetNotIPv4(Data)
    case unsupportedPacketType(Data)
    case emptyPayload
    case echoListenerFailure
    case invalidConfigFile
}
