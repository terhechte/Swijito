//
//  PhotoCollector.swift
//  Swijito
//
//  Created by Benedikt Terhechte on 09/06/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

import Cocoa

class OutlineItem: NSObject {
    var title: String
    var children: Array<OutlineItem>
    var account: PhotoAccount?
    init(title: String, account: PhotoAccount?, children: Array<OutlineItem>) {
        self.children = children
        self.title = title
        self.children = children
        self.account = account
    }
    func hasChildren() -> Bool {
        return self.children.count > 0
    }
    func itemCount() -> Int {
        if let ac = self.account {
            return ac.image_count
        }
        return 0
    }
}

class PhotoCollector: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSOutlineViewDataSource, NSOutlineViewDelegate {
    
    @IBOutlet var addAccountSheet: NSWindow?
    @IBOutlet var addAccountURLField: NSTextField?
    @IBOutlet var addAccountErrorMessage: NSTextField?
    @IBOutlet var tableView: NSTableView?
    @IBOutlet var outlineView: NSOutlineView?
    
    // We could also use a NSTreeController or NSArrayController, but then we'd loose or strong types again.
    // TODO: I wonder how much of a speed penalty NSArrayController + Bindings vs Array + DataSource is
    var accounts: Array<OutlineItem>
    
    // The current photos for the current account
    var photos: [PhotoObject]
    
    //------------------------------------------------------------------------
    // Initialization
    //------------------------------------------------------------------------

    override init()  {
        // NOTE: So apparently before calling super, all the non-optional
        // properties need to have an assignment
        // NOTE: super.init is optional, *unless* I'm using =self= in here
        self.photos = []
        self.accounts = []
        
        super.init()
        
        self.waitForView()
    }
    
    // While 10.10 finally got support for viewDidAppear, willAppear, etc
    // in NSViewController, I'm writing this for 10.9, so we'll do it
    // the old and ugly way
    func waitForView() {
        if self.tableView == nil {
            dispatch_after(1, dispatch_get_main_queue(), {() -> Void in
                self.waitForView()
                })
            return
        }
        
        self.tableView!.postsFrameChangedNotifications = true;
        
        NSNotificationCenter.defaultCenter().addObserverForName(NSViewFrameDidChangeNotification, object: self.tableView!, queue: NSOperationQueue.mainQueue(), usingBlock:
            {(n: NSNotification!) in
                // TODO: Only notify for the currently visible rows
                let indexes = NSIndexSet(indexesInRange: NSMakeRange(0, self.photos.count))
                self.tableView!.noteHeightOfRowsWithIndexesChanged(indexes)
            })
        
        // load all accounts into the sidebar
        self.updateAccountOutlineView()
    }
    
    //------------------------------------------------------------------------
    // Account Interaction & Loading
    //------------------------------------------------------------------------
    
    func updateForAccount(account: PhotoAccount) {
        PhotoModel.loadStream(account, handler: {(v: [PhotoObject]) -> () in
            self.photos = v
            self.tableView!.reloadData()
        })
    }
    
    @IBAction func showAccountPanel(sender: AnyObject!) {
        self.addAccountErrorMessage!.stringValue = ""
        self.tableView!.window!.beginSheet(self.addAccountSheet!,
            completionHandler: nil)
    }
    
    @IBAction func addAccount(sender: AnyObject!) {
        if let field = self.addAccountURLField {
            let urlString = field.stringValue
            // TODO: parse the user id out of the url
            // for now we're only accepting the extracted id...
            PhotoModel.loadAccount(urlString, host: PhotoAccount.defaultHost(), handler: {(account: PhotoAccount?, error: NSError?) -> Void in
                
                if let e = error {
                    self.addAccountErrorMessage!.stringValue = "Could not find Stream"
                    return
                }
                
                if let a = account {
                    PhotoModel.addAccount(a)
                    self.updateAccountOutlineView()
                } else {
                    self.addAccountErrorMessage!.stringValue = "Could not find User"
                    return
                }
                
                self.tableView!.window!.endSheet(self.addAccountSheet!)

                })
        }
    }
    
    @IBAction func removeAccount(sender: AnyObject?) {
        // TODO: The button should only be active, if there's a selection
        switch self.outlineView!.selectedRowIndexes {
        case let indexes where indexes.count > 0:
            // TODO: A TreeController would make this easier...
            if let item = self.accountForIndex(indexes.firstIndex) {
                PhotoModel.removeAccount(item)
                self.updateAccountOutlineView()
            }
        default:
            NSBeep()
        }
    }
    
    @IBAction func cancelAddAccount(sender: AnyObject?) {
        self.tableView!.window!.endSheet(self.addAccountSheet!)
    }
    
    //------------------------------------------------------------------------
    // Photos Table View
    //------------------------------------------------------------------------
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let view = self.tableView!.makeViewWithIdentifier(tableColumn!.identifier!, owner: self) {
            view.prepareForReuse()
            
            // TODO: Make Magic numbers a constant somewhere
            let photoCellTag = 42
            
            // only load & display the image if this method has been called
            if let imageView:PhotoCellImageView = view.viewWithTag(photoCellTag) as? PhotoCellImageView  {
                // The image will be downloaded upon first request of image, and then cached
                self.photos[row].cacheImage()
                imageView.bind("image", toObject: self.photos[row], withKeyPath: "image", options: nil)
            }
            
            return view as! NSView
        }
        
        return nil;
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return self.photos.count
    }

    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        let r:PhotoObject = self.photos[row]
        return r
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        // calculate the height of the row based on the image ratio & the current width
        // but don't go beyond the max height
        let currentWidth = self.tableView!.frame.size.width
        let size = self.photos[row].size
        let height = (size.height / size.width) * currentWidth
        // add the padding
        // TODO: Fetch this padding from the cell / constraints, don't have to
        // do this manually in here
        return height + 47 + 17
    }
    
    //------------------------------------------------------------------------
    // Sidebar Outline View
    //------------------------------------------------------------------------
    
    func accountForIndex(index: Int) -> PhotoAccount? {
        // we have to remove 1 from the index because the headline "Accounts" takes one up
        // this is awful code and needs to be refactored
        return self.accounts[0].children[index - 1].account
    }
    
    func updateAccountOutlineView() {
        let accounts = PhotoModel.accounts()
        self.accounts = [OutlineItem(title: "Streams", account: nil,
            children: accounts.map({(p: PhotoAccount) -> OutlineItem in
                return OutlineItem(title: p.streamname, account: p, children: [])
                }))]
        if let o = self.outlineView {
            o.reloadData()
            // there ought to be a better way to do this. apparently stackoverflow disagrees
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))) , dispatch_get_main_queue()){
                self.outlineView!.expandItem(nil, expandChildren: true)
            }
        }
    }
    
    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if let theItem: AnyObject = item {
            // not the root item
            let o:OutlineItem = item as! OutlineItem
            return o.children.count
        }
        // otherwise, just one headline so far
        return self.accounts.count
    }
    
    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if let theItem: AnyObject = item {
            // not the root item
            let o:OutlineItem = item as! OutlineItem
            return o.children[index]
        }
        return self.accounts[index]
    }
    
    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        let o:OutlineItem = item as! OutlineItem
        return o.hasChildren()
    }
    
    func outlineView(outlineView: NSOutlineView, objectValueForTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject? {
        return item
    }
    
    func outlineView(outlineView: NSOutlineView, shouldSelectItem item: AnyObject) -> Bool {
        let o:OutlineItem = item as! OutlineItem
        if o.hasChildren() {
            return false
        } else {
            // select the account, but only if it exists
            if let account = o.account {
                self.updateForAccount(account)
                return true
            }
            return false
        }
    }

    
}
