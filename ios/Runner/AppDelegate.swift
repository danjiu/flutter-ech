import Flutter
import UIKit
import Foundation
import Security

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Register VPN Bridge - 简化版本
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not type FlutterViewController")
        }

        let channel = FlutterMethodChannel(name: "ech_flutter_vpn/vpn", binaryMessenger: controller.binaryMessenger)

        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "startEchoProxy":
                result(true)  // 简化：直接返回成功，Flutter端处理实际逻辑
            case "stopEchoProxy":
                result(true)
            case "getConnectionStats":
                // 返回模拟的统计信息
                let stats: [String: Any] = [
                    "bytes_uploaded": UserDefaults.standard.integer(forKey: "vpn_upload_bytes"),
                    "bytes_downloaded": UserDefaults.standard.integer(forKey: "vpn_download_bytes"),
                    "connection_duration": UserDefaults.standard.integer(forKey: "vpn_connection_duration")
                ]
                result(stats)
            case "getVpnLog":
                let logs = [
                    "ECH VPN Log:",
                    "简化版本 - 实际日志由Flutter管理"
                ].joined(separator: "\n")
                result(logs)
            case "updateRoutingMode":
                result(true)
            case "requestVpnPermission":
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Register Certificate Manager Channel
        let certificateChannel = FlutterMethodChannel(name: "ech_vpn/certificate", binaryMessenger: controller.binaryMessenger)

        certificateChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "installCACertificate":
                if let certificateData = call.arguments as? [String: Any],
                   let data = certificateData["certificateData"] as? FlutterStandardTypedData {
                    do {
                        try CertificateManager.installCACertificate(certificateData: data.data)
                        result(true)
                    } catch {
                        result(FlutterError(code: "CERTIFICATE_ERROR", message: error.localizedDescription, details: nil))
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid certificate data", details: nil))
                }

            case "installClientCertificate":
                if let args = call.arguments as? [String: Any],
                   let p12Data = args["p12Data"] as? FlutterStandardTypedData,
                   let password = args["password"] as? String {
                    do {
                        try CertificateManager.installClientCertificate(p12Data: p12Data.data, password: password)
                        result(true)
                    } catch {
                        result(FlutterError(code: "CERTIFICATE_ERROR", message: error.localizedDescription, details: nil))
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                }

            case "isCertificateInstalled":
                if let args = call.arguments as? [String: Any],
                   let commonName = args["commonName"] as? String {
                    let isInstalled = CertificateManager.isCertificateInstalled(commonName: commonName)
                    result(isInstalled)
                } else {
                    result(false)
                }

            case "getInstalledCertificates":
                let certificates = CertificateManager.getInstalledCertificates()
                result(certificates)

            case "removeCertificate":
                if let args = call.arguments as? [String: Any],
                   let commonName = args["commonName"] as? String {
                    do {
                        try CertificateManager.removeCertificate(commonName: commonName)
                        result(true)
                    } catch {
                        result(FlutterError(code: "CERTIFICATE_ERROR", message: error.localizedDescription, details: nil))
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Common name not provided", details: nil))
                }

            case "removeAllVPNCertificates":
                do {
                    try CertificateManager.removeAllVPNCertificates()
                    result(true)
                } catch {
                    result(FlutterError(code: "CERTIFICATE_ERROR", message: error.localizedDescription, details: nil))
                }

            case "createVPNProfile":
                if let args = call.arguments as? [String: Any],
                   let serverAddress = args["serverAddress"] as? String {
                    let certificateData = args["certificateData"] as? FlutterStandardTypedData
                    let profileData = CertificateManager.createVPNProfile(
                        serverAddress: serverAddress,
                        certificateData: certificateData?.data
                    )
                    result(FlutterStandardTypedData(bytes: profileData))
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Server address not provided", details: nil))
                }

            case "generateCertificate":
                if let args = call.arguments as? [String: Any],
                   let commonName = args["commonName"] as? String,
                   let organization = args["organization"] as? String,
                   let country = args["country"] as? String {
                    let validDays = args["validDays"] as? Int ?? 365

                    if let certificatePEM = CertificateGenerator.generateSelfSignedCertificate(
                        commonName: commonName,
                        organization: organization,
                        country: country,
                        validDays: validDays
                    ) {
                        result([
                            "certificate": certificatePEM,
                            "privateKey": "", // 私钥在原生代码中管理，不导出
                            "publicKey": certificatePEM // 自签名证书中包含公钥
                        ])
                    } else {
                        result(FlutterError(code: "GENERATION_FAILED", message: "Certificate generation failed", details: nil))
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Required parameters missing", details: nil))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
