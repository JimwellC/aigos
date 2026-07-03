//
//  PlaceField.swift
//  aigos
//
//  Gazetteer-backed autocomplete field. The user must pick a real place from the
//  dropdown — free text is never treated as valid. `selectedKey` is non-nil only
//  once a suggestion is chosen; editing the text clears it.
//

import SwiftUI

struct PlaceField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var selectedKey: String?
    let personalPlaces: [PersonalPlace]
    var showError: Bool = false
    var startOpen: Bool = false   // DEBUG: force the dropdown open for screenshots

    @FocusState private var focused: Bool
    @State private var suggestions: [PlaceSuggestion] = []
    @State private var justSelected = false
    @State private var forceOpen = false

    private var isValid: Bool { selectedKey != nil }
    private var showDropdown: Bool { (focused || forceOpen) && selectedKey == nil && !suggestions.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            field
            if showDropdown {
                dropdown
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showDropdown)
        .onChange(of: startOpen) { _, open in
            if open, !text.isEmpty {
                suggestions = PlaceSearch.suggestions(for: text, personalPlaces: personalPlaces)
                forceOpen = true
            }
        }
    }

    // MARK: - Field

    private var field: some View {
        HStack(spacing: Space.sm) {
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.aigosTextTertiary))
                .rounded(17, weight: .medium)
                .foregroundStyle(.white)
                .tint(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .focused($focused)
                .onChange(of: text) { _, newValue in handleTextChange(newValue) }

            if isValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.aigosAmber)
            } else if !text.isEmpty {
                Button { clear() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.aigosTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 14)
        .background(isValid ? Color.aigosAmber.opacity(0.18) : Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: (showError && !isValid) ? 2 : 1)
        )
    }

    private var borderColor: Color {
        if showError && !isValid { return Color(hex: "#FF6B6B") }
        return isValid ? Color.aigosAmber.opacity(0.7) : Color.white.opacity(0.3)
    }

    // MARK: - Dropdown

    private var dropdown: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { s in
                Button { select(s) } label: { row(s) }
                    .buttonStyle(.plain)
                if s.id != suggestions.last?.id {
                    Divider().overlay(Color.white.opacity(0.12))
                }
            }
        }
        .glassCard()
    }

    private func row(_ s: PlaceSuggestion) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: s.isPersonal ? "star.fill" : "mappin.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.aigosAmber)
            VStack(alignment: .leading, spacing: 1) {
                Text(s.title)
                    .rounded(16, weight: .semibold)
                    .foregroundStyle(.white)
                Text(s.subtitle)
                    .rounded(12)
                    .foregroundStyle(Color.aigosTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - Behaviour

    private func handleTextChange(_ newValue: String) {
        // Ignore the programmatic text set from selecting a suggestion.
        if justSelected { justSelected = false; return }
        // An exact full match (typed in full, or set from a Saved/Talk draft)
        // auto-validates; anything else shows the dropdown and stays unselected.
        if let resolved = PlaceSearch.exactKey(newValue, personalPlaces: personalPlaces) {
            selectedKey = resolved
            suggestions = []
        } else {
            if selectedKey != nil { selectedKey = nil }
            suggestions = PlaceSearch.suggestions(for: newValue, personalPlaces: personalPlaces)
        }
    }

    private func select(_ s: PlaceSuggestion) {
        Haptics.tap(.light)
        justSelected = true
        text = s.title
        selectedKey = s.resolveKey
        suggestions = []
        focused = false
    }

    private func clear() {
        text = ""
        selectedKey = nil
        suggestions = []
    }
}
