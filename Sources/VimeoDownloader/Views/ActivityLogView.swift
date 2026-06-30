import SwiftUI

struct ActivityLogView: View {
    let title: String
    let subtitle: String
    let lines: [String]
    let progress: Double?
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if isRunning {
                    ProgressView(value: progress)
                        .frame(width: 160)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if lines.isEmpty {
                            ContentUnavailableView("No Log Output", systemImage: "terminal")
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }
                        }
                    }
                    .padding(10)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onChange(of: lines.count) { _, count in
                    guard count > 0 else {
                        return
                    }
                    proxy.scrollTo(count - 1, anchor: .bottom)
                }
            }
        }
        .padding()
    }
}
