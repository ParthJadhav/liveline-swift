import Foundation

#if os(macOS)
import AppKit

@main
struct LivelineRenderCommand {
    @MainActor
    static func main() {
        do {
            _ = NSApplication.shared
            let options = try RenderOptions.parse(Array(CommandLine.arguments.dropFirst()))
            try MP4Exporter(options: options).export()
        } catch {
            let message = "error: \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
#else
@main
struct LivelineRenderCommand {
    static func main() {
        FileHandle.standardError.write(Data("error: liveline-render requires macOS 13 or newer\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
#endif
