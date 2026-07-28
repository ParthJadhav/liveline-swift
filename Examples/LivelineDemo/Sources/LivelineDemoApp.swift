import SwiftUI

@main
struct LivelineDemoApp: App {
    private let preferredColorScheme: ColorScheme? = {
        if CommandLine.arguments.contains("-ui-test-dark-appearance") {
            return .dark
        }
        if CommandLine.arguments.contains("-ui-test-light-appearance") {
            return .light
        }
        return nil
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferredColorScheme)
        }
    }
}
