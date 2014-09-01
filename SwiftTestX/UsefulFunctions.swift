//
//  UsefulFunctions.swift
//  Swijito
//
//  Created by Benedikt Terhechte on 9/1/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

import Foundation

extension NSDateFormatter {
    class func validDateWithFormat(format: String, values: AnyObject?...) -> NSDate? {
        // Per Swift Docs, 'NSDateFormatter(dateFormat: "")' should be 
        // the correct thing to do, but that doesn't work
    
        let aDateFormatter = NSDateFormatter()
        aDateFormatter.dateFormat = format;

        for value in values {
            if let validValue = value as? String {
                return aDateFormatter.dateFromString(validValue)
            }
        }

        return nil
    }
}

