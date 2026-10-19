//
//  SwiftQuit.swift
//  Swift Quit
//
//  Created by Johnny Baird on 5/25/22.
//

import Foundation
import AppKit
import AXSwift
import Swindler
import PromiseKit

class SwiftQuit {
    
    class func activateAutomaticAppClosing(state: Swindler.State){
        state.on { (event: WindowDestroyedEvent) in
            if !event.window.application.knownWindows.isEmpty {
                print("Application still has windows; aborting")
                return
            }
            
            let processIdentifier = event.window.application.processIdentifier
            closeApplication(pid:processIdentifier, eventApp:event.window.application)
        }
    }
    
    class func closeApplication(pid:Int32, eventApp:Swindler.Application) {
        let myAppPid = ProcessInfo.processInfo.processIdentifier

        guard let app = AppKit.NSRunningApplication.init(processIdentifier: pid) else {
            print("Application with PID \(pid) no longer running")
            return
        }

        guard let bundleURL = app.bundleURL else {
            print("Application with PID \(pid) has no bundle URL")
            return
        }
        var applicationName = bundleURL.absoluteString

        print(app.isFinishedLaunching);
        
        if(app.isFinishedLaunching){
            applicationName.remove(at: applicationName.index(before: applicationName.endIndex))
            applicationName = applicationName.replacingOccurrences(of: "file://", with: "")
            applicationName = applicationName.replacingOccurrences(of: "%20", with: " ")
            
            if(myAppPid != pid){
                
                let excludedServices:[String] = ["/System/Library/CoreServices/Spotlight.app","/System/Library/CoreServices/Finder.app","/System/Library/CoreServices/NotificationCenter.app"];
                
                if(!excludedServices.contains(applicationName)){
                    if (shouldCloseApplication(applicationName: applicationName)) {
                        
                        print(applicationName)
                        
                        let closeDelay = AppSettings.shared.closeDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(closeDelay)) {
                            if eventApp.knownWindows.isEmpty {
                                terminateApplication(app: app)
                            }
                        }
                    }
                }
            }
        }
        
        
    }
    
    class func shouldCloseApplication(applicationName:String) -> Bool {
        return (AppSettings.shared.ruleMode == .excludeApps && !AppSettings.shared.applicationPaths.contains(applicationName)) || (AppSettings.shared.ruleMode == .includeApps && AppSettings.shared.applicationPaths.contains(applicationName))
    }
    
    class func terminateApplication(app:NSRunningApplication) {
        print("Terminated " + (app.localizedName ?? "<no_name>"))
        app.terminate()
    }
    
}
