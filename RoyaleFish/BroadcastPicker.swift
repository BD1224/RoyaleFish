//
//  BroadcastPicker.swift
//  RoyaleFish
//
//  Created by Benjamin Duboshinsky on 2/21/26.
//

import SwiftUI
import ReplayKit

struct BroadcastPicker: UIViewRepresentable {
    let extensionBundleID: String

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let v = RPSystemBroadcastPickerView(frame: .zero)
        v.preferredExtension = extensionBundleID
        v.showsMicrophoneButton = false
        return v
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
