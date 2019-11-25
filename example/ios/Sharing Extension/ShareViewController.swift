//
//  ShareViewController.swift
//  Sharing Extension
//
//  Created by Kasem Mohamed on 2019-05-30.
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
    
    
    private func handleFiles (content: NSExtensionItem, attachment: NSItemProvider, index: Int){
        attachment.loadItem(forTypeIdentifier: urlContentType, options: nil) { [weak self] data, error in
            
            if error == nil, let url = data as? URL, let this = self {
                
                //for component in url.path.components(separatedBy: "/") where component.contains(".pdf") {
                let componentList = url.path.components(separatedBy: "/")
                let component = componentList.last
                //let fileName = component.components(separatedBy: ".").first!
                let fileName = component
                if let asset = this.imageAssetDictionary[fileName!] {
                        this.sharedData.append( asset.localIdentifier)
                    } else {
                        // If we could not find the file then copy it
                        let newPath = FileManager.default
                            .containerURL(forSecurityApplicationGroupIdentifier: "group.\(this.hostAppBundleIdentifier)")!.appendingPathComponent(fileName!)
                        let copied = this.copyFile(at: url, to: newPath)
                        if(copied) {
                            this.sharedData.append(newPath.absoluteString)
                        }
                    }
                    //break
                //}
                
                // If this is the last item, save imagesData in userDefaults and redirect to host app
                if index == (content.attachments?.count)! - 1 {
                    let userDefaults = UserDefaults(suiteName: "group.\(this.hostAppBundleIdentifier)")
                    userDefaults?.set(this.sharedData, forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                    this.redirectToHostApp(type: .text)
                } else {
                    self?.dismissWithError()
                }
                
            } else {
                self?.dismissWithError()
            }
        }
    }
    
    private func handleImages (content: NSExtensionItem, attachment: NSItemProvider, index: Int){
        attachment.loadItem(forTypeIdentifier: imageContentType, options: nil) { [weak self] data, error in
            if error == nil, let url = data as? URL, let this = self {
                //for component in url.path.components(separatedBy: "/") where component.contains("IMG_") {
                let componentList = url.path.components(separatedBy: "/")
                let component = componentList.last
                //let fileName = component!.components(separatedBy: ".").first!
                let fileName = component
                if let asset = this.imageAssetDictionary[fileName!] {
                    this.sharedData.append( asset.localIdentifier)
                } else {
                    // If we could not find the file then copy it
                    let newPath = FileManager.default
                        .containerURL(forSecurityApplicationGroupIdentifier: "group.\(this.hostAppBundleIdentifier)")!.appendingPathComponent(fileName!)
                    let copied = this.copyFile(at: url, to: newPath)
                    if(copied) {
                        this.sharedData.append(newPath.absoluteString)
                    }
                }
                   // break
                //}
                // If this is the last item, save imagesData in userDefaults and redirect to host app
                if index == (content.attachments?.count)! - 1 {
                    let userDefaults = UserDefaults(suiteName: "group.\(this.hostAppBundleIdentifier)")
                    userDefaults?.set(this.sharedData, forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                    this.redirectToHostApp(type: .text)
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
        case image
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
}
