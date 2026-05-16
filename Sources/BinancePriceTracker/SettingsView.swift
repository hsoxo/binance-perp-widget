import SwiftUI

struct SettingsView: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var catalog: SymbolCatalog
    @State private var newSymbol: String = ""
    @State private var errorText: String?
    @State private var validating: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tracked USDT-M Perpetual Symbols")
                .font(.headline)

            symbolList

            HStack(spacing: 8) {
                TextField("Add symbol (e.g. SOLUSDT)", text: $newSymbol)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await addSymbol() } }
                    .disabled(validating)
                if validating {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 18, height: 18)
                }
                Button("Add") { Task { await addSymbol() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty || validating)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Text(footerHint)
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            opacitySection

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 540, minHeight: 460)
    }

    private var footerHint: String {
        if catalog.isLoaded {
            return "\(catalog.symbols.count) USDT-M perpetuals available. Drag rows to reorder."
        } else {
            return "Loading symbol catalog from Binance… examples: BTCUSDT, ETHUSDT, SOLUSDT."
        }
    }

    private var opacitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Floating Window Opacity")
                    .font(.headline)
                Spacer()
                Text("\(Int((prefs.floatingOpacity * 100).rounded()))%")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
            Slider(value: $prefs.floatingOpacity, in: 0.4...1.0)
            Text("Lower = more see-through. Slide all the way right for fully opaque.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var symbolList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Symbol").bold().frame(maxWidth: .infinity, alignment: .leading)
                Text("Menu Bar").bold().frame(width: 90, alignment: .center)
                Text("Floating").bold().frame(width: 90, alignment: .center)
                Text("").frame(width: 28)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            List {
                ForEach(prefs.symbols) { sym in
                    row(for: sym)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
                .onMove(perform: move)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .frame(minHeight: 220)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }

    private func row(for sym: TrackedSymbol) -> some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .font(.caption)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(sym.symbol)
                    .font(.system(.body, design: .monospaced))
                Text(PriceFormat.baseAsset(sym.symbol))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: binding(for: sym, keyPath: \.showInMenuBar))
                .labelsHidden()
                .frame(width: 90, alignment: .center)

            Toggle("", isOn: binding(for: sym, keyPath: \.showInFloating))
                .labelsHidden()
                .frame(width: 90, alignment: .center)

            Button {
                prefs.symbols.removeAll { $0.id == sym.id }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .frame(width: 28)
            .help("Remove \(sym.symbol)")
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        prefs.symbols.move(fromOffsets: source, toOffset: destination)
    }

    private var trimmed: String {
        newSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func addSymbol() async {
        let cleaned = trimmed
        guard !cleaned.isEmpty else { return }
        guard cleaned.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            errorText = "Symbols can only contain letters and digits."
            return
        }
        if prefs.symbols.contains(where: { $0.symbol == cleaned }) {
            errorText = "\(cleaned) is already tracked."
            return
        }
        errorText = nil
        validating = true
        let ok = await catalog.validate(cleaned)
        validating = false
        guard ok else {
            errorText = "\(cleaned) is not a valid Binance USDT-M perpetual symbol."
            return
        }
        prefs.symbols.append(
            TrackedSymbol(symbol: cleaned, showInMenuBar: true, showInFloating: true)
        )
        newSymbol = ""
    }

    private func binding(for sym: TrackedSymbol,
                         keyPath: WritableKeyPath<TrackedSymbol, Bool>) -> Binding<Bool> {
        Binding(
            get: {
                prefs.symbols.first(where: { $0.id == sym.id })?[keyPath: keyPath] ?? false
            },
            set: { newValue in
                guard let idx = prefs.symbols.firstIndex(where: { $0.id == sym.id }) else { return }
                prefs.symbols[idx][keyPath: keyPath] = newValue
            }
        )
    }
}
