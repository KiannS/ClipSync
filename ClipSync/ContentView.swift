import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var clipboardMonitor: ClipboardMonitor
    @Binding var settingsOpened: Bool
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ClipboardItem.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)
        ],
        animation: .default
    )
    private var items: FetchedResults<ClipboardItem>
    
    @State private var searchText = ""
    
    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return Array(items)
        }
        return items.filter { item in
            item.content?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 8) {
                HStack {
                    Text("ClipSync")
                        .font(.headline)
                    
                    Spacer()
                    
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search clipboard...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
            
            Divider()
            
            // Clipboard history
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No clipboard history yet")
                        .foregroundColor(.gray)
                    Text("Copy something to get started!")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Pinned items section
                        ForEach(filteredItems.filter { $0.isPinned }) { item in
                            ClipboardItemRow(item: item)
                            Divider()
                        }
                        
                        // Separator if there are pinned items
                        if filteredItems.contains(where: { $0.isPinned }) && filteredItems.contains(where: { !$0.isPinned }) {
                            HStack {
                                Text("Recent")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                Spacer()
                            }
                            .background(Color.gray.opacity(0.05))
                        }
                        
                        // Unpinned items section
                        ForEach(filteredItems.filter { !$0.isPinned }) { item in
                            ClipboardItemRow(item: item)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            print("👀 ContentView appeared!")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshClipboardHistory"))) { _ in
            print("🔄 Received refresh notification - reloading data")
            viewContext.refreshAllObjects()
        }
    }
}

struct ClipboardItemRow: View {
    @ObservedObject var item: ClipboardItem
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Show image thumbnail or category icon
            if item.contentType == "image", let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .clipped()
            } else if let categoryString = item.category,
                      let category = ClipboardCategory(rawValue: categoryString) {
                Image(systemName: category.icon)
                    .foregroundColor(colorForCategory(category.color))
                    .frame(width: 20)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.content ?? "")
                    .lineLimit(3)
                    .font(.system(size: 13))
                
                HStack(spacing: 8) {
                    Text(timeAgo(from: item.timestamp ?? Date()))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Show category label
                    if let categoryString = item.category,
                       let category = ClipboardCategory(rawValue: categoryString) {
                        Text(category.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colorForCategory(category.color).opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 8) {
                    // Pin button
                    Button(action: togglePin) {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                            .foregroundColor(item.isPinned ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "Unpin" : "Pin")
                    
                    // Delete button
                    Button(action: deleteItem) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }
        }
        .padding(12)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            if item.contentType == "image" {
                copyImageToClipboard()
            } else {
                copyToClipboard()
            }
        }
        .contextMenu {
            contextMenuItems()
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenuItems() -> some View {
        // Image-specific actions
        if item.contentType == "image" {
            Button(action: openImage) {
                Label("Open in Preview", systemImage: "eye")
            }
            
            Button(action: copyImageToClipboard) {
                Label("Copy Image", systemImage: "doc.on.doc")
            }
            
            Button(action: saveImageToFile) {
                Label("Save Image As...", systemImage: "square.and.arrow.down")
            }
        } else {
            // Text actions
            Button(action: copyToClipboard) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            // Category-specific actions
            if let categoryString = item.category,
               let category = ClipboardCategory(rawValue: categoryString) {
                
                switch category {
                case .url:
                    Button(action: openURL) {
                        Label("Open in Browser", systemImage: "safari")
                    }
                    
                case .email:
                    Button(action: openEmail) {
                        Label("Open in Mail", systemImage: "envelope")
                    }
                    
                case .phone:
                    Button(action: openPhone) {
                        Label("Call with FaceTime", systemImage: "phone.fill")
                    }
                    
                case .address:
                    Button(action: openInMaps) {
                        Label("Open in Maps", systemImage: "map.fill")
                    }
                    
                default:
                    EmptyView()
                }
                
                Divider()
            }
        }
        
        // Pin/Unpin
        Button(action: togglePin) {
            Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
        }
        
        // Delete
        Button(action: deleteItem) {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Helper Functions
    
    private func colorForCategory(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "pink": return .pink
        default: return .gray
        }
    }
    
    private func togglePin() {
        item.isPinned.toggle()
        try? viewContext.save()
    }
    
    private func deleteItem() {
        viewContext.delete(item)
        try? viewContext.save()
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content ?? "", forType: .string)
        print("📋 Copied to clipboard")
    }
    
    private func copyImageToClipboard() {
        guard let imageData = item.imageData, let image = NSImage(data: imageData) else {
            print("❌ No image data to copy")
            return
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        print("🖼️ Copied image to clipboard")
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    // MARK: - Image Actions
    
    private func openImage() {
        guard let imageData = item.imageData else {
            print("❌ No image data")
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("ClipSync-\(item.id?.uuidString ?? "image").png")
        
        do {
            try imageData.write(to: tempFile)
            NSWorkspace.shared.open(tempFile)
            print("🖼️ Opened image in Preview")
        } catch {
            print("❌ Failed to open image: \(error)")
        }
    }
    
    private func saveImageToFile() {
        guard let imageData = item.imageData else {
            print("❌ No image data")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "ClipSync-Image-\(Date().timeIntervalSince1970).png"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try imageData.write(to: url)
                    print("✅ Saved image to: \(url)")
                } catch {
                    print("❌ Failed to save image: \(error)")
                }
            }
        }
    }
    
    // MARK: - Context Menu Actions
    
    private func openURL() {
        guard let content = item.content else { return }
        var urlString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !urlString.lowercased().hasPrefix("http://") &&
           !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            print("🌐 Opening URL: \(url)")
        }
    }
    
    private func openEmail() {
        guard let content = item.content else { return }
        let email = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let url = URL(string: "mailto:\(email)") {
            NSWorkspace.shared.open(url)
            print("📧 Opening email: \(email)")
        }
    }
    
    private func openPhone() {
        guard let content = item.content else { return }
        let phone = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsOnly = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if let url = URL(string: "tel:\(digitsOnly)") {
            NSWorkspace.shared.open(url)
            print("📞 Opening phone: \(phone)")
        }
    }
    
    private func openInMaps() {
        guard let content = item.content else { return }
        let address = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        
        if let url = URL(string: "http://maps.apple.com/?address=\(encodedAddress)") {
            NSWorkspace.shared.open(url)
            print("🗺️ Opening Maps: \(address)")
        }
    }
}
