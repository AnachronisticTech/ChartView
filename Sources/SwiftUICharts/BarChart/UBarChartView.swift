//
//  ChartView.swift
//  ChartView
//
//  Created by András Samu on 2019. 06. 12..
//  Copyright © 2019. András Samu. All rights reserved.
//
// Modified by Daniel Marriner on Fri 09 Oct 2020
//

import SwiftUI

public struct UBarChartView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    private var data: ChartData
    private var title: String
    private var legend: String? = nil
    private var style = Styles.barChartStyleOrangeLight {
        willSet {
            darkModeStyle = newValue.darkModeStyle ?? Styles.barChartStyleOrangeDark
        }
    }
    private var darkModeStyle = Styles.barChartStyleOrangeDark
    private var formSize: CGSize = ChartForm.medium
    private var dropShadow: Bool = true
    private var cornerImage = Image(systemName: "waveform.path.ecg")
    private var valueSpecifier: String = "%.1f"

    public init(
        data: ChartData,
        title: String,
        legend: String? = nil,
        style: ChartStyle = Styles.barChartStyleOrangeLight,
        form: CGSize = ChartForm.medium,
        dropShadow: Bool = true,
        cornerImage: Image = Image(systemName: "waveform.path.ecg"),
        valueSpecifier: String = "%.1f"
    ) {
        self.data = data
        self.title = title
        self.legend = legend
        self.style = style
        self.formSize = form
        self.dropShadow = dropShadow
        self.cornerImage = cornerImage
        self.valueSpecifier = valueSpecifier
    }

    @State private var touchLocation: CGFloat = -1.0
    @State private var showValue: Bool = false
    @State private var showLabelValue: Bool = false
    @State private var currentValue: Double = 0 {
        didSet{
            if(oldValue != self.currentValue && self.showValue) {
                HapticFeedback.playSelection()
            }
        }
    }
    var isFullWidth: Bool {
        return self.formSize == ChartForm.large
    }

    public var body: some View {
        ZStack{
            Rectangle()
                .fill(self.colorScheme == .dark ? self.darkModeStyle.backgroundColor : self.style.backgroundColor)
                .cornerRadius(20)
                .shadow(color: self.style.dropShadowColor, radius: self.dropShadow ? 8 : 0)
            VStack(alignment: .leading) {
                HStack {
                    if !showValue {
                        Text(self.title)
                            .font(.headline)
                            .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.textColor : self.style.textColor)
                    } else {
                        Text("\(self.currentValue, specifier: self.valueSpecifier)")
                            .font(.headline)
                            .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.textColor : self.style.textColor)
                    }
                    if self.formSize == ChartForm.large && !showValue, let legend = self.legend {
                        Text(legend)
                            .font(.callout)
                            .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.accentColor : self.style.accentColor)
                            .transition(.opacity)
                            .animation(.easeOut)
                    }
                    Spacer()
                    self.cornerImage
                        .imageScale(.large)
                        .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.legendTextColor : self.style.legendTextColor)
                }
                .padding()
                UBarChartRow(
                    data: data.points,
                    accentColor: self.colorScheme == .dark ? self.darkModeStyle.accentColor : self.style.accentColor,
                    gradient: self.colorScheme == .dark ? self.darkModeStyle.gradientColor : self.style.gradientColor,
                    touchLocation: self.$touchLocation
                )
                if self.legend != nil && self.formSize == ChartForm.medium && !self.showLabelValue {
                    Text(self.legend!)
                        .font(.headline)
                        .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.legendTextColor : self.style.legendTextColor)
                        .padding()
                } else if self.data.valuesGiven && self.getCurrentValue() != nil {
                    LabelView(
                        arrowOffset: self.getArrowOffset(touchLocation: self.touchLocation),
                        title: .constant(self.getCurrentValue()!.0)
                    )
                    .offset(x: self.getLabelViewOffset(touchLocation: self.touchLocation), y: -6)
                    .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.legendTextColor : self.style.legendTextColor)
                }
            }
        }
        .frame(
            minWidth: self.formSize.width,
            maxWidth: self.isFullWidth ? .infinity : self.formSize.width,
            minHeight: self.formSize.height,
            maxHeight: self.formSize.height
        )
        .gesture(DragGesture()
            .onChanged { value in
                self.touchLocation = value.location.x / self.formSize.width
                self.showValue = true
                self.currentValue = self.getCurrentValue()?.1 ?? 0
                if self.data.valuesGiven && self.formSize == ChartForm.medium {
                    self.showLabelValue = true
                }
            }
            .onEnded { _ in
                self.showValue = false
                self.showLabelValue = false
                self.touchLocation = -1
            }
        )
        .gesture(TapGesture())
    }

    func getArrowOffset(touchLocation: CGFloat) -> Binding<CGFloat> {
        let realLoc = (self.touchLocation * self.formSize.width) - 50
        if realLoc < 10 {
            return .constant(realLoc - 10)
        } else if realLoc > self.formSize.width - 110 {
            return .constant((self.formSize.width - 110 - realLoc) * -1)
        } else {
            return .constant(0)
        }
    }

    func getLabelViewOffset(touchLocation: CGFloat) -> CGFloat {
        return min(self.formSize.width - 110, max(10, (self.touchLocation * self.formSize.width) - 50))
    }

    func getCurrentValue() -> (String, Double)? {
        guard self.data.points.count > 0 else { return nil }
        let index = max(0, min(self.data.points.count - 1, Int(floor((self.touchLocation * self.formSize.width) / (self.formSize.width / CGFloat(self.data.points.count))))))
        let data = self.data.points[index]
        return (data.string, data.point)
    }
}

public struct UBarChartRow: View {
    var data: [ChartDataPoint]
    var accentColor: Color
    var gradient: GradientColor?

    var maxValue: Double {
        guard let max = data.map({ $0.point }).max() else {
            return 1
        }
        return max != 0 ? max : 1
    }
    @Binding var touchLocation: CGFloat

    public var body: some View {
        GeometryReader { geometry in
            HStack(
                alignment: .bottom,
                spacing: (geometry.frame(in: .local).width - 22) / CGFloat(self.data.count * 3)
            ) {
                ForEach(Array(zip(self.data.indices, self.data)), id: \.1) { (index, item) in
                    UBarChartCell(
                        value: self.normalized(item),
                        index: index,
                        width: Float(geometry.frame(in: .local).width - 22),
                        numberOfDataPoints: self.data.count,
                        accentColor: self.accentColor,
                        gradient: self.gradient,
                        touchLocation: self.$touchLocation
                    )
                    .scaleEffect(
                        self.touchLocation > CGFloat(index) / CGFloat(self.data.count) && self.touchLocation < CGFloat(index + 1) / CGFloat(self.data.count) ? CGSize(width: 1.4, height: 1.1) : CGSize(width: 1, height: 1),
                        anchor: .bottom
                    )
                    .animation(.spring())
                }
            }
            .padding([.top, .leading, .trailing], 10)
        }
    }

    func normalizedValue(index: Int) -> Double {
        return Double(self.data[index].point) / Double(self.maxValue)
    }

    func normalizedValue(of point: Double) -> Double {
        return Double(point) / Double(self.maxValue)
    }

    func normalized(_ item: ChartDataPoint) -> ChartDataPoint {
        return ChartDataPoint(item.id, item.string, normalizedValue(of: item.point))
    }
}

public struct UBarChartCell: View {
    var value: ChartDataPoint
    var index: Int = 0
    var width: Float
    var numberOfDataPoints: Int
    var cellWidth: Double {
        return Double(width) / (Double(numberOfDataPoints) * 1.5)
    }
    var accentColor: Color
    var gradient: GradientColor?

    @State var scaleValue: Double = 0
    @Binding var touchLocation: CGFloat

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(
                    gradient: gradient?.getGradient() ?? GradientColor(
                        start: accentColor,
                        end: accentColor
                    ).getGradient(),
                    startPoint: .bottom,
                    endPoint: .top
            ))
        }
        .frame(width: CGFloat(self.cellWidth))
        .scaleEffect(CGSize(width: 1, height: self.value.point), anchor: .bottom)
        .animation(Animation.spring().delay(self.touchLocation < 0 ? Double(self.index) * 0.04 : 0))
    }
}

#if DEBUG
struct TempView: View {
    @State private var selection = 0
    var dataSets = [
        ChartData(values: [("Item 1", 3), ("Item 2", 2), ("Item 3", 1)]),
        ChartData(values: [("Item 4", 2), ("Item 5", 1), ("Item 6", 2), ("Item b", 5)]),
        ChartData(values: [("Item 7", 1), ("Item 8", 2), ("Item 9", 3)])
    ]

    var body: some View {
        VStack {
            UBarChartView(
                data: dataSets[selection],
                title: "Model 3 sales",
                legend: "Quarterly",
                form: ChartForm.extraLarge,
                valueSpecifier: "%.0f"
            )
            Text("Using set \(selection)")
            Picker(selection: $selection, label: Text("Which dataset?")) {
                Text("First").tag(0)
                Text("Second").tag(1)
                Text("Third").tag(2)
            }.pickerStyle(SegmentedPickerStyle())
        }
    }
}


struct UChartView_Previews: PreviewProvider {
    static var previews: some View {
        TempView()
    }
}
#endif
