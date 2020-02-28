//
//  BGUtils.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/6.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

import Foundation

let APP_SUPPORT_DIR = "/Library/Application Support/TrojanX/"
let LAUNCH_AGENT_DIR = "/Library/LaunchAgents/"
let LAUNCH_AGENT_CONF_SSLOCAL_NAME = "TrojanX.trojan.plist"
let LAUNCH_AGENT_CONF_PRIVOXY_NAME = "TrojanX.http.plist"


func getFileSHA1Sum(_ filepath: String) -> String {
    if let data = try? Data(contentsOf: URL(fileURLWithPath: filepath)) {
        return data.sha1()
    }
    return ""
}

// Ref: https://developer.apple.com/library/mac/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html
// Genarate the mac launch agent service plist

//  MARK: trojan

func generateSSLocalLauchAgentPlist() -> Bool {
    let sslocalPath = NSHomeDirectory() + APP_SUPPORT_DIR + "trojan"
    let logFilePath = NSHomeDirectory() + "/Library/Logs/trojan.log"
    let launchAgentDirPath = NSHomeDirectory() + LAUNCH_AGENT_DIR
    let plistFilepath = launchAgentDirPath + LAUNCH_AGENT_CONF_SSLOCAL_NAME
    
    // Ensure launch agent directory is existed.
    let fileMgr = FileManager.default
    if !fileMgr.fileExists(atPath: launchAgentDirPath) {
        try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let oldSha1Sum = getFileSHA1Sum(plistFilepath)
    let arguments = [sslocalPath, "-c", "trojan.json"]
    
    let dict: NSMutableDictionary = [
        "Label": "TrojanX.trojan",
        "WorkingDirectory": NSHomeDirectory() + APP_SUPPORT_DIR,
        "StandardOutPath": logFilePath,
        "StandardErrorPath": logFilePath,
        "ProgramArguments": arguments
    ]
    dict.write(toFile: plistFilepath, atomically: true)
    let Sha1Sum = getFileSHA1Sum(plistFilepath)
    if oldSha1Sum != Sha1Sum {
        NSLog("generateSSLocalLauchAgentPlist - File has been changed.")
        return true
    } else {
        NSLog("generateSSLocalLauchAgentPlist - File has not been changed.")
        return false
    }
}

func StartSSLocal() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "start_trojan.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Start Trojan succeeded.")
    } else {
        NSLog("Start Trojan failed.")
    }
}

func StopSSLocal() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "stop_trojan.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Stop Trojan succeeded.")
    } else {
        NSLog("Stop Trojan failed.")
    }
}

func InstallSSLocal() {
    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir+APP_SUPPORT_DIR
    if !fileMgr.fileExists(atPath: appSupportDir + "trojan") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_trojan.sh", ofType: nil)
        let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install Trojan succeeded.")
        } else {
            NSLog("Install Trojan failed.")
        }
    }
}

func writeSSLocalConfFile(profile: ServerProfile) -> Bool {
    do {
        let defaults = UserDefaults.standard
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "trojan.json"
        
        let remote_addr = profile.serverHost
        let remote_port = String(profile.serverPort)
        let local_addr = defaults.string(forKey: "LocalSocks5.ListenAddress")!
        let local_port = String(defaults.integer(forKey: "LocalSocks5.ListenPort"))
        let password = profile.password
        
        let conf_local = "{\"run_type\":\"client\",\"local_addr\":\"" + local_addr + "\",\"local_port\":" + local_port
        let conf_remote = ",\"remote_addr\":\"" + remote_addr + "\",\"remote_port\":" + remote_port
        let conf_pass = ",\"password\":[\"" + password + "\"],"
        let conf_other = "\"log_level\":2,\"ssl\":{\"verify\":false,\"verify_hostname\":false,\"cert\":\"\",\"cipher\":\"\",\"cipher_tls13\":\"TLS_CHACHA20_POLY1305_SHA256\",\"sni\":\"\",\"alpn\":[\"h2\"],\"reuse_session\":true,\"session_ticket\":false,\"curves\":\"\"},\"tcp\":{\"no_delay\":true,\"keep_alive\":true,\"reuse_port\":false,\"fast_open\":false,\"fast_open_qlen\":20}}"
        
        let confJson = conf_local + conf_remote + conf_pass + conf_other

        let oldSum = getFileSHA1Sum(filepath)
        try confJson.write(to: URL(fileURLWithPath: filepath), atomically: true, encoding: String.Encoding.utf8)
        let newSum = getFileSHA1Sum(filepath)

        if oldSum == newSum {
            NSLog("writeSSLocalConfFile - File has not been changed.")
            return false
        }

        NSLog("writeSSLocalConfFile - File has been changed.")
        return true
    } catch {
        NSLog("Write trojan.json file failed.")
    }
    return false
}

func removeSSLocalConfFile() {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "trojan.json"
        try FileManager.default.removeItem(atPath: filepath)
    } catch {
    }
}

func SyncSSLocal() {
    var changed: Bool = false
    changed = changed || generateSSLocalLauchAgentPlist()
    let mgr = ServerProfileManager.instance
    if mgr.activeProfileId != nil {
        if let profile = mgr.getActiveProfile() {
            changed = changed || writeSSLocalConfFile(profile: profile)
        }
        
        let on = UserDefaults.standard.bool(forKey: "ShadowsocksOn")
        if on {
            if changed {
                StopSSLocal()
                DispatchQueue.main.asyncAfter(
                    deadline: DispatchTime.now() + DispatchTimeInterval.seconds(2),
                    execute: {
                        () in
                        StartSSLocal()
                })
            } else {
                StartSSLocal()
            }
        } else {
            StopSSLocal()
        }
    } else {
        removeSSLocalConfFile()
        StopSSLocal()
    }
    SyncPac()
    SyncPrivoxy()
}

// --------------------------------------------------------------------------------
//  MARK: privoxy

func generatePrivoxyLauchAgentPlist() -> Bool {
    let privoxyPath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy"
    let logFilePath = NSHomeDirectory() + "/Library/Logs/privoxy.log"
    let launchAgentDirPath = NSHomeDirectory() + LAUNCH_AGENT_DIR
    let plistFilepath = launchAgentDirPath + LAUNCH_AGENT_CONF_PRIVOXY_NAME
    
    // Ensure launch agent directory is existed.
    let fileMgr = FileManager.default
    if !fileMgr.fileExists(atPath: launchAgentDirPath) {
        try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let oldSha1Sum = getFileSHA1Sum(plistFilepath)
    
    let arguments = [privoxyPath, "--no-daemon", "privoxy.config"]
    
    // For a complete listing of the keys, see the launchd.plist manual page.
    let dict: NSMutableDictionary = [
        "Label": "TrojanX.http",
        "WorkingDirectory": NSHomeDirectory() + APP_SUPPORT_DIR,
        "StandardOutPath": logFilePath,
        "StandardErrorPath": logFilePath,
        "ProgramArguments": arguments
    ]
    dict.write(toFile: plistFilepath, atomically: true)
    let Sha1Sum = getFileSHA1Sum(plistFilepath)
    if oldSha1Sum != Sha1Sum {
        return true
    } else {
        return false
    }
}

func StartPrivoxy() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "start_privoxy.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Start privoxy succeeded.")
    } else {
        NSLog("Start privoxy failed.")
    }
}

func StopPrivoxy() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "stop_privoxy.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Stop privoxy succeeded.")
    } else {
        NSLog("Stop privoxy failed.")
    }
}

func InstallPrivoxy() {
    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir+APP_SUPPORT_DIR
    if !fileMgr.fileExists(atPath: appSupportDir + "privoxy") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_privoxy.sh", ofType: nil)
        let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install privoxy succeeded.")
        } else {
            NSLog("Install privoxy failed.")
        }
    }
}

func writePrivoxyConfFile() -> Bool {
    do {
        let defaults = UserDefaults.standard
        let bundle = Bundle.main
        let examplePath = bundle.path(forResource: "privoxy.config.example", ofType: nil)
        var example = try String(contentsOfFile: examplePath!, encoding: .utf8)
        example = example.replacingOccurrences(of: "{http}", with: defaults.string(forKey: "LocalHTTP.ListenAddress")! + ":" + String(defaults.integer(forKey: "LocalHTTP.ListenPort")))
        example = example.replacingOccurrences(of: "{socks5}", with: defaults.string(forKey: "LocalSocks5.ListenAddress")! + ":" + String(defaults.integer(forKey: "LocalSocks5.ListenPort")))
        let data = example.data(using: .utf8)
        
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy.config"
        
        let oldSum = getFileSHA1Sum(filepath)
        try data?.write(to: URL(fileURLWithPath: filepath), options: .atomic)
        let newSum = getFileSHA1Sum(filepath)
        
        if oldSum == newSum {
            return false
        }
        
        return true
    } catch {
        NSLog("Write privoxy file failed.")
    }
    return false
}

func removePrivoxyConfFile() {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy.config"
        try FileManager.default.removeItem(atPath: filepath)
    } catch {
        
    }
}

func SyncPrivoxy() {
    var changed: Bool = false
    changed = changed || generatePrivoxyLauchAgentPlist()
    let mgr = ServerProfileManager.instance
    if mgr.activeProfileId != nil {
        changed = changed || writePrivoxyConfFile()
        
        let on = UserDefaults.standard.bool(forKey: "LocalHTTPOn")
        if on {
            if changed {
                StopPrivoxy()
                DispatchQueue.main.asyncAfter(
                    deadline: DispatchTime.now() + DispatchTimeInterval.seconds(1),
                    execute: {
                        () in
                        StartPrivoxy()
                })
            } else {
                StartPrivoxy()
            }
        } else {
            StopPrivoxy()
        }
    } else {
        removePrivoxyConfFile()
        StopPrivoxy()
    }
}
