//
//  AntiphonyDemoMessages.swift
//
//
//  Created by Clockwork on Jan 31, 2023.
//

public enum AntiphonyDemoRequest: Codable
{
    case echo(Echo)
}

public struct Echo: Codable
{
    public let message: String

    public init(message: String)
    {
        self.message = message
    }
}

public enum AntiphonyDemoResponse: Codable
{
    case echo(String)
}