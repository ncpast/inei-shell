pragma Singleton
import QtQuick

QtObject {
    readonly property color background:  '#{{colors.background.default.hex_stripped}}'   // hardest bg, bar base
    readonly property color background1: '#{{colors.surface_container.default.hex_stripped}}'   // default bg
    readonly property color background2: '#{{colors.surface_container_highest.default.hex_stripped}}'   // raised surface

    readonly property color border_light: '#{{colors.outline_variant.default.hex_stripped}}'  // subtle dividers
    readonly property color border:       '#{{colors.outline.default.hex_stripped}}'  // dividers

    readonly property color surface:      '#{{colors.surface.default.hex_stripped}}'  // panels / popovers
    readonly property color text:         '#{{colors.on_primary_container.default.hex_stripped}}'  // primary text
    readonly property color accent:       '#{{colors.primary.default.hex_stripped}}'  // orange (unchanged)
}
