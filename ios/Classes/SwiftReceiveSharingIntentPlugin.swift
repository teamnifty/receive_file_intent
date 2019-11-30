import Flutter
import UIKit
import Photos

public class SwiftReceiveSharingIntentPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    static let kMessagesChannel = "receive_sharing_intent/messages";
    static let kEventsChannelFile = "receive_sharing_intent/events-file";
    static let kEventsChannelLink = "receive_sharing_intent/events-text";
    
    private var initialFile: [String]? = nil
    private var latestFile: [String]? = nil
    
    private var initialText: String? = nil
    private var latestText: String? = nil
    
    private var eventSinkFile: FlutterEventSink? = nil;
    private var eventSinkText: FlutterEventSink? = nil;
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftReceiveSharingIntentPlugin()
        
        let channel = FlutterMethodChannel(name: kMessagesChannel, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let chargingChannelFile = FlutterEventChannel(name: kEventsChannelFile, binaryMessenger: registrar.messenger())
        chargingChannelFile.setStreamHandler(instance)
        
        let chargingChannelLink = FlutterEventChannel(name: kEventsChannelLink, binaryMessenger: registrar.messenger())
        chargingChannelLink.setStreamHandler(instance)
        
        registrar.addApplicationDelegate(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        switch call.method {
        case "getInitialFile":
            result(self.initialFile);
        case "getInitialText":
            result(self.initialText);
        case "reset":
            self.initialFile = nil
            self.latestFile = nil
            self.initialText = nil
            self.latestText = nil
            result(nil);
        default:
            result(FlutterMethodNotImplemented);
        }
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
        if let url = launchOptions[UIApplicationLaunchOptionsKey.url] as? URL {
            return handleUrl(url: url, setInitialData: true)
        } else if let activityDictionary = launchOptions[UIApplicationLaunchOptionsKey.userActivityDictionary] as? [AnyHashable: Any] { //Universal link
            for key in activityDictionary.keys {
                if let userActivity = activityDictionary[key] as? NSUserActivity {
                    if let url = userActivity.webpageURL {
                        return handleUrl(url: url, setInitialData: true)
                    }
                }
            }
        }
        return false
    }
    
    public func application(_ application: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return handleUrl(url: url, setInitialData: false)
    }
    
    public func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]) -> Void) -> Bool {
        return handleUrl(url: userActivity.webpageURL, setInitialData: true)
    }
    
    private func handleUrl(url: URL?, setInitialData: Bool) -> Bool {
        if let url = url {
            let appDomain = Bundle.main.bundleIdentifier!
            let userDefaults = UserDefaults(suiteName: "group.\(appDomain)")
            if url.fragment == "text" {
                if let key = url.host?.components(separatedBy: "=").last,
                    let sharedArray = userDefaults?.object(forKey: key) as? [String] {
                    latestText =  sharedArray.joined(separator: ",")
                    if(setInitialData) {
                        initialText = latestText
                    }
                    eventSinkText?(latestText)
                }
            } else {
                if let key = url.host?.components(separatedBy: "=").last,
                    let sharedArray = userDefaults?.object(forKey: key) as? [String] {
                    let absoluteUrls = sharedArray.compactMap{getAbsolutePath(for: $0)}
                    latestFile = absoluteUrls
                    if(setInitialData) {
                        initialFile = latestFile
                    }
                    eventSinkFile?(latestFile)
                }
            }
            return true
        }
        
        latestFile = nil
        latestText = nil
        return false
    }
    
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
       if (arguments as! String? == "text") {
            eventSinkText = events;
        } else {
            eventSinkFile = events;
        }
        return nil;
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if (arguments as! String? == "text") {
            eventSinkText = nil;
        } else {
            eventSinkFile = nil;
        }
        return nil;
    }
    
    private func getAbsolutePath(for identifier: String) -> String? {
        if (identifier.starts(with: "file://") || identifier.starts(with: "/var/mobile/Media") || identifier.starts(with: "/private/var/mobile")) {
            return identifier.replacingOccurrences(of: "file://", with: "")
        }
        let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: .none).firstObject
        if(phAsset == nil) {
            return nil
        }
        var url: String?
        
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImageData(for: phAsset!, options: options) { (data, fileName, orientation, info) in
            url = (info?["PHImageFileURLKey"] as? NSURL)?.absoluteString?.replacingOccurrences(of: "file://", with: "")
        }
        return url
    }
}
