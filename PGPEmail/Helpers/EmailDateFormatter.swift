//
//  EmailDateFormatter.swift
//  PGPEmail
//
//  Source: https://amirrezaeghtedari.com/relative-date-and-time-with-swift/
//

import Foundation

class EmailDateFormatter: Formatter {
    override func string(for obj: Any?) -> String? {
        guard let date = obj as? Date else { return nil }
        
        // Round down the current date
        let roundUnits: Set<Calendar.Component> = [.year, .month, .day]
        let roundedDateComponents = Calendar.current.dateComponents(roundUnits, from: date)
        
        guard let roundedCurrentDate = Calendar.current.date(from: roundedDateComponents) else {
            return "Unable to calculate"
        }
        
        let units: Set<Calendar.Component> = [.minute, .day, .year, .weekOfYear]
        let components = Calendar.current.dateComponents(units, from: roundedCurrentDate, to: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        
        let year = components.year ?? 0
        let weeks = components.weekOfYear ?? 0
        let days = components.day ?? 0
        
        if year >= 1 || Calendar.current.component(.year, from: Date()) != Calendar.current.component(.year, from: roundedCurrentDate) {
            dateFormatter.dateFormat = "MM/dd/yy"
            return dateFormatter.string(from: date)
        }
        
        if weeks >= 1 {
            dateFormatter.dateFormat = "LLL dd"
            return dateFormatter.string(from: date)
        }
        
        if days > 1 {
            dateFormatter.dateFormat = "EE"
            return dateFormatter.string(from: date)
        }
        
        if days == 1 {
            return "Yesterday"
        }
        
        let units2: Set<Calendar.Component> = [.minute]
        let components2 = Calendar.current.dateComponents(units2, from: date, to: Date())
        let minutes = components2.minute ?? 0
        
        if minutes > 1 {
            dateFormatter.dateFormat = "h:mm a"
            return dateFormatter.string(from: date)
        }
        
        if minutes == 1 {
            return "Last minute"
        }
        
        return "Just now"
    }
}
