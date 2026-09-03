import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("설정")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
                Button("완료") { app.showSettings = false }
                    .buttonStyle(PressableButtonStyle(tint: .accentColor))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("백업 위치")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("모든 skill이 최종적으로 모이는 캐노니컬 저장소 위치. iCloud Drive 경로로 두면 OS 초기화나 새 맥에서도 그대로 복구됨.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(app.settingsStore.canonicalStorePath)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    Button("폴더 변경…") { pickFolder() }
                        .buttonStyle(PressableButtonStyle(tint: .accentColor, filled: false))

                    if !app.settingsStore.isDefault {
                        Button("기본값(iCloud)으로 재설정") { app.resetCanonicalStoreToDefault() }
                            .buttonStyle(PressableButtonStyle(tint: .orange, filled: false))
                    }
                }

                Label("기존 위치에 있던 skill들은 새 폴더로 자동 이동됨(같은 이름이 이미 있으면 건드리지 않음).", systemImage: "info.circle")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "선택")
        panel.directoryURL = app.settingsStore.canonicalDirURL.deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url {
            app.changeCanonicalStore(to: url.appendingPathComponent("skills"))
        }
    }
}
