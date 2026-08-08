import AVKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: FramePickerViewModel

    var body: some View {
        HSplitView {
            OutputSidebarView(viewModel: viewModel)
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)

            MainWorkspaceView(viewModel: viewModel)
                .frame(minWidth: 700)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("エラー", isPresented: $viewModel.isShowingError) {
            ErrorAlertActions(viewModel: viewModel)
        } message: {
            Text(viewModel.errorMessage ?? "不明なエラーが発生しました。")
        }
    }
}

private struct ErrorAlertActions: View {
    @ObservedObject var viewModel: FramePickerViewModel

    var body: some View {
        Button("閉じる", role: .cancel) {}
        if viewModel.canRetry {
            Button("再試行") { viewModel.retryLastAction() }
        }
    }
}

private struct OutputSidebarView: View {
    @ObservedObject var viewModel: FramePickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("出力")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("選択フレーム")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(viewModel.capturedFrames.count)枚")
                    .font(.title3.monospacedDigit())
            }

            ExportButton(viewModel: viewModel)
            ExportStatusView(viewModel: viewModel)

            Spacer()

            Text("画像は001.pngから順に、毎回新しいフォルダへ保存します。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct ExportButton: View {
    @ObservedObject var viewModel: FramePickerViewModel

    var body: some View {
        Button {
            viewModel.exportFrames()
        } label: {
            Label("連番PNGを書き出す", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.capturedFrames.isEmpty || viewModel.isExporting)
    }
}

private struct ExportStatusView: View {
    @ObservedObject var viewModel: FramePickerViewModel

    var body: some View {
        if viewModel.isExporting {
            ProgressView(value: viewModel.exportProgress)
            Text("書き出し中…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let outputURL = viewModel.lastOutputURL {
            VStack(alignment: .leading, spacing: 8) {
                Label("書き出し完了", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(outputURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Button("Finderで表示") {
                    viewModel.revealLastOutput()
                }
            }
        }
    }
}

private struct MainWorkspaceView: View {
    @ObservedObject var viewModel: FramePickerViewModel

    var body: some View {
        VStack(spacing: 0) {
            SourceToolbarView(viewModel: viewModel)
            Divider()
            VideoAreaView(viewModel: viewModel)
            Divider()
            SequenceView(viewModel: viewModel)
                .frame(height: 188)
        }
    }
}

private struct SourceToolbarView: View {
    @ObservedObject var viewModel: FramePickerViewModel

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.videoTitle ?? "動画を選択")
                    .font(.headline)
                    .lineLimit(1)
                Text(viewModel.sourceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                viewModel.openLatestScreenRecording()
            } label: {
                Label("iPhoneの最新録画", systemImage: "iphone")
            }
            .disabled(viewModel.isLoadingSource)

            Button {
                viewModel.chooseLocalVideo()
            } label: {
                Label("Macの動画", systemImage: "folder")
            }
            .disabled(viewModel.isLoadingSource)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct VideoAreaView: View {
    @ObservedObject var viewModel: FramePickerViewModel
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
            videoContent
            DropTargetBorder(isVisible: isDropTargeted)
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            viewModel.loadLocalVideo(url)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    @ViewBuilder
    private var videoContent: some View {
        if viewModel.isLoadingSource {
            LoadingVideoView(message: viewModel.loadingMessage)
        } else if viewModel.hasVideo {
            VStack(spacing: 0) {
                VideoPlayer(player: viewModel.player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                CaptureControlsView(viewModel: viewModel)
                    .padding(12)
                    .background(.ultraThinMaterial)
            }
        } else {
            EmptyVideoView(viewModel: viewModel)
        }
    }
}

private struct LoadingVideoView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

private struct EmptyVideoView: View {
    @ObservedObject var viewModel: FramePickerViewModel

    var body: some View {
        ContentUnavailableView {
            Label("動画を開く", systemImage: "film")
        } description: {
            Text("iPhoneの画面収録、またはMac上の動画を選択してください。")
        } actions: {
            HStack {
                Button("iPhoneの最新録画") {
                    viewModel.openLatestScreenRecording()
                }
                Button("Macの動画を選ぶ") {
                    viewModel.chooseLocalVideo()
                }
            }
        }
        .foregroundStyle(.white)
    }
}

private struct DropTargetBorder: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.blue, style: StrokeStyle(lineWidth: 4, dash: [10]))
                .padding(16)
                .allowsHitTesting(false)
        }
    }
}

private struct CaptureControlsView: View {
    @ObservedObject var viewModel: FramePickerViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.stepFrame(backward: true)
            } label: {
                Image(systemName: "backward.frame.fill")
            }
            .help("1フレーム戻る")

            Slider(value: timeBinding, in: 0...sliderMaximum)

            Text(viewModel.formattedCurrentTime)
                .font(.caption.monospacedDigit())
                .frame(width: 86, alignment: .trailing)

            Button {
                viewModel.stepFrame(backward: false)
            } label: {
                Image(systemName: "forward.frame.fill")
            }
            .help("1フレーム進む")

            Button {
                viewModel.captureCurrentFrame()
            } label: {
                Label("このフレームを追加", systemImage: "plus.square.on.square")
            }
            .buttonStyle(.borderedProminent)
        }
        .disabled(!viewModel.hasVideo)
    }

    private var timeBinding: Binding<Double> {
        Binding(
            get: { viewModel.currentTime },
            set: { viewModel.seek(to: $0) }
        )
    }

    private var sliderMaximum: Double {
        max(viewModel.duration, 0.01)
    }
}

private struct SequenceView: View {
    @ObservedObject var viewModel: FramePickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sequenceHeader
            sequenceContent
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sequenceHeader: some View {
        HStack {
            Text("動画シーケンス")
                .font(.headline)
            Text("追加した順に出力")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !viewModel.capturedFrames.isEmpty {
                Button("すべて削除", role: .destructive) {
                    viewModel.removeAllFrames()
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private var sequenceContent: some View {
        if viewModel.capturedFrames.isEmpty {
            ContentUnavailableView(
                "まだフレームがありません",
                systemImage: "rectangle.stack.badge.plus",
                description: Text("動画上の「このフレームを追加」で並べていきます。")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(viewModel.capturedFrames.indices, id: \.self) { index in
                        CapturedFrameCard(
                            frame: viewModel.capturedFrames[index],
                            index: index,
                            count: viewModel.capturedFrames.count,
                            moveLeft: { viewModel.moveFrame(at: index, offset: -1) },
                            moveRight: { viewModel.moveFrame(at: index, offset: 1) },
                            remove: { viewModel.removeFrame(at: index) }
                        )
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}

private struct CapturedFrameCard: View {
    let frame: CapturedFrame
    let index: Int
    let count: Int
    let moveLeft: () -> Void
    let moveRight: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            thumbnail
            cardActions
        }
    }

    private var thumbnail: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: frame.image)
                .resizable()
                .scaledToFit()
                .frame(width: 116, height: 92)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("\(index + 1)")
                .font(.caption2.monospacedDigit().weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.72), in: Capsule())
                .foregroundStyle(.white)
                .padding(5)
        }
    }

    private var cardActions: some View {
        HStack(spacing: 4) {
            Button(action: moveLeft) { Image(systemName: "chevron.left") }
                .disabled(index == 0)
            Button(action: remove) { Image(systemName: "trash") }
                .foregroundStyle(.red)
            Button(action: moveRight) { Image(systemName: "chevron.right") }
                .disabled(index == count - 1)
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }
}
