import Foundation

/// The framing of git's wire protocol: each line is prefixed with its length, four hex digits that count themselves.
public enum PktLine {
    /// Ends a request or a list.
    public static let flush = "0000"
    /// Separates a command from its arguments, in protocol version 2.
    public static let delimiter = "0001"

    /// Returns one line framed with its length.
    /// @example PktLine.encode("command=ls-refs\n") // "0014command=ls-refs\n"
    public static func encode(_ line: String) -> String {
        String(format: "%04x", line.utf8.count + 4) + line
    }

    /// Returns the text of each data line in order, without its trailing newline, stopping at the first line that
    /// cannot be read; flush and delimiter lines carry no text and are skipped.
    /// @example PktLine.lines(in: Data("0009abcd\n0000".utf8)) // ["abcd"]
    public static func lines(in data: Data) -> [String] {
        let bytes = [UInt8](data)
        var lines: [String] = []
        var index = 0
        while index + 4 <= bytes.count {
            guard let length = Int(String(decoding: bytes[index..<index + 4], as: UTF8.self), radix: 16) else { break }
            if length < 4 {
                index += 4
                continue
            }
            guard index + length <= bytes.count else { break }
            var line = String(decoding: bytes[index + 4..<index + length], as: UTF8.self)
            if line.hasSuffix("\n") { line.removeLast() }
            lines.append(line)
            index += length
        }
        return lines
    }
}
