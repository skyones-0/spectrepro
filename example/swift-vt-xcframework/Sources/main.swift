import Foundation
import SpectreProVt

// Create a terminal with a small grid
var terminal: SpectreProTerminal?
let result = spectrepro_terminal_new(nil, &terminal, 80, 24)
guard result == SPECTREPRO_SUCCESS, let terminal else {
    fatalError("Failed to create terminal")
}

// Write some VT-encoded content
let text = "Hello from \u{1b}[1mSwift\u{1b}[0m via xcframework!\r\n"
text.withCString { ptr in
    spectrepro_terminal_vt_write(terminal, ptr, strlen(ptr))
}

// Format the terminal contents as plain text
var fmtOpts = SpectreProFormatterTerminalOptions()
fmtOpts.size = MemoryLayout<SpectreProFormatterTerminalOptions>.size
fmtOpts.emit = SPECTREPRO_FORMATTER_FORMAT_PLAIN
fmtOpts.trim = true

var formatter: SpectreProFormatter?
let fmtResult = spectrepro_formatter_terminal_new(nil, &formatter, terminal, fmtOpts)
guard fmtResult == SPECTREPRO_SUCCESS, let formatter else {
    fatalError("Failed to create formatter")
}

var buf: UnsafeMutablePointer<UInt8>?
var len: Int = 0
let allocResult = spectrepro_formatter_format_alloc(formatter, nil, &buf, &len)
guard allocResult == SPECTREPRO_SUCCESS, let buf else {
    fatalError("Failed to format")
}

print("Plain text (\(len) bytes):")
let data = Data(bytes: buf, count: len)
print(String(data: data, encoding: .utf8) ?? "<invalid UTF-8>")

spectrepro_free(nil, buf, len)
spectrepro_formatter_free(formatter)
spectrepro_terminal_free(terminal)
