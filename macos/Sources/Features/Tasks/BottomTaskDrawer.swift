import SwiftUI
import AppKit

public struct BottomTaskDrawer: View {
    @ObservedObject var taskManager = BackgroundTaskManager.shared
    var onAttachToTerminal: ((String) -> Void)? = nil

    public init(onAttachToTerminal: ((String) -> Void)? = nil) {
        self.onAttachToTerminal = onAttachToTerminal
    }

    private var selectedTask: BackgroundTaskItem? {
        if let id = taskManager.activeDrawerTaskId {
            return taskManager.tasks.first(where: { $0.id == id })
        }
        return taskManager.tasks.first
    }

    public var body: some View {
        if !taskManager.tasks.isEmpty {
            VStack(spacing: 0) {
                // Top border / divider
                Divider()

                if taskManager.isDrawerExpanded, let task = selectedTask {
                    // Expanded Console Drawer
                    VStack(spacing: 0) {
                        // Header Bar
                        HStack(spacing: 8) {
                            Group {
                                switch task.status {
                                case .running:
                                    BrailleSpinner()
                                case .succeeded:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                case .failed:
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.red)
                                case .cancelled:
                                    Image(systemName: "stop.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 12, height: 12)

                            if taskManager.tasks.count > 1 {
                                Menu {
                                    ForEach(taskManager.tasks) { t in
                                        Button {
                                            taskManager.activeDrawerTaskId = t.id
                                        } label: {
                                            HStack {
                                                Text(t.title)
                                                Spacer()
                                                Text(t.durationString)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(task.title)
                                            .font(.system(size: 12, weight: .medium))
                                            .lineLimit(1)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                            } else {
                                Text(task.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                            }

                            Text(task.durationString)
                                .font(.system(size: 11, design: .monospaced).monospacedDigit())
                                .foregroundStyle(.secondary)

                            if task.outputWasTruncated {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .help("Older output is not shown because the in-memory log limit was reached.")
                            }

                            Spacer()

                            if !task.status.isTerminal {
                                StopTaskButton {
                                    taskManager.stop(id: task.id)
                                }
                            }

                            TaskToolbarIconButton(
                                symbol: "eye.slash",
                                help: "Hide task output"
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    taskManager.isDrawerExpanded = false
                                }
                            }

                            TaskToolbarIconButton(
                                symbol: "trash",
                                help: "Delete task",
                                isDestructive: true
                            ) {
                                taskManager.remove(id: task.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(.ultraThinMaterial)
                        .overlay(Color.black.opacity(0.12))

                        Divider()

                        // Console Log Area
                        ScrollViewReader { scrollProxy in
                            ScrollView(.vertical) {
                                Text(task.output)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color(nsColor: .textColor))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(8)
                                    .id("logBottom")
                            }
                            .background(Color.black.opacity(0.85))
                            .frame(height: 130)
                            .onChange(of: task.output) { _ in
                                scrollProxy.scrollTo("logBottom", anchor: .bottom)
                            }
                        }
                    }
                } else {
                    // Collapsed Status Pill Bar
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            if taskManager.activeCount > 0 {
                                ProgressView()
                                    .controlSize(.mini)
                                    .frame(width: 10, height: 10)
                                Text("\(taskManager.activeCount) task\(taskManager.activeCount == 1 ? "" : "s") running")
                                    .font(.system(size: 11, weight: .medium))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.green)
                                Text("Tasks completed")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let first = taskManager.tasks.first {
                            Text("• \(first.title)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text(first.durationString)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary.opacity(0.8))
                        }

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                taskManager.isDrawerExpanded = true
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text("Logs")
                                    .font(.system(size: 10, weight: .semibold))
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)

                        Button {
                            taskManager.clearFinished()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            taskManager.isDrawerExpanded = true
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

private struct BrailleSpinner: View {
    private static let frames = Array("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏").map(String.init)

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { timeline in
            let index = Int(timeline.date.timeIntervalSinceReferenceDate / 0.08) % Self.frames.count
            Text(Self.frames[index])
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

private struct StopTaskButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label("Stop", systemImage: "stop.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHovered ? Color.red : Color.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(isHovered ? Color.red.opacity(0.12) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
    }
}

private struct TaskToolbarIconButton: View {
    let symbol: String
    let help: String
    var isDestructive = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHovered && isDestructive ? Color.red : Color.secondary)
                .frame(width: 24, height: 24)
                .background(
                    isHovered ? (isDestructive ? Color.red.opacity(0.12) : Color.primary.opacity(0.08)) : .clear,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .focusable(false)
        .onHover { isHovered = $0 }
    }
}
