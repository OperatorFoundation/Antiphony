//
//  AntiphonyUniverse.swift
//  Antiphony
//
//  Created by Mafalda on 1/6/23.
//

import Foundation

#if os(macOS) || os(iOS)
import os.log
#else
import Logging
#endif

import Chord
import Flower
import Gardener
import InternetProtocols
import Net
import Puppy
import Spacetime
import TransmissionTypes
import Universe

class AntiphonyUniverse: Universe
{
    let messageHandler: (IPv4Address, Message, Packet, Conduit) throws -> Void
    let listenAddr: String
    let listenPort: Int
    
    var pool = AddressPool()
    let connectionsQueue = DispatchQueue(label: "ConnectionsQueue")
    var conduitCollection = ConduitCollection()
    
    var tcpLogger = Puppy()
    
    public init(listenAddr: String, listenPort: Int, effects: BlockingQueue<Effect>, events: BlockingQueue<Event>, logger: Logger, messageHandler: @escaping (IPv4Address, Message, Packet, Conduit) throws -> Void)
    {
        self.listenAddr = listenAddr
        self.listenPort = listenPort
        self.messageHandler = messageHandler
        
        let logFileURL = URL(fileURLWithPath: "AntiphonyTcpLog.log")
        if File.exists(logFileURL.path)
        {
            let _ = File.delete(atPath: logFileURL.path)
        }
        
        if let file = try? FileLogger("AntiphonyTCPLogger",
                              logLevel: .debug,
                              fileURL: logFileURL,
                              filePermission: "600")  // Default permission is "640".
        {
            tcpLogger.add(file)
        }

        tcpLogger.debug("AntiphonyTCPLogger Start")
    
        super.init(effects: effects, events: events, logger: logger)
    }
    
    override func main() throws
    {
        let listener = try self.listen(listenAddr, listenPort)
        display("listening on \(listenAddr) \(listenPort)")

        while true
        {
            display("Waiting to accept a connection.")

            let connection = try listener.accept()

            display("New connection")

            // MARK: async cannot be replaced with Task because it is not currently supported on Linux
            connectionsQueue.async
            {
                self.handleIncomingConnection(connection)
            }
        }
    }
    
    /// Takes a transmission connection and wraps it as a flower connection
    func handleIncomingConnection(_ connection: TransmissionTypes.Connection)
    {
        print("Antiphony.handleIncomingConnection() called.")
        
        let flowerConnection = FlowerConnection(connection: connection, log: nil, logReads: true, logWrites: true)
        
        print("Antiphony created a Flower connection from incoming connection.")

        let address: IPv4Address
        do
        {
            print("Antiphony.handleIncomingConnection: Calling handleFirstMessage()")
            
            address = try self.handleFirstMessageOfConnection(flowerConnection)
        }
        catch
        {
            flowerConnection.connection.close()
            return
        }

        while true
        {
            do
            {
                try self.handleMessage(address, flowerConnection)
            }
            catch
            {
                continue
            }
        }
    }
    
    /// Deals with the client IP assignment.
    func handleFirstMessageOfConnection(_ flowerConnection: FlowerConnection) throws -> IPv4Address
    {
        print("Antiphony.handleFirstMessageOfConnection: attempting to read from our flower connection...")
        
        guard let message = flowerConnection.readMessage() else
        {
            print("Antiphony.handleFirstMessageOfConnection: failed to read a flower message. Connection closed")
            throw AntiphonyError.connectionClosed
        }

        print("Antiphony.handleFirstMessageOfConnection: received an \(message.description)")
        
        switch message
        {
            case .IPRequestV4:
                guard let address = pool.allocate() else
                {
                    // FIXME - close connection
                    print("Address allocation failure")
                    throw AntiphonyError.addressPoolAllocationFailed
                }

                guard let ipv4 = IPv4Address(address) else
                {
                    // FIXME - address could not be parsed as an IPv4 address
                    throw AntiphonyError.addressStringIsNotIPv4(address)
                }

                conduitCollection.addConduit(address: address, flowerConnection: flowerConnection)

                print("Antiphony.handleFirstMessage: calling flowerConnection.writeMessage()")
                flowerConnection.writeMessage(message: .IPAssignV4(ipv4))

                return IPv4Address(address)!
            case .IPRequestV6:
                // FIXME - support IPv6
                throw AntiphonyError.unsupportedFirstMessage(message)
            case .IPRequestDualStack:
                // FIXME - support IPv6
                throw AntiphonyError.unsupportedFirstMessage(message)
            case .IPReuseV4(let ipv4):
                flowerConnection.writeMessage(message: .IPAssignV4(ipv4))
                throw AntiphonyError.unsupportedFirstMessage(message)
            case .IPReuseV6(_):
                // FIXME - support IPv6
                throw AntiphonyError.unsupportedFirstMessage(message)
            case .IPReuseDualStack(_, _):
                // FIXME - support IPv6
                throw AntiphonyError.unsupportedFirstMessage(message)
            default:
                // FIXME - close connection
                print("Bad first message: \(message.description)")
                throw AntiphonyError.unsupportedFirstMessage(message)
        }
    }

    /// Processes raw packets from an incoming connection
    /// after parsing and identifying, pass on to handleParsedMessage()
    func handleMessage(_ address: IPv4Address, _ flowerConnection: FlowerConnection) throws
    {
        guard let message = flowerConnection.readMessage() else
        {
            print("\n* Antiphony.handleNextMessage Failed to read a flower message. The connection is probably closed.")

            if let logs = flowerConnection.readLog
            {
                print("Readlogs:")
                print("******************")
                for log in logs
                {
                    print(log.hex)
                }
                print("******************")
            }

            throw AntiphonyError.connectionClosed
        }
        
        tcpLogger.debug("\n************************************************************")
        
        switch message
        {
            case .IPDataV4(let data):
                let packet = Packet(ipv4Bytes: data, timestamp: Date(), debugPrints: true)
                guard let ipv4Packet = packet.ipv4 else
                {
                    // Drop this packet, but then continue processing more packets
                    print("* Antiphony.handleNextMessage: received data was not an IPV4 packet, ignoring this packet.")
                    throw AntiphonyError.packetNotIPv4(data)
                }
                
                print("* Antiphony.handleNextMessage: received an IPV4 packet")
                
                guard let conduit = self.conduitCollection.getConduit(with: address.string) else
                {
                    print("* Unknown conduit address \(address)")
                    return
                }

                if let tcp = packet.tcp
                {
                    tcpLogger.debug("*** Parsing a TCP Packet ***")

                    guard let ipv4Source = IPv4Address(data: ipv4Packet.sourceAddress) else
                    {
                        // Drop this packet, but then continue processing more packets
                        throw AntiphonyError.addressDataIsNotIPv4(ipv4Packet.destinationAddress)
                    }
                    
                    let sourcePort = NWEndpoint.Port(integerLiteral: tcp.sourcePort)
                    let sourceEndpoint = EndpointV4(host: ipv4Source, port: sourcePort)
                    
                    guard let ipv4Destination = IPv4Address(data: ipv4Packet.destinationAddress) else
                    {
                        // Drop this packet, but then continue processing more packets
                        throw AntiphonyError.addressDataIsNotIPv4(ipv4Packet.destinationAddress)
                    }
                    let destinationPort = NWEndpoint.Port(integerLiteral: tcp.destinationPort)
                    let destinationEndpoint = EndpointV4(host: ipv4Destination, port: destinationPort)
                    let streamID = generateStreamID(source: sourceEndpoint, destination: destinationEndpoint)
                    
                    if tcp.destinationPort == 2234 {
                        tcpLogger.debug("* source address: \(sourceEndpoint.host.debugDescription):\(sourceEndpoint.port.rawValue)")
                        tcpLogger.debug("* destination address: \(destinationEndpoint.host.debugDescription):\(destinationEndpoint.port.rawValue)")
                        tcpLogger.debug("* sequence number:")
                        tcpLogger.debug("* \(tcp.sequenceNumber.uint32 ?? 0)")
                        tcpLogger.debug("* \(tcp.sequenceNumber.hex)")
                        tcpLogger.debug("* acknowledgement number:")
                        tcpLogger.debug("* \(tcp.acknowledgementNumber.uint32 ?? 0)")
                        tcpLogger.debug("* \(tcp.acknowledgementNumber.hex)")
                        tcpLogger.debug("* syn: \(tcp.syn)")
                        tcpLogger.debug("* ack: \(tcp.ack)")
                        tcpLogger.debug("* fin: \(tcp.fin)")
                        tcpLogger.debug("* rst: \(tcp.rst)")
                        tcpLogger.debug("* window size: \(tcp.windowSize)")
                        if let options = tcp.options {
                            tcpLogger.debug("* tcp options: \(options.hex)")
                        } else {
                            tcpLogger.debug("* no tcp options")
                        }
                        
                        if let payload = tcp.payload {
                            tcpLogger.debug("* payload: \(payload.count) *")
                        }
                        else {
                            tcpLogger.debug("* no payload *")
                        }
                        
                        tcpLogger.debug("* streamID: \(streamID)")
                        tcpLogger.debug("* IPV4 packet parsed ❣️")
                        tcpLogger.debug("************************************************************\n")
                    }
                    
                    if tcp.syn // If the syn flag is set, we will ignore all other flags (including acks) and treat this as a syn packet
                    {
                        let parsedMessage: Message = .TCPOpenV4(destinationEndpoint, streamID)
                        tcpLogger.debug("* tcp.syn received. Message is TCPOpenV4")
                        try self.messageHandler(address, parsedMessage, packet, conduit)
                    }
                    else if tcp.rst // TODO: Flower should be informed if a close message is an rst or a fin
                    {
                        let parsedMessage: Message = .TCPClose(streamID)
                        tcpLogger.debug("* tcp.rst received. Message is TCPClose")
                        try self.messageHandler(address, parsedMessage, packet, conduit)
                    }
                    else if tcp.fin // TODO: Flower should be informed if a close message is an rst or a fin
                    {
                        let parsedMessage: Message = .TCPClose(streamID)
                        tcpLogger.debug("* tcp.fin received. Message is TCPClose")
                        try self.messageHandler(address, parsedMessage, packet, conduit)
                    }
                    else
                    {
                        // TODO: Handle the situation where we never see an ack response to our syn/ack (resend the syn/ack)
                        if let payload = tcp.payload
                        {
                            let parsedMessage: Message = .TCPData(streamID, payload)
                            tcpLogger.debug("* Received a payload. Parsed the message as TCPData")
                            
                            try self.messageHandler(address, parsedMessage, packet, conduit)
                        }
                        else if tcp.ack
                        {
                            let parsedMessage: Message = .TCPData(streamID, Data())
                            print("* No payload but receives an ack. Parsed the message as TCPData with no payload")
                            
                            try self.messageHandler(address, parsedMessage, packet, conduit)
                        }
                    }
                }
                else if let udp = packet.udp
                {
                    guard let ipv4Destination = IPv4Address(data: ipv4Packet.destinationAddress) else
                    {
                        // Drop this packet, but then continue processing more packets
                        throw AntiphonyError.addressDataIsNotIPv4(ipv4Packet.destinationAddress)
                    }

                    let port = NWEndpoint.Port(integerLiteral: udp.destinationPort)
                    let endpoint = EndpointV4(host: ipv4Destination, port: port)
                    guard let payload = udp.payload else
                    {
                        throw AntiphonyError.emptyPayload
                    }

                    let parsedMessage: Message = .UDPDataV4(endpoint, payload)
                    
                    try self.messageHandler(address, parsedMessage, packet, conduit)
                }

            default:
                // Drop this message, but then continue processing more messages
                throw AntiphonyError.unsupportedNextMessage(message)
        }
    }
    
//    // TODO: Expose as API for UI code
//    // handles the specifics of the packet types
//    func handleParsedMessage(_ address: IPv4Address, _ message: Message, _ packet: Packet) throws
//    {
//        print("\n* Antiphony.handleParsedMessage()")
//        switch message
//        {
//            case .UDPDataV4(_, _):
//                print("* Antiphony received a UPDataV4 type message")
//                guard let conduit = self.conduitCollection.getConduit(with: address.string) else
//                {
//                    print("* Unknown conduit address \(address)")
//                    return
//                }
//                
//                // TODO: Expose as API for UI code
//
////                try self.udpProxy.processLocalPacket(conduit, packet)
//
//            case .UDPDataV6(_, _):
//                print("* Antiphony received a UDPDataV6 type message. This is not currently supported.")
//                throw AntiphonyError.unsupportedParsedMessage(message)
//                
//            case .TCPOpenV4(_, _), .TCPData(_, _), .TCPClose(_):
//                print("* Antiphony received a TCP message: \(message)")
//                guard let conduit = self.conduitCollection.getConduit(with: address.string) else
//                {
//                    print("* Unknown conduit address \(address)")
//                    return
//                }
//                
//                // TODO: Expose as API for UI code
////                AsyncAwaitThrowingEffectSynchronizer.sync
////                {
////                    try await self.tcpProxy.processUpstreamPacket(conduit, packet)
////                }
//                
//            default:
//                throw AntiphonyError.unsupportedParsedMessage(message)
//        }
//    }
    
    public func shutdown()
    {
        if File.exists("dataDatabase")
        {
            if let contents = File.contentsOfDirectory(atPath: "dataDatabase")
            {
                if contents.isEmpty
                {
                    let _ = File.delete(atPath: "dataDatabase")
                }
            }
        }

        if File.exists("relationDatabase")
        {
            if let contents = File.contentsOfDirectory(atPath: "relationDatabase")
            {
                if contents.isEmpty
                {
                    let _ = File.delete(atPath: "relationDatabase")
                }
            }
        }
    }
}
