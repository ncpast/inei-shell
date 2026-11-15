import Quickshell
import QtQuick
import Quickshell.Services.UPower
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell.Io
import "../Utils"
import "../Theme"
import "../Popups"

Row {
    visible: name !== "gpu" || Monitors.gpu_available   // no GPU reading (integrated GPU): hidden
    height: parent.height
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    property int iconSizeOffset: 0
    property string name: ""
    property string icon: ""
    property var stats: {
    if (name.includes('pu')) {
            const temp = Monitors[name + '_temp']
            return { val: temp, display: temp, col: Theme.accent }
        }
        if (name == 'battery') {
            const pct = UPower.displayDevice.percentage
            // red -> yellow -> green. Green is reached at 90%.
            const red = Qt.color("#ff0000"), yellow = Qt.color("#f5c542"), green = Qt.color("#51b34a")
            const mix = (a, b, t) => Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
            const t = Math.min(pct / 0.9, 1)
            const col = t < 0.5 ? mix(red, yellow, t / 0.5) : mix(yellow, green, (t - 0.5) / 0.5)
            const bat_ico = () => {
                const icons = [
                    ['󰁺', '󰢜'],  // 0-10%
                    ['󰁻', '󰂆'],  // 10-20%
                    ['󰁼', '󰂇'],  // 20-30%
                    ['󰁽', '󰂈'],  // 30-40%
                    ['󰁾', '󰢝'],  // 40-50%
                    ['󰁿', '󰂉'],  // 50-60%
                    ['󰂀', '󰢞'],  // 60-70%
                    ['󰂁', '󰂊'],  // 70-80%
                    ['󰂂', '󰂋'],  // 80-90%
                    ['󰁹', '󰂄'],  // 90-100%
                ]
                const i = Math.min(Math.floor(pct * 10), 9)
                return icons[i][UPower.onBattery ? 0 : 1]
            }

            return { val: pct, display: bat_ico(), col: col }
        }
        return { val: 0, display: '?', col: Theme.accent }
    }

    property real   val:     stats.val
    property string display: parent.height >= 28 ? stats.display : ""
    property color  col:      stats.col

    Item {
        height: parent.height
        width: height

        Text {
            text: display
            anchors.centerIn: parent
            font.weight: Font.Black
            color: col
            font.pixelSize: name.includes('pu') ? parent.height - 21 : parent.height - 18
        }

        Item {
            id: root
            property real progress: name.includes('pu') ? Math.pow(val / 90, 2) : val
            property real animatedProgress: 0
            property int  size:     parent.height
            property int  thickness: 3
            property color trackColor: Qt.darker(col, 2.75)//Qt.lighter(Theme.background1, Theme.bg_lighter)
            property color progressColor: col

            width: size
            height: size
            anchors.centerIn: parent
            
            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                propagateComposedEvents: false
                onEntered: {
                    PopupStates.tempEntered()
                    switch  (name) {
                        case "gpu":
                        case "cpu":
                            PopupStates.temp_displaying = "thermals"
                            break;
                        case "battery":
                            StatusUtils.getPowerProfile()
                            PopupStates.temp_displaying = "battery"
                            break;
                    }
                }
                onExited: PopupStates.tempExited()
            }

            Behavior on animatedProgress {
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.InOutQuad
                }
            }

            onProgressChanged: animatedProgress = progress

            Shape {
                id: ring
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                readonly property real cx: width / 2
                readonly property real cy: height / 2
                readonly property real r:  (width / 2) - root.thickness

                // Track
                ShapePath {
                    strokeColor: root.trackColor
                    strokeWidth: root.thickness
                    fillColor: "transparent"

                    PathAngleArc {
                        centerX: ring.cx
                        centerY: ring.cy
                        radiusX: ring.r
                        radiusY: ring.r
                        startAngle: 0
                        sweepAngle: 360
                    }
                }

                // Progress
                ShapePath {
                    strokeColor: root.animatedProgress > 0 ? root.progressColor : "transparent"
                    strokeWidth: root.thickness
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: ring.cx
                        centerY: ring.cy
                        radiusX: ring.r
                        radiusY: ring.r
                        startAngle: -90
                        sweepAngle: 360 * root.animatedProgress
                    }
                }
            }
        }

    }

    Text {
        visible: icon == "" ? false : (name == "battery" && !UPower.onBattery ? true : false)
        height: parent.height
        text: icon
        //anchors.centerIn: parent
        horizontalAlignment: Text.AlignHLeft
        verticalAlignment: Text.AlignVCenter
        font.weight: Font.Black
        color: col
        font.pixelSize: parent.height - 10 - iconSizeOffset
    }
}