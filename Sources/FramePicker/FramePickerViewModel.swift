import AppKit
import AVFoundation
import Combine
import Photos
import UniformTypeIdentifiers

struct CapturedFrame: Identifiable {
    let id = UUID()
    let time: Double
    let image: NSImage
}

@MainActor
final class FramePickerViewModel: NSObject, ObservableObject {
    @Published private(set) var player = AVPlayer()
    @Published private(set) var videoTitle: String?
    @Published private(set) var sourceDescription = "iPhone / Mac 両対応"
    @Published private(set) var duration = 0.0
    @Published private(set) var currentTime = 0.0
    @Published private(set) var capturedFrames: [CapturedFrame] = []
    @Published private(set) var isLoadingSource = false
    @Published private(set) var loadingMessage = "動画を読み込んでいます…"
    @Published private(set) var isExporting = false
    @Published private(set) var exportProgress = 0.0
    @Published private(set) var lastOutputURL: URL?
    @Published var isShowingError = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canRetry = false

    var hasVideo: Bool { player.currentItem != nil }

    var formattedCurrentTime: String {
        "\(Self.formatTime(currentTime)) / \(Self.formatTime(duration))"
    }

    private var timeObserver: Any?
    private var currentSourceID: String?
    private var currentPhotoAssetID: String?
    private var lastAction: (() -> Void)?
    private let sessionStore = SessionStore()

    override init() {
        super.init()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = max(0, time.seconds.isFinite ? time.seconds : 0)
            }
        }
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func chooseLocalVideo() {
        let panel = NSOpenPanel()
        panel.title = "動画を選択"
        panel.prompt = "開く"
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadLocalVideo(url)
    }

    func loadLocalVideo(_ url: URL) {
        guard url.isFileURL else {
            presentError("Mac上の動画ファイルを選択してください。", retry: nil)
            return
        }

        lastAction = { [weak self] in self?.loadLocalVideo(url) }
        let sourceID = "file:\(url.standardizedFileURL.path)"
        loadVideo(
            asset: AVURLAsset(url: url),
            title: url.deletingPathExtension().lastPathComponent,
            description: "Macの動画 • \(url.lastPathComponent)",
            sourceID: sourceID,
            photoAssetID: nil
        )
    }

    func openLatestScreenRecording() {
        lastAction = { [weak self] in self?.openLatestScreenRecording() }
        loadingMessage = "iPhoneの画面収録を探しています…"
        isLoadingSource = true
        canRetry = false

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            fetchLatestScreenRecording()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                Task { @MainActor in
                    guard let self else { return }
                    if newStatus == .authorized || newStatus == .limited {
                        self.fetchLatestScreenRecording()
                    } else {
                        self.isLoadingSource = false
                        self.presentError(
                            "写真へのアクセスが必要です。システム設定の「プライバシーとセキュリティ」→「写真」でFramePickerを許可してください。",
                            retry: self.lastAction
                        )
                    }
                }
            }
        case .denied, .restricted:
            isLoadingSource = false
            presentError(
                "写真へのアクセスが許可されていません。システム設定の「プライバシーとセキュリティ」→「写真」でFramePickerを許可してください。",
                retry: lastAction
            )
        @unknown default:
            isLoadingSource = false
            presentError("写真ライブラリの権限状態を確認できませんでした。", retry: lastAction)
        }
    }

    func seek(to seconds: Double) {
        let clamped = min(max(seconds, 0), duration)
        currentTime = clamped
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func stepFrame(backward: Bool) {
        player.pause()
        player.currentItem?.step(byCount: backward ? -1 : 1)
        currentTime = max(0, player.currentTime().seconds)
    }

    func captureCurrentFrame() {
        guard let asset = player.currentItem?.asset else { return }
        let time = max(0, player.currentTime().seconds)

        do {
            let image = try makeImage(asset: asset, at: time)
            capturedFrames.append(CapturedFrame(time: time, image: image))
            persistCurrentSession()
        } catch {
            presentError("フレームを取得できませんでした。\n\(error.localizedDescription)", retry: nil)
        }
    }

    func moveFrame(at index: Int, offset: Int) {
        let destination = index + offset
        guard capturedFrames.indices.contains(index), capturedFrames.indices.contains(destination) else { return }
        let frame = capturedFrames.remove(at: index)
        capturedFrames.insert(frame, at: destination)
        persistCurrentSession()
    }

    func removeFrame(at index: Int) {
        guard capturedFrames.indices.contains(index) else { return }
        capturedFrames.remove(at: index)
        persistCurrentSession()
    }

    func removeAllFrames() {
        capturedFrames.removeAll()
        persistCurrentSession()
    }

    func exportFrames() {
        guard !capturedFrames.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.title = "書き出し先を選択"
        panel.prompt = "ここに保存"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let parentURL = panel.url else { return }

        isExporting = true
        exportProgress = 0
        lastOutputURL = nil

        do {
            let outputURL = try createUniqueOutputDirectory(in: parentURL)
            for (index, frame) in capturedFrames.enumerated() {
                let filename = ExportNaming.filename(index: index, totalCount: capturedFrames.count)
                try writePNG(frame.image, to: outputURL.appendingPathComponent(filename))
                exportProgress = Double(index + 1) / Double(capturedFrames.count)
            }
            lastOutputURL = outputURL
            isExporting = false
        } catch {
            isExporting = false
            presentError("画像を書き出せませんでした。\n\(error.localizedDescription)", retry: nil)
        }
    }

    func revealLastOutput() {
        guard let lastOutputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastOutputURL])
    }

    func retryLastAction() {
        isShowingError = false
        lastAction?()
    }

    private func fetchLatestScreenRecording() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .video, options: options)

        var latest: PHAsset?
        assets.enumerateObjects { asset, _, stop in
            if asset.mediaSubtypes.contains(.videoScreenRecording) {
                latest = asset
                stop.pointee = true
            }
        }

        guard let latest else {
            isLoadingSource = false
            presentError(
                "写真ライブラリに画面収録が見つかりませんでした。iPhone側のiCloud写真の同期完了後に再試行してください。",
                retry: lastAction
            )
            return
        }

        loadPhotoAsset(latest)
    }

    private func loadPhotoAsset(_ photoAsset: PHAsset) {
        loadingMessage = "iCloudから画面収録を読み込んでいます…"

        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestAVAsset(forVideo: photoAsset, options: options) { [weak self] avAsset, _, info in
            Task { @MainActor in
                guard let self else { return }
                if let error = info?[PHImageErrorKey] as? Error {
                    self.isLoadingSource = false
                    self.presentError(
                        "iCloudから画面収録を取得できませんでした。\n\(error.localizedDescription)",
                        retry: self.lastAction
                    )
                    return
                }
                guard let avAsset else {
                    self.isLoadingSource = false
                    self.presentError("画面収録の動画データを取得できませんでした。", retry: self.lastAction)
                    return
                }

                let title = photoAsset.creationDate.map { Self.dateFormatter.string(from: $0) } ?? "最新の画面収録"
                self.loadVideo(
                    asset: avAsset,
                    title: title,
                    description: "iPhoneの画面収録 • iCloud写真",
                    sourceID: "photo:\(photoAsset.localIdentifier)",
                    photoAssetID: photoAsset.localIdentifier
                )
            }
        }
    }

    private func loadVideo(
        asset: AVAsset,
        title: String,
        description: String,
        sourceID: String,
        photoAssetID: String?
    ) {
        isLoadingSource = true
        loadingMessage = "動画を準備しています…"
        player.pause()
        player.replaceCurrentItem(with: nil)
        capturedFrames = []
        currentTime = 0
        duration = 0
        lastOutputURL = nil

        Task {
            do {
                let loadedDuration = try await asset.load(.duration)
                guard loadedDuration.seconds.isFinite, loadedDuration.seconds > 0 else {
                    throw FramePickerError.invalidDuration
                }

                let item = AVPlayerItem(asset: asset)
                player.replaceCurrentItem(with: item)
                duration = loadedDuration.seconds
                videoTitle = title
                sourceDescription = description
                currentSourceID = sourceID
                currentPhotoAssetID = photoAssetID
                isLoadingSource = false
                canRetry = false
                restoreCapturedFrames(for: asset, sourceID: sourceID)
            } catch {
                isLoadingSource = false
                presentError("動画を開けませんでした。\n\(error.localizedDescription)", retry: lastAction)
            }
        }
    }

    private func restoreCapturedFrames(for asset: AVAsset, sourceID: String) {
        guard let session = sessionStore.load(sourceID: sourceID), !session.capturedTimes.isEmpty else { return }

        for time in session.capturedTimes where time <= duration {
            if let image = try? makeImage(asset: asset, at: time) {
                capturedFrames.append(CapturedFrame(time: time, image: image))
            }
        }
    }

    private func makeImage(asset: AVAsset, at seconds: Double) throws -> NSImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let cgImage = try generator.copyCGImage(
            at: CMTime(seconds: seconds, preferredTimescale: 600),
            actualTime: nil
        )
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func persistCurrentSession() {
        guard let currentSourceID else { return }
        sessionStore.save(
            PersistedSession(
                sourceID: currentSourceID,
                capturedTimes: capturedFrames.map(\.time)
            )
        )
    }

    private func createUniqueOutputDirectory(in parentURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let baseName = ExportNaming.folderName(date: Date())
        var candidate = parentURL.appendingPathComponent(baseName, isDirectory: true)
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = parentURL.appendingPathComponent("\(baseName)-\(suffix)", isDirectory: true)
            suffix += 1
        }

        try fileManager.createDirectory(at: candidate, withIntermediateDirectories: false)
        return candidate
    }

    private func writePNG(_ image: NSImage, to url: URL) throws {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw FramePickerError.pngEncodingFailed
        }
        try png.write(to: url, options: .atomic)
    }

    private func presentError(_ message: String, retry: (() -> Void)?) {
        errorMessage = message
        lastAction = retry
        canRetry = retry != nil
        isShowingError = true
    }

    private static func formatTime(_ value: Double) -> String {
        guard value.isFinite else { return "00:00" }
        let seconds = max(0, Int(value.rounded(.down)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm の画面収録"
        return formatter
    }()
}

extension FramePickerViewModel: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self, self.currentPhotoAssetID != nil else { return }
            self.fetchLatestScreenRecording()
        }
    }
}

private final class SessionStore {
    private let key = "capturedSessions.v1"
    private let defaults = UserDefaults.standard

    func load(sourceID: String) -> PersistedSession? {
        guard
            let data = defaults.data(forKey: key),
            let sessions = try? JSONDecoder().decode([String: PersistedSession].self, from: data)
        else { return nil }
        return sessions[sourceID]
    }

    func save(_ session: PersistedSession) {
        var sessions: [String: PersistedSession] = [:]
        if
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([String: PersistedSession].self, from: data)
        {
            sessions = decoded
        }
        sessions[session.sourceID] = session
        if let encoded = try? JSONEncoder().encode(sessions) {
            defaults.set(encoded, forKey: key)
        }
    }
}

private enum FramePickerError: LocalizedError {
    case invalidDuration
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "動画の長さを取得できません。"
        case .pngEncodingFailed:
            return "PNG画像への変換に失敗しました。"
        }
    }
}
