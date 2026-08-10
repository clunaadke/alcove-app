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
        StaticConfiguration(kind: "AlcoveCapabilityWidget", provider: LabProvider()) { entry in
            AlcoveWidgetView(entry: entry)
        }
        .configurationDisplayName("Alcove 体检")
        .description("验证 Personal Team 能否安装并运行小组件。")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

private struct AlcoveWidgetView: View {
    let entry: LabEntry

    @Environment(\.widgetFamily) private var family

    @ViewBuilder
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Alcove")
                        .font(.caption2)
                        .minimumScaleFactor(0.7)
                }
            }
            .widgetAccentable()

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Label("Alcove", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                Text("小组件已运行")
                    .font(.caption)
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .widgetAccentable()

        case .accessoryInline:
            Label("Alcove 小组件已运行", systemImage: "checkmark.circle.fill")

        default:
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
    }
}

private struct AlcoveLabLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlcoveLabAttributes.self) { context in
            Text("\(context.attributes.name) · \(context.state.message)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Alcove")
                        .foregroundStyle(.pink)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.name)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.message)
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            } compactLeading: {
                Text("A")
                    .foregroundStyle(.pink)
            } compactTrailing: {
                Text("渡")
                    .foregroundStyle(.white)
            } minimal: {
                Text("A")
                    .foregroundStyle(.pink)
            }
            .keylineTint(.pink)
        }
    }
}
