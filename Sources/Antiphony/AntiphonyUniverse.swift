//
//  AntiphonyUniverse.swift
//  Antiphony
//
//  Created by Mafalda on 1/6/23.
//

import Foundation
import Logging

import Chord
import Gardener
import Net
import Spacetime
import TransmissionAsync
import Universe

class AntiphonyUniverse: Universe
{
    let connectionsQueue = DispatchQueue(label: "ConnectionsQueue")
    let listenAddr: String
    let listenPort: Int
    let antiphonyLogger = Logger(label: "AntiphonyLogger")
    
    public var listener: AsyncListener?
    
    public init(listenAddr: String, listenPort: Int, effects: BlockingQueue<Effect>, events: BlockingQueue<Event>, logger: Logger?)
    {
        self.listenAddr = listenAddr
        self.listenPort = listenPort
        
        // FIXME: Logger
        super.init(effects: effects, events: events, logger: nil)
    }
    
    override func main() throws
    {
        // TODO: Debug use - replacing Spacetime listener with trad
        // self.listener = try self.listen(listenAddr, listenPort)
        
        try self.listener = AsyncTcpSocketListener(port: listenPort, antiphonyLogger)
    }
    
    public func shutdown()
    {
        // Stub
    }
    
}
