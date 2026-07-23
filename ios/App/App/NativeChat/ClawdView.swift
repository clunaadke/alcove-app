import SwiftUI
import ImageIO

// 远程 GIF 解码显示（小螃蟹的一窝动图都在服务器上）
struct GifView: UIViewRepresentable {
    let name: String // 如 "clawd-idle.gif"

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentHuggingPriority(.required, for: .vertical)
        iv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        iv.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        load(into: iv)
        return iv
    }

    func updateUIView(_ iv: UIImageView, context: Context) {
        if context.coordinator.current != name {
            load(into: iv)
            context.coordinator.current = name
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(current: name) }
    final class Coordinator { var current: String; init(current: String) { self.current = current } }

    private func load(into iv: UIImageView) {
        let url = AlcoveAPI.fullURL("/\(name)")
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let img = Self.animatedImage(data) else { return }
            DispatchQueue.main.async { iv.image = img }
        }.resume()
    }

    static func animatedImage(_ data: Data) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(src)
        guard count > 1 else { return UIImage(data: data) }
        var frames: [UIImage] = []
        var duration: Double = 0
        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            frames.append(UIImage(cgImage: cg))
            let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let d = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
                ?? gif?[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1
            duration += max(d, 0.02)
        }
        return UIImage.animatedImage(with: frames, duration: duration)
    }
}

// 小螃蟹本蟹：跟着我的状态换动作，能拖，拖起来会生气挣扎
struct ClawdPet: View {
    @ObservedObject var store: ChatStore
    @State private var mood = "idle"
    @State private var lastActivity = Date()
    @State private var dragOffset: CGSize = .zero
    @AppStorage("clawdOffX") private var savedX = 0.0
    @AppStorage("clawdOffY") private var savedY = 0.0

    private var gif: String {
        switch mood {
        case "typing": return "clawd-typing.gif"
        case "thinking": return "clawd-thinking.gif"
        case "happy": return "clawd-happy.gif"
        case "sleeping": return "clawd-sleeping.gif"
        case "drag": return "clawd-react-annoyed.gif"
        default: return "clawd-idle.gif"
        }
    }

    var body: some View {
        GifView(name: gif)
            .frame(width: 64, height: 64)
            .contentShape(Rectangle())
            .offset(x: savedX + dragOffset.width, y: savedY + dragOffset.height)
            .highPriorityGesture(
                DragGesture()
                    .onChanged { v in
                        if mood != "drag" { mood = "drag" } // 被拎起来了，不高兴
                        dragOffset = v.translation
                    }
                    .onEnded { v in
                        savedX += v.translation.width
                        savedY += v.translation.height
                        // 别拖出屏幕太远，拉回可见范围
                        let bound = UIScreen.main.bounds
                        savedX = min(max(savedX, -bound.width + 76), 4)
                        savedY = min(max(savedY, -bound.height + 220), 4)
                        dragOffset = .zero
                        lastActivity = Date()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {}
                        mood = "idle"
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dragOffset == .zero)
            .onChange(of: store.isTyping) { typing in
                guard mood != "drag" else { return } // 被拎着的时候只管挣扎
                if typing {
                    mood = store.currentTool != nil ? "typing" : "thinking"
                    lastActivity = Date()
                } else if mood == "typing" || mood == "thinking" {
                    mood = "happy"
                    lastActivity = Date()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if mood == "happy" { mood = "idle" }
                    }
                }
            }
            .onChange(of: store.currentTool) { tool in
                guard mood != "drag" else { return }
                if store.isTyping { mood = tool != nil ? "typing" : "thinking" }
            }
            .onReceive(Timer.publish(every: 20, on: .main, in: .common).autoconnect()) { _ in
                if mood == "idle" && Date().timeIntervalSince(lastActivity) > 60 {
                    mood = "sleeping"
                } else if mood == "sleeping" && Date().timeIntervalSince(lastActivity) < 60 {
                    mood = "idle"
                }
            }
            .onChange(of: store.messages.count) { _ in
                lastActivity = Date()
                if mood == "sleeping" { mood = "idle" }
            }
    }
}
