import SwiftUI
import AppKit

public struct FloatingPromptView: View {
    @State private var entryText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successRecord: LogRecord? = nil
    @State private var recentLogs: [LogRecord] = []
    @State private var showRecent: Bool = false

    var onDismiss: () -> Void
    var onSaveSuccess: (LogRecord) -> Void

    public init(
        onDismiss: @escaping () -> Void,
        onSaveSuccess: @escaping (LogRecord) -> Void
    ) {
        self.onDismiss = onDismiss
        self.onSaveSuccess = onSaveSuccess
    }

    private var targetDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        // If hour < 5, reflection is for yesterday
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 5 {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            return formatter.string(from: yesterday)
        }
        return formatter.string(from: Date())
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.indigo, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.indigo.opacity(0.3), radius: 6, x: 0, y: 3)

                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Reflection")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("What did you do today? • \(targetDateString)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { showRecent.toggle() }) {
                    Label(showRecent ? "Prompt" : "History", systemImage: showRecent ? "square.and.pencil" : "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 16)

            Divider()
                .opacity(0.4)

            // Content Area
            if showRecent {
                historyList
            } else {
                editorContent
            }

            Divider()
                .opacity(0.4)

            // Footer
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .frame(minWidth: 70)
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

                Spacer()

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(1)
                }

                Button(action: submitEntry) {
                    HStack(spacing: 6) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isSubmitting ? "Saving..." : "Save Log")
                            .fontWeight(.semibold)
                        Text("⌘↵")
                            .font(.system(size: 11, weight: .regular))
                            .opacity(0.7)
                    }
                    .frame(minWidth: 100)
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
        }
        .frame(width: 540, height: 380)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .cornerRadius(14)
        .onAppear {
            loadRecentHistory()
        }
    }

    private var editorContent: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $entryText)
                .font(.system(size: 14, weight: .regular, design: .default))
                .lineSpacing(4)
                .padding(14)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor).opacity(0.4))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )

            if entryText.isEmpty {
                Text("Write your accomplishments, key moments, learnings, or thoughts...\n(Press ⌘ + Return to save)")
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondary.opacity(0.6))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 22)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var historyList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if recentLogs.isEmpty {
                    Text("No past logs recorded yet.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 40)
                } else {
                    ForEach(recentLogs, id: \.id) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(record.date)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.indigo)
                                Spacer()
                                Text(record.timestamp)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Text(record.entry)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
    }

    private func loadRecentHistory() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let logs = try? ProcessRunner.shared.listLogs(limit: 5) {
                DispatchQueue.main.async {
                    self.recentLogs = logs
                }
            }
        }
    }

    private func submitEntry() {
        let trimmed = entryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let record = try ProcessRunner.shared.saveLog(text: trimmed)
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    self.onSaveSuccess(record)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

/// VisualEffect view for native translucent glassmorphism background
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
