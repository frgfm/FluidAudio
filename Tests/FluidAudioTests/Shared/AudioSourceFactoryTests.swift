import AVFoundation
import Darwin
import Foundation
import XCTest

@testable import FluidAudio

final class AudioSourceFactoryTests: XCTestCase {
    func testSuccessfulSourceOwnsScratchUntilCleanup() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try Data(contentsOf: root.appendingPathComponent("input.wav"))
        let factory = AudioSourceFactory()
        var scratch: URL?
        let (source, _) = try factory.makeDiskBackedSource(
            from: root.appendingPathComponent("input.wav"), targetSampleRate: 16_000
        ) { file, converter, handle in
            scratch = try self.path(of: handle)
            return try factory.streamConvert(audioFile: file, converter: converter, handle: handle)
        }
        let url = try XCTUnwrap(scratch)
        defer { source.cleanup() }
        XCTAssertEqual(source.sampleCount, 16_000, accuracy: 2)
        XCTAssertEqual(try Data(contentsOf: url).count, source.sampleCount * MemoryLayout<Float>.stride)
        source.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("input.wav")), original)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("unrelated.raw"), encoding: .utf8), "keep")
    }

    func testConversionFailureRemovesWrittenScratchAndPreservesOriginal() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input.wav")
        let original = try Data(contentsOf: input)
        var scratch: URL?
        defer { if let scratch { try? FileManager.default.removeItem(at: scratch) } }
        enum Failure: Error { case injected }
        XCTAssertThrowsError(
            try AudioSourceFactory().makeDiskBackedSource(from: input, targetSampleRate: 16_000) {
                _, _, handle in
                scratch = try self.path(of: handle)
                try handle.write(contentsOf: Data(repeating: 0, count: 4096))
                XCTAssertEqual(try handle.offset(), 4096)
                throw Failure.injected
            })
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(scratch).path))
        XCTAssertEqual(try Data(contentsOf: input), original)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("unrelated.raw"), encoding: .utf8), "keep")
    }

    func testCancellationAfterScratchCreationRemovesIt() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input.wav")
        let original = try Data(contentsOf: input)
        let task = Task.detached {
            let factory = AudioSourceFactory()
            var scratch: URL?
            defer { if let scratch { try? FileManager.default.removeItem(at: scratch) } }
            do {
                _ = try factory.makeDiskBackedSource(from: input, targetSampleRate: 16_000) { file, converter, handle in
                    var bytes = [CChar](repeating: 0, count: Int(MAXPATHLEN))
                    guard fcntl(handle.fileDescriptor, F_GETPATH, &bytes) != -1 else {
                        throw CocoaError(.fileReadUnknown)
                    }
                    scratch = URL(fileURLWithPath: String(cString: bytes))
                    try handle.write(contentsOf: Data(repeating: 0, count: 4096))
                    withUnsafeCurrentTask { $0?.cancel() }
                    return try factory.streamConvert(audioFile: file, converter: converter, handle: handle)
                }
                XCTFail("Expected cooperative cancellation")
            } catch is CancellationError {
                XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(scratch).path))
            }
        }
        try await task.value
        XCTAssertEqual(try Data(contentsOf: input), original)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("unrelated.raw"), encoding: .utf8), "keep")
    }

    private func path(of handle: FileHandle) throws -> URL {
        var bytes = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard fcntl(handle.fileDescriptor, F_GETPATH, &bytes) != -1 else { throw CocoaError(.fileReadUnknown) }
        return URL(fileURLWithPath: String(cString: bytes))
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("audio-source-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000))
        buffer.frameLength = buffer.frameCapacity
        for frame in 0..<Int(buffer.frameLength) {
            buffer.floatChannelData![0][frame] = Float(sin(Double(frame) * 2 * .pi * 440 / 48_000)) * 0.2
            buffer.floatChannelData![1][frame] = Float(sin(Double(frame) * 2 * .pi * 660 / 48_000)) * 0.2
        }
        var settings = format.settings
        settings[AVLinearPCMIsNonInterleaved] = false
        let file = try AVAudioFile(forWriting: root.appendingPathComponent("input.wav"), settings: settings)
        try file.write(from: buffer)
        try "keep".write(to: root.appendingPathComponent("unrelated.raw"), atomically: true, encoding: .utf8)
        return root
    }
}
