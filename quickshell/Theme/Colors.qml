pragma Singleton
import QtQuick

QtObject {
    readonly property color background:  '#111318'   // hardest bg, bar base
    readonly property color background1: '#1d2024'   // default bg
    readonly property color background2: '#32353a'   // raised surface

    readonly property color border_light: '#43474e'  // subtle dividers
    readonly property color border:       '#8d9199'  // dividers

    readonly property color surface:      '#111318'  // panels / popovers
    readonly property color text:         '#d4e3ff'  // primary text
    readonly property color accent:       '#a5c8fe'  // orange (unchanged)
}
