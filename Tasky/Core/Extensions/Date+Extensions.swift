//
//  Date+Extensions.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import Foundation

extension Date {
    /// Sets the hour and minute components of the date
    func setting(hour: Int, minute: Int) -> Date? {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self)
    }

    /// Rounds the date to the nearest interval in minutes
    /// For example, with minutes = 15:
    /// - 9:07 rounds to 9:00
    /// - 9:12 rounds to 9:15
    func rounded(toNearest minutes: Int) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: self)
        let minute = components.minute ?? 0
        let roundedMinute = (minute / minutes) * minutes

        return calendar.date(bySettingHour: components.hour ?? 0,
                            minute: roundedMinute,
                            second: 0,
                            of: self) ?? self
    }

    /// Adds the specified number of minutes to the date
    func addingMinutes(_ minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }

    /// Returns the time components (hour and minute) as a tuple
    var timeComponents: (hour: Int, minute: Int) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0, components.minute ?? 0)
    }

    /// Checks if the date is on the same day as another date
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
