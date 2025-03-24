import SwiftUI

struct PieChartView: View {
    var consumed: Int
    var wasted: Int
    
    private var total: Int {
        consumed + wasted
    }
    
    private var consumedPercentage: Double {
        total > 0 ? Double(consumed) / Double(total) : 0
    }
    
    private var wastedPercentage: Double {
        total > 0 ? Double(wasted) / Double(total) : 0
    }
    
    var body: some View {
        VStack {
            ZStack {
                // If there's no data, show a gray circle
                if total == 0 {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 40)
                } else {
                    // Consumed slice (blue)
                    Circle()
                        .trim(from: 0, to: CGFloat(consumedPercentage))
                        .stroke(Color.blue, lineWidth: 40)
                        .rotationEffect(.degrees(-90))
                    
                    // Wasted slice (red)
                    Circle()
                        .trim(from: CGFloat(consumedPercentage), to: 1)
                        .stroke(Color.red, lineWidth: 40)
                        .rotationEffect(.degrees(-90))
                }
                
                // Total count in center
                VStack {
                    Text("\(total)")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(NSLocalizedString("unit_count", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            .padding()
            
            // Legend
            HStack(spacing: 20) {
                // Consumed legend item
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 16, height: 16)
                    
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("consumed", comment: ""))
                            .font(.subheadline)
                        Text("\(consumed) \(NSLocalizedString("unit_count", comment: ""))")
                            .font(.headline)
                    }
                }
                
                // Wasted legend item
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 16, height: 16)
                    
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("wasted", comment: ""))
                            .font(.subheadline)
                        Text("\(wasted) \(NSLocalizedString("unit_count", comment: ""))")
                            .font(.headline)
                    }
                }
            }
            .padding(.top)
            
            // Percentages
            if total > 0 {
                HStack(spacing: 20) {
                    Text(String(format: NSLocalizedString("consumption_rate", comment: ""), Int(consumedPercentage * 100)))
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(String(format: NSLocalizedString("waste_rate", comment: ""), Int(wastedPercentage * 100)))
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            }
        }
        .padding()
    }
}

struct PieChartView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PieChartView(consumed: 7, wasted: 3)
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("With Data")
            
            PieChartView(consumed: 0, wasted: 0)
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("No Data")
        }
    }
} 