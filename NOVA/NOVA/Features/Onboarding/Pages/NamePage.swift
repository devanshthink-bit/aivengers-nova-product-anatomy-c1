//
//  NamePage.swift
//  NOVA
//

import SwiftUI

/// One field, and permission not to fill it in.
///
/// Brink asks for a name and a birth year before it has earned either. NOVA asks for the
/// name only, after showing what the app does, and treats an empty field as a valid
/// answer — the button says "Skip for now" rather than greying out. No dead end.
///
/// The field is set at headline scale so it belongs to the question above it rather than
/// looking like a form control that wandered in.
struct NamePage: View {
    @Binding var name: String

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Onboarding.blockSpacing) {
            Headline(text: headline)
                .onboardingEntry(0)

            field
                .onboardingEntry(1)

            Text("Only used to greet you. It stays on this device.")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .onboardingEntry(2)

            Spacer(minLength: 0)
        }
        .onAppear {
            // A beat after the page settles, so the keyboard doesn't race the entry
            // animation and shove everything up mid-fade.
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                isFocused = true
            }
        }
    }

    private var headline: Text {
        Text("What should we\n").foregroundStyle(.secondary)
        + Text("call you?").foregroundStyle(.primary)
    }

    private var field: some View {
        TextField("", text: $name, prompt: Text("Your name").foregroundStyle(.tertiary))
            .font(.system(size: 26, weight: .bold))
            .tracking(-0.6)
            .textContentType(.givenName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($isFocused)
            .onSubmit { isFocused = false }
            .padding(.horizontal, 22)
            .frame(height: 68)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Onboarding.tileRadius, style: .continuous)
                    .fill(Onboarding.surface)
            }
    }
}

#Preview {
    @Previewable @State var name = ""
    NamePage(name: $name)
        .padding(.horizontal, Onboarding.pagePadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Onboarding.ground)
}
