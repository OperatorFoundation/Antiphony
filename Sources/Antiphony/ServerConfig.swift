//
//  ServerConfig.swift
//  Antiphony
//
//  Created by Mafalda on 1/6/23.
//

import Foundation

import Gardener

public struct ServerConfig: Codable
{
    public let name: String
    public let host: String
    public let port: Int
    public var stateDirectory: URL

    public init(name: String, host: String, port: Int, stateDirectory: URL? = nil)
    {
        self.name = name
        self.host = host
        self.port = port
        
        if let userStateDir = stateDirectory
        {
            self.stateDirectory = userStateDir
        }
        else
        {
            self.stateDirectory = File.homeDirectory().appendingPathComponent("AntiphonyState", isDirectory: true)
        }
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
            print("Failed to find a valid server config file at \(url.path). Received an error: \(error)")
            
            return nil
        }
    }
    
    public func save(to fileURL: URL) throws
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        
        let serverConfigData = try encoder.encode(self)
        try serverConfigData.write(to: fileURL)
    }
}
