import Foundation
import Security
import SwiftProtobuf

/// 证书管理器
/// 处理iOS平台的证书安装、验证和移除
class CertificateManager {

    // MARK: - 证书安装

    /// 安装CA证书到系统钥匙串
    static func installCACertificate(certificateData: Data) throws {
        // 创建证书对象
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            throw CertificateError.invalidCertificate
        }

        // 准备添加查询
        var query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // 添加到钥匙串
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // 证书已存在
            throw CertificateError.duplicateCertificate
        } else if status != errSecSuccess {
            throw CertificateError.installationFailed
        }
    }

    /// 安装客户端证书（PKCS12格式）
    static func installClientCertificate(p12Data: Data, password: String) throws {
        // 导入PKCS12数据
        var importResult: CFArray?
        var error: Unmanaged<CFError>?

        let status = SecPKCS12Import(
            p12Data as CFData,
            [kSecImportExportPassphrase as String: password] as CFDictionary,
            &importResult,
            &error
        )

        guard status == errSecSuccess, let items = importResult else {
            throw CertificateError.invalidCertificate
        }

        // 提取身份证书和私钥
        for item in items as NSArray {
            let dict = item as! NSDictionary
            if let identityRef = dict[kSecImportItemIdentity as String] {
                // 安装身份证书
                var identityQuery: [String: Any] = [
                    kSecClass as String: kSecClassIdentity,
                    kSecValueRef as String: identityRef,
                    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                ]

                SecItemAdd(identityQuery as CFDictionary, nil)
            }
        }
    }

    // MARK: - 证书验证

    /// 检查证书是否已安装
    static func isCertificateInstalled(commonName: String) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecAttrSubject as String: [kSecOIDCommonName as String: commonName]
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        return status == errSecSuccess
    }

    /// 获取所有已安装的VPN相关证书
    static func getInstalledCertificates() -> [String] {
        var certificates: [String] = []

        var query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]

        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)

        if status == errSecSuccess, let itemsArray = items as? [[String: Any]] {
            for item in itemsArray {
                if let subject = item[kSecAttrSubject as String] as? Data {
                    // 解析Subject以获取CN
                    if let cn = extractCommonName(from: subject) {
                        certificates.append(cn)
                    }
                }
            }
        }

        return certificates
    }

    /// 从Subject数据中提取Common Name
    private static func extractCommonName(from data: Data) -> String? {
        // 这里需要解析ASN.1格式的Subject数据
        // 简化实现：使用字符串搜索
        let dataString = String(data: data, encoding: .utf8) ?? ""

        // 查找CN模式
        let pattern = "CN=([^,]+)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: dataString.utf16.count)
            if let match = regex.firstMatch(in: dataString, options: [], range: range) {
                if let cnRange = Range(match.range(at: 1), in: dataString) {
                    return String(dataString[cnRange])
                }
            }
        }

        return nil
    }

    // MARK: - 证书移除

    /// 移除证书
    static func removeCertificate(commonName: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrSubject as String: [kSecOIDCommonName as String: commonName]
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw CertificateError.removalFailed
        }
    }

    /// 移除所有VPN相关证书
    static func removeAllVPNCertificates() throws {
        let certificates = getInstalledCertificates()

        for certificate in certificates {
            try removeCertificate(commonName: certificate)
        }
    }

    // MARK: - 配置描述文件

    /// 创建VPN配置描述文件
    static func createVPNProfile(
        serverAddress: String,
        certificateData: Data?
    ) -> Data {

        let profileDict: [String: Any] = [
            "PayloadContent": [
                [
                    "PayloadDescription": "Configures VPN settings",
                    "PayloadDisplayName": "ECH VPN",
                    "PayloadIdentifier": "com.ech.vpn.profile",
                    "PayloadOrganization": "ECH VPN",
                    "PayloadType": "com.apple.vpn.managed",
                    "PayloadVersion": 1,
                    "PayloadUUID": UUID().uuidString,
                    "Proxies": [
                        "ProxyAutoDiscoveryEnable": 0,
                        "ProxyAutoConfigEnable": 0,
                        "HTTPProxy": [
                            "ProxyServer": "127.0.0.1",
                            "ProxyServerPort": 1080
                        ]
                    ],
                    "VPN": [
                        "AuthName": "ECH VPN",
                        "AuthenticationMethod": "certificate",
                        "RemoteAddress": serverAddress,
                        "UserDefinedName": "ECH VPN",
                        "VPNType": "IKEv2"
                    ]
                ]
            ],
            "PayloadDisplayName": "ECH VPN Configuration",
            "PayloadIdentifier": "com.ech.vpn.config",
            "PayloadOrganization": "ECH VPN",
            "PayloadRemovalDisallowed": false,
            "PayloadType": "Configuration",
            "PayloadUUID": UUID().uuidString,
            "PayloadVersion": 1
        ]

        // 转换为XML plist
        return createPropertyListXML(from: profileDict)
    }

    /// 创建Property List XML
    private static func createPropertyListXML(from dict: [String: Any]) -> Data {
        // 在实际应用中，应该使用PropertyListSerialization
        // 这里是简化版本
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>PayloadDescription</key>
                    <string>Configures VPN settings</string>
                    <key>PayloadDisplayName</key>
                    <string>ECH VPN</string>
                    <key>PayloadIdentifier</key>
                    <string>com.ech.vpn.profile</string>
                    <key>PayloadOrganization</key>
                    <string>ECH VPN</string>
                    <key>PayloadType</key>
                    <string>com.apple.vpn.managed</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                    <key>PayloadUUID</key>
                    <string>\(UUID().uuidString)</string>
                    <key>Proxies</key>
                    <dict>
                        <key>ProxyAutoDiscoveryEnable</key>
                        <integer>0</integer>
                        <key>ProxyAutoConfigEnable</key>
                        <integer>0</integer>
                        <key>HTTPProxy</key>
                        <dict>
                            <key>ProxyServer</key>
                            <string>127.0.0.1</string>
                            <key>ProxyServerPort</key>
                            <integer>1080</integer>
                        </dict>
                    </dict>
                    <key>VPN</key>
                    <dict>
                        <key>AuthName</key>
                        <string>ECH VPN</string>
                        <key>AuthenticationMethod</key>
                        <string>certificate</string>
                        <key>RemoteAddress</key>
                        <string>\(serverAddress)</string>
                        <key>UserDefinedName</key>
                        <string>ECH VPN</string>
                        <key>VPNType</key>
                        <string>IKEv2</string>
                    </dict>
                </dict>
            </array>
            <key>PayloadDisplayName</key>
            <string>ECH VPN Configuration</string>
            <key>PayloadIdentifier</key>
            <string>com.ech.vpn.config</string>
            <key>PayloadOrganization</key>
            <string>ECH VPN</string>
            <key>PayloadRemovalDisallowed</key>
            <false/>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(UUID().uuidString)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
        </plist>
        """

        return xmlString.data(using: .utf8) ?? Data()
    }

    // MARK: - 错误类型

    enum CertificateError: Error, LocalizedError {
        case invalidCertificate
        case duplicateCertificate
        case installationFailed
        case removalFailed
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .invalidCertificate:
                return "证书格式无效"
            case .duplicateCertificate:
                return "证书已存在"
            case .installationFailed:
                return "证书安装失败"
            case .removalFailed:
                return "证书移除失败"
            case .exportFailed:
                return "证书导出失败"
            }
        }
    }
}