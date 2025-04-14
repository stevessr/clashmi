import Foundation
import Libclash

// import Sentry
import NetworkExtension

#if os(iOS)
// import WidgetKit
#endif
// #if os(iOS)
// import UIKit
// #elseif os(macOS)
// import AppKit
// #endif

class VpnServiceConfig: Codable {
    // var control_port: Int32 = 0
    var base_dir: String = ""
    var work_dir: String = ""
    var cache_dir: String = ""
    var core_path: String = ""
    var patch_core_path: String = ""
    var log_path: String = ""
    var err_path: String = ""
    var id: String = ""
    var version: String = ""
    var name: String = ""
    // var secret: String = ""
    // var install_refer: String = ""
}

struct ProviderMessage: Codable {
    var messageId: String = ""
    var messageParams: String = ""
}

struct ProviderMessageResponse: Codable {
    var err: String?
    var extra: [String: String] = [:]
}

enum VpnError: Error {
    case Error(String)
}

open class ExtensionProvider: NEPacketTunnelProvider {
    public static let controlKind = "com.nebula.clashmi.widget.ServiceToggle"
    private var config: VpnServiceConfig?
 
    override open func startTunnel(
        options: [String: NSObject]?
    ) async throws {
        // if options != nil && options!["noStart"] is NSString {
        //    return
        // }

        do {
            try await start()
        }
        catch let VpnError.Error(err) {
            writeError(err)
            exit(EXIT_FAILURE)
        }
        catch let err {
            writeError(err.localizedDescription)
            exit(EXIT_FAILURE)
        }
    }

    override open func stopTunnel(
        with reason: NEProviderStopReason, completionHandler: @escaping () -> Void
    ) {
        completionHandler() // completionHandler faster than syn
        exit(EXIT_SUCCESS)
        /* runBlocking { [self] in
             do {
                 try await stopService()
             }
             catch VpnError.Error(let err) {
                 NSLog(err)
             }
             catch let err {
                 NSLog(err.localizedDescription)
             }
             completionHandler() // completionHandler faster than syn
             exit(EXIT_SUCCESS)
         } */
    }

    override open func handleAppMessage(_ messageData: Data) async -> Data? {
        var messageResponse = ProviderMessageResponse()
#if os(iOS)
        if #available(iOS 18.0, *) {
            // ControlCenter.shared.reloadControls(ofKind: ExtensionProfile.controlKind)
        }
#endif
        do {
            let message = try! JSONDecoder().decode(ProviderMessage.self, from: messageData)
            // if message.messageId == "start" {
            //    try await start()
            // }
            if message.messageId == "restart" {
                try await restartService(extra: &messageResponse.extra)
            }
        }
        catch let VpnError.Error(err) {
            messageResponse.err = err
        }
        catch let err {
            messageResponse.err = err.localizedDescription
        }
#if os(iOS)
        if #available(iOS 18.0, *) {
            // ControlCenter.shared.reloadControls(ofKind: ExtensionProfile.controlKind)
        }
#endif
        if messageResponse.err != nil {
            let body: Data = try! JSONEncoder().encode(messageResponse)
            DispatchQueue.global().async {
                exit(EXIT_FAILURE)
            }
            return body
        }

        return nil
    }

    override open func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override open func wake() {
    }
}

extension ExtensionProvider {
    fileprivate func setupService() async throws {
        guard let conf = (protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration
        else {
            throw VpnError.Error("providerConfiguration invalid")
        }

        let configFilePath = conf["configFilePath"] as! String
        if !FileManager.default.fileExists(atPath: configFilePath) {
            throw VpnError.Error("file not exist \(configFilePath)")
        }
        let text = try! String(contentsOfFile: configFilePath, encoding: String.Encoding.utf8)
        let jsonData: Data = text.data(using: String.Encoding.utf8)!
        config = try! JSONDecoder().decode(VpnServiceConfig.self, from: jsonData)
        if config == nil {
            throw VpnError.Error("decode VpnServiceConfig failed: \(configFilePath)")
        }
        let setupOptions = LibclashSetupOptions()
        setupOptions.homeDir = config!.base_dir
        setupOptions.logFile = config!.log_path

        var error: NSError?
        LibclashSetup(setupOptions, &error)
        if error != nil {
            throw VpnError.Error("LibclashSetup failed: \(error!.localizedDescription)")
        }
    }

    fileprivate func writeError(_ message: String) {
        NSLog(message)
    }

    fileprivate func start() async throws {
        try await setupService()
        try await startService()
    }

    fileprivate func startService() async throws {
        let startOptions = LibclashStartOptions()
        startOptions.configFile = config!.core_path
        startOptions.patchConfigFile = config!.patch_core_path

        let tunInterface = ExtensionPlatformInterface(self)
        var error: NSError?
        LibclashStart(startOptions, tunInterface, &error)
        if error != nil {
            throw VpnError.Error("LibclashStart failed: \(error!.localizedDescription)")
        }
    }

    fileprivate func stopService() async throws {
        var error: NSError?
        LibclashStop(&error)
    }

    func restartService(extra: inout [String: String]) async throws {
        if reasserting {
            extra["is_close_error"] = "true"
            throw VpnError.Error("reasserting")
        }
        reasserting = true
        defer {
            reasserting = false
        }
        do {
            try await stopService()
        }
        catch let err {
            extra["is_close_error"] = "true"
            throw err
        }
        try await setupService()
        try await startService()
    }

    func postServiceClose() {
       
    }
}
