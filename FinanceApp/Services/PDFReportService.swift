import SwiftUI
import UIKit

@MainActor
enum PDFReportService {
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 46
    private static let blue = UIColor(red: 0.18, green: 0.49, blue: 0.96, alpha: 1)
    private static let purple = UIColor(red: 0.40, green: 0.30, blue: 0.92, alpha: 1)

    static func makeOverviewReport(entries: [IncomeEntry]) throws -> URL {
        let statistics = IncomeAnalytics.yearStatistics(from: entries)
        let currentYear = Calendar.current.component(.year, from: .now)
        let current = IncomeAnalytics.yearStatistic(for: currentYear, entries: entries)
        let url = reportURL(name: "Доходы-общий-отчёт.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            drawHeader(title: "Динамика дохода", subtitle: "Общий отчёт • \(formattedDate())", context: context.cgContext)
            drawMetricCards(
                items: [
                    ("Доход за \(currentYear)", AppFormatters.currency(current.total)),
                    ("Среднее в месяц", AppFormatters.currency(current.average)),
                    ("Изменение", AppFormatters.percent(current.change)),
                    ("Лучший месяц", current.bestMonth.map { AppFormatters.monthName($0.month) } ?? "—")
                ],
                y: 134,
                context: context.cgContext
            )
            drawChart(
                values: statistics.map { ($0.year, $0.total.doubleValue) },
                frame: CGRect(x: margin, y: 300, width: pageSize.width - margin * 2, height: 230),
                context: context.cgContext
            )
            drawText("Статистика по годам", at: CGPoint(x: margin, y: 570), font: .systemFont(ofSize: 19, weight: .bold))

            var rowY: CGFloat = 606
            drawTableHeader(columns: ["Год", "Доход", "Среднее / мес.", "Изменение"], y: rowY, context: context.cgContext)
            rowY += 30
            for item in statistics.reversed() {
                if rowY > 785 {
                    drawFooter(context: context.cgContext)
                    context.beginPage()
                    drawHeader(title: "Статистика по годам", subtitle: "Продолжение", context: context.cgContext)
                    rowY = 138
                    drawTableHeader(columns: ["Год", "Доход", "Среднее / мес.", "Изменение"], y: rowY, context: context.cgContext)
                    rowY += 30
                }
                drawTableRow(
                    columns: [String(item.year), AppFormatters.currency(item.total), AppFormatters.currency(item.average), AppFormatters.percent(item.change)],
                    y: rowY,
                    context: context.cgContext
                )
                rowY += 34
            }
            drawFooter(context: context.cgContext)
        }
        return url
    }

    static func makeYearReport(year: Int, entries: [IncomeEntry]) throws -> URL {
        let statistic = IncomeAnalytics.yearStatistic(for: year, entries: entries)
        let months = IncomeAnalytics.monthStatistics(for: year, entries: entries)
        let url = reportURL(name: "Доходы-\(year).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            drawHeader(title: "Доход за \(year)", subtitle: "Годовой отчёт • \(formattedDate())", context: context.cgContext)
            drawMetricCards(
                items: [
                    ("Общий доход", AppFormatters.currency(statistic.total)),
                    ("Среднее в месяц", AppFormatters.currency(statistic.average)),
                    ("Изменение", AppFormatters.percent(statistic.change)),
                    ("Лучший месяц", statistic.bestMonth.map { AppFormatters.monthName($0.month) } ?? "—")
                ],
                y: 134,
                context: context.cgContext
            )
            drawChart(
                values: months.compactMap { item in item.amount.map { (item.month, $0.doubleValue) } },
                frame: CGRect(x: margin, y: 300, width: pageSize.width - margin * 2, height: 230),
                context: context.cgContext,
                monthLabels: true
            )
            drawText("Доход по месяцам", at: CGPoint(x: margin, y: 570), font: .systemFont(ofSize: 19, weight: .bold))
            drawTableHeader(columns: ["Месяц", "Доход", "Изменение"], y: 606, context: context.cgContext, threeColumns: true)

            var y: CGFloat = 636
            for item in months.prefix(5) {
                let amountText = item.amount == nil ? "Нет данных" : AppFormatters.currency(item.amount!)
                drawTableRow(
                    columns: [AppFormatters.monthName(item.month), amountText, AppFormatters.percent(item.change)],
                    y: y,
                    context: context.cgContext,
                    threeColumns: true
                )
                y += 34
            }
            drawFooter(context: context.cgContext)

            context.beginPage()
            drawHeader(title: "Доход по месяцам", subtitle: String(year), context: context.cgContext)
            drawTableHeader(columns: ["Месяц", "Доход", "Изменение"], y: 138, context: context.cgContext, threeColumns: true)
            y = 168
            for item in months.dropFirst(5) {
                let amountText = item.amount == nil ? "Нет данных" : AppFormatters.currency(item.amount!)
                drawTableRow(
                    columns: [AppFormatters.monthName(item.month), amountText, AppFormatters.percent(item.change)],
                    y: y,
                    context: context.cgContext,
                    threeColumns: true
                )
                y += 46
            }
            drawFooter(context: context.cgContext)
        }
        return url
    }

    private static func reportURL(name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private static func formattedDate() -> String {
        Date.now.formatted(.dateTime.locale(AppFormatters.russianLocale).day().month(.wide).year())
    }

    private static func drawHeader(title: String, subtitle: String, context: CGContext) {
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [blue.cgColor, purple.cgColor] as CFArray,
            locations: [0, 1]
        )!
        context.saveGState()
        let background = CGRect(x: 0, y: 0, width: pageSize.width, height: 104)
        context.addRect(background)
        context.clip()
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: pageSize.width, y: 104), options: [])
        context.restoreGState()
        drawText(title, at: CGPoint(x: margin, y: 30), font: .systemFont(ofSize: 26, weight: .bold), color: .white)
        drawText(subtitle, at: CGPoint(x: margin, y: 66), font: .systemFont(ofSize: 11, weight: .medium), color: UIColor.white.withAlphaComponent(0.8))
    }

    private static func drawMetricCards(items: [(String, String)], y: CGFloat, context: CGContext) {
        let gap: CGFloat = 10
        let width = (pageSize.width - margin * 2 - gap) / 2
        let height: CGFloat = 70
        for (index, item) in items.enumerated() {
            let column = CGFloat(index % 2)
            let row = CGFloat(index / 2)
            let frame = CGRect(x: margin + column * (width + gap), y: y + row * (height + gap), width: width, height: height)
            UIColor.secondarySystemGroupedBackground.setFill()
            UIBezierPath(roundedRect: frame, cornerRadius: 14).fill()
            drawText(item.0, at: CGPoint(x: frame.minX + 14, y: frame.minY + 12), font: .systemFont(ofSize: 9, weight: .medium), color: .secondaryLabel)
            drawText(item.1, at: CGPoint(x: frame.minX + 14, y: frame.minY + 34), font: .systemFont(ofSize: 15, weight: .bold), color: .label)
        }
    }

    private static func drawChart(values: [(Int, Double)], frame: CGRect, context: CGContext, monthLabels: Bool = false) {
        UIColor.secondarySystemGroupedBackground.setFill()
        UIBezierPath(roundedRect: frame, cornerRadius: 18).fill()
        guard !values.isEmpty else {
            drawText("Недостаточно данных для графика", at: CGPoint(x: frame.minX + 20, y: frame.midY - 8), font: .systemFont(ofSize: 13), color: .secondaryLabel)
            return
        }
        let plot = frame.insetBy(dx: 28, dy: 32)
        let maximum = max(values.map(\.1).max() ?? 1, 1)
        let minimumKey = values.map(\.0).min() ?? 0
        let maximumKey = values.map(\.0).max() ?? minimumKey
        let keyRange = max(maximumKey - minimumKey, 1)
        let points = values.map { key, value in
            CGPoint(
                x: plot.minX + CGFloat(key - minimumKey) / CGFloat(keyRange) * plot.width,
                y: plot.maxY - CGFloat(value / maximum) * plot.height
            )
        }

        context.saveGState()
        context.setStrokeColor(UIColor.tertiaryLabel.withAlphaComponent(0.18).cgColor)
        context.setLineWidth(0.7)
        for index in 0...3 {
            let lineY = plot.minY + CGFloat(index) * plot.height / 3
            context.move(to: CGPoint(x: plot.minX, y: lineY))
            context.addLine(to: CGPoint(x: plot.maxX, y: lineY))
        }
        context.strokePath()

        context.setStrokeColor(blue.cgColor)
        context.setLineWidth(3)
        context.setLineCap(.round)
        if let first = points.first {
            context.move(to: first)
            for point in points.dropFirst() { context.addLine(to: point) }
            context.strokePath()
        }
        for point in points {
            context.setFillColor(blue.cgColor)
            context.fillEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
        }
        context.restoreGState()

        let labelIndexes: [Int] = values.count <= 6
            ? Array(values.indices)
            : values.indices.filter { $0 % 2 == 0 || $0 == values.count - 1 }
        for index in labelIndexes {
            let label = monthLabels ? AppFormatters.monthName(values[index].0, short: true) : String(values[index].0)
            drawText(label, at: CGPoint(x: points[index].x - 16, y: frame.maxY - 22), font: .systemFont(ofSize: 8, weight: .medium), color: .secondaryLabel)
        }
    }

    private static func drawTableHeader(columns: [String], y: CGFloat, context: CGContext, threeColumns: Bool = false) {
        let frame = CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 28)
        UIColor.systemGray5.setFill()
        UIBezierPath(roundedRect: frame, cornerRadius: 8).fill()
        drawColumns(columns, y: y + 8, font: .systemFont(ofSize: 8, weight: .semibold), color: .secondaryLabel, threeColumns: threeColumns)
    }

    private static func drawTableRow(columns: [String], y: CGFloat, context: CGContext, threeColumns: Bool = false) {
        drawColumns(columns, y: y + 7, font: .systemFont(ofSize: 9, weight: .medium), color: .label, threeColumns: threeColumns)
        context.setStrokeColor(UIColor.separator.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y + 30))
        context.addLine(to: CGPoint(x: pageSize.width - margin, y: y + 30))
        context.strokePath()
    }

    private static func drawColumns(_ columns: [String], y: CGFloat, font: UIFont, color: UIColor, threeColumns: Bool) {
        let available = pageSize.width - margin * 2
        let fractions: [CGFloat] = threeColumns ? [0, 0.35, 0.75] : [0, 0.16, 0.48, 0.8]
        for (index, text) in columns.enumerated() where index < fractions.count {
            drawText(text, at: CGPoint(x: margin + available * fractions[index] + 10, y: y), font: font, color: color)
        }
    }

    private static func drawFooter(context: CGContext) {
        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: 806))
        context.addLine(to: CGPoint(x: pageSize.width - margin, y: 806))
        context.strokePath()
        drawText("FinanceApp • Личный отчёт", at: CGPoint(x: margin, y: 816), font: .systemFont(ofSize: 8), color: .secondaryLabel)
    }

    private static func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor = .label) {
        text.draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }
}
