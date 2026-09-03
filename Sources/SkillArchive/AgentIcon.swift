import SwiftUI
import AppKit

/// A small icon representing one agent: the real installed app's icon when we can find one
/// on disk, otherwise a colored monogram/glyph chip so every agent still reads as distinct.
struct AgentIcon: View {
    let agent: AgentLocation?
    var size: CGFloat = 18

    private static var cache: [String: NSImage] = [:]

    private var resolvedAppIcon: NSImage? {
        guard let agent else { return nil }
        if let cached = Self.cache[agent.id] { return cached }
        for bundleID in Self.bundleCandidates[agent.id] ?? [] {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                Self.cache[agent.id] = icon
                return icon
            }
        }
        return nil
    }

    var body: some View {
        Group {
            if let nsImage = resolvedAppIcon {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                let spec = Self.fallback[agent?.id ?? ""] ?? ("app.dashed", Color.gray, nil)
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(spec.1.gradient)
                    .frame(width: size, height: size)
                    .overlay(
                        Group {
                            if let glyph = spec.2 {
                                Text(glyph)
                                    .font(.system(size: size * 0.52, weight: .bold, design: .rounded))
                            } else {
                                Image(systemName: spec.0)
                                    .font(.system(size: size * 0.5, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.28)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                    )
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
    }

    /// Real bundle IDs to look up via NSWorkspace when the app happens to be installed —
    /// only added where we're certain of the ID, so we never show the wrong app's icon.
    private static let bundleCandidates: [String: [String]] = [
        "cursor": ["com.todesktop.230313mzl4w4u92"],
    ]

    /// Fallback glyph chip per agent: (SF Symbol name or nil, tint color, text glyph or nil).
    /// Exactly one of symbol/glyph is used.
    private static let fallback: [String: (String, Color, String?)] = [
        "claude": ("", Color(red: 0.82, green: 0.47, blue: 0.36), "C"),
        "cursor": ("cursorarrow", Color(white: 0.16), nil),
        "gemini": ("", Color(red: 0.26, green: 0.52, blue: 0.96), "G"),
        "codex": ("chevron.left.forwardslash.chevron.right", Color(white: 0.10), nil),
        "opencode": ("chevron.left.slash.chevron.right", Color(red: 0.16, green: 0.55, blue: 0.28), nil),
        "factory": ("gearshape.fill", Color(red: 0.40, green: 0.24, blue: 0.62), nil),
        "grok": ("bolt.fill", Color(white: 0.08), nil),
        "commandcode": ("command", Color(red: 0.31, green: 0.27, blue: 0.90), nil),
        "pi": ("", Color(red: 0.20, green: 0.56, blue: 0.86), "π"),
        "universal": ("square.stack.3d.up.fill", Color(white: 0.45), nil),
    ]
}
