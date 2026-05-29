import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("historyLimit") private var historyLimit: Int = 100
    @AppStorage("autoDeleteDays") private var autoDeleteDays: Int = 30
    @State private var showingClearConfirmation = false
    @State private var showingExportPicker = false
    @State private var showingImportPicker = false
    @State private var exportFormat: ExportFormat = .json
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        case txt = "Plain Text"
        
        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            case .txt: return "txt"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("ClipSync Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Divider()
                
                // Keyboard Shortcut Section
                GroupBox(label: Label("Keyboard Shortcut", systemImage: "keyboard")) {
                    VStack(alignment: .leading, spacing: 12) {
                        KeyboardShortcuts.Recorder("Toggle ClipSync:", name: .toggleClipSync)
                        
                        Text("Use this shortcut from anywhere to open/close ClipSync")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }
                
                // History Management Section
                GroupBox(label: Label("History Management", systemImage: "clock.arrow.circlepath")) {
                    VStack(alignment: .leading, spacing: 16) {
                        // History Limit
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Maximum items to keep:")
                                Spacer()
                                Text("\(historyLimit)")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(historyLimit) },
                                set: { newValue in
                                    historyLimit = Int(newValue)
                                    triggerCleanup()
                                }
                            ), in: 10...500, step: 10)
                            
                            Text("Older items will be automatically removed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Auto-delete by age
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Auto-delete items older than:")
                                Spacer()
                                Picker("", selection: $autoDeleteDays) {
                                    Text("7 days").tag(7)
                                    Text("14 days").tag(14)
                                    Text("30 days").tag(30)
                                    Text("60 days").tag(60)
                                    Text("90 days").tag(90)
                                    Text("Never").tag(0)
                                }
                                .frame(width: 120)
                                .onChange(of: autoDeleteDays) { oldValue, newValue in
                                    print("📅 Auto-delete changed to \(newValue) days")
                                    triggerCleanup()
                                }
                            }
                            
                            Text("Items older than this will be automatically removed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Clear All Button
                        Button(action: {
                            showingClearConfirmation = true
                        }) {
                            Label("Clear All History", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                    .padding(8)
                }
                
                // Import/Export Section
                GroupBox(label: Label("Import / Export", systemImage: "arrow.up.arrow.down.circle")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Export Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Export Format:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("Export Format", selection: $exportFormat) {
                                ForEach(ExportFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue).tag(format)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Button(action: {
                                showingExportPicker = true
                            }) {
                                Label("Export Clipboard History", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Divider()
                        
                        // Import Section
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                showingImportPicker = true
                            }) {
                                Label("Import Clipboard History", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.bordered)
                            
                            Text("Supports JSON, CSV, and TXT files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                }
                
                Spacer()
                
                // App Info
                VStack(spacing: 4) {
                    Text("ClipSync v1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("A universal clipboard manager")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .padding()
        }
        .frame(width: 550, height: 650)
        .alert("Clear All History?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllHistory()
            }
        } message: {
            Text("This will permanently delete all clipboard history. This action cannot be undone.")
        }
        .alert("ClipSync", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .fileExporter(
            isPresented: $showingExportPicker,
            document: ClipboardExportDocument(format: exportFormat),
            contentType: contentTypeForFormat(exportFormat),
            defaultFilename: "ClipSync-Export-\(dateString()).\(exportFormat.fileExtension)"
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json, .commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }
    
    // MARK: - Helper Functions
    
    private func triggerCleanup() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let context = PersistenceController.shared.container.viewContext
            let monitor = ClipboardMonitor(context: context)
            monitor.forceCleanup()
            print("🧹 Cleanup triggered from settings change")
        }
    }
    
    private func contentTypeForFormat(_ format: ExportFormat) -> UTType {
        switch format {
        case .json: return .json
        case .csv: return .commaSeparatedText
        case .txt: return .plainText
        }
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func clearAllHistory() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        
        do {
            let items = try context.fetch(fetchRequest)
            let count = items.count
            
            print("🗑️ Deleting \(count) items...")
            
            for item in items {
                context.delete(item)
            }
            
            try context.save()
            print("✅ Context saved")
            
            context.refreshAllObjects()
            
            NotificationCenter.default.post(name: NSNotification.Name("RefreshClipboardHistory"), object: nil)
            
            alertMessage = "Successfully cleared \(count) items from history."
            showingAlert = true
            print("✅ Cleared \(count) items - notification posted")
            
        } catch {
            alertMessage = "Failed to clear history: \(error.localizedDescription)"
            showingAlert = true
            print("❌ Failed to clear history: \(error)")
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            alertMessage = "Successfully exported clipboard history to:\n\(url.lastPathComponent)"
            showingAlert = true
            print("✅ Exported to: \(url)")
        case .failure(let error):
            alertMessage = "Export failed: \(error.localizedDescription)"
            showingAlert = true
            print("❌ Export failed: \(error)")
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importClipboardHistory(from: url)
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
            print("❌ Import failed: \(error)")
        }
    }
    
    private func importClipboardHistory(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let context = PersistenceController.shared.container.viewContext
            
            let fileExtension = url.pathExtension.lowercased()
            var importedCount = 0
            
            switch fileExtension {
            case "json":
                importedCount = try importJSON(data, context: context)
            case "csv":
                importedCount = try importCSV(data, context: context)
            case "txt":
                importedCount = try importTXT(data, context: context)
            default:
                alertMessage = "Unsupported file format: \(fileExtension)"
                showingAlert = true
                return
            }
            
            try context.save()
            alertMessage = "Successfully imported \(importedCount) items from \(url.lastPathComponent)"
            showingAlert = true
            print("✅ Imported \(importedCount) items")
            
        } catch {
            alertMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
            print("❌ Import error: \(error)")
        }
    }
    
    private func importJSON(_ data: Data, context: NSManagedObjectContext) throws -> Int {
        struct ImportItem: Codable {
            let content: String
            let timestamp: Date
            let isPinned: Bool
            let category: String?
        }
        
        let items = try JSONDecoder().decode([ImportItem].self, from: data)
        
        for item in items {
            let newItem = ClipboardItem(context: context)
            newItem.id = UUID()
            newItem.content = item.content
            newItem.timestamp = item.timestamp
            newItem.isPinned = item.isPinned
            newItem.category = item.category
        }
        
        return items.count
    }
    
    private func importCSV(_ data: Data, context: NSManagedObjectContext) throws -> Int {
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ClipSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid CSV encoding"])
        }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return 0 }
        
        var count = 0
        for line in lines.dropFirst() {
            let components = line.components(separatedBy: ",")
            guard components.count >= 2 else { continue }
            
            let newItem = ClipboardItem(context: context)
            newItem.id = UUID()
            newItem.content = components[0].trimmingCharacters(in: .whitespaces)
            newItem.timestamp = Date()
            newItem.isPinned = false
            newItem.category = components.count > 2 ? components[2] : nil
            count += 1
        }
        
        return count
    }
    
    private func importTXT(_ data: Data, context: NSManagedObjectContext) throws -> Int {
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ClipSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid text encoding"])
        }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        for line in lines {
            let newItem = ClipboardItem(context: context)
            newItem.id = UUID()
            newItem.content = line
            newItem.timestamp = Date()
            newItem.isPinned = false
            newItem.category = CategoryDetector.detectCategory(for: line).rawValue
        }
        
        return lines.count
    }
}

// MARK: - Export Document

struct ClipboardExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    
    let format: SettingsView.ExportFormat
    
    init(format: SettingsView.ExportFormat) {
        self.format = format
    }
    
    init(configuration: ReadConfiguration) throws {
        self.format = .json
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)]
        
        let items = try context.fetch(fetchRequest)
        
        let data: Data
        switch format {
        case .json:
            data = try exportAsJSON(items)
        case .csv:
            data = try exportAsCSV(items)
        case .txt:
            data = try exportAsTXT(items)
        }
        
        return FileWrapper(regularFileWithContents: data)
    }
    
    private func exportAsJSON(_ items: [ClipboardItem]) throws -> Data {
        struct ExportItem: Codable {
            let content: String
            let timestamp: Date
            let isPinned: Bool
            let category: String?
        }
        
        let exportItems = items.map { item in
            ExportItem(
                content: item.content ?? "",
                timestamp: item.timestamp ?? Date(),
                isPinned: item.isPinned,
                category: item.category
            )
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(exportItems)
    }
    
    private func exportAsCSV(_ items: [ClipboardItem]) throws -> Data {
        var csv = "Content,Timestamp,Category,Pinned\n"
        
        let formatter = ISO8601DateFormatter()
        
        for item in items {
            let content = (item.content ?? "").replacingOccurrences(of: ",", with: ";")
            let timestamp = formatter.string(from: item.timestamp ?? Date())
            let category = item.category ?? "Text"
            let pinned = item.isPinned ? "Yes" : "No"
            
            csv += "\(content),\(timestamp),\(category),\(pinned)\n"
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
    
    private func exportAsTXT(_ items: [ClipboardItem]) throws -> Data {
        let text = items.map { $0.content ?? "" }.joined(separator: "\n---\n")
        return text.data(using: .utf8) ?? Data()
    }
}
