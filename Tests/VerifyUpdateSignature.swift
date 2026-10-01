import CryptoKit
import Foundation

let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
guard let signature = Data(base64Encoded: CommandLine.arguments[2]),
      let keyData = Data(base64Encoded: CommandLine.arguments[3]) else { fatalError("Invalid base64") }
let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
precondition(key.isValidSignature(signature, for: archive), "Update signature is invalid")
var modified = archive
modified[modified.startIndex] ^= 1
precondition(!key.isValidSignature(signature, for: modified), "Modified archive was accepted")
print("PASS: update signature verified; modified archive rejected.")
