import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AlcoveCapabilityWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlcoveHomeWidget()
        AlcoveLabLiveActivity()
    }
}

private struct LabEntry: TimelineEntry {
    let date: Date
}

private struct LabProvider: TimelineProvider {
    func placeholder(in context: Context) -> LabEntry { LabEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (LabEntry) -> Void) {
        completion(LabEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LabEntry>) -> Void) {
        completion(Timeline(entries: [LabEntry(date: .now)], policy: .never))
    }
}

private struct AlcoveHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlcoveCapabilityWidget", provider: LabProvider()) { _ in
            ZStack {
                Color(red: 0.08, green: 0.075, blue: 0.09)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Alcove")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                    Text("免费签名体检")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("小组件已运行", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .padding()
            }
            .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Alcove 体检")
        .description("验证 Personal Team 能否安装并运行小组件。")
        .supportedFamilies([.systemSmall])
    }
}

private struct AlcoveLabLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlcoveLabAttributes.self) { context in
            HStack(spacing: 10) {
                Image(systemName: "wave.3.right.circle.fill")
                VStack(alignment: .leading) {
                    Text(context.attributes.name)
                        .font(.headline)
                    Text(context.state.message)
                        .font(.caption)
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.86))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "wave.3.right")
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.name)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.message).font(.caption)
                }
            } compactLeading: {
                Image(systemName: "wave.3.right")
            } compactTrailing: {
                Text("在")
            } minimal: {
                Image(systemName: "wave.3.right")
            }
        }
    }
}
