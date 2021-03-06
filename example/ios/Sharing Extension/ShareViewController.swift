//
//  ShareViewController.swift
//  Sharing Extension
//
//  Created by Kasem Mohamed on 2019-05-30.
//  Modified by Manuel Klemm on 2019-12-02.
//  Copyright © 2019 The Chromium Authors. All rights reserved.
//

import UIKit
import Social
import MobileCoreServices
import Photos

class ShareViewController: SLComposeServiceViewController {
    // TODO: IMPORTANT: This should be your host app bundle identifier
    let hostAppBundleIdentifier = "com.craftbuddy"
    let sharedKey = "ShareKey"
    var sharedData: [String] = []
    let imageContentType = kUTTypeImage as String
    let textContentType = kUTTypeText as String
    let urlContentType = kUTTypeURL as String
    let videoContentType = kUTTypeMovie as String
    let fileContentType = kUTTypeItem as String
    
    override func isContentValid() -> Bool {
        return true
    }
    
    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        if let content = extensionContext!.inputItems[0] as? NSExtensionItem {
            if let contents = content.attachments {
                for (index, attachment) in (contents as! [NSItemProvider]).enumerated() {
                    if attachment.hasItemConformingToTypeIdentifier(imageContentType) {
                        handleImages(content: content, attachment: attachment, index: index)
                    } else if attachment.hasItemConformingToTypeIdentifier(textContentType) {
                        handleText(content: content, attachment: attachment, index: index)
                    } else if attachment.hasItemConformingToTypeIdentifier(videoContentType) {
                        handleVideos(content: content, attachment: attachment, index: index)
                    } else {
                        handleFiles(content: content, attachment: attachment, index: index)
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        print("didSelectPost");
    }
    
    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }
    
    private func handleText (content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: textContentType, options: nil) { [weak self] data, error in
            
            if error == nil, let item = data as? String, let this = self {
                this.sharedData.append(item)
                
                // If this is the last item, save imagesData in userDefaults and redirect to host app
                if index == (content.attachments?.count)! - 1 {
                    let userDefaults = UserDefaults(suiteName: "group.\(this.hostAppBundleIdentifier)")
                    userDefaults?.set(this.sharedData, forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .text)
                    this.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                }
            } else {
                self?.dismissWithError()
            }
        }
    }
    
    private func handleImages (content: NSExtensionItem, attachment: NSItemProvider, index: Int){
        attachment.loadItem(forTypeIdentifier: imageContentType, options: nil) { [weak self] data, error in
            if error == nil, let url = data as? URL, let this = self {
                let componentList = url.path.components(separatedBy: "/")
                let fileName = componentList.last
                let newPath = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: "group.\(this.hostAppBundleIdentifier)")!.appendingPathComponent(fileName!)
                let copied = this.copyFile(at: url, to: newPath)
                if(copied) {
                    this.sharedData.append(newPath.absoluteString)
                }
                if index == (content.attachments?.count)! - 1 {
                    let userDefaults = UserDefaults(suiteName: "group.\(this.hostAppBundleIdentifier)")
                    userDefaults?.set(this.sharedData, forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                    this.redirectToHostApp(type: .file)
                }
            } else {
                self?.dismissWithError()
            }
        }
    }
    
    
    
    private func handleUrl (content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: urlContentType, options: nil) { [weak self] data, error in
            
            if error == nil, let item = data as? URL, let this = self {
                this.sharedData.append(item.absoluteString)
                
                // If this is the last item, save imagesData in userDefaults and redirect to host app
                if index == (content.attachments?.count)! - 1 {
                    let userDefaults = UserDefaults(suiteName: "group.\(this.hostAppBundleIdentifier)")
                    userDefaults?.set(this.sharedData, forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .text)
                    this.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                }
                
            } else {
                self?.dismissWithError()
            }
        }
    }
    
    private func handleVideos (content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: videoContentType, options: nil) { [weak self] data, error in
            
            if error == nil, let url = data as? URL, let this = self {
                let fileExtension = this.getExtension(from: url, type: .video)
                let newName = UUID().uuidString
                let newPath = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: "group.\(this.hostAppBundleIdentifier)")!
                    .appendingPathComponent("\(newName).\(fileExtension)")
                let copied = this.copyFile(at: url, to: newPath)
                if(copied) {
                    this.sharedData.append(newPath.absoluteString)
                }
                
                // If this is the last item, save imagesData in userDefaults and redirect to host app
                if index == (content.attachments?.count)! - 1 {
                    let userDefaults = UserDefaults(suiteName: "group.\(this.hostAppBundleIdentifier)")
                    //userDefaults?.set(this.toData(data: this.sharedMedia), forKey: this.sharedKey)
                    userDefaults?.set(this.sharedData, forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .file)
                    this.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                }
                
            } else {
                self?.dismissWithError()
            }
        }
    }
    private func handleFiles (content: NSExtensionItem, attachment: NSItemProvider, index: Int){
        attachment.loadItem(forTypeIdentifier: urlContentType, options: nil) { [weak self] data, error in
            
            if error == nil, let url = data as? URL, let this = self {
                let componentList = url.path.components(separatedBy: "/")
                let component = componentList.last
                let fileName = component
                
                // If we could not find the file then copy it
                let newPath = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: "group.\(this.hostAppBundleIdentifier)")!.appendingPathComponent(fileName!)
                let copied = this.copyFile(at: url, to: newPath)
                let newPath2 = newPath.absoluteString
                if(copied) {
                    this.sharedData.append(newPath2.removingPercentEncoding ?? "")
                }
                
                // If this is the last item, save file in userDefaults and redirect to host app
                if index == (content.attachments?.count)! - 1 {
                    let userDefaults = UserDefaults(suiteName: "group.\(this.hostAppBundleIdentifier)")
                    userDefaults?.set(this.sharedData, forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .file)
                    this.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                } else {
                    self?.dismissWithError()
                }
                
            } else {
                self?.dismissWithError()
            }
        }
    }
    
    private func dismissWithError(){
        print("GETTING ERROR")
        let alert = UIAlertController(title: "Error", message: "Error loading image", preferredStyle: .alert)
        
        let action = UIAlertAction(title: "Error", style: .cancel) { _ in
            self.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    private func redirectToHostApp(type: RedirectType) {
        let url = URL(string: "SharePhotos://dataUrl=\(sharedKey)#\(type)")
        var responder = self as UIResponder?
        let selectorOpenURL = sel_registerName("openURL:")
        
        while (responder != nil) {
            if (responder?.responds(to: selectorOpenURL))! {
                let _ = responder?.perform(selectorOpenURL, with: url)
            }
            responder = responder!.next
        }
    }
    
    enum RedirectType {
        case file
        case text
    }
    
    /// Key is the matched asset's original file name without suffix. E.g. IMG_193
    private lazy var imageAssetDictionary: [String : PHAsset] = {
        
        let options = PHFetchOptions()
        options.includeHiddenAssets = true
        
        let fetchResult = PHAsset.fetchAssets(with: options)
        
        var assetDictionary = [String : PHAsset]()
        
        for i in 0 ..< fetchResult.count {
            let asset = fetchResult[i]
            let fileName = asset.value(forKey: "filename") as! String
            let fileNameWithoutSuffix = fileName.components(separatedBy: ".").first!
            assetDictionary[fileNameWithoutSuffix] = asset
        }
        
        return assetDictionary
    }()
    func getExtension(from url: URL, type: SharedMediaType) -> String {
        let parts = url.lastPathComponent.components(separatedBy: ".")
        var ex: String? = nil
        if (parts.count > 1) {
            ex = parts.last
        }
        
        if (ex == nil) {
            switch type {
            case .image:
                ex = "PNG"
            case .video:
                ex = "MP4"
            }
        }
        return ex ?? "Unknown"
    }
    func copyFile(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.removeItem(at: dstURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
        } catch (let error) {
            print("Cannot copy item at \(srcURL) to \(dstURL): \(error)")
            return false
        }
        return true
    }
    private func getSharedMediaFile(forVideo: URL) -> SharedMediaFile? {
        let asset = AVAsset(url: forVideo)
        let duration = (CMTimeGetSeconds(asset.duration) * 1000).rounded()
        let thumbnailPath = getThumbnailPath(for: forVideo)
        
        if FileManager.default.fileExists(atPath: thumbnailPath.path) {
            return SharedMediaFile(path: forVideo.absoluteString, thumbnail: thumbnailPath.absoluteString, duration: duration, type: .video)
        }
        
        var saved = false
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        //        let scale = UIScreen.main.scale
        assetImgGenerate.maximumSize =  CGSize(width: 360, height: 360)
        do {
            let img = try assetImgGenerate.copyCGImage(at: CMTimeMakeWithSeconds(1.0, 600), actualTime: nil)
            try UIImagePNGRepresentation(UIImage(cgImage: img))?.write(to: thumbnailPath)
            saved = true
        } catch {
            saved = false
        }
        
        return saved ? SharedMediaFile(path: forVideo.absoluteString, thumbnail: thumbnailPath.absoluteString, duration: duration, type: .video) : nil
        
    }
    
    private func getThumbnailPath(for url: URL) -> URL {
        let fileName = Data(url.lastPathComponent.utf8).base64EncodedString().replacingOccurrences(of: "==", with: "")
        let path = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.\(hostAppBundleIdentifier)")!
            .appendingPathComponent("\(fileName).jpg")
        return path
    }
    
    class SharedMediaFile: Codable {
        var path: String; // can be image, video or url path. It can also be text content
        var thumbnail: String?; // video thumbnail
        var duration: Double?; // video duration in milliseconds
        var type: SharedMediaType;
        
        init(path: String, thumbnail: String?, duration: Double?, type: SharedMediaType) {
            self.path = path
            self.thumbnail = thumbnail
            self.duration = duration
            self.type = type
        }
    }
    
    enum SharedMediaType: Int, Codable {
        case image
        case video
    }
    
    func toData(data: [SharedMediaFile]) -> Data {
        let encodedData = try? JSONEncoder().encode(data)
        return encodedData!
    }
}

extension Array {
    subscript (safe index: UInt) -> Element? {
        return Int(index) < count ? self[Int(index)] : nil
    }
}
