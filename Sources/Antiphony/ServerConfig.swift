//
//  ServerConfig.swift
//  Antiphony
//
//  Created by Mafalda on 1/6/23.
//

import Foundation

public struct ServerConfig: Codable
{
    public let name: String
    public let host: String
    public let port: Int

    public init(name: String, host: String, port: Int)
    {
        self.name = name
        self.host = host
        self.port = port
    }
    
    public init?(from data: Data)
    {
        let decoder = JSONDecoder()
        do
        {
            let decoded = try decoder.decode(ServerConfig.self, from: data)
            self = decoded
        }
        catch
        {
            print("Error received while attempting to decode a server configuration json file: \(error)")
            return nil
        }
    }
    
    public init?(path: String)
    {
        let url = URL(fileURLWithPath: path)
        
        self.init(url: url)
    }
    
    public init?(url: URL)
    {
        do
        {
            let data = try Data(contentsOf: url)
            self.init(from: data)
        }
        catch
        {
            print("Error decoding Shadow config file: \(error)")
            
            return nil
        }
    }
    
    public func save(to fileURL: URL) throws
    {
        let encoder = JSONEncoder()
        let serverConfigData = try encoder.encode(self)
        try serverConfigData.write(to: fileURL)
    }
}
