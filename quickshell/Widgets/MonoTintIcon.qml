import QtQuick
import "../Theme"

// An icon with its white and black (and light / dark grey) parts recoloured to `tint` (default Theme.text);
// coloured parts keep their colours. Used for tray icons in the menu bar dropdowns (shaders/icon_tint.frag).
Item {
    id: root

    property string source          // a tray item's `icon`, an icon name or a file path
    property color tint: Theme.text

    // Fixed load size (64 px): sizing it from root.width left it at 0 x 0 while the row was still being
    // laid out, and it never loaded. The shader layer renders at 4x the item and is scaled down with
    // mipmaps, which anti-aliases the edges the shader cuts (it drops the icon's drop shadow).
    Image {
        id: img
        width: 64
        height: 64
        sourceSize: Qt.size(64, 64)
        fillMode: Image.PreserveAspectFit
        mipmap: true
        smooth: true
        source: root.source
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent
        visible: img.status === Image.Ready
        property variant source: img
        property color tint: root.tint
        fragmentShader: Qt.resolvedUrl("shaders/icon_tint.frag.qsb")
        layer.enabled: true
        layer.smooth: true
        layer.mipmap: true
        layer.textureSize: Qt.size(width * 4, height * 4)
    }
}
