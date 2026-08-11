import ReplayKit
import CoreImage
import ImageIO
import UIKit

final class SampleHandler: RPBroadcastSampleHandler {
    private var uploadInFlight = false
    private var uploaded = false
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let captureURL = URL(string: "https://alcove.ob-memory.uk/api/screen-share/capture")!

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        uploadInFlight = false
        uploaded = false
    }

    override func broadcastPaused() {}
    override func broadcastResumed() {}
    override func broadcastFinished() {}

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, !uploaded, !uploadInFlight,
              CMSampleBufferDataIsReady(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let token = Bundle.main.object(forInfoDictionaryKey: "AlcoveLocToken") as? String,
              !token.isEmpty else { return }
        uploadInFlight = true

        guard let jpeg = makeJPEG(pixelBuffer: pixelBuffer, sampleBuffer: sampleBuffer) else {
            uploadInFlight = false
            return
        }
        var request = URLRequest(url: captureURL)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Auth-Token")
        request.httpBody = jpeg
        request.timeoutInterval = 30
        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            guard let self else { return }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(code) {
                self.uploaded = true
            }
            self.uploadInFlight = false
        }.resume()
    }

    private func makeJPEG(pixelBuffer: CVPixelBuffer, sampleBuffer: CMSampleBuffer) -> Data? {
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        if let raw = CMGetAttachment(
            sampleBuffer,
            key: RPVideoSampleOrientationKey as CFString,
            attachmentModeOut: nil
        ) as? NSNumber {
            image = image.oriented(forExifOrientation: Int32(raw.intValue))
        }

        let extent = image.extent.integral
        let longest = max(extent.width, extent.height)
        if longest > 1280 {
            let scale = 1280 / longest
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        guard let cgImage = context.createCGImage(image, from: image.extent.integral) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.75)
    }
}
