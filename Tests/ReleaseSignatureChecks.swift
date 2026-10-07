import Foundation
import CryptoKit

// Run against the exact release bytes, using only the public key embedded in the app.
@main struct ReleaseSignatureChecks {
    static func main() throws {
        guard CommandLine.arguments.count == 4 else {
            throw NSError(domain: "Usage: release-signature-checks archive.zip appcast.xml Info.plist", code: 1)
        }
        let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let feed = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let plist = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))
        let info = try PropertyListSerialization.propertyList(from: plist, format: nil) as! [String: Any]
        let keyData = Data(base64Encoded: info["SUPublicEDKey"] as! String)!
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        let xml = String(decoding: feed, as: UTF8.self)
        let archiveSignature = try capture(#"sparkle:edSignature="([^"]+)""#, in: xml)
        guard let signature = Data(base64Encoded: archiveSignature), key.isValidSignature(signature, for: archive) else {
            throw NSError(domain: "Archive signature does not match embedded public key", code: 2)
        }
        var tampered = archive
        tampered[tampered.count - 1] ^= 1
        guard !key.isValidSignature(signature, for: tampered) else {
            throw NSError(domain: "Tampered archive accepted", code: 3)
        }
        let feedSignature = try capture(#"edSignature: ([A-Za-z0-9+/=]+)"#, in: xml)
        let length = Int(try capture(#"length: ([0-9]+)"#, in: xml))!
        guard length > 0, length < feed.count,
              let feedSignatureData = Data(base64Encoded: feedSignature),
              key.isValidSignature(feedSignatureData, for: feed.prefix(length)) else {
            throw NSError(domain: "Feed signature does not match embedded public key", code: 4)
        }
        var tamperedFeed = Data(feed.prefix(length))
        tamperedFeed[0] ^= 1
        guard !key.isValidSignature(feedSignatureData, for: tamperedFeed) else {
            throw NSError(domain: "Tampered feed accepted", code: 5)
        }
        print("PASS: archive and feed match app public key; tampered archive and feed rejected")
    }

    private static func capture(_ pattern: String, in string: String) throws -> String {
        let regex = try NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range(at: 1), in: string) else {
            throw NSError(domain: "Missing release signature metadata", code: 6)
        }
        return String(string[range])
    }
}
