

import Foundation
import NetworkExtension
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
import Security
#elseif os(tvOS)
typealias FlutterResult = (Any?) -> Void
#endif

let kProxyServiceVPNStatusNotification = "kProxyServiceVPNStatusNotification"

enum FlutterVpnState: Int {
    case invalid
    case disconnected
    case connecting
    case connected
    case reasserting
    case disconnecting
}

enum TunnelStatus {
    case off
    case connecting
    case on
    case disconnecting
}

struct Message: Codable {
    var messageId: String = ""
    var messageParams: String = ""
}

class VpnServiceHandler {
    public var bundleIdentifier: String = ""
    public var configFilePath: String = ""
    public var uiServerAddress: String = ""
    public var uiLocalizedDescription: String = ""
    #if os(macOS)
    public var perapp: Bool = false
    #endif

    static let shared = VpnServiceHandler()
    var observerAdded: Bool = false

    fileprivate(set) var tunnelStatus = TunnelStatus.off {
        didSet {
            NotificationCenter.default.post(name: Notification.Name(rawValue: kProxyServiceVPNStatusNotification), object: nil)
        }
    }

    init() {
        loadProviderManager {
            guard let manager = $0 else { return }
            self.updateTunnelStatus(manager)
        }
        addVPNStatusObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func addVPNStatusObserver() {
        guard !observerAdded else {
            return
        }
        loadProviderManager { [unowned self] manager in
            if let manager = manager {
                self.observerAdded = true
                NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: manager.connection, queue: OperationQueue.main, using: { [unowned self] _ in
                    self.updateTunnelStatus(manager)
                })
            }
        }
    }

    func updateTunnelStatus(_ manager: NEVPNManager) {
        switch manager.connection.status {
        case .connecting:
            tunnelStatus = .connecting
        case .connected:
            tunnelStatus = .on
        case .disconnecting:
            tunnelStatus = .disconnecting
        case .disconnected:
            tunnelStatus = .off
        case .invalid:
            tunnelStatus = .off
        case .reasserting:
            tunnelStatus = .connecting
            break
        @unknown default:
            break
        }
    }
}

extension VpnServiceHandler {
    fileprivate func createProviderManager() -> NETunnelProviderManager {
        // #if os(macOS)
        // let manager = NETunnelProviderManager.forPerAppVPN()
        // #else
        let manager = NETunnelProviderManager()
        // #endif

        let conf = NETunnelProviderProtocol()
        conf.serverAddress = uiServerAddress
        conf.providerBundleIdentifier = bundleIdentifier

        manager.protocolConfiguration = conf
        manager.localizedDescription = uiLocalizedDescription
        return manager
    }

    func loadAndCreatePrividerManager(_ complete: @escaping (NETunnelProviderManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, _ in
            guard let managers = managers else {
                complete(nil)
                return
            }
            let manager: NETunnelProviderManager
            if managers.count > 0 {
                manager = managers[0]
                self.delDupConfig(managers)
            }
            else {
                manager = self.createProviderManager()
            }

            manager.isEnabled = true
            self.setRulerConfig(manager)

            manager.saveToPreferences {
                if $0 != nil {}
                manager.loadFromPreferences {
                    if $0 != nil {
                        NSLog($0.debugDescription)
                        complete(nil)
                        return
                    }
                    self.addVPNStatusObserver()
                    complete(manager)
                }
            }
        }
    }

    func loadProviderManager(_ complete: @escaping (NETunnelProviderManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, _ in
            if let managers = managers {
                if managers.count > 0 {
                    let manager = managers[0]
                    complete(manager)
                    return
                }
            }
            complete(nil)
        }
    }

    func unloadProviderManager(_ complete: @escaping (String?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let managers = managers {
                if managers.count > 0 {
                    let manager = managers[0]
                    manager.removeFromPreferences { error in
                        if error != nil {
                            complete(error!.localizedDescription)
                            return
                        }
                        complete(nil)
                    }
                }
                else {
                    complete(nil)
                }
            }
            else {
                complete(nil)
            }
        }
    }

    func delDupConfig(_ arrays: [NETunnelProviderManager]) {
        if (arrays.count) > 1 {
            for i in 0 ..< arrays.count {
                arrays[i].removeFromPreferences(completionHandler: { error in
                    if error != nil {
                        NSLog(error.debugDescription)
                    }
                })
            }
        }
    }
}

extension VpnServiceHandler {
    func install(result: @escaping FlutterResult) {
        loadAndCreatePrividerManager { manager in
            guard let _ = manager else {
                result("create vpn config failed")
                return
            }
            result(nil)
        }
    }

    func isInstall(result: @escaping FlutterResult) {
        loadProviderManager {
            guard let manager = $0 else {
                result(false)
                return
            }

            result(true)
        }
    }

    func uninstall(result: @escaping FlutterResult) {
        unloadProviderManager(result)
    }

    func start(result: @escaping FlutterResult) {
        loadAndCreatePrividerManager { manager in
            guard let mgr = manager else {
                result("start vpn failed")
                return
            }
            do {
                try mgr.connection.startVPNTunnel(options: [:])
                result(nil)
            }
            catch let err {
                result(err.localizedDescription)
            }
        }
    }

    func stop(result: @escaping FlutterResult) {
        loadProviderManager {
            guard let manager = $0 else {
                result(nil)
                return
            }
            manager.connection.stopVPNTunnel()
            result(nil)
        }
    }

    func restart(result: @escaping FlutterResult) {
        var message = Message()
        message.messageId = "restart"
        sendmessage(message: message, result: result)
    }

    func getState(result: @escaping FlutterResult) {
        loadProviderManager {
            guard let manager = $0 else {
                result(FlutterVpnState.invalid.rawValue)
                return
            }
            switch manager.connection.status {
            case .connecting:
                result(FlutterVpnState.connecting.rawValue)
            case .connected:
                result(FlutterVpnState.connected.rawValue)
            case .disconnecting:
                result(FlutterVpnState.disconnecting.rawValue)
            case .disconnected:
                result(FlutterVpnState.disconnected.rawValue)
            case .invalid:
                result(FlutterVpnState.invalid.rawValue)
            case .reasserting:
                result(FlutterVpnState.reasserting.rawValue)
                break
            @unknown default:
                result(FlutterVpnState.invalid.rawValue)
            }
        }
    }

    func sendmessage(message: Message, result: @escaping FlutterResult) {
        let body: Data = try! JSONEncoder().encode(message)
        loadProviderManager {
            guard let manager = $0 else {
                result(nil)
                return
            }
            let session = manager.connection as? NETunnelProviderSession
            do {
                try session?.sendProviderMessage(body) { response in
                    guard let rspdata = response else {
                        return result(nil)
                    }
                    result(String(data: rspdata, encoding: .utf8)!)
                }
            }
            catch let err {
                result(err.localizedDescription)
            }
        }
    }

    func setAlwaysOn(enable: Bool, result: @escaping FlutterResult) {
        loadProviderManager {
            guard let manager = $0 else {
                result(nil)
                return
            }
            self.setOnDemandRules(manager, enable: enable)
            result(nil)
        }
    }

    fileprivate func setRulerConfig(_ manager: NETunnelProviderManager) {
        var conf = [String: AnyObject]()
        conf["configFilePath"] = configFilePath as AnyObject?

        let orignConf = manager.protocolConfiguration as! NETunnelProviderProtocol
        orignConf.providerConfiguration = conf
        manager.protocolConfiguration = orignConf
    }

    fileprivate func setOnDemandRules(_ manager: NETunnelProviderManager, enable: Bool) {
        let interfaceRule = NEOnDemandRuleConnect()
        interfaceRule.interfaceTypeMatch = .any
        let probeRule = NEOnDemandRuleConnect()
        probeRule.probeURL = URL(string: "http://captive.apple.com")
        manager.isOnDemandEnabled = enable
        manager.onDemandRules = [interfaceRule, probeRule]
        manager.saveToPreferences()
    }

    #if os(macOS)
    fileprivate func getAppRule(_ identifiers: [String]) -> [NEAppRule] {
        var appRules = [NEAppRule]()
        for identifier in identifiers {
            if let designatedRequirement = getDesignatedRequirement(for: identifier) {
                appRules.append(NEAppRule(signingIdentifier: identifier, designatedRequirement: designatedRequirement))
            }
        }
        return appRules
    }

    func getDesignatedRequirement(for bundleIdentifier: String) -> String? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            print("Could not find the application with bundle identifier: \(bundleIdentifier)")
            return nil
        }

        var appSec: SecStaticCode?
        SecStaticCodeCreateWithPath(appURL as CFURL, [], &appSec)

        if appSec == nil {
            print("Failed to retrieve the designated path: \(appURL)")
            return nil
        }

        var requirement: SecRequirement?
        SecCodeCopyDesignatedRequirement(appSec!, [], &requirement)
        if requirement == nil {
            print("Failed to retrieve the designated: \(appURL)")
            return nil
        }

        var requirementString: CFString?
        if SecRequirementCopyString(requirement!, [], &requirementString) == errSecSuccess {
            return requirementString! as String
        }
        print("Failed to retrieve the designated requirement string.")
        return nil
    }
    #endif
}
