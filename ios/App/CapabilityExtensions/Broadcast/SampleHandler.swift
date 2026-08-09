import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler {
    private var receivedFirstVideoFrame = false

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        receivedFirstVideoFrame = false
    }

    override func broadcastPaused() {}
    override func broadcastResumed() {}
    override func broadcastFinished() {}

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, !receivedFirstVideoFrame else { return }
        receivedFirstVideoFrame = true
        // 冒烟版不保存、不上传画面。能走到这里，就证明扩展收到了真实屏幕帧。
    }
}
