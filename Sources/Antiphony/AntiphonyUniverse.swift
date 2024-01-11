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
import Transmission
import Universe

class AntiphonyUniverse: Universe
{
    let listenAddr: String
    let listenPort: Int
    let connectionsQueue = DispatchQueue(label: "ConnectionsQueue")
    
    public var listener: Transmission.Listener?
    
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
        
        self.listener = TransmissionListener(port: listenPort, logger: nil)
    }
    
    public func shutdown()
    {
        // Stub
    }
    
}
