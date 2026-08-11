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
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let nextMidnight = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [LabEntry(date: now)], policy: .after(nextMidnight)))
    }
}

private struct AlcoveHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlcoveCapabilityWidget", provider: LabProvider()) { entry in
            AlcoveWidgetView(entry: entry)
        }
        .configurationDisplayName("Alcove")
        .description("看看家里此刻正在发生什么。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

private struct AlcoveWidgetView: View {
    let entry: LabEntry

    @Environment(\.widgetFamily) private var family

    @ViewBuilder
    var body: some View {
        switch family {
        case .systemSmall:
            widgetContent
                .containerBackground(
                    Color(red: 0.08, green: 0.075, blue: 0.09),
                    for: .widget
                )
        case .systemMedium:
            widgetContent
                .containerBackground(
                    Color(red: 0.21, green: 0.21, blue: 0.23),
                    for: .widget
                )
        default:
            widgetContent
                .containerBackground(.clear, for: .widget)
        }
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch family {
        case .systemMedium:
            ZStack {
                Color(red: 0.21, green: 0.21, blue: 0.23)
                HStack(spacing: 22) {
                    RavenMark(size: 118)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time, gently kept.")
                            .font(.system(.title3, design: .serif, weight: .medium))
                            .italic()
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("✦")
                                .font(.title3)
                            Text("\(togetherDays)")
                                .font(.system(size: 42, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Text("DAYS")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
            }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                RavenMark(size: 35)
            }
            .widgetAccentable()

        case .accessoryRectangular:
            HStack(spacing: 7) {
                RavenMark(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Still here")
                        .font(.headline)
                    Text("NEAR, ALWAYS.")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 2)
                Image(systemName: "heart.fill")
                    .font(.caption)
            }
            .widgetAccentable()

        case .accessoryInline:
            Label("Still here", systemImage: "heart.fill")

        default:
            ZStack {
                Color(red: 0.08, green: 0.075, blue: 0.09)
                VStack(spacing: 7) {
                    RavenMark(size: 78)
                    Text("Still here")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    HStack(spacing: 5) {
                        Text("ALCOVE · ONLINE")
                        Image(systemName: "heart.fill")
                    }
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)
                .padding(10)
            }
        }
    }

    private var togetherDays: Int {
        let calendar = Calendar.autoupdatingCurrent
        guard let startDate = calendar.date(
            from: DateComponents(year: 2026, month: 6, day: 1)
        ) else { return 0 }

        let start = calendar.startOfDay(for: startDate)
        let today = calendar.startOfDay(for: entry.date)
        return max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
    }
}

private struct RavenMark: View {
    let size: CGFloat

    var body: some View {
        Image("RavenOutlined", bundle: .main)
            .resizable()
            .renderingMode(.original)
            .interpolation(.none)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipped()
            .accessibilityHidden(true)
    }
}

private struct AlcoveLabLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlcoveLabAttributes.self) { context in
            HStack(spacing: 12) {
                RavenMark(size: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Still here")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    Text("\(context.attributes.name) · ONLINE")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(context.state.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    PulseNumber(bpm: context.state.bpm, size: 15)
                    VStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.headline)
                        Text("PULSE")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .tracking(1)
                    }
                }
            }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RavenMark(size: 48)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("Still here")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                        Text("\(context.attributes.name) · ONLINE")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 6) {
                        PulseNumber(bpm: context.state.bpm, size: 14)
                        VStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.headline)
                            Text("PULSE")
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .tracking(1)
                        }
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                RavenMark(size: 23)
            } compactTrailing: {
                HStack(spacing: 3) {
                    PulseNumber(bpm: context.state.bpm, size: 11)
                    Image(systemName: "heart.fill")
                        .font(.caption)
                }
                .foregroundStyle(.white)
            } minimal: {
                RavenMark(size: 23)
            }
            .keylineTint(.white)
        }
    }
}

private struct PulseNumber: View {
    let bpm: Int
    let size: CGFloat

    var body: some View {
        Text(bpm > 0 ? "\(bpm)" : "—")
            .font(.system(size: size, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .contentTransition(.numericText())
            .accessibilityLabel(bpm > 0 ? "心率 \(bpm)" : "心率暂无数据")
    }
}
