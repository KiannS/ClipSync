import AppKit
import Combine
import CoreData

class ClipboardMonitor: ObservableObject {
    @Published var items: [ClipboardItem] = []
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        print("🎬 ClipboardMonitor initialized")
        self.startMonitoring()
    }
    
    func startMonitoring() {
        print("🎯 Starting clipboard monitoring...")
        lastChangeCount = pasteboard.changeCount
        print("📊 Initial changeCount: \(lastChangeCount)")
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        print("✅ Timer started - monitoring active")
    }
    
    func stopMonitoring() {
        print("⏹️ Stopping monitoring")
        timer?.invalidate()
    }
    
    private func checkClipboard() {
        let currentCount = pasteboard.changeCount
        
        guard currentCount != lastChangeCount else {
            return
        }
        
        lastChangeCount = currentCount
        print("✨ Change detected! New changeCount: \(currentCount)")
        
        // Check for image first
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            print("🖼️ Got image from clipboard")
            saveImageItem(image: image)
        }
        // Then check for text
        else if let content = pasteboard.string(forType: .string), !content.isEmpty {
            print("📝 Got content: '\(content.prefix(50))'")
            saveItem(content: content)
        } else {
            print("❌ No content found in clipboard")
        }
    }
    
    private func saveItem(content: String) {
        print("💾 Attempting to save text item...")
        
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)]
        fetchRequest.fetchLimit = 1
        
        if let lastItem = try? context.fetch(fetchRequest).first,
           lastItem.content == content && lastItem.imageData == nil {
            print("⏭️ Skipping duplicate text")
            return
        }
        
        let newItem = ClipboardItem(context: context)
        newItem.id = UUID()
        newItem.content = content
        newItem.timestamp = Date()
        newItem.isPinned = false
        newItem.category = CategoryDetector.detectCategory(for: content).rawValue
        newItem.contentType = "text"
        newItem.imageData = nil
        
        print("📦 Created new text ClipboardItem")
        
        do {
            try context.save()
            print("✅ Successfully saved to Core Data!")
            
            if Int.random(in: 1...10) == 1 {
                cleanupOldItems()
            }
        } catch {
            print("❌ Failed to save: \(error.localizedDescription)")
        }
    }
    
    private func saveImageItem(image: NSImage) {
        print("💾 Attempting to save image item...")
        
        // Convert image to PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("❌ Failed to convert image to PNG")
            return
        }
        
        // Check for duplicate by comparing image size (rough check)
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)]
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "contentType == %@", "image")
        
        if let lastItem = try? context.fetch(fetchRequest).first,
           let lastImageData = lastItem.imageData,
           lastImageData.count == pngData.count {
            print("⏭️ Skipping duplicate image (same size)")
            return
        }
        
        let newItem = ClipboardItem(context: context)
        newItem.id = UUID()
        newItem.content = "Image (\(image.size.width)x\(image.size.height))"
        newItem.timestamp = Date()
        newItem.isPinned = false
        newItem.category = ClipboardCategory.image.rawValue
        newItem.contentType = "image"
        newItem.imageData = pngData
        
        print("📦 Created new image ClipboardItem: \(image.size)")
        
        do {
            try context.save()
            print("✅ Successfully saved image to Core Data!")
            
            if Int.random(in: 1...10) == 1 {
                cleanupOldItems()
            }
        } catch {
            print("❌ Failed to save image: \(error.localizedDescription)")
        }
    }
    
    func forceCleanup() {
        print("🧹 Force cleanup triggered from settings")
        cleanupOldItems()
    }
    
    func cleanupOldItems() {
        let historyLimit = UserDefaults.standard.integer(forKey: "historyLimit")
        let autoDeleteDays = UserDefaults.standard.integer(forKey: "autoDeleteDays")
        
        let limit = historyLimit > 0 ? historyLimit : 100
        
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardItem.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)
        ]
        
        do {
            let allItems = try context.fetch(fetchRequest)
            let unpinnedItems = allItems.filter { !$0.isPinned }
            
            if unpinnedItems.count > limit {
                let itemsToDelete = Array(unpinnedItems.dropFirst(limit))
                for item in itemsToDelete {
                    context.delete(item)
                }
                print("🗑️ Deleted \(itemsToDelete.count) items (exceeded limit)")
            }
            
            if autoDeleteDays > 0 {
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: Date()) ?? Date()
                
                let oldItems = allItems.filter { item in
                    !item.isPinned && (item.timestamp ?? Date()) < cutoffDate
                }
                
                for item in oldItems {
                    context.delete(item)
                }
                
                if !oldItems.isEmpty {
                    print("🗑️ Deleted \(oldItems.count) items older than \(autoDeleteDays) days")
                }
            }
            
            try context.save()
        } catch {
            print("❌ Cleanup failed: \(error)")
        }
    }
}
