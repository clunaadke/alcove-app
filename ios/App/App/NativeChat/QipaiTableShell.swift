import SwiftUI
import UIKit

// 三张牌桌共用的外壳：背景、顶栏（返回/连接状态/聊天/帮助）、等人开局页、
// 牌桌聊天、toast、SSE 生命周期。游戏各自只画"开局之后"的桌面和自己的帮助页。

struct QipaiTableShell<GameV: Decodable, Content: View, Help: View>: View {
    @ObservedObject var store: QipaiTableStore<GameV>
    let fallbackTitle: String
    var round: Int?
    var onExit: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let help: () -> Help

    @State private var showChat = false
    @State private var showHelp = false
    @State private var chatDraft = ""
    @State private var inviteCopied = false

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                if let frame = store.frame {
                    if !frame.started {
                        waitingRoom(frame)
                    } else if store.view != nil {
                        content()
                    } else {
                        ProgressView().frame(maxHeight: .infinity)
                    }
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }
            }
            toast
        }
        .onAppear { store.start() }
        .onDisappear { store.stop() }
        .onChange(of: store.frame?.closed ?? false) { closed in
            if closed { onExit() }
        }
        .sheet(isPresented: $showChat) { chatSheet }
        .sheet(isPresented: $showHelp) { helpSheet }
    }

    // MARK: 背景与顶栏

    private var background: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            Image("QipaiWallPortrait2")
                .resizable().scaledToFill().ignoresSafeArea()
                .opacity(QipaiPalette.night ? 0.18 : 0.45)
            QipaiPalette.fog.opacity(QipaiPalette.night ? 0.72 : 0.55).ignoresSafeArea()
            QipaiDots(spacing: 18, radius: 1.2, opacity: 0.16).ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { onExit() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(QipaiEmbossedButtonStyle())

            VStack(alignment: .leading, spacing: 1) {
                Text(store.frame.map { $0.name.isEmpty ? $0.gameName : $0.name } ?? fallbackTitle)
                    .font(.system(size: 14.5, weight: .bold, design: .serif))
                    .foregroundColor(QipaiPalette.ink)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(store.code).font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(QipaiPalette.inkDim)
                    if let round {
                        Text("第 \(round) 局").font(.system(size: 9.5))
                            .foregroundColor(QipaiPalette.inkDim)
                    }
                }
            }
            Spacer()
            Circle()
                .fill(store.connected ? QipaiPalette.accent : QipaiPalette.red)
                .frame(width: 7, height: 7)
            Text(store.connected ? "已連接" : "重連中")
                .font(.system(size: 9.5)).foregroundColor(QipaiPalette.inkDim)
            Button { showChat = true } label: {
                Image(systemName: "bubble.left").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(QipaiEmbossedButtonStyle())
            Button { showHelp = true } label: {
                Image(systemName: "questionmark").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(QipaiEmbossedButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: 等人开局

    private func waitingRoom(_ frame: QipaiTableFrame<GameV>) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text("等人上桌")
                .font(.qipaiDisplay(24))
                .foregroundColor(QipaiPalette.ink)
            Text("\(frame.seats.count)/\(frame.maxPlayers) 人 · 房號 \(frame.code)")
                .font(.system(size: 12)).foregroundColor(QipaiPalette.inkDim)
            VStack(spacing: 8) {
                ForEach(frame.seats) { seat in
                    HStack(spacing: 8) {
                        Image(systemName: seat.isAI ? "sparkles" : "person.fill")
                            .font(.system(size: 11))
                            .foregroundColor(QipaiPalette.accent)
                        Text(seat.name).font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(QipaiPalette.ink)
                        if seat.isHost { QipaiChip(text: "房主", tone: .live) }
                        Spacer()
                    }
                    .padding(11)
                    .qipaiPanel(corner: 13)
                }
            }
            .padding(.horizontal, 30)

            if let invite = frame.inviteToken {
                Button {
                    UIPasteboard.general.string = QipaiAPI.inviteLink(code: frame.code, inviteToken: invite)
                    inviteCopied = true
                } label: {
                    Label(inviteCopied ? "邀請連結已複製" : "複製邀請連結",
                          systemImage: inviteCopied ? "checkmark" : "link")
                }
                .buttonStyle(QipaiEmbossedButtonStyle())
            }

            Spacer()
            if store.isHost {
                if frame.seats.count >= frame.minPlayers {
                    QipaiSlideControl(label: "slide to 開局") { Task { await store.startGame() } }
                        .padding(.horizontal, 34)
                } else {
                    QipaiWhisper(text: "人齊了才能開。喊人，或者回大廳拉 AI。")
                }
            } else {
                QipaiWhisper(text: "等房主開局…")
            }
            Spacer().frame(height: 30)
        }
    }

    // MARK: toast / 聊天 / 帮助

    @ViewBuilder private var toast: some View {
        if let text = store.toast {
            VStack {
                Spacer()
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    // 固定深底白字，日夜都成立（夜里 ink 是月白，不能当底色）
                    .background(Capsule().fill(QipaiPalette.qhex(0x2A2F38).opacity(0.94)))
                    .padding(.bottom, 130)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: store.toast)
            .allowsHitTesting(false)
        }
    }

    private var chatSheet: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            QipaiDots(spacing: 16, radius: 1.3, opacity: 0.25).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("牌桌閒聊")
                    .font(.qipaiMemo(17))
                    .foregroundColor(QipaiPalette.ink)
                    .padding(.top, 16)
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.frame?.chat ?? []) { msg in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(msg.name)
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundColor(QipaiPalette.accent)
                                    Text(msg.text)
                                        .font(.system(size: 12.5))
                                        .foregroundColor(QipaiPalette.ink)
                                        .padding(.horizontal, 11).padding(.vertical, 7)
                                        .background(RoundedRectangle(cornerRadius: 13)
                                            .fill(.white.opacity(0.85)))
                                        .overlay(RoundedRectangle(cornerRadius: 13)
                                            .stroke(QipaiPalette.line, lineWidth: 0.8))
                                }
                                .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: store.frame?.chat.count ?? 0) { _ in
                        if let last = store.frame?.chat.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if let last = store.frame?.chat.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                HStack(spacing: 8) {
                    TextField("聊點什麼…", text: $chatDraft)
                        .font(.system(size: 13))
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Capsule().fill(.white.opacity(0.9)))
                        .overlay(Capsule().stroke(QipaiPalette.line, lineWidth: 1))
                    Button {
                        let text = chatDraft
                        chatDraft = ""
                        Task { await store.sendChat(text) }
                    } label: {
                        Image(systemName: "paperplane.fill").font(.system(size: 13))
                    }
                    .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                    .disabled(chatDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var helpSheet: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    help()
                    QipaiWhisper(text: "no real money. only face.")
                }
                .padding(20)
            }
        }
        .presentationDetents([.medium])
    }
}
