//
//  functions.swift
//  Swijito
//
//  Created by Benedikt Terhechte on 09/06/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

import Foundation
import Cocoa

// A simple threading operator: thrush(dictionary, key1, key2, key3)
func thrush (collection: NSDictionary, key:NSCopying...) -> AnyObject? {
    var val: NSDictionary = collection
    for i in key {
        if let v: AnyObject = val[i] {
            if v is NSDictionary {
                val = v as NSDictionary
            } else {
                return v
            }
        } else {
            return nil
        }
    }
    return val
}

struct PhotoAccount {
    var username: String
    var streamname: String
    var userid: String
    var image_count: Int
    var host: String
    
    static func defaultHost() -> String {
        return "p23-sharedstreams.icloud.com"
    }
    
    // Add a conversion function for NSDictionary
    // and the other way around
    func toDictionary() -> NSDictionary {
        return ["username": self.username,
            "userid": self.userid,
            "streamname": self.streamname,
            "image_count": self.image_count as NSNumber,
            "host": self.host] as NSDictionary
    }
    
    static func fromDictionary(delf: NSDictionary) -> PhotoAccount {
        // default host
        var host: String
        if delf["host"] != nil {
            host = delf["host"]! as String
        } else {
            // default
            host = PhotoAccount.defaultHost()
        }
        
        return PhotoAccount(username: delf["username"] as NSString,
            streamname: delf["streamname"] as NSString,
            userid: delf["userid"] as NSString,
            image_count: (delf["image_count"] as NSNumber).integerValue,
            host: host)
    }
    
    func streamURLString() -> String {
        return "https://\(self.host)/\(self.userid)/sharedstreams/webstream"
    }
    func assetURLString() -> String {
        return "https://\(self.host)/\(self.userid)/sharedstreams/webasseturls"
    }
}

// TODO: *ahem*
// This was supposed to be a lightweight struct around the data coming in from
// the Apple API and turned out to become this massive monster class that looks
// everything *but* lightweight
class PhotoObject : NSObject {
    enum PhotoObjectType {
        case Photo
        case Video
    }
    var type: PhotoObjectType
    var size: CGSize
    var created: NSDate
    var caption: NSString
    // Full name (synthesized), First Name, Last Name
    var contributor: (String, String, String)
    var photoGuuid: String
    var image: NSImage?
    // the checksum of the main, big file
    var checksum: String?
    var url: NSURL?
    
    init(d: NSDictionary) {
        // TODO: Confusing Double / Float non-conversion issues
        var w: CDouble = 0
        var h: CDouble = 0
        var t: PhotoObjectType = PhotoObjectType.Photo
        
        // TODO: Try to use pattern matching to improve this awfull code
        // TODO: Activate video support
        if d.objectForKey("mediaAssetType") != nil {
            let p:NSString = d["mediaAssetType"] as NSString!

            if p == "video" {
                w = (thrush(d, "derivatives", "PosterFrame", "width") as NSString).doubleValue
                h = (thrush(d, "derivatives", "PosterFrame", "height") as NSString).doubleValue
                t = PhotoObjectType.Video
            }
            
        } else {
            w = (d["width"] as NSString).doubleValue
            h = (d["height"] as NSString).doubleValue
        }
        
        self.type = t
        self.size = CGSizeMake(CGFloat(w), CGFloat(h))
        
        switch NSDateFormatter.validDateWithFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", values: d["dateCreated"], d["batchDateCreated"]) {
        case let d:
            self.created = d!
        case .None:
            self.created = NSDate()
        }
        
        self.caption = d["caption"] as NSString!
        self.contributor = (d["contributorFullName"] as NSString!,
                d["contributorFirstName"] as NSString!,
                d["contributorLastName"] as NSString!)
        self.photoGuuid = d["photoGuid"]! as NSString
        self.url = nil
        self.checksum = thrush(d, "derivatives", String(Int(h)), "checksum") as NSString?
    }
    
    // TODO: Surely there's a better way to do this than having a seperate cache image function?
    func cacheImage() {
        if self.image == nil {
            let r = NSURLRequest(URL: url)
            NSURLConnection.sendAsynchronousRequest(r, queue: NSOperationQueue(), completionHandler: {(r: NSURLResponse!, d: NSData!, e: NSError!) -> Void in
                if e != nil {
                    dispatch_async(dispatch_get_main_queue(), {() -> Void in
                        self.image = NSImage(data: d)
                        })
                }})
        }
    }
}

struct PhotoModel {
    
    static func requestForURLString(urlString: String, payload: String) -> NSURLRequest {
        let url: NSURL = NSURL(string: urlString)
        let req: NSMutableURLRequest = NSMutableURLRequest(URL: url, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 100.0)
        req.HTTPMethod = "POST"
        req.HTTPBody = payload.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
        
        // set the appropriate headers from the cookies
        // these seem to not be necessary for all streams.
        // I'll remove them until I have fully figured out how this works.

        /*let cookie_string = cookies.map({(v:(String, String)) -> String in
            let (header_key, header_value) = v
            return "\(header_key)=\(header_value)"})
        req.setValue((cookie_string as NSArray).componentsJoinedByString("\n"),
            forHTTPHeaderField: "Cookie")*/
        
        req.setValue("(Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.153 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("https://www.icloud.com/photostream/", forHTTPHeaderField: "Referer")
        return req.copy() as NSURLRequest
    }
    
    //------------------------------------------------------------------------
    // Account Functionality
    //------------------------------------------------------------------------
    
    static func load_accounts() -> NSArray {
        if let a:NSArray = NSUserDefaults.standardUserDefaults().objectForKey("accounts") as? NSArray {
           return a
        }
        // otherwise, create it and return empty
        NSUserDefaults.standardUserDefaults().setObject(NSArray(), forKey: "accounts")
        return NSArray()
    }
    
    static func store_accounts(accounts: NSArray) {
        NSUserDefaults.standardUserDefaults().setObject(accounts, forKey: "accounts")
    }
    
    static func addAccount(account: PhotoAccount) {
        // accounts are just stored in the userdefaults
        // we're not using Array just yet, because I suppose it will break the compiler
        // as var p:Array = [1, 2, [3, 4]] does
        var current_accounts: NSMutableArray = self.load_accounts().mutableCopy() as NSMutableArray
        current_accounts.addObject(account.toDictionary())
        store_accounts(current_accounts.copy() as NSArray)
    }
    
    static func removeAccount(account: PhotoAccount) {
        let current_accounts: NSArray = self.load_accounts()
        var mutable_current_accounts: NSMutableArray = current_accounts.mutableCopy() as NSMutableArray
        for a:AnyObject in current_accounts {
            // TODO: There ought to be a better way around this...
            let d = a as NSDictionary
            let u:String = a["userid"]! as String
            if u == account.userid {
                mutable_current_accounts.removeObject(a)
            }
        }
        store_accounts(mutable_current_accounts.copy() as NSArray)
    }
    
    static func accounts() -> Array<PhotoAccount> {
        var r:Array<PhotoAccount> = []
        for d:AnyObject in load_accounts() {
            let o = d as NSDictionary
            r.append(PhotoAccount.fromDictionary(o))
        }
        return r
    }
    
    static func loadAccount(userid: String, host: String, handler: (account: PhotoAccount?, error: NSError?) -> Void) {
        // create a mini account to get the urls
        // TODO: This whole ordeal needs to be cleaned up. It is really not clean
        let ac: PhotoAccount = PhotoAccount(username: "", streamname: "", userid: userid, image_count: 0, host: host)
        // TODO: Duplicate code here (with loadStream)
        let metaRequest: NSURLRequest = self.requestForURLString(ac.streamURLString(), payload: "{\"streamCtag\":null}")
        NSURLConnection.sendAsynchronousRequest(metaRequest, queue: NSOperationQueue(),
            completionHandler: {(r: NSURLResponse!, data: NSData!, e: NSError!) -> Void in
                if e != nil {
                    dispatch_async(dispatch_get_main_queue(), {() -> Void in
                        handler(account: nil, error: e)
                        })
                } else {
                    let jsonResult: NSDictionary = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: nil) as NSDictionary
                    
                    // if we got a forwarding call, we update with the new info
                    if let newHost: String = jsonResult["X-Apple-MMe-Host"] as? String {
                        self.loadAccount(userid, host: newHost, handler: handler)
                        return
                    }
                    
                    // make sure we have the valid keys
                    // TODO: There ought to be a better way to do this
                    if jsonResult["userFirstName"] == nil || jsonResult["userLastName"] == nil ||
                        jsonResult["streamName"] == nil || jsonResult["photos"] == nil {
                            let error = NSError(domain: "Account Error", code: 0, userInfo: nil)
                            handler(account: nil, error: error)
                            return
                    }
                    
                    // return info about this account
                    
                    let username: String = (jsonResult["userFirstName"]! as String) + " " + (jsonResult["userLastName"]! as String)
                    let newAccount: PhotoAccount = PhotoAccount(username: username,
                        streamname: jsonResult["streamName"]! as String,
                        userid: userid,
                        image_count: (jsonResult["photos"]! as NSArray).count,
                        host: ac.host)
                    handler(account: newAccount, error: nil)
                }
        })

    }
    
    //------------------------------------------------------------------------
    // Photos Functionality
    //------------------------------------------------------------------------
    
    // Read the json data from a persons feed,
    // Calls the handler closure when ready
    static func loadStream(account: PhotoAccount, handler: (Array<PhotoObject>) -> ()) {
        
        // we need two requests: One for the metadata
        // one for the actual file urls
        let queue: NSOperationQueue = NSOperationQueue()
        // we want a serial queue, so that we know when the correct data has arrived
        queue.maxConcurrentOperationCount = 1
        
        // This is where we create our pictures
        // TODO: This should not need to be stored in three containers...
        var photo_container: Dictionary<String, PhotoObject> = [:]
        // Dictionaries are not sorted, so we need another list of guids to keep the original order
        var photo_sort: Array<String> = []
        // We need all guids that we intend to request image urls for
        var photo_guids: Array<String> = []
        
        let metaRequest: NSURLRequest = self.requestForURLString(account.streamURLString(), payload: "{\"streamCtag\":null}")
        NSURLConnection.sendAsynchronousRequest(metaRequest, queue: queue,
            completionHandler: {(r: NSURLResponse!, data: NSData!, e: NSError!) -> Void in
                if e != nil {
                    dispatch_async(dispatch_get_main_queue(), {() -> Void in
                        handler([])
                        })
                } else {
                    let jsonResult: NSDictionary = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: nil) as NSDictionary
                    // TODO: A bit verbose and cumbersome, but putting it in one line
                    // crashes the type inferencer
                    var photos: NSArray = jsonResult["photos"] as NSArray
                    for photo:AnyObject in photos {
                        let aPhoto:NSDictionary = photo as NSDictionary
                        
                        // ignore videos (for now)
                        // TODO: Activate them again
                        if aPhoto.objectForKey("mediaAssetType") != nil {
                            continue
                        }
                        
                        let aPhotoObject = PhotoObject(d: aPhoto)
                        if let checksum = aPhotoObject.checksum {
                            photo_container[checksum] = aPhotoObject
                            photo_sort.append(checksum)
                            photo_guids.append(aPhotoObject.photoGuuid)
                        }
                    }
                    
                    // now run the second request. Swift really needs a CSP implementation akin to
                    // go channels, core async. Or just something like akka.
                    
                    // we need a list of guids to get data for
                    let top_100 = photo_guids[0..<(photo_guids.count < 100 ? photo_guids.count : 100)]
                    var guids:NSDictionary = NSDictionary(object: NSArray(array: Array(top_100)), forKey: "photoGuids")
                    
                    var jsonGuids: NSData = NSJSONSerialization.dataWithJSONObject(guids, options: NSJSONWritingOptions.fromMask(0), error: nil)!
                    
                    
                    let fileRequest: NSURLRequest = self.requestForURLString(account.assetURLString(), payload: NSString(data: jsonGuids, encoding: NSUTF8StringEncoding))
                    NSURLConnection.sendAsynchronousRequest(fileRequest, queue: queue,
                        completionHandler: {(r: NSURLResponse!, data: NSData!, e: NSError!) -> Void in
                            
                            let httpResponse: NSHTTPURLResponse = r as NSHTTPURLResponse
                            
                            // sometimes we get empty data packages here. I haven't really understood why yet,
                            if data.length == 0 {
                                handler([])
                                return
                            }
                            
                            let jsonResult: NSDictionary = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: nil) as NSDictionary
                            
                            // our temporary storage for the locations
                            var locationEndPoints: Dictionary<String, String> = [:]
                            
                            // TODO: Why do I have to explicitly cast NS' types all over the place?
                            var locations: NSDictionary = jsonResult["locations"] as NSDictionary
                            let items: NSDictionary = jsonResult["items"] as NSDictionary
                            for key : AnyObject in items.allKeys {
                                var item: NSDictionary = items[key as NSString] as NSDictionary
                                // we build a URL String out of all these items
                                let locationInfo: NSDictionary = locations[item["url_location"] as NSString] as NSDictionary
                                let locationHosts = locationInfo["hosts"] as NSArray
                                if locationHosts.count == 0 {continue}
                                var url: String = (locationInfo["scheme"] as String) + "://" + (locationHosts[0] as String) + (item["url_path"] as String)
                                locationEndPoints[key as String] = url
                                
                                // assign the url
                                if let obj: PhotoObject = photo_container[key as String] {
                                    obj.url = NSURL(string: url)
                                }
                            }
                            
                            // finally, create a sorted array
                            var sortedArray: Array<PhotoObject> = []
                            for key in photo_sort {
                                sortedArray.append(photo_container[key]!)
                            }
                            
                            dispatch_async(dispatch_get_main_queue(), {() -> Void in
                                handler(sortedArray)
                                })
                        })
                    
                }
            })
    }

}


