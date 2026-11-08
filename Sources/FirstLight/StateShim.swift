import SwiftUI

/// `@ViewState` is SwiftUI's `@State` property wrapper, spelled so the
/// compiler can only resolve it to the wrapper type.
///
/// From the macOS 27 SDK on, SwiftUICore also declares `@State` as an
/// attached macro (`SwiftUIMacros.StateMacro`) and attribute lookup prefers
/// it. That macro's compiler plugin ships only inside Xcode.app — the
/// Command Line Tools have just ObservationMacros and SwiftMacros — so a
/// plain `@State` fails to build with CLT ("plugin for module
/// 'SwiftUIMacros' not found"). A typealias names only the type, never the
/// macro, so this builds identically with CLT or Xcode on any SDK.
typealias ViewState = SwiftUI.State
