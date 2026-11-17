pragma Singleton
import QtQuick

QtObject {
    readonly property color background:  '#131313'   // hardest bg, bar base
    readonly property color background1: '#1f1f1f'   // default bg
    readonly property color background2: '#353535'   // raised surface

    readonly property color border_light: '#474747'  // subtle dividers
    readonly property color border:       '#919191'  // dividers

    readonly property color surface:      '#131313'  // panels / popovers
    readonly property color text:         '#e2e2e2'  // primary text
    readonly property color accent:       '#ffffff'  // accent
}
