// swift-tools-version: 6.0
import PackageDescription

// Echo uses ASR only. Keep upstream sources unchanged and omit unrelated engines at build time.
let package = Package(
    name: "FluidAudio",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "FluidAudioASR", targets: ["FluidAudio"])],
    targets: [
        .target(
            name: "FluidAudio",
            dependencies: ["MachTaskSelfWrapper"],
            path: "Sources/FluidAudio",
            exclude: [
                "ASR/Parakeet/Unified/benchmark.md", "FluidAudioSwift.swift", "ITN", "Speaker", "VAD",
                "Diarizer/Clustering", "Diarizer/Extraction", "Diarizer/LS-EEND", "Diarizer/Offline",
                "Diarizer/Segmentation", "Diarizer/DiarizationDER.swift", "Diarizer/DiarizerProtocol.swift",
                "Diarizer/DiarizerTimeline.swift", "Diarizer/HungarianAssignment.swift",
                "Diarizer/Core/DiarizerManager.swift", "Diarizer/Core/DiarizerModels.swift",
                "Diarizer/Sortformer/Offline", "Diarizer/Sortformer/SortformerDiarizer.swift",
                "Diarizer/Sortformer/SortformerModelInference.swift", "Diarizer/Sortformer/SortformerStateUpdater.swift",
                "TTS/G2P", "TTS/KokoroAne", "TTS/LuxTts", "TTS/NeuTts", "TTS/SSML", "TTS/Shared",
                "TTS/StyleTTS2", "TTS/Supertonic3", "TTS/TtsBackend.swift", "TTS/TtsConstants.swift",
                "TTS/Inflect/Assets", "TTS/Inflect/Pipeline", "TTS/Inflect/InflectError.swift",
                "TTS/Inflect/InflectManager.swift", "TTS/Inflect/InflectSymbols.swift",
                "TTS/PocketTTS/Assets", "TTS/PocketTTS/Pipeline", "TTS/PocketTTS/Tokenizer",
                "TTS/PocketTTS/PocketTTSError.swift", "TTS/PocketTTS/PocketTtsManager.swift",
            ]
        ),
        .target(
            name: "MachTaskSelfWrapper",
            path: "Sources/MachTaskSelfWrapper",
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "FluidAudioTests",
            dependencies: ["FluidAudio"],
            path: "Tests/FluidAudioTests/Shared",
            exclude: ["ArraySliceTests.swift", "RandomAccessCollectionTests.swift"]
        ),
    ]
)
