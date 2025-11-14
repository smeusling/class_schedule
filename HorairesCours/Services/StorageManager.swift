// Services/StorageManager.swift

import Foundation
import SwiftData

@MainActor
class StorageManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func saveSchedules(_ schedules: [CourseSchedule]) throws {
        try deleteAllSchedules()
        
        for schedule in schedules {
            modelContext.insert(schedule)
        }
        
        try modelContext.save()
    }
    
    func loadSchedules() throws -> [CourseSchedule] {
        let descriptor = FetchDescriptor<CourseSchedule>(
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func deleteAllSchedules() throws {
        let descriptor = FetchDescriptor<CourseSchedule>()
        let schedules = try modelContext.fetch(descriptor)
        
        for schedule in schedules {
            modelContext.delete(schedule)
        }
        
        try modelContext.save()
    }
    
    func hasData() -> Bool {
        do {
            let descriptor = FetchDescriptor<CourseSchedule>()
            let count = try modelContext.fetchCount(descriptor)
            return count > 0
        } catch {
            return false
        }
    }
    
    func getLastUpdateDate() -> Date? {
        UserDefaults.standard.object(forKey: "lastUpdateDate") as? Date
    }
    
    func setLastUpdateDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "lastUpdateDate")
    }
}
