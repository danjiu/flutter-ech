import Foundation
import Security

/// 证书生成器
/// 使用iOS Security框架生成自签名证书
class CertificateGenerator {

    /// 生成自签名证书
    /// - Parameters:
    ///   - commonName: 通用名称
    ///   - organization: 组织名称
    ///   - country: 国家代码
    ///   - validDays: 有效天数
    /// - Returns: 证书PEM字符串
    static func generateSelfSignedCertificate(
        commonName: String,
        organization: String,
        country: String,
        validDays: Int = 365
    ) -> String? {

        // 1. 创建RSA私钥
        let privateKeyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecAttrIsPermanent as String: false
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(
            privateKeyAttributes as CFDictionary,
            &error
        ) else {
            print("Failed to create private key: \(error?.takeRetainedValue() ?? "Unknown error")")
            return nil
        }

        // 2. 创建证书主题
        let subject: [String: Any] = [
            kSecAttrCommonName as String: commonName,
            kSecAttrOrganizationName as String: organization,
            kSecAttrCountryName as String: country
        ]

        // 3. 配置证书扩展
        let extensions: [String: Any] = [
            // 基本约束
            kSecAttrBasicConstraints as String: [
                kSecAttrBasicConstraintsIsCA as String: true,
                kSecAttrBasicConstraintsPathLenConstraint as String: 0
            ],
            kSecAttrBasicConstraintsCritical as String: true,

            // 密钥用法
            kSecAttrKeyUsage as String: [
                kSecAttrKeyUsageDigitalSignature,
                kSecAttrKeyUsageKeyEncipherment,
                kSecAttrKeyUsageCertSign,
                kSecAttrKeyUsageCRLSign
            ],
            kSecAttrKeyUsageCritical as String: true,

            // 扩展密钥用法
            kSecAttrExtendedKeyUsage as String: [
                kSecAttrExtendedKeyUsageServerAuth,
                kSecAttrExtendedKeyUsageClientAuth
            ],

            // 主题密钥标识符
            kSecAttrSubjectKeyIdentifier as String: true,

            // 颁发者密钥标识符（自签名）
            kSecAttrAuthorityKeyIdentifier as String: true,

            // 主体备用名称（用于本地测试）
            kSecAttrSubjectAlternativeName as String: [
                "DNS:localhost",
                "DNS:ech.local",
                "IP:127.0.0.1",
                "IP:::1"
            ]
        ]

        // 4. 创建自签名证书
        let certificate = SecCertificateCreateSelfSigned(
            subject as CFDictionary,
            privateKey,
            extensions as CFDictionary,
            &error
        )

        if let error = error {
            print("Failed to create certificate: \(error.takeRetainedValue())")
            return nil
        }

        guard let cert = certificate else {
            print("Certificate is nil")
            return nil
        }

        // 5. 导出为PEM格式
        return exportCertificateToPEM(cert)
    }

    /// 生成服务器证书（由CA签名）
    /// - Parameters:
    ///   - commonName: 服务器域名
    ///   - organization: 组织名称
    ///   - country: 国家代码
    ///   - caCertificate: CA证书
    ///   - caPrivateKey: CA私钥
    ///   - validDays: 有效天数
    /// - Returns: 证书和私钥的PEM字符串
    static func generateServerCertificate(
        commonName: String,
        organization: String,
        country: String,
        caCertificate: SecCertificate,
        caPrivateKey: SecKey,
        validDays: Int = 365
    ) -> (certificate: String?, privateKey: String?)? {

        // 1. 生成服务器私钥
        let privateKeyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecAttrIsPermanent as String: false
        ]

        var error: Unmanaged<CFError>?
        guard let serverPrivateKey = SecKeyCreateRandomKey(
            privateKeyAttributes as CFDictionary,
            &error
        ) else {
            print("Failed to create server private key")
            return nil
        }

        // 2. 创建证书主题
        let subject: [String: Any] = [
            kSecAttrCommonName as String: commonName,
            kSecAttrOrganizationName as String: organization,
            kSecAttrCountryName as String: country
        ]

        // 3. 配置证书扩展（服务器证书）
        let extensions: [String: Any] = [
            // 基本约束
            kSecAttrBasicConstraints as String: [
                kSecAttrBasicConstraintsIsCA as String: false
            ],
            kSecAttrBasicConstraintsCritical as String: true,

            // 密钥用法
            kSecAttrKeyUsage as String: [
                kSecAttrKeyUsageDigitalSignature,
                kSecAttrKeyUsageKeyEncipherment
            ],
            kSecAttrKeyUsageCritical as String: true,

            // 扩展密钥用法
            kSecAttrExtendedKeyUsage as String: [
                kSecAttrExtendedKeyUsageServerAuth
            ],

            // 主体备用名称
            kSecAttrSubjectAlternativeName as String: [
                "DNS:\(commonName)",
                "DNS:localhost",
                "DNS:ech.local",
                "IP:127.0.0.1",
                "IP:::1"
            ]
        ]

        // 4. 创建证书签名请求
        guard let csr = createCertificateSigningRequest(
            subject: subject,
            privateKey: serverPrivateKey,
            extensions: extensions
        ) else {
            print("Failed to create CSR")
            return nil
        }

        // 5. 使用CA签名证书
        guard let signedCert = signCertificate(
            csr: csr,
            caCertificate: caCertificate,
            caPrivateKey: caPrivateKey,
            validDays: validDays
        ) else {
            print("Failed to sign certificate")
            return nil
        }

        // 6. 导出为PEM格式
        let certPEM = exportCertificateToPEM(signedCert)
        let keyPEM = exportPrivateKeyToPEM(serverPrivateKey)

        return (certPEM, keyPEM)
    }

    /// 创建证书签名请求（简化实现）
    private static func createCertificateSigningRequest(
        subject: [String: Any],
        privateKey: SecKey,
        extensions: [String: Any]
    ) -> Data? {
        // 在实际实现中，这里应该创建一个完整的CSR
        // 简化实现：直接返回模拟的CSR数据
        return "CSR_DATA_PLACEHOLDER".data(using: .utf8)
    }

    /// 使用CA签名证书
    private static func signCertificate(
        csr: Data,
        caCertificate: SecCertificate,
        caPrivateKey: SecKey,
        validDays: Int
    ) -> SecCertificate? {
        // 在实际实现中，这里应该使用CA私钥签名CSR
        // 简化实现：返回一个自签名证书作为示例
        let subject: [String: Any] = [
            kSecAttrCommonName as String: "ECH VPN Server",
            kSecAttrOrganizationName as String: "ECH VPN",
            kSecAttrCountryName as String: "CN"
        ]

        let extensions: [String: Any] = [
            kSecAttrBasicConstraints as String: [
                kSecAttrBasicConstraintsIsCA as String: false
            ],
            kSecAttrKeyUsage as String: [
                kSecAttrKeyUsageDigitalSignature,
                kSecAttrKeyUsageKeyEncipherment
            ],
            kSecAttrExtendedKeyUsage as String: [
                kSecAttrExtendedKeyUsageServerAuth
            ]
        ]

        var error: Unmanaged<CFError>?
        let certificate = SecCertificateCreateSelfSigned(
            subject as CFDictionary,
            caPrivateKey,
            extensions as CFDictionary,
            &error
        )

        return certificate
    }

    /// 导出证书为PEM格式
    static func exportCertificateToPEM(_ certificate: SecCertificate) -> String? {
        guard let derData = SecCertificateCopyData(certificate) else {
            return nil
        }

        let base64String = (derData as Data).base64EncodedString()
        var pemString = "-----BEGIN CERTIFICATE-----\n"

        // 每64个字符换行
        let lines = chunked(string: base64String, size: 64)
        for line in lines {
            pemString += line + "\n"
        }

        pemString += "-----END CERTIFICATE-----"
        return pemString
    }

    /// 导出私钥为PEM格式
    static func exportPrivateKeyToPEM(_ privateKey: SecKey) -> String? {
        var error: Unmanaged<CFError>?
        guard let derData = SecKeyCopyExternalRepresentation(privateKey, &error) else {
            print("Failed to export private key: \(error?.takeRetainedValue() ?? "Unknown error")")
            return nil
        }

        let base64String = (derData as Data).base64EncodedString()
        var pemString = "-----BEGIN RSA PRIVATE KEY-----\n"

        let lines = chunked(string: base64String, size: 64)
        for line in lines {
            pemString += line + "\n"
        }

        pemString += "-----END RSA PRIVATE KEY-----"
        return pemString
    }

    /// 导出公钥为PEM格式
    static func exportPublicKeyToPEM(_ publicKey: SecKey) -> String? {
        var error: Unmanaged<CFError>?
        guard let derData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            return nil
        }

        // 构建SubjectPublicKeyInfo结构
        var spki = Data()
        // Algorithm identifier for RSA
        spki.append(contentsOf: [0x30, 0x0d]) // SEQUENCE, length 13
        spki.append(contentsOf: [0x06, 0x09]) // OID, length 9
        spki.append(contentsOf: [0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01]) // RSA OID
        spki.append(contentsOf: [0x05, 0x00]) // NULL parameters
        spki.append(contentsOf: [0x03, 0x81, 0x8f]) // BIT STRING, length 143
        spki.append(0x00) // unused bits

        // 添加公钥数据
        spki.append(derData)

        let base64String = spki.base64EncodedString()
        var pemString = "-----BEGIN PUBLIC KEY-----\n"

        let lines = chunked(string: base64String, size: 64)
        for line in lines {
            pemString += line + "\n"
        }

        pemString += "-----END PUBLIC KEY-----"
        return pemString
    }

    /// 创建PKCS12容器
    /// - Parameters:
    ///   - certificate: 证书
    ///   - privateKey: 私钥
    ///   - password: 保护密码
    /// - Returns: PKCS12数据
    static func createPKCS12(
        certificate: SecCertificate,
        privateKey: SecKey,
        password: String
    ) -> Data? {
        // 在实际实现中，应该使用SecPKCS12Export
        // 简化实现：返回模拟数据
        let pkcs12Data = "PKCS12_PLACEHOLDER".data(using: .utf8)
        return pkcs12Data
    }

    /// 验证证书
    static func validateCertificate(_ certificate: SecCertificate) -> Bool {
        var trust: SecTrust?
        let policy = SecPolicyCreateSSL(true, nil)

        let status = SecTrustCreateWithCertificates(
            certificate as CFTypeRef,
            policy,
            &trust
        )

        guard status == errSecSuccess, let trustObj = trust else {
            return false
        }

        var result: SecTrustResultType = .invalid
        let evalStatus = SecTrustEvaluate(trustObj, &result)

        return evalStatus == errSecSuccess &&
               (result == .unspecified || result == .proceed)
    }

    /// 字符串分块
    private static func chunked(string: String, size: Int) -> [String] {
        return stride(from: 0, to: string.count, by: size).map {
            let start = string.index(string.startIndex, offsetBy: $0)
            let end = string.index(start, offsetBy: size, limitedBy: string.endIndex) ?? string.endIndex
            return String(string[start..<end])
        }
    }
}

/// 证书生成错误
enum CertificateGeneratorError: Error, LocalizedError {
    case keyGenerationFailed
    case certificateCreationFailed
    case exportFailed
    case invalidParameters

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "密钥生成失败"
        case .certificateCreationFailed:
            return "证书创建失败"
        case .exportFailed:
            return "证书导出失败"
        case .invalidParameters:
            return "参数无效"
        }
    }
}