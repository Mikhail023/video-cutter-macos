import SwiftUI

struct TimelineView: View {
    let duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Видеодорожка")
                    .font(.caption.weight(.medium))
                Spacer()
                Text(VideoTimeFormatter.string(for: duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.25))
                    HStack(spacing: 2) {
                        ForEach(0..<12, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white.opacity(0.12))
                        }
                    }
                    .padding(3)
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2)
                        .offset(x: max(0, geometry.size.width * 0.1))
                }
            }
            .frame(height: 58)

            Text("Аудиодорожка появится здесь после загрузки метаданных.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }
}
