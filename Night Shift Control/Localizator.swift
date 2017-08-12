//
//  Localizator.swift
//  Night Shift Control
//
//  Created by Isaias M. Teweldeberhan on 8/11/17.
//  Copyright © 2017 Isaias M. Teweldeberhan. All rights reserved.
//

import Foundation

private class Localizator {
    
    static let sharedInstance = Localizator()
    
    lazy var localizableDictionary : NSDictionary! = {
        if let path = Bundle.main.path(forResource: "string_resource", ofType: "plist")
        {
            return NSDictionary(contentsOfFile: path)
        }
        
        fatalError("string_resource file not found")
    }()
    
    func localize(string: String) -> String {
        guard let localizedString = (localizableDictionary.value(forKey: string) as AnyObject).value(forKey: "value") as? String else {
            assertionFailure("Missing translation for: \(string)")
            return ""
        }
        
        return localizedString
    }
    
    
}

extension String {
    var localized: String {
        return Localizator.sharedInstance.localize(string: self)
    }
}
