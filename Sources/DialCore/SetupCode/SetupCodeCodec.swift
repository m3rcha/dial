import Foundation
import zlib

public enum SetupCodeError: Error, LocalizedError, Equatable, Sendable {
    case invalidPrefix
    case invalidBase64
    case compressionFailed
    case decompressionFailed
    case invalidJSON
    case unsupportedVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidPrefix:
            return "Setup code must start with \"dial:v1:\"."
        case .invalidBase64:
            return "Setup code contains invalid Base64URL data."
        case .compressionFailed:
            return "Could not compress setup payload."
        case .decompressionFailed:
            return "Setup code is corrupted or not valid zlib data."
        case .invalidJSON:
            return "Setup code payload is not valid Dial JSON."
        case .unsupportedVersion(let version):
            return "Setup code version \(version) is not supported by this version of Dial."
        }
    }
}

public enum SetupCodeCodec {
    public static let prefix = "dial:v1:"

    public static func encode(_ payload: SetupCodePayload) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonData = try encoder.encode(payload)
        let compressed = try zlibCompress(jsonData)
        return prefix + base64URLEncode(compressed)
    }

    public static func decode(_ rawInput: String) throws -> SetupCodePayload {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // Support pasting a dial://import?code=... URL directly as well.
        let codeString: String
        if trimmed.lowercased().hasPrefix("dial://"), let url = URL(string: trimmed) {
            guard let extracted = extractCode(from: url) else {
                throw SetupCodeError.invalidPrefix
            }
            codeString = extracted
        } else {
            codeString = trimmed
        }

        guard codeString.hasPrefix(prefix) else {
            throw SetupCodeError.invalidPrefix
        }

        let encodedPart = String(codeString.dropFirst(prefix.count))
        guard !encodedPart.isEmpty, let compressed = base64URLDecode(encodedPart) else {
            throw SetupCodeError.invalidBase64
        }

        let decompressed = try zlibDecompress(compressed)
        let payload: SetupCodePayload
        do {
            payload = try JSONDecoder().decode(SetupCodePayload.self, from: decompressed)
        } catch {
            throw SetupCodeError.invalidJSON
        }

        guard payload.v == 1 else {
            throw SetupCodeError.unsupportedVersion(payload.v)
        }

        return payload
    }

    public static func deepLinkURL(for code: String) -> URL? {
        var components = URLComponents()
        components.scheme = "dial"
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url
    }

    public static func extractCode(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "dial",
              url.host?.lowercased() == "import",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            return nil
        }
        return code
    }

    // MARK: - Base64URL (RFC 4648 §5, unpadded)

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder == 1 { return nil }
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }

    // MARK: - RFC 1950 zlib

    private static func zlibCompress(_ data: Data) throws -> Data {
        if data.isEmpty {
            return Data([0x78, 0x9C, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01])
        }

        let bound = Int(compressBound(uLong(data.count)))
        var output = Data(count: bound)
        var destLen = uLongf(bound)

        let result: Int32 = data.withUnsafeBytes { srcPtr in
            output.withUnsafeMutableBytes { dstPtr in
                guard let srcBase = srcPtr.bindMemory(to: Bytef.self).baseAddress,
                      let dstBase = dstPtr.bindMemory(to: Bytef.self).baseAddress else {
                    return Z_DATA_ERROR
                }
                return compress2(dstBase, &destLen, srcBase, uLong(data.count), Z_DEFAULT_COMPRESSION)
            }
        }

        guard result == Z_OK else {
            throw SetupCodeError.compressionFailed
        }

        output.count = Int(destLen)
        return output
    }

    private static func zlibDecompress(_ data: Data) throws -> Data {
        guard !data.isEmpty else {
            throw SetupCodeError.decompressionFailed
        }

        var stream = z_stream()
        var status = inflateInit_(&stream, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else {
            throw SetupCodeError.decompressionFailed
        }
        defer { inflateEnd(&stream) }

        var output = Data()
        let chunkSize = 16_384
        var buffer = [UInt8](repeating: 0, count: chunkSize)

        try data.withUnsafeBytes { srcPtr in
            guard let srcBase = srcPtr.bindMemory(to: Bytef.self).baseAddress else {
                throw SetupCodeError.decompressionFailed
            }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: srcBase)
            stream.avail_in = uInt(data.count)

            repeat {
                let written: Int = try buffer.withUnsafeMutableBytes { dstPtr in
                    guard let dstBase = dstPtr.bindMemory(to: Bytef.self).baseAddress else {
                        throw SetupCodeError.decompressionFailed
                    }
                    stream.next_out = dstBase
                    stream.avail_out = uInt(chunkSize)
                    status = inflate(&stream, Z_NO_FLUSH)
                    if status != Z_OK && status != Z_STREAM_END {
                        throw SetupCodeError.decompressionFailed
                    }
                    return chunkSize - Int(stream.avail_out)
                }
                if written > 0 {
                    output.append(buffer, count: written)
                }
                // Guard against zip bombs (> 2 MB uncompressed JSON)
                if output.count > 2_097_152 {
                    throw SetupCodeError.decompressionFailed
                }
            } while status != Z_STREAM_END
        }

        return output
    }
}
