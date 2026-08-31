import SwiftUI
import UIKit
import PhotosUI

// 横屏麻将桌（0831 陈霁的规格）。跟竖屏那张是两套布局、一个 store——
// 从竖屏 fullScreenCover 弹出来，共用同一个 QipaiTableStore，不重连 SSE。
//
// 她拍板的几条，改之前先看：
//   · 四边围坐，座位**按打牌顺序**绕圈（我在下，下家在右，对家在上，上家在左）。
//     正因为位置本身就是顺序，横屏**不显示「你的下家 XXX」**那行字——竖屏那行保留。
//   · 背景白瓷波点（不是壁纸照片），桌面一块**花边蕾丝桌布**，整体粉白灰。
//   · 牌面复用竖屏那套 MahjongTileFace，**平的，正上方看，不做立体/透视**——
//     斜视角要真三维，工作量翻几倍，斜着的牌点击判定还不准。
//   · 副露跟自己的手牌之间**留一段间距**分开（她点名的）。
//   · 中央留「还剩几张」：一张麻将背面 + 数字，照参考图。
//   · 四周照参考图铺各家的牌河，围成一圈。
//   · 头像先做圆形 + 名字第一个字（她以后会在棋牌室加真头像，换图源即可，位置不动）。
//   · 右边缘一个贴边小拉手，点开聊天室、桌子**向左缩小**（不是盖上去）；
//     按钮不消失，只把箭头翻个方向。
//
// ‼️横屏一律走 requestGeometryUpdate 请系统转（CowatchView 0826 验过的路子）。
// 别再走「把画面 rotationEffect 转 90 度」那条老路——手势和布局全是歪的。

// MARK: - 粉白灰（横屏桌面专用，不动 QipaiPalette）

enum MahjongCloth {
    private static func pick(_ day: UInt32, _ dark: UInt32) -> Color {
        QipaiPalette.qhex(QipaiPalette.night ? dark : day)
    }
    /// 桌布主色·藕粉
    static var felt: Color      { pick(0xF2DCE0, 0x3A2E33) }
    /// 桌布中心稍深一点，让布面有点凹
    static var feltDeep: Color  { pick(0xE7CBD2, 0x322830) }
    /// 蕾丝花边·近白
    static var lace: Color      { pick(0xFBF3F4, 0x4A3E44) }
    /// 蕾丝上的走线/眼孔
    static var thread: Color    { pick(0xD8B9C2, 0x5E4E56) }

    // 台唇（0901 她批的：桌子要有一圈护栏，但**淡**——不要玫瑰金深粉）
    /// 护栏亮面
    static var rimHi: Color     { pick(0xFAF4F5, 0x3C3238) }
    /// 护栏暗面
    static var rimLo: Color     { pick(0xEADFE2, 0x2E262B) }
    /// 护栏描边 / 布面陷进去那圈内阴影
    static var rimEdge: Color   { pick(0xCFBCC2, 0x4B3F46) }

    // 桌体（0901 她要真透视：桌面底下这一层往下错开，倾斜之后就是**前侧立面**，
    // 也就是她说的"看得见桌沿厚度"。左右两侧在转角处也会露出一条）
    /// 立面上沿（挨着桌面，亮一点）
    static var bodyHi: Color    { pick(0xE3D3D7, 0x2A2328) }
    /// 立面下沿（背光，暗）
    static var bodyLo: Color    { pick(0xC7B2B8, 0x1E181C) }
}

// MARK: - 花边蕾丝桌布

/// 一整块画在 Canvas 里：边缘一圈半圆花瓣（蕾丝牙子）＋布面＋一圈眼孔走线。
/// 用 Canvas 不用几十个 Circle 视图——四家牌河已经上百张牌了，别再给布局器加担子。
struct MahjongLaceCloth: View {
    var scallop: CGFloat = 11
    /// 只为让 @AppStorage 一变就重画（她换了桌布图）
    var version: Int = 0

    /// 台唇宽度：布陷在这一圈里面
    private let rimWidth: CGFloat = 11

    var body: some View {
        ZStack {
            rim
            ZStack {
                // 底层：一圈花瓣（蕾丝牙子），永远画，换不换图都有
                Canvas { ctx, size in
                    let r = scallop
                    ctx.fill(scallopPath(clothRect(size, r), r), with: .color(MahjongCloth.lace))
                }
                // 中层：布面 —— 她换过图就铺图，没换就是原来那块藕粉
                clothFace
                    .padding(scallop)
                // 顶层：走线和一圈眼孔压在布面上（图也要有这圈线，不然不像块布）
                Canvas { ctx, size in
                    let r = scallop
                    let rect = clothRect(size, r)
                    ctx.stroke(eyeletRing(rect), with: .color(MahjongCloth.thread.opacity(0.75)),
                               lineWidth: 1)
                    ctx.fill(eyeletHoles(rect), with: .color(MahjongCloth.thread.opacity(0.55)))
                }
            }
            .padding(rimWidth)
        }
        .allowsHitTesting(false)
    }

    /// 桌子本体：投影 → 桌体厚度 → 台唇。
    /// 0901 她定的：淡，不要玫瑰金深粉。光源左上，影子往右下。
    ///
    /// ‼️桌体那一层是**往下错开**画的同一个形状。整张桌子按 28° 倾斜之后，
    /// 露出来的那一条就是她要的「前侧桌框厚度」，左右转角也会带出一点侧厚。
    /// 别把它删了当成多余的重复图层。
    private var rim: some View {
        let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)
        return ZStack {
            // 桌体：前侧立面
            shape
                .fill(LinearGradient(colors: [MahjongCloth.bodyHi, MahjongCloth.bodyLo],
                                     startPoint: .top, endPoint: .bottom))
                .offset(y: 22)
            // 台面那一圈护栏
            shape
                .fill(LinearGradient(colors: [MahjongCloth.rimHi, MahjongCloth.rimLo],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(shape.strokeBorder(.white.opacity(0.9), lineWidth: 1.4).padding(0.7))
                .overlay(shape.stroke(MahjongCloth.rimEdge.opacity(0.7), lineWidth: 1))
        }
        .shadow(color: QipaiPalette.shadowTint.opacity(0.22), radius: 14, x: 4, y: 10)
    }

    private func clothRect(_ size: CGSize, _ r: CGFloat) -> CGRect {
        CGRect(x: r, y: r, width: max(size.width - r * 2, 1), height: max(size.height - r * 2, 1))
    }

    private var clothShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
    }

    private var clothFace: some View {
        Group {
            if let img = MahjongFaces.clothImage() {
                // 存的时候已经按桌布比例裁好了，这里 fill 一下兜住零头差异。
                // ‼️图是**平铺**的，不做斜视角——她问过这个：斜了照片会变形，
                // 而且斜着的牌点击判定会不准。要"陷进去"的感觉靠下面那圈内阴影，不靠透视。
                Color.clear
                    .overlay(Image(uiImage: img).resizable().scaledToFill())
                    .clipShape(clothShape)
            } else {
                clothShape.fill(LinearGradient(colors: [MahjongCloth.felt, MahjongCloth.feltDeep],
                                               startPoint: .top, endPoint: .bottom))
            }
        }
        // 内阴影：描粗一道再糊开，用自己的形状裁掉外溢——布就像陷在台唇里
        .overlay(
            clothShape
                .stroke(MahjongCloth.rimEdge.opacity(0.55), lineWidth: 5)
                .blur(radius: 4)
                .mask(clothShape)
                .allowsHitTesting(false)
        )
    }

    /// 沿四边排一圈半圆花瓣。拆成独立函数，别塞进 Canvas 闭包里让类型检查器吃不下
    private func scallopPath(_ rect: CGRect, _ r: CGFloat) -> Path {
        var p = Path()
        var x = rect.minX + r
        while x <= rect.maxX - r + 0.5 {
            p.addEllipse(in: CGRect(x: x - r, y: rect.minY - r, width: r * 2, height: r * 2))
            p.addEllipse(in: CGRect(x: x - r, y: rect.maxY - r, width: r * 2, height: r * 2))
            x += r * 2
        }
        var y = rect.minY + r
        while y <= rect.maxY - r + 0.5 {
            p.addEllipse(in: CGRect(x: rect.minX - r, y: y - r, width: r * 2, height: r * 2))
            p.addEllipse(in: CGRect(x: rect.maxX - r, y: y - r, width: r * 2, height: r * 2))
            y += r * 2
        }
        return p
    }

    private func eyeletRing(_ rect: CGRect) -> Path {
        Path(roundedRect: rect.insetBy(dx: 9, dy: 9), cornerRadius: 20, style: .continuous)
    }

    /// 走线上串一圈小孔，蕾丝的眼儿
    private func eyeletHoles(_ rect: CGRect) -> Path {
        let inner = rect.insetBy(dx: 9, dy: 9)
        let d: CGFloat = 2.6
        let step: CGFloat = 15
        var p = Path()
        var x = inner.minX + step / 2
        while x < inner.maxX {
            p.addEllipse(in: CGRect(x: x - d / 2, y: inner.minY - d / 2, width: d, height: d))
            p.addEllipse(in: CGRect(x: x - d / 2, y: inner.maxY - d / 2, width: d, height: d))
            x += step
        }
        var y = inner.minY + step / 2
        while y < inner.maxY {
            p.addEllipse(in: CGRect(x: inner.minX - d / 2, y: y - d / 2, width: d, height: d))
            p.addEllipse(in: CGRect(x: inner.maxX - d / 2, y: y - d / 2, width: d, height: d))
            y += step
        }
        return p
    }
}

// MARK: - 聊天拉手（贴右边缘，只有左边两个角是圆的）

struct MahjongTabShape: Shape {
    var radius: CGFloat = 13

    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + r),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.maxY),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 头像与名字（0901 她要的：横屏里能自己改，只存这台手机）

/// 服务器给的座位名是权威（战绩、日志、他那边的上下文全用它），这里只做**显示层覆盖**：
/// 改名字不会改比赛记录，换头像也只是本机的图。所以随便改，改坏了点「还原」就回去。
enum MahjongFaces {
    private static func aliasKey(_ name: String) -> String { "qipai.alias." + name }

    static func alias(_ name: String) -> String {
        let v = (UserDefaults.standard.string(forKey: aliasKey(name)) ?? "")
            .trimmingCharacters(in: .whitespaces)
        return v.isEmpty ? name : v
    }

    static func setAlias(_ v: String, for name: String) {
        UserDefaults.standard.set(v.trimmingCharacters(in: .whitespaces), forKey: aliasKey(name))
        bump()
    }

    /// 头像落在 Documents 里，文件名按原名算个稳定哈希（名字里有中文和点，不能直接当文件名）
    private static func fileURL(_ name: String) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var h: UInt64 = 5381
        for b in name.utf8 { h = h &* 33 &+ UInt64(b) }
        return dir.appendingPathComponent("qipai_face_\(h).jpg")
    }

    static func image(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(name).path)
    }

    static func setImage(_ data: Data, for name: String) {
        // 存之前压一道：头像最大边 320 够用了，别把一张 5MB 原图塞进沙盒
        let img = UIImage(data: data)
        let out = img.flatMap { shrink($0, maxSide: 320) }?.jpegData(compressionQuality: 0.85) ?? data
        try? out.write(to: fileURL(name))
        bump()
    }

    static func clear(_ name: String) {
        try? FileManager.default.removeItem(at: fileURL(name))
        UserDefaults.standard.removeObject(forKey: aliasKey(name))
        bump()
    }

    private static func shrink(_ img: UIImage, maxSide: CGFloat) -> UIImage? {
        let side = max(img.size.width, img.size.height)
        guard side > maxSide else { return img }
        let k = maxSide / side
        let size = CGSize(width: img.size.width * k, height: img.size.height * k)
        return UIGraphicsImageRenderer(size: size).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: 桌布（0901 她要的：自己换图，按桌布比例裁）

    /// 桌布是个很扁的长方形。裁剪框、存图、渲染三处都用这一个数，别各写各的。
    static let clothAspect: CGFloat = 2.2

    private static var clothURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("qipai_cloth.jpg")
    }

    static func clothImage() -> UIImage? { UIImage(contentsOfFile: clothURL.path) }

    /// 存已经裁好的那块。长边压到 1600——横屏桌布最宽也就这么点，
    /// 再大只是白占沙盒和内存（她那台是 2 核 4G 的手机不是服务器，但道理一样）
    static func setCloth(_ img: UIImage) {
        let out = shrink(img, maxSide: 1600)?.jpegData(compressionQuality: 0.88)
        guard let out else { return }
        try? out.write(to: clothURL)
        bump()
    }

    static func clearCloth() {
        try? FileManager.default.removeItem(at: clothURL)
        bump()
    }

    /// 改完让界面重画：视图里 @AppStorage 盯着这个数
    static func bump() {
        let n = UserDefaults.standard.integer(forKey: "qipai.facesVersion")
        UserDefaults.standard.set(n + 1, forKey: "qipai.facesVersion")
    }
}

/// 圆形头像：她换过图就用图，没换就用名字第一个字
struct MahjongAvatar: View {
    let name: String
    var tone: Color
    var size: CGFloat = 34
    var active: Bool = false
    /// 只为让 @AppStorage 变化时这个视图跟着重建，本身不用
    var version: Int = 0

    private var initial: String {
        String(MahjongFaces.alias(name).trimmingCharacters(in: .whitespaces).prefix(1))
    }

    var body: some View {
        ZStack {
            if let img = MahjongFaces.image(name) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Circle().fill(LinearGradient(colors: [tone.opacity(0.32), tone.opacity(0.62)],
                                             startPoint: .top, endPoint: .bottom))
                Circle().fill(LinearGradient(colors: [.white.opacity(0.55), .clear],
                                             startPoint: .top, endPoint: .center))
                Text(initial)
                    .font(.system(size: size * 0.46, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .shadow(color: QipaiPalette.shadowTint.opacity(0.35), radius: 1, y: 0.5)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(tone, lineWidth: active ? 2.4 : 1.2))
        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1).padding(1.4))
        .shadow(color: QipaiPalette.shadowTint.opacity(active ? 0.3 : 0.16),
                radius: active ? 5 : 2.5, y: 1.5)
    }
}

/// .fullScreenCover(item:) 要 Identifiable，UIImage 不是，包一层
struct MahjongPickedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - 桌布裁剪（0901 她点名要的「桌布大小的裁剪预览」）

/// 桌布是 2.2:1 的扁长方形，她随手拍的照片多半是竖的，直接铺上去会被裁得乱七八糟。
/// 所以选完图先进这一页：框就是桌布的真实比例，图能拖能捏，她自己挑哪一块露出来。
/// 确定时**照屏幕上那一刻的样子原样重画一遍**（同一套 scale/offset，只是放大到 1600 宽），
/// 所见即所得——别去算什么裁剪矩形再 cropping，那条路最容易在图片方向上翻车。
struct MahjongClothCropper: View {
    let image: UIImage
    var onDone: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero

    private let aspect = MahjongFaces.clothAspect

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - 32
            let h = w / aspect
            VStack(spacing: 16) {
                Text("拖动和捏合，挑桌布上要露出来的那一块")
                    .font(.system(size: 12.5))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 22)

                frame(w: w, h: h)

                Text("框的比例就是牌桌上桌布的比例，框里是什么样，桌上就是什么样")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Spacer()
                HStack(spacing: 14) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                    Button("重置") { reset() }
                        .foregroundColor(.white.opacity(0.75))
                    Button("用这块") {
                        onDone(render(w: w, h: h))
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().fill(.white))
                }
                .font(.system(size: 15))
                .padding(.horizontal, 22).padding(.bottom, 26)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func frame(w: CGFloat, h: CGFloat) -> some View {
        Color.black
            .overlay(
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(scale)
                    .offset(offset)
            )
            .frame(width: w, height: h)
            .clipped()
            .overlay(Rectangle().stroke(.white.opacity(0.9), lineWidth: 2))
            .overlay(grid)
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { v in
                            offset = CGSize(width: steadyOffset.width + v.translation.width,
                                            height: steadyOffset.height + v.translation.height)
                        }
                        .onEnded { _ in steadyOffset = offset },
                    // 用老的 MagnificationGesture：ChatView 里三处都是它，编得过。
                    // 新的 MagnifyGesture 大概率也行，但没必要在这儿冒险试
                    MagnificationGesture()
                        .onChanged { v in scale = max(1, min(steadyScale * v, 6)) }
                        .onEnded { _ in steadyScale = scale }
                )
            )
    }

    /// 三分格参考线，方便她摆正
    private var grid: some View {
        GeometryReader { g in
            Path { p in
                for i in 1...2 {
                    let x = g.size.width * CGFloat(i) / 3
                    let y = g.size.height * CGFloat(i) / 3
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: g.size.height))
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: g.size.width, y: y))
                }
            }
            .stroke(.white.opacity(0.22), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
    }

    private func reset() {
        scale = 1; steadyScale = 1
        offset = .zero; steadyOffset = .zero
    }

    /// 把框里那一块按原样重画成一张 1600 宽的图
    private func render(w: CGFloat, h: CGFloat) -> UIImage {
        let outW: CGFloat = 1600
        let out = CGSize(width: outW, height: outW / aspect)
        let k = outW / max(w, 1)                       // 屏幕 → 成品的放大倍数
        let iw = max(image.size.width, 1)
        let ih = max(image.size.height, 1)
        let base = max(w / iw, h / ih)                 // scaledToFill 的底倍数
        let s = base * scale * k
        let dw = iw * s
        let dh = ih * s
        let cx = out.width / 2 + offset.width * k
        let cy = out.height / 2 + offset.height * k
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: out, format: fmt).image { _ in
            image.draw(in: CGRect(x: cx - dw / 2, y: cy - dh / 2, width: dw, height: dh))
        }
    }
}

// MARK: - 设置面板（横屏「竖屏」按钮下面那个）

struct MahjongFaceSettings: View {
    /// 桌上所有人的**原名**（服务器给的，改的是显示层）
    let names: [String]
    var tone: (String) -> Color
    @Environment(\.dismiss) private var dismiss
    @AppStorage("qipai.facesVersion") private var version = 0
    /// 控制选图页开关
    @State private var picking: String?
    /// ‼️「在给谁选」单独存一份。0901 她抓的「换头像换桌布都不行」就死在这儿：
    /// 系统把选图页关掉 → isPresented 的 setter 把 picking 清成 nil →
    /// 之后 onChange(pick) 才轮到保存，一看不知道给谁的，直接 return，什么都没存。
    /// 顺序是反的。target 只由 loadPick 自己清，关窗动不了它。
    @State private var target: String?
    @State private var pick: PhotosPickerItem?
    @State private var cropping: MahjongPickedImage?

    /// picking 存的是"在给谁选图"：座位名，或者这个哨兵表示在选桌布
    private static let clothSlot = "\u{0}cloth"

    var body: some View {
        NavigationStack {
            List {
                Section("桌布") { clothRow }
                Section("头像和名字") {
                    ForEach(names, id: \.self) { n in row(n) }
                }
                Section {
                    EmptyView()
                } footer: {
                    Text("都只改这台手机上的显示。战绩、日志、他那边看到的名字，都还是原来的。")
                        .font(.system(size: 11))
                }
            }
            .navigationTitle("牌桌设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .photosPicker(isPresented: Binding(get: { picking != nil },
                                           set: { if !$0 { picking = nil } }),
                      selection: $pick, matching: .images)
        .onChange(of: pick) { _ in loadPick() }
        .fullScreenCover(item: $cropping) { box in
            MahjongClothCropper(image: box.image) { MahjongFaces.setCloth($0) }
        }
    }

    // MARK: 桌布那一行

    private var clothRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 预览就按桌布真实比例摆，她一眼看得出贴上去是什么样
            MahjongLaceCloth(version: version)
                .aspectRatio(MahjongFaces.clothAspect, contentMode: .fit)
                .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                Button {
                    target = Self.clothSlot
                    picking = Self.clothSlot
                } label: {
                    Label(MahjongFaces.clothImage() == nil ? "选一张图" : "换一张",
                          systemImage: "photo")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundColor(QipaiPalette.accent)
                Spacer()
                if MahjongFaces.clothImage() != nil {
                    Button("用回粉布") { MahjongFaces.clearCloth() }
                        .font(.system(size: 12.5))
                        .buttonStyle(.plain)
                        .foregroundColor(QipaiPalette.red)
                }
            }
            Text("选完会先让你按桌布的比例裁一次，框里什么样桌上就什么样。花边和波点不会盖掉。")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func row(_ n: String) -> some View {
        HStack(spacing: 12) {
            Button {
                target = n
                picking = n
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    MahjongAvatar(name: n, tone: tone(n), size: 46, version: version)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .padding(3.5)
                        .background(Circle().fill(QipaiPalette.accent))
                        .offset(x: 3, y: 3)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                TextField(n, text: Binding(
                    get: { MahjongFaces.alias(n) },
                    set: { MahjongFaces.setAlias($0, for: n) }))
                    .font(.system(size: 15))
                Text("原名 " + n)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("还原") { MahjongFaces.clear(n) }
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .foregroundColor(QipaiPalette.red)
        }
        .padding(.vertical, 3)
    }

    private func loadPick() {
        guard let item = pick, let who = target else { return }
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            await MainActor.run {
                if let data {
                    if who == Self.clothSlot {
                        // 桌布不直接存：先让她按桌布比例裁一次
                        if let img = UIImage(data: data) {
                            cropping = MahjongPickedImage(image: img)
                        }
                    } else {
                        MahjongFaces.setImage(data, for: who)
                    }
                }
                pick = nil
                picking = nil
                target = nil
            }
        }
    }
}

// MARK: - 抢牌大圆钮（我们自己的风格：拟物玻璃，不是腾讯那种大金饼）

struct MahjongRoundButton: View {
    let text: String
    var tone: Color
    var diameter: CGFloat = 54
    var action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(LinearGradient(
                    colors: pressed ? [tone.opacity(0.75), tone]
                                    : [tone.opacity(0.95), tone.opacity(0.62)],
                    startPoint: .top, endPoint: .bottom))
                Circle().fill(LinearGradient(colors: [.white.opacity(0.62), .clear],
                                             startPoint: .top, endPoint: .center))
                    .padding(1.5)
                Text(text)
                    .font(.system(size: diameter * 0.38, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .shadow(color: QipaiPalette.shadowTint.opacity(0.4), radius: 1, y: 0.7)
            }
            .frame(width: diameter, height: diameter)
            .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.4).padding(1))
            .overlay(Circle().stroke(tone.opacity(0.75), lineWidth: 1))
            .shadow(color: QipaiPalette.shadowTint.opacity(pressed ? 0.12 : 0.3),
                    radius: pressed ? 2 : 6, y: pressed ? 1 : 3)
            .scaleEffect(pressed ? 0.94 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false })
        .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

// MARK: - 座位方位

/// 我永远在下。剩下的按打牌顺序绕圈：下家在右、对家在上、上家在左。
/// 少于四人时不留空位，摆成对称的形状（两人对坐，三人三角）。
enum MahjongSeatSlot {
    case bottom, right, top, left

    static func layout(count: Int) -> [MahjongSeatSlot] {
        switch count {
        case ...1: return [.bottom]
        case 2:    return [.bottom, .top]
        case 3:    return [.bottom, .right, .left]
        default:   return [.bottom, .right, .top, .left]
        }
    }
}

/// 谁坐哪儿。用具名结构不用元组：元组数组的标签转换 Swift 不给隐式做
struct MahjongSeatAssign {
    let player: MahjongPlayerView
    let slot: MahjongSeatSlot
}

/// 头顶那个三秒气泡
private struct MahjongBubble: Equatable {
    let text: String
    let token: Int
}

// MARK: - 横屏牌桌

struct QipaiMahjongLandscapeView: View {
    @ObservedObject var store: QipaiTableStore<MahjongView>
    var onClose: () -> Void

    @State private var showChat = false
    @State private var selected: String?
    @State private var chiPicking = false
    @State private var draft = ""
    @State private var bubbles: [String: MahjongBubble] = [:]
    @State private var bubbleToken = 0
    @State private var showFaces = false
    /// 她在设置里改了头像/名字，这个数一变整页重画
    @AppStorage("qipai.facesVersion") private var facesVersion = 0

    var body: some View {
        GeometryReader { geo in
            let chatW = min(320, geo.size.width * 0.34)
            HStack(spacing: 0) {
                stage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                chatHandle
                if showChat {
                    chatColumn
                        .frame(width: chatW)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .background(ground)
        // ‼️别在这儿加 .ignoresSafeArea()。整树忽略安全区之后，横屏时左边缘的
        // 灵动岛/刘海会压住「竖屏」按钮（她第一次构建的截图里就压着）。
        // 背景自己已经铺满了（ground 内部忽略安全区），内容留在安全区里就对了。
        .onAppear {
            turn(.landscapeRight)
            // 外壳上挂着 .onDisappear { store.stop() }。现在横屏是同树内切换、
            // 外壳没被移出层级，照理不会触发；但 start() 里有 guard sseTask == nil，
            // 补这一刀是空操作，留着当保险——真被掐了这里能自己接回来。
            store.start()
        }
        .onDisappear { turn(.portrait) }
        .onChange(of: (store.view?.seq ?? 0)) { _ in syncSelection() }
        .onChange(of: store.feed.count) { _ in catchBubble() }
        .sheet(isPresented: $showFaces) {
            MahjongFaceSettings(names: (store.view?.players ?? []).map { $0.name },
                                tone: { n in
                                    let pid = (store.view?.players ?? [])
                                        .first { $0.name == n }?.id
                                    return seatTone(pid ?? "")
                                })
        }
    }

    private func turn(_ mask: UIInterfaceOrientationMask) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    }

    /// 局面翻页：抬起的那张可能已经打掉了，清掉免得打出一张不在手里的（同竖屏）
    private func syncSelection() {
        let hand = store.view?.me?.hand ?? []
        if let s = selected, !hand.contains(s) { selected = nil }
        if store.view?.claim?.mine != true { chiPicking = false }
    }

    // MARK: 背景：白瓷波点

    private var ground: some View {
        ZStack {
            QipaiPalette.panel
            QipaiDots(spacing: 16, radius: 1.7, opacity: 0.4)
        }
        .ignoresSafeArea()
    }

    // MARK: 桌面整体

    /// ‼️0901 她要的真透视：**不是**正上方俯拍，是一张摆在面前的桌子。
    /// 俯角 28°（她给的区间 25~35 取中），近大远小、左右边往里收、
    /// 牌的侧面朝着镜头 —— 这些是绕 X 轴旋转 + perspective 之后自然出来的，
    /// 不用逐张牌自己算透视。
    ///
    /// ‼️桌子和牌**一起**转（同一个 ZStack 里），不能只转桌子——
    /// 只转桌子的话牌会浮在斜面上方，比全平还假。
    /// SwiftUI 的 rotation3DEffect 会把点击也一起换算，所以牌照样点得准；
    /// 真要是点偏了跟我说，我把角度收小。
    private let tiltDegrees: Double = 28
    private let tiltPerspective: CGFloat = 0.62

    private var stage: some View {
        GeometryReader { geo in
            ZStack {
                // ── 跟着透视一起斜的那层：桌子 + 桌上所有的牌 ──
                ZStack {
                    MahjongLaceCloth(version: facesVersion)   // 她换了桌布，这块跟着重画
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    if let view = store.view {
                        board(view, size: geo.size)
                    }
                }
                .rotation3DEffect(.degrees(tiltDegrees),
                                  axis: (x: 1, y: 0, z: 0),
                                  anchor: .center,
                                  perspective: tiltPerspective)

                // ── 不跟着斜的那层：界面元件。斜了就难读也难点 ──
                if let view = store.view {
                    overlays(view)
                } else {
                    Text("重连中…")
                        .font(.system(size: 13))
                        .foregroundColor(QipaiPalette.inkDim)
                }
                topBar
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    // MARK: 顶上那条（回竖屏 / 局数 / 状态）

    private var topBar: some View {
        HStack(alignment: .top, spacing: 9) {
            // 竖屏 + 设置竖着摞在左上角（她定的：设置放竖屏按钮下面）
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    turn(.portrait)
                    onClose()
                } label: {
                    pill("rectangle.portrait.rotate", "竖屏")
                }
                .buttonStyle(.plain)
                Button { showFaces = true } label: {
                    pill("person.crop.circle", "设置")
                }
                .buttonStyle(.plain)
            }

            if let r = store.view?.round, r > 0 {
                QipaiChip(text: "第 \(r) 局", tone: .neutral)
            }
            if let line = statusText {
                Text(line)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(statusIsMine ? QipaiPalette.red : QipaiPalette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(QipaiPalette.panel.opacity(0.92)))
                    .overlay(Capsule().stroke(QipaiPalette.line, lineWidth: 1))
            }
        }
        .padding(.leading, 26)
        .padding(.top, 14)
    }

    /// 左上角那两个小胶囊按钮，一个样子
    private func pill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text).font(.system(size: 11.5, weight: .medium))
        }
        .foregroundColor(QipaiPalette.ink)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(QipaiPalette.panel.opacity(0.92)))
        .overlay(Capsule().stroke(QipaiPalette.line, lineWidth: 1))
    }

    /// 「等 XX 表态…」这种一行字，拆出来算，别在插值里套三元（类型检查器吃不消）
    private var statusText: String? {
        guard let view = store.view, view.phase == "playing" else { return nil }
        if let claim = view.claim {
            if claim.mine {
                if claim.kind == "rob" { return "有人补杠 " + claim.label + " —— 抢不抢？" }
                return claim.label + " 摆着，你要不要？"
            }
            // 闭包套闭包最能拖垮类型检查器，拆成三步走
            let who = claim.pending
                .compactMap { view.player($0)?.name }
                .map(MahjongFaces.alias)
                .joined(separator: "、")
            return who.isEmpty ? nil : who + " 正在思考…"
        }
        guard let raw = view.player(view.current)?.name else { return nil }
        let name = MahjongFaces.alias(raw)
        return view.current == view.you ? "轮到你了" : name + " 正在思考…"
    }

    private var statusIsMine: Bool {
        guard let view = store.view else { return false }
        if let claim = view.claim { return claim.mine }
        return view.current == view.you
    }

    // MARK: 四边围坐

    private func board(_ view: MahjongView, size: CGSize) -> some View {
        let seats = seating(view)
        return ZStack {
            centerCluster(view, seats: seats)
            ForEach(Array(seats.enumerated()), id: \.offset) { item in
                seatBlock(item.element.player, slot: item.element.slot, view: view)
            }
            myHandArea(view, width: size.width)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    /// 按打牌顺序给每个人派方位。我永远 bottom，其余沿 turnOrder 往后走。
    /// ‼️元组的标签要一路写全：`[(A, B)]` 不会自动转成 `[(player: A, slot: B)]`，
    /// 数组里的元组标签转换 Swift 不给隐式做，写漏了就是一条 cannot convert。
    private func seating(_ view: MahjongView) -> [MahjongSeatAssign] {
        let order = view.turnOrder
        // 有座位就以我为锚，观战就锚在当前行动的人身上（那人坐 bottom）
        let anchor = view.you ?? view.current ?? order.first
        guard !order.isEmpty, let a = anchor,
              let idx = order.firstIndex(of: a) else {
            return view.players.map { MahjongSeatAssign(player: $0, slot: .bottom) }
        }
        let slots = MahjongSeatSlot.layout(count: order.count)
        var out: [MahjongSeatAssign] = []
        for step in 0..<order.count {
            guard step < slots.count else { break }
            let pid = order[(idx + step) % order.count]
            if let p = view.player(pid) {
                out.append(MahjongSeatAssign(player: p, slot: slots[step]))
            }
        }
        return out
    }

    private func seatTone(_ id: String) -> Color {
        store.seatIndex(ofPlayer: id).map(QipaiPalette.seatTone) ?? QipaiPalette.accent
    }

    // MARK: 一个座位（头像 + 扣着的手牌 + 副露）

    @ViewBuilder
    private func seatBlock(_ p: MahjongPlayerView, slot: MahjongSeatSlot,
                           view: MahjongView) -> some View {
        switch slot {
        case .bottom:
            // 我自己整块都在 myHandArea 里画（头像跟手牌同一行）。
            // ‼️别改回「头像单独钉在 bottomLeading」：手牌那一条也钉在底部、还占满宽，
            // 两个叠在一起头像会被压在牌底下（0901 她第一次构建的截图）。
            EmptyView()
        case .top:
            VStack(spacing: 5) {
                seatHeader(p, slot: slot, view: view)
                backRow(p.handCount, width: 17, axis: .horizontal)
                if !p.melds.isEmpty { meldRow(p.melds, width: 18, axis: .horizontal) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
        case .left:
            HStack(spacing: 5) {
                VStack(spacing: 5) {
                    seatHeader(p, slot: slot, view: view)
                    if !p.melds.isEmpty { meldRow(p.melds, width: 17, axis: .vertical) }
                }
                backRow(p.handCount, width: 15, axis: .vertical)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, 26)
        case .right:
            HStack(spacing: 5) {
                backRow(p.handCount, width: 15, axis: .vertical)
                VStack(spacing: 5) {
                    seatHeader(p, slot: slot, view: view)
                    if !p.melds.isEmpty { meldRow(p.melds, width: 17, axis: .vertical) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 26)
        }
    }

    /// 气泡往哪边冒。0901 她抓的：原来冒在头顶，对家那个直接被屏幕顶切没了。
    /// 一律朝**屏幕中间**冒——右边那家得往左，不然照样出屏。
    private func bubbleDX(_ slot: MahjongSeatSlot) -> CGFloat {
        slot == .right ? -92 : 92
    }

    /// 头像 + 名字 + 张数。轮到他就把头像圈亮，说话就在头像旁边冒气泡
    private func seatHeader(_ p: MahjongPlayerView, slot: MahjongSeatSlot,
                            view: MahjongView) -> some View {
        let owed = view.owed.contains(p.id)
        return VStack(spacing: 3) {
            ZStack {
                MahjongAvatar(name: p.name, tone: seatTone(p.id), size: 36,
                              active: owed, version: facesVersion)
                if let b = bubbles[p.id] {
                    bubbleView(b.text)
                        .offset(x: bubbleDX(slot))
                        .transition(AnyTransition.opacity.combined(with: .scale(scale: 0.85)))
                }
                if view.leader == p.id {
                    Text("庄")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1.5)
                        .background(Capsule().fill(QipaiPalette.red))
                        .offset(x: 16, y: 16)
                }
            }
            .frame(height: 40)
            // 0901：名字和张数坐在一块白卡上。原来直接写在粉布上，糊得看不清
            VStack(spacing: 2) {
                Text(MahjongFaces.alias(p.name))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(seatTone(p.id))
                    .lineLimit(1)
                seatSubline(p)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(nameCard)
        }
        .frame(minWidth: 56)
    }

    /// 名牌那块白卡：顶边一道高光、底下一点投影，跟牌一个光源
    private var nameCard: some View {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        return shape
            .fill(QipaiPalette.panel.opacity(0.95))
            .overlay(shape.strokeBorder(.white.opacity(0.9), lineWidth: 1).padding(0.5))
            .overlay(shape.stroke(MahjongCloth.rimEdge.opacity(0.5), lineWidth: 0.8))
            .shadow(color: QipaiPalette.shadowTint.opacity(0.16), radius: 4, y: 2)
    }

    @ViewBuilder private func seatSubline(_ p: MahjongPlayerView) -> some View {
        if p.out {
            QipaiChip(text: p.won?.zimo == true ? "自摸" : "已胡", tone: .red)
        } else {
            Text(handCountLine(p))
                .font(.system(size: 9)).foregroundColor(QipaiPalette.inkDim)
        }
    }

    private func handCountLine(_ p: MahjongPlayerView) -> String {
        var s = "\(p.handCount) 张"
        if !p.melds.isEmpty { s += " · \(p.melds.count) 副" }
        return s
    }

    /// 我自己那块小牌：头像 + 本局增减
    private func mySeatBadge(_ p: MahjongPlayerView, view: MahjongView) -> some View {
        HStack(spacing: 7) {
            ZStack(alignment: .bottom) {
                MahjongAvatar(name: p.name, tone: seatTone(p.id), size: 38,
                              active: view.owed.contains(p.id), version: facesVersion)
                if let b = bubbles[p.id] {
                    bubbleView(b.text)
                        .offset(y: -46)
                        .transition(AnyTransition.opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)))
                }
            }
            .frame(height: 42)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(MahjongFaces.alias(p.name))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(seatTone(p.id))
                        .lineLimit(1)
                    if view.leader == p.id { QipaiChip(text: "庄", tone: .red) }
                }
                Text(myScoreLine(p))
                    .font(.system(size: 9)).foregroundColor(QipaiPalette.inkDim)
            }
        }
    }

    private func myScoreLine(_ p: MahjongPlayerView) -> String {
        if p.gain > 0 { return "本局 +\(p.gain) · 累计 \(p.score)" }
        if p.gain < 0 { return "本局 \(p.gain) · 累计 \(p.score)" }
        return "累计 \(p.score) 分"
    }

    private func bubbleView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundColor(QipaiPalette.ink)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(maxWidth: 132)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(QipaiPalette.panel))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(QipaiPalette.line, lineWidth: 1))
            .shadow(color: QipaiPalette.shadowTint.opacity(0.18), radius: 4, y: 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: 扣着的手牌 / 副露

    private enum Axis2 { case horizontal, vertical }

    @ViewBuilder
    private func backRow(_ count: Int, width: CGFloat, axis: Axis2) -> some View {
        let n = max(0, min(count, 14))
        if axis == .horizontal {
            HStack(spacing: -width * 0.1) {
                ForEach(0..<n, id: \.self) { _ in MahjongTileBack(width: width) }
            }
        } else {
            VStack(spacing: -width * 0.62) {
                ForEach(0..<n, id: \.self) { _ in MahjongTileBack(width: width) }
            }
        }
    }

    @ViewBuilder
    private func meldRow(_ melds: [MahjongMeld], width: CGFloat, axis: Axis2) -> some View {
        if axis == .horizontal {
            HStack(spacing: 5) {
                ForEach(melds) { m in meldGroup(m, width: width, axis: axis) }
            }
        } else {
            VStack(spacing: 3) {
                ForEach(melds) { m in meldGroup(m, width: width, axis: .horizontal) }
            }
        }
    }

    /// 一组副露。暗杠对别人是四张背面
    private func meldGroup(_ m: MahjongMeld, width: CGFloat, axis: Axis2) -> some View {
        HStack(spacing: -width * 0.16) {
            if let tiles = m.tiles {
                ForEach(Array(tiles.enumerated()), id: \.offset) { item in
                    MahjongTileFace(id: item.element, width: width)
                }
            } else {
                ForEach(0..<max(m.count, 1), id: \.self) { _ in
                    MahjongTileBack(width: width)
                }
            }
        }
    }

    // MARK: 中央：牌河围一圈 + 还剩几张

    private func centerCluster(_ view: MahjongView, seats: [MahjongSeatAssign]) -> some View {
        func tiles(_ slot: MahjongSeatSlot) -> [String] {
            seats.first { $0.slot == slot }?.player.discards ?? []
        }
        return VStack(spacing: 5) {
            riverBlock(tiles(.top), axis: .horizontal, view: view)
            HStack(spacing: 7) {
                riverBlock(tiles(.left), axis: .vertical, view: view)
                wallBadge(view)
                riverBlock(tiles(.right), axis: .vertical, view: view)
            }
            riverBlock(tiles(.bottom), axis: .horizontal, view: view)
        }
        .padding(9)
    }

    /// 中央那个骰盅：立体小方座 + 一个凹进去的圆盘写「剩余 N」。
    /// 0901 她定的：淡，不要玫瑰金。所以座子用台唇同一套浅色。
    private func wallBadge(_ view: MahjongView) -> some View {
        let base = RoundedRectangle(cornerRadius: 17, style: .continuous)
        return ZStack {
            base
                .fill(LinearGradient(colors: [MahjongCloth.rimHi, MahjongCloth.rimLo],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(base.strokeBorder(.white.opacity(0.9), lineWidth: 1.2).padding(0.6))
                .overlay(base.stroke(MahjongCloth.rimEdge.opacity(0.75), lineWidth: 1))
            // 凹进去的盘：内阴影同款做法（描粗→糊开→自己裁）
            Circle()
                .fill(QipaiPalette.panelDeep.opacity(0.55))
                .overlay(Circle().stroke(MahjongCloth.rimEdge.opacity(0.6), lineWidth: 4)
                    .blur(radius: 3).mask(Circle()))
                .padding(9)
            VStack(spacing: -1) {
                Text("剩余")
                    .font(.system(size: 8.5))
                    .foregroundColor(QipaiPalette.inkDim)
                Text("\(view.wallCount)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(QipaiPalette.ink)
            }
        }
        .frame(width: 74, height: 74)
        .shadow(color: QipaiPalette.shadowTint.opacity(0.17), radius: 6, y: 3)
    }

    /// 一家的牌河。横向的排成几行，纵向的排成几列；最后打出那张亮着，其余压暗
    @ViewBuilder
    private func riverBlock(_ tiles: [String], axis: Axis2, view: MahjongView) -> some View {
        let w: CGFloat = 19
        let per = axis == .horizontal ? 9 : 5
        let rows = chunk(tiles, per)
        // 空牌河也占个位，免得中间那圈随出牌一跳一跳。宽高先算成常量再喂 frame——
        // 一句里塞两个三元加字面量正是「expression too complex」的经典形状（这项目栽过三次）
        let padW: CGFloat = axis == .horizontal ? 1 : w
        let padH: CGFloat = axis == .horizontal ? w : 1
        if tiles.isEmpty {
            Color.clear.frame(width: padW, height: padH)
        } else if axis == .horizontal {
            VStack(spacing: 1.5) {
                ForEach(Array(rows.enumerated()), id: \.offset) { row in
                    HStack(spacing: 1.5) {
                        ForEach(Array(row.element.enumerated()), id: \.offset) { item in
                            MahjongTileFace(id: item.element, width: w,
                                            dimmed: !isFresh(item.element, tiles: tiles, view: view))
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 1.5) {
                ForEach(Array(rows.enumerated()), id: \.offset) { col in
                    VStack(spacing: 1.5) {
                        ForEach(Array(col.element.enumerated()), id: \.offset) { item in
                            MahjongTileFace(id: item.element, width: w,
                                            dimmed: !isFresh(item.element, tiles: tiles, view: view))
                        }
                    }
                }
            }
        }
    }

    /// 是不是场上最后打出的那张（牌 id 每张唯一，直接比就行）
    private func isFresh(_ id: String, tiles: [String], view: MahjongView) -> Bool {
        guard let last = view.lastDiscard else { return false }
        return last.tile == id && tiles.last == id
    }

    private func chunk(_ arr: [String], _ n: Int) -> [[String]] {
        guard n > 0, !arr.isEmpty else { return [] }
        var out: [[String]] = []
        var i = 0
        while i < arr.count {
            out.append(Array(arr[i..<min(i + n, arr.count)]))
            i += n
        }
        return out
    }

    // MARK: 我这一横条：手牌 —— 间距 —— 副露

    private func myHandArea(_ view: MahjongView, width: CGFloat) -> some View {
        VStack(spacing: 7) {
            actionCluster(view)
            HStack(alignment: .bottom, spacing: 12) {
                if let me = view.me { mySeatBadge(me, view: view) }
                handStrip(view, width: width)
            }
            .padding(.horizontal, 22)
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func handStrip(_ view: MahjongView, width: CGFloat) -> some View {
        if let me = view.me, let hand = me.hand {
            let drawn = view.drawn
            let rest = hand.filter { $0 != drawn }
            let showDrawn = drawn.map { hand.contains($0) } ?? false
            let n = rest.count + (showDrawn ? 1 : 0)
            let w = handTileWidth(count: n, stage: width, melds: me.melds.count)
            let canDiscard = view.claim == nil && view.current == view.you && view.phase == "playing"
            HStack(alignment: .bottom, spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    ForEach(rest, id: \.self) { id in tileButton(id, width: w, enabled: canDiscard) }
                    if showDrawn, let d = drawn {
                        // 刚摸的那张单独摆右边（麻将老规矩，一眼看得出是哪张）
                        Spacer().frame(width: w * 0.34)
                        tileButton(d, width: w, enabled: canDiscard)
                    }
                }
                if !me.melds.isEmpty {
                    // 她点名的：副露跟自己的牌之间留一段，别连着排
                    Spacer().frame(width: 30)
                    HStack(spacing: 6) {
                        ForEach(me.melds) { m in meldGroup(m, width: w * 0.66, axis: .horizontal) }
                    }
                }
                Spacer(minLength: 0)
            }
        } else {
            Text("观战中 · 谁的手牌都看不见")
                .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
                .padding(.bottom, 10)
        }
    }

    /// 手牌一横条，宽度随场地和副露多少缩放——聊天室拉开时桌子变窄，牌跟着变小。
    /// 左边还要给自己那块头像牌让出位置（约 170），别让牌顶到它身上。
    private func handTileWidth(count: Int, stage: CGFloat, melds: Int) -> CGFloat {
        let meldRoom = CGFloat(melds) * 74 + (melds > 0 ? 30 : 0)
        let badgeRoom: CGFloat = 170
        let usable = max(stage - meldRoom - badgeRoom - 56, 120)
        let raw = usable / CGFloat(max(count, 1))
        return min(max(raw, 18), 38)
    }

    private func tileButton(_ id: String, width: CGFloat, enabled: Bool) -> some View {
        MahjongTileFace(id: id, width: width)
            .offset(y: selected == id ? -14 : 0)
            .onTapGesture {
                guard enabled else { return }
                selected = (selected == id) ? nil : id      // 再点一下放回去
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.75), value: selected == id)
    }

    // MARK: 操作区（抢牌大圆钮 / 打出）

    private var claimMoves: [QipaiLegalMove] { store.legal.filter { $0.type == "claim" } }
    private func claims(_ kind: String) -> [QipaiLegalMove] { claimMoves.filter { $0.kind == kind } }

    @ViewBuilder
    private func actionCluster(_ view: MahjongView) -> some View {
        if view.phase != "playing" {
            EmptyView()
        } else if let claim = view.claim, claim.mine {
            if chiPicking { chiPicker(claim) } else { claimButtons() }
        } else if view.claim == nil, view.current == view.you {
            turnBar(view)
        } else {
            EmptyView()   // 不是我的事就什么都不摆——状态那行字在顶上写着
        }
    }

    /// 胡 ＞ 碰/杠 ＞ 吃，最后永远有个「过」。摆在手牌上方偏右（照参考图）
    private func claimButtons() -> some View {
        HStack(spacing: 11) {
            Spacer(minLength: 0)
            if let hu = claims("hu").first {
                MahjongRoundButton(text: "胡", tone: QipaiPalette.red, diameter: 58) { send(hu) }
                    .disabled(store.busy)
            }
            if let gang = claims("gang").first {
                MahjongRoundButton(text: "杠", tone: QipaiPalette.qhex(0xB08D57)) { send(gang) }
                    .disabled(store.busy)
            }
            if let peng = claims("peng").first {
                MahjongRoundButton(text: "碰", tone: QipaiPalette.qhex(0x6E9A87)) { send(peng) }
                    .disabled(store.busy)
            }
            if !claims("chi").isEmpty {
                MahjongRoundButton(text: "吃", tone: QipaiPalette.accent) {
                    let opts = claims("chi")
                    if opts.count == 1 { send(opts[0]) } else { chiPicking = true }
                }
                .disabled(store.busy)
            }
            MahjongRoundButton(text: "过", tone: QipaiPalette.qhex(0x9AA0AD), diameter: 50) {
                Task { await store.act(["type": "pass"]) }
            }
            .disabled(store.busy)
        }
        .padding(.trailing, 40)
    }

    /// 吃的第二段：把每种搭法连同被吃那张摆成一组，点哪组吃哪组（防手滑，同竖屏）
    private func chiPicker(_ claim: MahjongClaim) -> some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Text("怎么吃 \(claim.label)？")
                .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
            ForEach(claims("chi")) { mv in
                Button { send(mv) } label: {
                    HStack(spacing: 1.5) {
                        ForEach(chiRun(mv, claim: claim), id: \.self) { t in
                            MahjongTileFace(id: t, width: 24)
                        }
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(QipaiPalette.fieldBg))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(QipaiPalette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(store.busy)
            }
            Button("算了") { chiPicking = false }
                .buttonStyle(QipaiEmbossedButtonStyle())
        }
        .padding(.trailing, 40)
    }

    private func chiRun(_ mv: QipaiLegalMove, claim: MahjongClaim) -> [String] {
        var out: [String] = mv.tiles ?? []
        out.append(mv.tile ?? claim.tile)
        out.sort { MahjongTile.num($0) < MahjongTile.num($1) }
        return out
    }

    /// 轮到我打牌：自摸/暗杠/补杠按合法招现给，加上常驻「打出」（两段出牌，防手滑）
    private func turnBar(_ view: MahjongView) -> some View {
        let zimo = store.legal.first { $0.type == "zimo" }
        let gangs = store.legal.filter { $0.type == "angang" || $0.type == "bugang" }
        return HStack(spacing: 10) {
            Spacer(minLength: 0)
            if let zimo {
                MahjongRoundButton(text: "胡", tone: QipaiPalette.red, diameter: 58) { send(zimo) }
                    .disabled(store.busy)
            }
            ForEach(gangs) { mv in
                Button(mv.label ?? "杠") { send(mv) }
                    .buttonStyle(QipaiEmbossedButtonStyle())
                    .disabled(store.busy)
            }
            Text(selected.map { "打 " + MahjongTile.label($0) } ?? "点一张牌抬起来")
                .font(.system(size: 11))
                .foregroundColor(selected == nil ? QipaiPalette.inkDim : QipaiPalette.ink)
            Button("打出") {
                guard let sel = selected else { return }
                selected = nil
                Task { await store.act(["type": "discard", "tile": sel]) }
            }
            .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
            .disabled(selected == nil || store.busy)
        }
        .padding(.trailing, 40)
    }

    private func send(_ mv: QipaiLegalMove) {
        chiPicking = false
        selected = nil
        var body: [String: Any] = ["type": mv.type]
        if let k = mv.kind { body["kind"] = k }
        if let t = mv.tile { body["tile"] = t }
        if let ts = mv.tiles { body["tiles"] = ts }
        Task { await store.act(body) }
    }

    // MARK: 结算盖板（横屏版，比竖屏窄一点）

    @ViewBuilder
    private func overlays(_ view: MahjongView) -> some View {
        if view.phase == "round_over" || view.phase == "game_over" {
            VStack(spacing: 10) {
                if view.phase == "round_over", let r = view.lastResults {
                    Text(resultTitle(r))
                        .font(.qipaiDisplay(24)).foregroundColor(QipaiPalette.ink)
                    ForEach(r.players) { row in
                        HStack {
                            Text(row.name).font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(QipaiPalette.ink)
                            Spacer()
                            Text(gainText(row.gain))
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                .foregroundColor(gainTone(row.gain))
                            Text("累计 \(row.score)")
                                .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                                .frame(width: 56, alignment: .trailing)
                        }
                    }
                } else {
                    Text("收盤").font(.qipaiDisplay(24)).foregroundColor(QipaiPalette.ink)
                    if let w = view.player(view.winner) {
                        Text("\(w.name) 是最后的大赢家")
                            .font(.system(size: 12)).foregroundColor(QipaiPalette.inkDim)
                    }
                }
                resultButtons(view)
            }
            .padding(16)
            .frame(maxWidth: 320)
            .qipaiPanel(corner: 20, dotted: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.3))
        }
    }

    private func resultTitle(_ r: MahjongResults) -> String {
        if r.draw { return "流局" }
        return r.winners.count > 1 ? "一炮多响" : "胡了"
    }

    private func gainText(_ g: Int) -> String { g > 0 ? "+\(g)" : "\(g)" }

    private func gainTone(_ g: Int) -> Color {
        if g > 0 { return QipaiPalette.accent }
        if g < 0 { return QipaiPalette.red }
        return QipaiPalette.inkDim
    }

    @ViewBuilder
    private func resultButtons(_ view: MahjongView) -> some View {
        HStack(spacing: 10) {
            if view.phase == "round_over", store.mySeat != nil {
                Button("再来一局") { Task { await store.nextRound() } }
                    .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                    .disabled(store.busy)
            }
            Button("回竖屏") {
                turn(.portrait)
                onClose()
            }
            .buttonStyle(QipaiEmbossedButtonStyle())
        }
    }

    // MARK: 右边缘的拉手

    private var chatHandle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.26)) { showChat.toggle() }
        } label: {
            ZStack {
                MahjongTabShape(radius: 13)
                    .fill(LinearGradient(colors: [QipaiPalette.panel, QipaiPalette.panelDeep],
                                         startPoint: .top, endPoint: .bottom))
                MahjongTabShape(radius: 13)
                    .stroke(QipaiPalette.line, lineWidth: 1)
                Image(systemName: showChat ? "chevron.right" : "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(QipaiPalette.accent)
            }
            .frame(width: 24, height: 92)
            .shadow(color: QipaiPalette.shadowTint.opacity(0.16), radius: 4, x: -2)
        }
        .buttonStyle(.plain)
    }

    // MARK: 迷你聊天室

    private var chatColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("牌桌闲聊").font(.qipaiMemo(14)).foregroundColor(QipaiPalette.ink)
                Spacer()
                if !store.connected {
                    QipaiChip(text: "重连中", tone: .red)
                }
            }
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 6)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(store.feed) { item in feedRow(item) }
                        Color.clear.frame(height: 1).id("tail")
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                }
                .onChange(of: store.feed.count) { _ in
                    withAnimation(.easeOut(duration: 0.24)) { proxy.scrollTo("tail", anchor: .bottom) }
                }
                .onAppear { proxy.scrollTo("tail", anchor: .bottom) }
            }

            // 横屏键盘这条路 CowatchView 0826 趟过了，照它的形状写，别从零试
            HStack(spacing: 7) {
                TextField("说点什么…", text: $draft)
                    .font(.system(size: 12.5))
                    .foregroundColor(QipaiPalette.ink)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(Capsule().fill(QipaiPalette.fieldBg))
                    .overlay(Capsule().stroke(QipaiPalette.line, lineWidth: 1))
                    .submitLabel(.send)
                    .onSubmit(sendDraft)
                Button(action: sendDraft) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 12)
        }
        .background(QipaiPalette.panel)
        .overlay(Rectangle().frame(width: 1).foregroundColor(QipaiPalette.line),
                 alignment: .leading)
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        draft = ""
        Task { await store.sendChat(text) }
    }

    @ViewBuilder private func feedRow(_ item: QipaiFeedItem) -> some View {
        switch item {
        case .log(let e):
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("›").font(.system(size: 10, weight: .bold))
                    .foregroundColor(QipaiPalette.inkDim.opacity(0.6))
                Text(e.text)
                    .font(.system(size: 10.5))
                    .foregroundColor(QipaiPalette.inkDim)
            }
            .padding(.horizontal, 8).padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Capsule().fill(QipaiPalette.panelDeep.opacity(0.45)))
        case .chat(let m):
            VStack(alignment: .leading, spacing: 2) {
                Text(m.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(store.seatIndex(of: m).map(QipaiPalette.seatTone)
                                     ?? QipaiPalette.accent)
                Text(m.text)
                    .font(.system(size: 12))
                    .foregroundColor(QipaiPalette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(QipaiPalette.fieldBg))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(QipaiPalette.line, lineWidth: 0.8))
            }
        }
    }

    // MARK: 头顶气泡：谁说一句就冒一个，3 秒消失（历史照样在聊天室里翻）

    private func catchBubble() {
        guard case .chat(let m)? = store.feed.last, let who = m.by else { return }
        bubbleToken += 1
        let token = bubbleToken
        withAnimation(.easeOut(duration: 0.2)) {
            bubbles[who] = MahjongBubble(text: m.text, token: token)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            // 这 3 秒里他要是又说了一句，token 就变了——那条归新的计时，别提前抹掉
            guard bubbles[who]?.token == token else { return }
            withAnimation(.easeIn(duration: 0.25)) { bubbles[who] = nil }
        }
    }
}
