import SwiftUI

@main
struct DODApp: App {

    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}
