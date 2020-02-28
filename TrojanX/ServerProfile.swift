//
//  ServerProfile.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/6.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

import Cocoa


class ServerProfile: NSObject, NSCopying {
    
    @objc var uuid: String

    @objc var serverHost: String = ""
    @objc var serverPort: uint16 = 443
    @objc var password:String = ""
    @objc var remark:String = ""
    
    override init() {
        uuid = UUID().uuidString
    }

    init(uuid: String) {
        self.uuid = uuid
    }

    convenience init?(url: URL) {
        self.init()
        if let host = url.host {
            self.serverHost = host;
        }
        if let port = url.port {
            self.serverPort = uint16(port);
        }
        if let pwd = url.user {
            self.password = pwd;
        }
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = ServerProfile()
        copy.serverHost = self.serverHost
        copy.serverPort = self.serverPort
        copy.password = self.password
        copy.remark = self.remark
        return copy;
    }
    
    static func fromDictionary(_ data:[String:Any?]) -> ServerProfile {
        let cp = {
            (profile: ServerProfile) in
            profile.serverHost = data["ServerHost"] as! String
            profile.serverPort = (data["ServerPort"] as! NSNumber).uint16Value
            profile.password = data["Password"] as! String
            if let remark = data["Remark"] {
                profile.remark = remark as! String
            }
        }

        if let id = data["Id"] as? String {
            let profile = ServerProfile(uuid: id)
            cp(profile)
            return profile
        } else {
            let profile = ServerProfile()
            cp(profile)
            return profile
        }
    }

    func toDictionary() -> [String:AnyObject] {
        var d = [String:AnyObject]()
        d["Id"] = uuid as AnyObject?
        d["ServerHost"] = serverHost as AnyObject?
        d["ServerPort"] = NSNumber(value: serverPort as UInt16)
        d["Password"] = password as AnyObject?
        d["Remark"] = remark as AnyObject?
        return d
    }

    func toJsonConfig() -> [String: AnyObject] {
        var conf: [String: AnyObject] = ["password": password as AnyObject,
                                         "method": method as AnyObject,]
        
        let defaults = UserDefaults.standard
        conf["local_port"] = NSNumber(value: UInt16(defaults.integer(forKey: "LocalSocks5.ListenPort")) as UInt16)
        conf["local_address"] = defaults.string(forKey: "LocalSocks5.ListenAddress") as AnyObject?
        conf["timeout"] = NSNumber(value: UInt32(defaults.integer(forKey: "LocalSocks5.Timeout")) as UInt32)
        conf["server"] = serverHost as AnyObject
        conf["server_port"] = NSNumber(value: serverPort as UInt16)

        return conf
    }

    func isValid() -> Bool {
        func validateIpAddress(_ ipToValidate: String) -> Bool {

            var sin = sockaddr_in()
            var sin6 = sockaddr_in6()

            if ipToValidate.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
                // IPv6 peer.
                return true
            }
            else if ipToValidate.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
                // IPv4 peer.
                return true
            }

            return false;
        }

        func validateDomainName(_ value: String) -> Bool {
            let validHostnameRegex = "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$"

            if (value.range(of: validHostnameRegex, options: .regularExpression) != nil) {
                return true
            } else {
                return false
            }
        }

        if !(validateIpAddress(serverHost) || validateDomainName(serverHost)){
            return false
        }

        if password.isEmpty {
            return false
        }

        return true
    }

    func trojanURL(legacy: Bool = false) -> URL? {
        let urlString = String(format: "trojan://%@@%@:%ld",password,serverHost,serverPort)
        return URL(string: urlString)
    }
    
    func title() -> String {
        if remark.isEmpty {
            return "\(serverHost):\(serverPort)"
        } else {
            return "\(remark) (\(serverHost):\(serverPort))"
        }
    }
    
}
