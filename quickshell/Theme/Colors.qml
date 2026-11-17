pragma Singleton
import QtQuick

QtObject {
    readonly property color background:  '#11140f'   // hardest bg, bar base
    readonly property color background1: '#1d211b'   // default bg
    readonly property color background2: '#32362f'   // raised surface

    readonly property color border_light: '#43483f'  // subtle dividers
    readonly property color border:       '#8d9387'  // dividers

    readonly property color surface:      '#11140f'  // panels / popovers
    readonly property color text:         '#d7e8cd'  // primary text
    readonly property color accent:       '#a5d395'  // accent
}
