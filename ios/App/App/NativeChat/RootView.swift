import SwiftUI

// App 根视图：原生聊天页为主，右上角进完整小屋（WebView 兜底）
struct RootView: View {
    @State private var showHouse = false
    @AppStorage("assistantName") private var assistantName = "陈璟"

    var body: some View {
        NavigationStack {
            ChatView()
                .navigationTitle(assistantName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showHouse = true } label: {
                            Image(systemName: "house")
                        }
                    }
                }
                .fullScreenCover(isPresented: $showHouse) {
                    NavigationStack {
                        WebViewPage(url: AlcoveAPI.base)
                            .ignoresSafeArea(edges: .bottom)
                            .navigationTitle("小屋")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("返回聊天") { showHouse = false }
                                }
                            }
                    }
                }
        }
        .tint(Color(red: 0.86, green: 0.44, blue: 0.57))
    }
}
