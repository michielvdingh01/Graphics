// Puts a run of pictures and a sound together as an mp4, with what macOS has
// on board: swift tools/trailer/encode.swift <frames dir> <fps> <sound.wav> <out.mp4>
//
// The pictures are the .jpg files in the folder, in the order of their names,
// all of the size of the first. The film is H.264 at a rate that keeps the
// grain of the game, the sound AAC; a sound that runs longer than the pictures
// is cut off at their end.
import AVFoundation
import CoreImage
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
	FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
	exit(1)
}

let args = CommandLine.arguments
if args.count != 5 {
	fail("usage: swift encode.swift <frames dir> <fps> <sound.wav> <out.mp4>")
}
let folder = URL(fileURLWithPath: args[1])
guard let fps = Int32(args[2]), fps > 0 else { fail("fps is not a number: \(args[2])") }
let soundURL = URL(fileURLWithPath: args[3])
let outURL = URL(fileURLWithPath: args[4])

let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?
	.filter { $0.hasSuffix(".jpg") }.sorted() ?? []
if names.isEmpty { fail("no .jpg in \(folder.path)") }

func picture(_ name: String) -> CGImage {
	let url = folder.appendingPathComponent(name)
	guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
		let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
	else { fail("cannot read \(url.path)") }
	return image
}

let first = picture(names[0])
let width = first.width
let height = first.height

try? FileManager.default.removeItem(at: outURL)
let writer: AVAssetWriter
do {
	writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
} catch {
	fail("cannot write \(outURL.path): \(error)")
}

let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
	AVVideoCodecKey: AVVideoCodecType.h264,
	AVVideoWidthKey: width,
	AVVideoHeightKey: height,
	AVVideoCompressionPropertiesKey: [
		// Sand, grass and smoke take a lot of bits to keep their grain: 21
		// Mbit/s for 1080p at 60, where YouTube asks for 12.
		AVVideoAverageBitRateKey: width * height * Int(fps) / 6,
		AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
		AVVideoMaxKeyFrameIntervalKey: Int(fps),
		AVVideoAllowFrameReorderingKey: true,
	],
	AVVideoColorPropertiesKey: [
		AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
		AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
		AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
	],
])
video.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
	kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
	kCVPixelBufferWidthKey as String: width,
	kCVPixelBufferHeightKey as String: height,
])
writer.add(video)

let sound = AVURLAsset(url: soundURL)
let semaphore = DispatchSemaphore(value: 0)
var soundTrack: AVAssetTrack?
sound.loadTracks(withMediaType: .audio) { tracks, _ in
	soundTrack = tracks?.first
	semaphore.signal()
}
semaphore.wait()
guard let track = soundTrack else { fail("no sound in \(soundURL.path)") }
let reader: AVAssetReader
do {
	reader = try AVAssetReader(asset: sound)
} catch {
	fail("cannot read \(soundURL.path): \(error)")
}
let pcm = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
reader.add(pcm)
let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
	AVFormatIDKey: kAudioFormatMPEG4AAC,
	AVSampleRateKey: 48000,
	AVNumberOfChannelsKey: 2,
	AVEncoderBitRateKey: 256_000,
])
audio.expectsMediaDataInRealTime = false
writer.add(audio)

writer.startWriting()
reader.startReading()
writer.startSession(atSourceTime: .zero)
let end = CMTime(value: CMTimeValue(names.count), timescale: fps)

// The writer takes picture and sound interleaved: given only pictures it
// stops taking them, waiting for sound. So the sound goes along with them,
// half a second ahead, and further whenever the pictures are not taken.
var soundDone = false
// Once it is all in, the writer is told so, or it waits for more.
var waiting: CMSampleBuffer? = pcm.copyNextSampleBuffer()
func feedSound(until: CMTime) {
	while let samples = waiting {
		let at = CMSampleBufferGetPresentationTimeStamp(samples)
		if CMTimeCompare(at, end) >= 0 {
			waiting = nil
			break
		}
		if CMTimeCompare(at, until) > 0 || !audio.isReadyForMoreMediaData {
			return
		}
		if !audio.append(samples) {
			fail("sound was not taken: \(String(describing: writer.error))")
		}
		waiting = pcm.copyNextSampleBuffer()
	}
	if waiting == nil && !soundDone {
		soundDone = true
		audio.markAsFinished()
	}
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
for (index, name) in names.enumerated() {
	let time = CMTime(value: CMTimeValue(index), timescale: fps)
	var ahead = CMTime(value: 1, timescale: 2)
	while !video.isReadyForMoreMediaData {
		feedSound(until: CMTimeAdd(time, ahead))
		ahead = CMTimeAdd(ahead, CMTime(value: 1, timescale: 10))
		Thread.sleep(forTimeInterval: 0.002)
	}
	feedSound(until: CMTimeAdd(time, CMTime(value: 1, timescale: 2)))
	let image = index == 0 ? first : picture(name)
	var buffer: CVPixelBuffer?
	CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
	guard let pixels = buffer else { fail("no pixel buffer") }
	CVPixelBufferLockBaseAddress(pixels, [])
	let context = CGContext(
		data: CVPixelBufferGetBaseAddress(pixels), width: width, height: height, bitsPerComponent: 8,
		bytesPerRow: CVPixelBufferGetBytesPerRow(pixels), space: space,
		bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
	context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
	CVPixelBufferUnlockBaseAddress(pixels, [])
	CVBufferSetAttachment(pixels, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
	CVBufferSetAttachment(pixels, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
	CVBufferSetAttachment(pixels, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
	if !adaptor.append(pixels, withPresentationTime: time) {
		fail("picture \(name) was not taken: \(String(describing: writer.error))")
	}
}
video.markAsFinished()
while !soundDone {
	feedSound(until: end)
	Thread.sleep(forTimeInterval: 0.002)
}
writer.endSession(atSourceTime: end)
writer.finishWriting {
	semaphore.signal()
}
semaphore.wait()
if writer.status != .completed {
	fail("not written: \(String(describing: writer.error))")
}
print("\(outURL.path): \(names.count) pictures at \(fps) fps, \(width)x\(height)")
