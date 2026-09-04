import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Motion & press feedback (Apple HIG: respond on press, critically damped by default)

private extension Animation {
    static var snappy: Animation { .spring(response: 0.32, dampingFraction: 1.0) }
}

struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tint: Color = .accentColor
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(filled ? tint.opacity(configuration.isPressed ? 0.75 : 1.0) : tint.opacity(configuration.isPressed ? 0.28 : 0.16))
            )
            .foregroundStyle(filled ? .white : tint)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1.0)
            .animation(reduceMotion ? .easeOut(duration: 0.1) : .snappy, value: configuration.isPressed)
    }
}

private struct IconToolbarButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.0))
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1.0)
            .animation(reduceMotion ? .easeOut(duration: 0.1) : .snappy, value: configuration.isPressed)
    }
}

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @State private var filter: String = ""
    @State private var selected: CatalogEntry.ID?

    var filtered: [CatalogEntry] {
        var list = app.catalog
        if let agentID = app.selectedAgentID {
            list = list.filter { $0.agentCopies[agentID] != nil }
        }
        guard !filter.isEmpty else { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                Toolbar(visibleCount: filtered.count)
                Divider().opacity(0.5)
                if let progress = app.busyProgress {
                    BusyProgressBar(progress: progress)
                    Divider().opacity(0.5)
                }
                if app.isScanning && app.catalog.isEmpty {
                    ScanningView()
                } else {
                    List(filtered, selection: $selected) { entry in
                        EntryRow(entry: entry)
                    }
                    .listStyle(.inset)
                    .animation(.snappy, value: filtered.map(\.id))
                }
            }
        }
        .searchable(text: $filter, prompt: "skill 검색")
        .sheet(isPresented: $app.showSettings) {
            SettingsView()
                .environmentObject(app)
        }
        .alert("에러", isPresented: Binding(get: { app.lastError != nil }, set: { if !$0 { app.lastError = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(app.lastError ?? "") }
        .overlay(alignment: .bottom) {
            if let msg = app.lastMessage {
                ToastView(text: msg)
                    .padding(.bottom, 14)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation(.snappy) { app.lastMessage = nil }
                        }
                    }
            }
        }
        .animation(.snappy, value: app.lastMessage)
    }
}

private struct ScanningView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("skill 스캔 중…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BusyProgressBar: View {
    let progress: BusyProgress
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(progress.label)
                    .font(.system(size: 10.5, weight: .semibold))
                Text("· \(progress.currentItem) 처리 중…")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(progress.completed)/\(progress.total)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: Double(progress.completed), total: Double(max(progress.total, 1)))
                .progressViewStyle(.linear)
                .animation(.easeInOut(duration: 0.2), value: progress.completed)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

private struct ToastView: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}

// MARK: - Toolbar

private struct Toolbar: View {
    @EnvironmentObject var app: AppState
    let visibleCount: Int

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 0) {
                    Text("SkillArchive")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .kerning(-0.2)
                    Text("\(visibleCount)개 skill 표시 중")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                if app.isScanning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 2)
                }
            }

            Spacer()

            toolbarIcon("tray.and.arrow.down", help: "agent에만 있고 캐노니컬엔 없는 skill 전부 백업") {
                app.backupAllAgentSkills()
            }
            toolbarIcon("arrow.up.doc", help: "프로젝트 전용 skill 전부 글로벌 승격") {
                app.promoteAllProjectSkills()
            }
            toolbarIcon("square.and.arrow.down.on.square", help: "캐노니컬 skill 전부 → 모든 agent에 설치") {
                app.installAllToAllAgents()
            }
            Divider().frame(height: 16)
            toolbarIcon("arrow.clockwise", help: "새로고침") {
                app.rescan()
            }
            toolbarIcon("gearshape", help: "설정") {
                app.showSettings = true
            }
        }
        .disabled(app.isBusy)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func toolbarIcon(_ system: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(IconToolbarButtonStyle())
        .help(help)
    }
}

// MARK: - Sidebar

private struct SidebarView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        List {
            Section("AGENT · \(app.enabledAgentIDs.count)/\(Registry.agents.count) 설치 대상") {
                agentRow(agent: nil, count: nil)
                ForEach(Registry.agents) { agent in
                    HStack(spacing: 6) {
                        Toggle("", isOn: Binding(
                            get: { app.enabledAgentIDs.contains(agent.id) },
                            set: { app.setAgentEnabled(agent.id, $0) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .help("전체 백업 / 전체 설치 대상에 포함")

                        agentRow(agent: agent, count: count(agent))
                            .opacity(app.enabledAgentIDs.contains(agent.id) ? 1.0 : 0.45)
                    }
                }
                HStack(spacing: 10) {
                    Button("전체 선택") { withAnimation(.snappy) { app.selectAllAgents() } }
                    Button("감지된 것만") { withAnimation(.snappy) { app.selectOnlyDetectedAgents() } }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
            }
            Section("프로젝트 SKILL 폴더") {
                ForEach(app.projectStore.projects) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.projectName).font(.system(size: 12.5, weight: .medium))
                            Text(p.path).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Button(role: .destructive) { withAnimation(.snappy) { app.removeProject(p) } } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
                Button {
                    pickFolder()
                } label: {
                    Label("프로젝트 skills 폴더 추가…", systemImage: "plus.circle")
                        .font(.system(size: 12.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            Section("캐노니컬 저장소") {
                Text(app.settingsStore.canonicalStorePath)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Button {
                    app.showSettings = true
                } label: {
                    Label("변경…", systemImage: "gearshape")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 260)
    }

    @ViewBuilder
    private func agentRow(agent: AgentLocation?, count: Int?) -> some View {
        let id = agent?.id
        let name = agent?.displayName ?? "전체 보기"
        let isSelected = app.selectedAgentID == id
        Button {
            withAnimation(.snappy) {
                app.selectedAgentID = (app.selectedAgentID == id) ? nil : id
            }
        } label: {
            HStack(spacing: 8) {
                if agent != nil {
                    AgentIcon(agent: agent, size: 17)
                } else {
                    RoundedRectangle(cornerRadius: 4.5)
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 17, height: 17)
                        .overlay(Image(systemName: "square.grid.2x2").font(.system(size: 8.5, weight: .semibold)).foregroundStyle(.secondary))
                }
                Text(name)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if id == nil && isSelected {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        )
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
    }

    func count(_ agent: AgentLocation) -> Int {
        app.catalog.filter { $0.agentCopies[agent.id] != nil }.count
    }

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "선택")
        if panel.runModal() == .OK, let url = panel.url {
            app.addProjectFolder(url)
        }
    }
}

// MARK: - Status pill

private struct StatusPill: View {
    let text: LocalizedStringKey
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.13)))
    }
}

// MARK: - Row

private struct EntryRow: View {
    let entry: CatalogEntry
    @EnvironmentObject var app: AppState
    @State private var expanded = false

    var status: (LocalizedStringKey, Color) {
        if entry.canonical == nil && !entry.projectCopies.isEmpty { return ("승격 필요", .orange) }
        if entry.canonical == nil { return ("백업 안됨", .red) }
        if entry.missingAgents.isEmpty { return ("전체 설치됨", .green) }
        return ("일부 미설치", .blue)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                if !entry.projectCopies.isEmpty {
                    ForEach(Array(entry.projectCopies.keys), id: \.id) { proj in
                        HStack {
                            Label("프로젝트: \(proj.projectName)", systemImage: "folder")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if entry.canonical != nil {
                                Button("심볼릭 링크로 교체") { app.linkProject(entry, project: proj) }
                                    .buttonStyle(PressableButtonStyle(tint: .purple, filled: false))
                            }
                        }
                    }
                    Divider()
                }
                ForEach(Registry.agents) { agent in
                    let isEnabled = app.enabledAgentIDs.contains(agent.id)
                    HStack(spacing: 6) {
                        AgentIcon(agent: agent, size: 14)
                        Text(agent.displayName).font(.system(size: 11.5))
                        if !isEnabled {
                            Text("제외됨").font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if entry.agentCopies[agent.id] != nil {
                            Label("설치됨", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.green)
                        } else if entry.canonical != nil {
                            Button("설치") { app.install(entry, agentID: agent.id) }
                                .buttonStyle(PressableButtonStyle(tint: .accentColor))
                        } else {
                            Text("캐노니컬 없음").font(.system(size: 10.5)).foregroundStyle(.tertiary)
                        }
                    }
                    .opacity(isEnabled ? 1.0 : 0.5)
                }
            }
            .padding(.top, 6)
            .padding(.leading, 4)
            .disabled(app.isBusy)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 13, weight: .semibold))
                    if let d = entry.description {
                        Text(d)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                StatusPill(text: status.0, color: status.1)

                if entry.isPromotable {
                    Button("글로벌 승격") { app.backup(entry) }
                        .buttonStyle(PressableButtonStyle(tint: .orange))
                        .disabled(app.isBusy)
                } else if entry.isBackupable {
                    Button("백업") { app.backup(entry) }
                        .buttonStyle(PressableButtonStyle(tint: .red))
                        .disabled(app.isBusy)
                } else if entry.canonical != nil && !entry.missingAgents.isEmpty {
                    Button("전체 설치") { app.installToAllMissing(entry) }
                        .buttonStyle(PressableButtonStyle(tint: .blue))
                        .disabled(app.isBusy)
                }
            }
            .padding(.vertical, 3)
        }
    }
}
