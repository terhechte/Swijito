//
//  FastImageView.swift
//  Swijito
//
//  Created by Benedikt Terhechte on 12/06/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

import Cocoa

@IBDesignable
class PhotoCellImageView: NSImageView {
    
    override func drawRect(dirtyRect: NSRect) {
        if self.image != nil {
            super.drawRect(dirtyRect)
        } else {
            // no image | loading screen
            NSColor.grayColor().setFill()
            NSRectFill(dirtyRect)
        }
    }
    
}
