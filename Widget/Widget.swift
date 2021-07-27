//
//  Widget.swift
//  Widget
//
//  Created by Kevin Guan on 7/3/21.
//

import Intents
import SwiftUI
import WidgetKit

struct EmailEntry: TimelineEntry {
    let available: Bool
    let from: String
    let date: Date
    let title: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> EmailEntry {
        return EmailEntry(available: true, from: "test@hello.com", date: Date(), title: "Welcome to PGPEmail App!")
    }

    func getLatest() -> EmailEntry {
        if let userDefaults = UserDefaults(suiteName: "group.com.kevinguan.PGPEmailGroup") {
            if let from = userDefaults.string(forKey: "from"), let title = userDefaults.string(forKey: "title") {
                let date = userDefaults.integer(forKey: "date")
                return EmailEntry(available: true, from: from, date: Date(timeIntervalSince1970: TimeInterval(date)), title: title)
            }
        }

        let readMessage = Storage.retrieve("INBOX.data", as: [Message].self) ?? []
        if let last = readMessage.first {
            let name = last.from.name
            return EmailEntry(available: true, from: name == "" ? last.from.email : name, date: last.sendDate, title: last.subject)
        }

        return EmailEntry(available: false, from: "", date: Date(), title: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (EmailEntry) -> ()) {
        let latest = getLatest()
        completion(latest)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let latest = getLatest()
        completion(Timeline(entries: [latest], policy: .atEnd))
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family: WidgetFamily
    let available: Bool
    let from: String
    let date: Date
    let title: String

    @ViewBuilder
    var body: some View {
        switch family {
        case .systemSmall: WidgetSmallView(available: available, from: from, date: date, title: title)
        default: WidgetNotAvailableView()
        }
    }
}

struct WidgetSmallView: View {
    let available: Bool
    let from: String
    let date: Date
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if available {
                Group {
                    Text(from)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                        .padding(.top)
                        .padding(.horizontal)

                    Text(getDisplayDate(date: date))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.top, 3)

                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                        .padding(.top, 3)
                        .lineLimit(4)
                }
                .widgetURL(URL(string: "widget://")!)
                Spacer()
            } else {
                Text("No email is available at this moment")
                    .padding()
            }
        }
    }
    
    func getDisplayDate(date: Date) ->String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, h:mm a"
        return dateFormatter.string(from: date)
    }
}

struct WidgetNotAvailableView: View {
    var body: some View {
        Text("Widget Not Available")
    }
}

@main
struct Widget: SwiftUI.Widget {
    let kind: String = "Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetEntryView(available: entry.available, from: entry.from, date: entry.date, title: entry.title)
        }
        .configurationDisplayName("Latest Email")
        .supportedFamilies([.systemSmall])
        .description("View the latest email")
    }
}
