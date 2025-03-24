import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var foodHistoryStore: FoodHistoryStore
    @State private var selectedDate = Date()
    @State private var weekEntries: [FoodHistoryEntry] = []
    @State private var selectedWeekIndex = 0
    
    var weekDates: [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        
        // Get dates for the last 8 weeks
        for i in 0..<8 {
            if let date = calendar.date(byAdding: .weekOfYear, value: -i, to: Date()) {
                dates.append(date)
            }
        }
        return dates
    }
    
    var selectedWeekStartAndEnd: (start: Date, end: Date) {
        let calendar = Calendar.current
        let date = weekDates[selectedWeekIndex]
        let weekOfYearComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        
        guard let weekStart = calendar.date(from: weekOfYearComponents) else {
            return (date, date)
        }
        
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return (weekStart, weekStart)
        }
        
        return (weekStart, weekEnd)
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Week Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("select_week", comment: "") + ":")
                        .font(.headline)
                    
                    Picker(NSLocalizedString("select_week", comment: ""), selection: $selectedWeekIndex) {
                        ForEach(weekDates.indices, id: \.self) { index in
                            let weekRange = getWeekRangeString(from: weekDates[index])
                            Text(weekRange).tag(index)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 100)
                    .clipped()
                    
                    // Selected week range display
                    Text("\(dateFormatter.string(from: selectedWeekStartAndEnd.start)) - \(dateFormatter.string(from: selectedWeekStartAndEnd.end))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Statistics visualization
                let stats = foodHistoryStore.weeklyStatistics(date: weekDates[selectedWeekIndex])
                PieChartView(consumed: stats.consumed, wasted: stats.wasted)
                
                // Detailed entry list
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("detailed_records", comment: ""))
                        .font(.headline)
                        .padding(.horizontal)
                    
                    List {
                        if weekEntries.isEmpty {
                            Text(NSLocalizedString("no_records_this_week", comment: ""))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ForEach(weekEntries) { entry in
                                HStack {
                                    // Icon and category
                                    Image(systemName: entry.category.iconName)
                                        .foregroundColor(.secondary)
                                    
                                    // Food name and date
                                    VStack(alignment: .leading) {
                                        Text(entry.foodName)
                                            .font(.headline)
                                        
                                        Text(entry.category.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(dateFormatter.string(from: entry.disposalDate))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Disposal type indicator
                                    Text(entry.disposalType.rawValue)
                                        .font(.subheadline)
                                        .padding(6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(entry.disposalType == .consumed ? Color.blue.opacity(0.2) : Color.red.opacity(0.2))
                                        )
                                        .foregroundColor(entry.disposalType == .consumed ? .blue : .red)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .id(selectedWeekIndex) // Force list recreation when selected index changes
                }
            }
            .navigationTitle(NSLocalizedString("food_history", comment: ""))
        }
        .onAppear {
            foodHistoryStore.load()
            updateWeekEntries()
        }
        .onChange(of: selectedWeekIndex) { _ in
            updateWeekEntries()
        }
    }
    
    // Update the entries for the selected week
    private func updateWeekEntries() {
        if weekDates.indices.contains(selectedWeekIndex) {
            weekEntries = foodHistoryStore.entriesForWeek(date: weekDates[selectedWeekIndex])
        } else {
            weekEntries = []
        }
    }
    
    // Helper to format date range string for week picker
    private func getWeekRangeString(from date: Date) -> String {
        let calendar = Calendar.current
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        
        guard let weekStart = calendar.date(from: weekComponents) else {
            return NSLocalizedString("invalid_date", comment: "")
        }
        
        let weekFormatter = DateFormatter()
        weekFormatter.dateFormat = "MM/dd"
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return NSLocalizedString("invalid_date", comment: "")
        }
        
        let year = yearFormatter.string(from: weekStart)
        let weekNumber = calendar.component(.weekOfYear, from: date)
        
        return String(format: NSLocalizedString("week_format", comment: ""), year, weekNumber)
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environmentObject(FoodHistoryStore())
    }
} 