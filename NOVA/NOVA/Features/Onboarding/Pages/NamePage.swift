//
//  NamePage.swift
//  NOVA
//

import SwiftUI

/// One field, and permission not to fill it in.
///
/// Brink asks for a name and a birth year before it has earned either. NOVA asks for the
/// name only, after showing what the app does, and treats an empty field as a valid
/// answer rather than a dead end — the CTA changes to "Skip for now" instead of greying
/// out.
struct NamePage: View {
    @Binding var name: String

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Onboarding.blockSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Hello")
                    .onboardingEntry(0)

                headline
                    .font(Onboarding.headline())
                    .tracking(-0.8)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingEntry(1)
            }

            field
                .onboardingEntry(2)

            Text("Only used to greet you. It stays on this device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .onboardingEntry(3)

            Spacer(minLength: 0)
        }
        .onAppear {
            // A beat after the page settles, so the keyboard doesn't race the entry
            // animation and shove everything up mid-fade.
            Task {
                try? await Task.sleep(for: .seconds(0.45))
                isFocused = true
            }
        }
    }

    private var headline: Text {
        Text("What should we\n").foregroundStyle(.secondary)
        + Text("call you?").foregroundStyle(.primary)
    }

    private var field: some View {
        TextField("Your name", text: $name)
            .font(.system(.title3, weight: .medium))
            .textContentType(.givenName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($isFocused)
            .onSubmit { isFocused = false }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingCore()
            .onboardingShell()
    }
}

#Preview {
    @Previewable @State var name = ""
    NamePage(name: $name)
        .padding(.horizontal, Nova.screenPadding)
}
