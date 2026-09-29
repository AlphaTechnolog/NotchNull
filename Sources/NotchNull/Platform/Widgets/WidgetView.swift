import SwiftUI

/// Colors and type for widget files: the notch's own tokens by name, or any "#RRGGBB".
@MainActor
enum WidgetStyle {
    static func color(_ value: JSONValue?) -> Color? {
        guard let name = value?.string?.lowercased(), !name.isEmpty else { return nil }
        if name.hasPrefix("#"), let hex = UInt32(name.dropFirst(), radix: 16), name.count == 7 { return Color(hex: hex) }
        switch name {
        case "accent": return Preferences.shared.accent
        case "primary", "white": return Theme.Palette.textPrimary
        case "secondary": return Theme.Palette.textSecondary
        case "tertiary", "muted": return Theme.Palette.textTertiary
        case "green", "success": return Theme.Accent.success
        case "red", "danger": return Theme.Accent.danger
        case "orange", "warning": return Theme.Accent.warning
        case "yellow": return Theme.Accent.lowPower
        case "blue": return Theme.Accent.download
        case "sky": return Theme.Accent.airdrop
        case "purple": return Theme.Accent.tray
        case "pink": return Theme.Accent.mirror
        case "teal": return Theme.Accent.clipboard
        case "claude": return Theme.Accent.claude
        case "codex": return Theme.Accent.codex
        case "gray", "grey": return Theme.Accent.system
        default: return nil
        }
    }

    static func font(_ name: String?) -> Font {
        switch name {
        case "hero": Theme.Typeface.hero
        case "heroSmall", "large": Theme.Typeface.heroSmall
        case "title": Theme.Typeface.title
        case "bodyStrong", "strong": Theme.Typeface.bodyStrong
        case "caption": Theme.Typeface.caption
        case "label": Theme.Typeface.label
        case "mono", "code": Theme.Typeface.mono
        case "metric", "number": Theme.Typeface.metric
        default: Theme.Typeface.body
        }
    }

    static func alignment(_ name: String?) -> HorizontalAlignment {
        switch name {
        case "center": .center
        case "trailing", "right": .trailing
        default: .leading
        }
    }

    static func verticalAlignment(_ name: String?) -> VerticalAlignment {
        switch name {
        case "top": .top
        case "bottom": .bottom
        case "baseline", "firstTextBaseline": .firstTextBaseline
        default: .center
        }
    }

    /// The widget's own animation for data changes: "spring" (default), "smooth", "bouncy" or "none".
    static func animation(_ name: String?) -> Animation? {
        switch name {
        case "none": nil
        case "smooth": .smooth(duration: 0.35)
        case "bouncy": .spring(response: 0.4, dampingFraction: 0.62)
        case "snappy": .snappy(duration: 0.25)
        default: Motion.value
        }
    }
}

/// Draws one node of a widget's `view` tree. Unknown types draw a small labeled placeholder, so a
/// typo is visible in the notch and in `notchnull render` instead of silently vanishing.
struct WidgetNodeView: View {
    let node: JSONValue
    let scope: JSONValue
    let widgetID: String
    var tint: Color = Theme.Accent.clipboard

    var body: some View {
        content
            .opacity(Template.resolve(node["opacity"], in: scope)?.double ?? 1)
    }

    private var type: String { node["type"]?.string ?? "text" }

    private func prop(_ key: String) -> JSONValue? { Template.resolve(node[key], in: scope) }
    private func text(_ key: String) -> String { Template.text(node[key], in: scope) }
    private func color(_ key: String, fallback: Color) -> Color { WidgetStyle.color(prop(key)) ?? fallback }
    private func number(_ key: String) -> Double? { prop(key)?.double }

    @ViewBuilder
    private var content: some View {
        if let when = node["when"], !(Template.resolve(when, in: scope)?.isTruthy ?? false) {
            EmptyView()
        } else {
            switch type {
            case "column", "vstack": column
            case "row", "hstack": row
            case "stack", "zstack": stack
            case "text": textView
            case "value": value
            case "symbol", "icon": symbol
            case "gauge", "ring": gauge
            case "bar", "progress": bar
            case "sparkline", "chart": sparkline
            case "list", "foreach": list
            case "button": button
            case "badge", "chip": badge
            case "image": image
            case "spacer": Spacer(minLength: number("min").map { CGFloat($0) } ?? 0)
            case "divider": Rectangle().fill(Theme.Palette.hairline).frame(height: 1)
            default:
                Text("Unknown type \"\(type)\"")
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Accent.danger)
            }
        }
    }

    private var children: [JSONValue] { node["children"]?.array ?? [] }

    private var column: some View {
        VStack(alignment: WidgetStyle.alignment(node["align"]?.string), spacing: CGFloat(number("spacing") ?? 4)) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                WidgetNodeView(node: child, scope: scope, widgetID: widgetID, tint: tint)
            }
        }
        .frame(maxWidth: node["fill"]?.bool == false ? nil : .infinity, alignment: Alignment(horizontal: WidgetStyle.alignment(node["align"]?.string), vertical: .center))
    }

    private var row: some View {
        HStack(alignment: WidgetStyle.verticalAlignment(node["align"]?.string), spacing: CGFloat(number("spacing") ?? 6)) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                WidgetNodeView(node: child, scope: scope, widgetID: widgetID, tint: tint)
            }
        }
    }

    private var stack: some View {
        ZStack {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                WidgetNodeView(node: child, scope: scope, widgetID: widgetID, tint: tint)
            }
        }
    }

    private var textView: some View {
        Text(text("text"))
            .font(WidgetStyle.font(node["style"]?.string))
            .foregroundStyle(color("color", fallback: Theme.Palette.textPrimary))
            .lineLimit(Int(number("lines") ?? 1))
            .truncationMode(.tail)
            .multilineTextAlignment(node["align"]?.string == "center" ? .center : .leading)
            .contentTransition(.numericText())
    }

    /// A big number with its unit and a label, the notch's hero style.
    private var value: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(text("value"))
                    .font(node["style"]?.string == "small" ? Theme.Typeface.heroSmall : Theme.Typeface.hero)
                    .foregroundStyle(color("color", fallback: Theme.Palette.textPrimary))
                    .contentTransition(.numericText(value: number("value") ?? 0))
                if node["unit"] != nil {
                    Text(text("unit"))
                        .font(Theme.Typeface.title)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            if node["label"] != nil {
                Text(text("label"))
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private var symbol: some View {
        Image(systemName: text("name").isEmpty ? "questionmark.square.dashed" : text("name"))
            .font(.system(size: CGFloat(number("size") ?? 14), weight: .semibold))
            .foregroundStyle(color("color", fallback: tint))
            .contentTransition(.symbolEffect(.replace))
    }

    private var gauge: some View {
        let fraction = min(max(number("value") ?? 0, 0), 1)
        let size = CGFloat(number("size") ?? 44)
        let ringTint = color("color", fallback: tint)
        return ZStack {
            Circle().stroke(Theme.Palette.track, lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringTint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(node["label"] != nil ? text("label") : "\(Int((fraction * 100).rounded()))")
                .font(.system(size: size * 0.28, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.Palette.textPrimary)
                .contentTransition(.numericText(value: fraction))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(Int((fraction * 100).rounded())) percent")
    }

    private var bar: some View {
        let fraction = min(max(number("value") ?? 0, 0), 1)
        let barTint = color("color", fallback: tint)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.track)
                Capsule().fill(barTint).frame(width: max(fraction > 0 ? 3 : 0, proxy.size.width * fraction))
            }
        }
        .frame(height: CGFloat(number("height") ?? 4))
        .accessibilityLabel("\(Int((fraction * 100).rounded())) percent")
    }

    private var sparkline: some View {
        let values = (prop("values")?.array ?? []).compactMap(\.double)
        let lineTint = color("color", fallback: tint)
        return Sparkline(values: values, tint: lineTint, maxValue: number("max"))
            .frame(height: CGFloat(number("height") ?? 28))
            .accessibilityLabel("Chart of \(values.count) values")
    }

    /// Repeats `item` for each element of `items`; inside, `{{item.x}}` and `{{index}}` work.
    private var list: some View {
        let items = Array((prop("items")?.array ?? []).prefix(Int(number("limit") ?? 20)))
        let template = node["item"] ?? .object(["type": .string("text"), "text": .string("{{item}}")])
        return VStack(alignment: .leading, spacing: CGFloat(number("spacing") ?? 4)) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                WidgetNodeView(node: template, scope: scope.merging(["item": item, "index": .number(Double(index))]), widgetID: widgetID, tint: tint)
            }
            if items.isEmpty, node["empty"] != nil {
                Text(text("empty"))
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    private var button: some View {
        let buttonTint = color("color", fallback: Theme.Palette.textPrimary)
        return Button {
            WidgetStore.shared.perform(node["action"], widget: widgetID, scope: scope)
        } label: {
            HStack(spacing: 5) {
                if node["symbol"] != nil {
                    Image(systemName: text("symbol")).font(.system(size: 10, weight: .semibold))
                }
                if node["title"] != nil {
                    Text(text("title")).font(Theme.Typeface.caption).lineLimit(1)
                }
            }
            .foregroundStyle(buttonTint)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(Theme.Palette.surfaceHover))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle(hoverFill: Theme.Palette.surfaceActive, cornerRadius: 11, padding: EdgeInsets()))
        .help(text("help"))
        .accessibilityLabel(node["title"] != nil ? text("title") : text("symbol"))
    }

    private var badge: some View {
        let badgeTint = color("color", fallback: tint)
        return Text(text("text"))
            .font(Theme.Typeface.caption)
            .foregroundStyle(badgeTint)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(Capsule().fill(badgeTint.opacity(0.16)))
    }

    /// Local images only (a path, `~` allowed); widgets never fetch from the network.
    @ViewBuilder
    private var image: some View {
        let path = (text("path") as NSString).expandingTildeInPath
        let size = CGFloat(number("size") ?? 36)
        if let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: CGFloat(number("radius") ?? 7), style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.Palette.surfaceHover)
                .frame(width: size, height: size)
        }
    }
}

extension JSONValue {
    /// Adds keys to an object scope (item/index inside lists).
    func merging(_ values: [String: JSONValue]) -> JSONValue {
        var base = object ?? [:]
        base.merge(values) { $1 }
        return .object(base)
    }
}

/// A widget in the Widgets tab: header with its symbol and title, then its view, or its error.
struct WidgetCard: View {
    let widget: LoadedWidget

    var body: some View {
        let definition = widget.definition
        let tint = WidgetStyle.color(definition?.tint) ?? Theme.Accent.clipboard
        let scope = JSONValue.object(["data": widget.data])
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: definition?.symbol ?? (widget.error == nil ? "square.dashed" : "exclamationmark.triangle.fill"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(widget.error == nil ? tint : Theme.Accent.danger)
                Text(definition?.title ?? widget.file.lastPathComponent)
                    .font(Theme.Typeface.label)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if widget.state == .loading {
                    ProgressView().controlSize(.mini)
                }
            }
            if let error = widget.error {
                Text(error)
                    .font(Theme.Typeface.mono)
                    .foregroundStyle(Theme.Accent.danger.opacity(0.9))
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                Text(widget.file.lastPathComponent)
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            } else if let definition {
                WidgetNodeView(node: definition.view, scope: scope, widgetID: widget.id, tint: tint)
                    .animation(WidgetStyle.animation(definition.view["animation"]?.string), value: widget.data)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.surface - 4, style: .continuous).fill(Theme.Palette.surface))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.surface - 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.surface - 4, style: .continuous)
                .strokeBorder(widget.error == nil ? Color.clear : Theme.Accent.danger.opacity(0.35))
        )
    }

    private var width: CGFloat {
        switch widget.definition?.size ?? .medium {
        case .small: 150
        case .medium: 220
        case .wide: 320
        }
    }
}
