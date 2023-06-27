//
//  Antiphony.swift
//  Antiphony
//
//  Created by Mafalda on 1/6/23.
//

import Foundation
import Lifecycle
import NIO

#if os(macOS)
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
    let logger: Logger
    
    static public func generateNew(name: String, port: Int, serverConfigURL: URL, clientConfigURL: URL, keychainURL: URL, keychainLabel: String) throws
    {
        let ip: String

        #if os(macOS)
        ip = getIPAddress() // Use LAN IP for macOS local testing (localhost won't work with Android emulator client)
        #else
        ip = try Ipify.getPublicIP() // Use public IP for Linux servers
        #endif
        
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
    
    #if os(macOS)
    static func getIPAddress() -> String
    {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0
        {
            var ptr = ifaddr
            while ptr != nil
            {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6)
                {
                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name: String = String(cString: (interface.ifa_name))
                    if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address ?? ""
    }
    #endif
    
    private let lock = DispatchSemaphore(value: 0)
    var lifecycle: ServiceLifecycle
    public var listener: Transmission.Listener? = nil
    
    public init(serverConfigURL: URL, loggerLabel: String, capabilities: Capabilities, label: String = "antiphony") throws
    {
        guard let config = ServerConfig(url: serverConfigURL) else
        {
            throw AntiphonyError.invalidConfigFile
        }
        
        self.lifecycle = ServiceLifecycle()

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        lifecycle.registerShutdown(label: "eventLoopGroup", .sync(eventLoopGroup.syncShutdownGracefully))
        
        #if os(macOS) || os(iOS)
        self.logger = Logger(subsystem: loggerLabel, category: "RunServer")
        #else
        self.logger = Logger(label: loggerLabel)
        #endif
        
        let simulation = Simulation(capabilities: capabilities)
        let universe = AntiphonyUniverse(listenAddr: config.host, listenPort: config.port, effects: simulation.effects, events: simulation.events, logger: logger)

        lifecycle.register(label: label, start: .sync(universe.run), shutdown: .sync(self.shutdown))

        lifecycle.start
        {
            error in

            if let error = error
            {
                print("Failed to start the Antiphony server ☠️: \(error)")
            }
            else
            {
                print("Server started 🚀")
            }
            
            self.lock.signal()
        }
        
        lock.wait()
        
        if let universeListener = universe.listener
        {
            self.listener = universeListener
            print("Server listening 🪐")
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
