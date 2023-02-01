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
import Gardener
import Net
import Puppy
import Spacetime
import Transmission
import Universe

class AntiphonyUniverse: Universe
{
    let listenAddr: String
    let listenPort: Int
    let connectionsQueue = DispatchQueue(label: "ConnectionsQueue")
    
    public var listener: Transmission.Listener?
    
    public init(listenAddr: String, listenPort: Int, effects: BlockingQueue<Effect>, events: BlockingQueue<Event>, logger: Logger)
    {
        self.listenAddr = listenAddr
        self.listenPort = listenPort
    
        super.init(effects: effects, events: events, logger: logger)
    }
    
    override func main() throws
    {
        self.listener = try self.listen(listenAddr, listenPort)
        display("listening on \(listenAddr) \(listenPort)")
    }
    
    public func shutdown()
    {
        // Stub
    }
    
}
