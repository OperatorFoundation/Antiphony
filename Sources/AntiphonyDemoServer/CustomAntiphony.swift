//
//  AntiphonyDemo.swift
//  AntiphonyCLI
//
//  Created by Mafalda on 1/31/23.
//

import Foundation

import Antiphony

public class CustomAntiphony: Antiphony
{
    public var antiphonyServer: AntiphonyDemoServer? = nil
    
    public override func shutdown()
    {
        print("AntiphonyDemo shutting down")
        antiphonyServer?.shutdown()
    }
}
