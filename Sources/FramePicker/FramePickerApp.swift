import SwiftUI

@main
struct FramePickerApp: App {
    @StateObject private var viewModel = FramePickerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Macの動画を開く…") {
                    viewModel.chooseLocalVideo()
                }
                .keyboardShortcut("o")

                Button("iPhoneの最新画面収録を開く") {
                    viewModel.openLatestScreenRecording()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
    }
}
