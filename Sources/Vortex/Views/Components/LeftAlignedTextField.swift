import SwiftUI
import AppKit

struct LeftAlignedTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var focusOnAppear: Bool = false

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.alignment = .left
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .default
        field.delegate = context.coordinator
        if focusOnAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                field.window?.makeFirstResponder(field)
            }
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LeftAlignedTextField
        init(_ parent: LeftAlignedTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}
