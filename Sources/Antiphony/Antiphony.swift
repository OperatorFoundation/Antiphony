//
//  Antiphony.swift
//  Antiphony
//
//  Created by Mafalda on 1/6/23.
//

import Foundation
import Lifecycle
import Logging
import NIO

#if os(macOS)
//
#else
import FoundationNetworking
#endif

import KeychainCli
import Net
import Transmission
import TransmissionAsync

open class Antiphony
{
    public let logger: Logger
    
    static public func generateNew(name: String, port: Int, serverConfigURL: URL, clientConfigURL: URL, keychainURL: URL, keychainLabel: String, stateDirectory: URL? = nil, overwriteKey: Bool = false) throws
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

        guard let privateKeyKeyAgreement = keychain.generateAndSavePrivateKey(label: keychainLabel, type: KeyType.P256KeyAgreement, overwrite: overwriteKey) else
        {
            throw AntiphonyError.couldNotGeneratePrivateKey
        }

        if let test = TransmissionConnection(host: ip, port: port)
        {
            test.close()

            print("⚠️ Failed to create a test connection with the intended ip: \(ip) and port: \(port). The resulting config files may not work correctly. Please check the server address and make sure that it is accessible and that the indicated port is not already in use.")
        }
        
        let serverConfig = ServerConfig(name: name, host: ip, port: port, stateDirectory: stateDirectory)
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
    public var lifecycle: ServiceLifecycle
    public var listener: AsyncListener? = nil
    
    public convenience init(serverConfigURL: URL, loggerLabel: String, label: String = "antiphony") throws
    {
        try self.init(serverConfigURL: serverConfigURL, logger: Logger(label: loggerLabel), label: label)
    }
    
    public init(serverConfigURL: URL, logger: Logger, label: String = "antiphony") throws
    {
        guard let config = ServerConfig(url: serverConfigURL) else
        {
            throw AntiphonyError.invalidConfigFile
        }
        
        self.lifecycle = ServiceLifecycle()

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        lifecycle.registerShutdown(label: "eventLoopGroup", .sync(eventLoopGroup.syncShutdownGracefully))
        
        self.logger = logger

        lifecycle.register(label: label, start: .sync({try self.start(config: config)}), shutdown: .sync(self.shutdown))

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
    }
    
    func start(config: ServerConfig) throws
    {
        try self.listener = AsyncTcpSocketListener(port: config.port, self.logger, verbose: self.logger.logLevel == .debug)
        print("Server listening on \(config.host):\(config.port)🪐")
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
