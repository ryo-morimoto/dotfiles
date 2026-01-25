import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt.labs.folderlistmodel

PanelWindow {
    id: root

    property bool isVisible: false
    property string wallpaperDir: "file:///home/ryo-morimoto/.config/wallpaper"

    // Design tokens
    readonly property color bgColor: Qt.rgba(0.12, 0.12, 0.16, 0.85)
    readonly property color accentColor: "#7e9cd8"
    readonly property color accentGlow: Qt.rgba(0.494, 0.612, 0.847, 0.4)
    readonly property color textPrimary: "#dcd7ba"
    readonly property color textSecondary: Qt.rgba(0.86, 0.84, 0.73, 0.7)
    readonly property color cardBg: Qt.rgba(1, 1, 1, 0.05)
    readonly property color cardHover: Qt.rgba(1, 1, 1, 0.1)
    readonly property color cardFocus: Qt.rgba(0.494, 0.612, 0.847, 0.15)
    readonly property int spacing8: 8
    readonly property int spacing16: 16
    readonly property int spacing24: 24
    readonly property int radiusSmall: 8
    readonly property int radiusLarge: 16
    readonly property int focusBorderWidth: 3
    readonly property int focusBorderOffset: 2

    visible: isVisible
    color: "transparent"

    anchors {
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    implicitHeight: isVisible ? 240 : 0

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutQuart
        }
    }

    function toggle() {
        isVisible = !isVisible
        if (isVisible) {
            listView.forceActiveFocus()
        }
    }

    function show() {
        isVisible = true
        listView.forceActiveFocus()
    }

    function hide() {
        isVisible = false
    }

    function applyWallpaper(filePath) {
        wallpaperProcess.command = [
            "sh", "-c",
            "swww img '" + filePath + "' --transition-type grow --transition-step 90 --transition-duration 2 --transition-fps 60 && " +
            "wallust run '" + filePath + "' && " +
            "~/.config/wallust/scripts/reload-theme.sh"
        ]
        wallpaperProcess.running = true
        hide()
    }

    Process {
        id: wallpaperProcess
        command: []
    }

    // Main container with clip for proper corner rounding
    Item {
        id: container
        anchors.fill: parent
        anchors.topMargin: spacing8
        anchors.leftMargin: spacing24
        anchors.rightMargin: spacing24

        opacity: isVisible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        // Background panel
        Rectangle {
            id: bgPanel
            anchors.fill: parent
            radius: radiusLarge
            color: bgColor

            // Subtle top border for definition
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                radius: radiusLarge
                color: Qt.rgba(1, 1, 1, 0.1)
            }
        }

        // Drop shadow
        MultiEffect {
            source: bgPanel
            anchors.fill: bgPanel
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowBlur: 1.0
            shadowVerticalOffset: -4
            shadowHorizontalOffset: 0
            z: -1
        }

        // Content
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: spacing16
            spacing: spacing8

            // Header with title and keyboard hints
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24

                Text {
                    text: "Wallpaper"
                    color: textPrimary
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                Item { Layout.fillWidth: true }

                // Keyboard hints
                Row {
                    spacing: spacing16

                    Text {
                        text: "← → Tab Navigate"
                        color: textSecondary
                        font.pixelSize: 11
                    }
                    Text {
                        text: "Enter Select"
                        color: textSecondary
                        font.pixelSize: 11
                    }
                    Text {
                        text: "ESC Close"
                        color: textSecondary
                        font.pixelSize: 11
                    }
                }
            }

            // Wallpaper grid
            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: spacing16
                clip: true
                focus: true

                model: FolderListModel {
                    id: folderModel
                    folder: root.wallpaperDir
                    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]
                    showDirs: false
                    sortField: FolderListModel.Name
                }

                delegate: Item {
                    id: delegateItem
                    width: 180
                    height: listView.height

                    property bool isSelected: listView.currentIndex === index
                    property bool isHovered: mouseArea.containsMouse
                    property bool isFocused: isSelected && listView.activeFocus

                    Column {
                        anchors.fill: parent
                        anchors.topMargin: spacing8
                        spacing: spacing8

                        // Card container with focus glow
                        Item {
                            width: 180
                            height: 120

                            // Focus glow effect (behind the card)
                            Rectangle {
                                id: focusGlow
                                anchors.fill: parent
                                anchors.margins: -focusBorderOffset
                                radius: radiusSmall + focusBorderOffset
                                color: "transparent"
                                border.width: delegateItem.isFocused ? focusBorderWidth : 0
                                border.color: accentColor
                                opacity: delegateItem.isFocused ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }
                                Behavior on border.width {
                                    NumberAnimation { duration: 100 }
                                }

                                // Outer glow
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    radius: parent.radius + 4
                                    color: "transparent"
                                    border.width: delegateItem.isFocused ? 6 : 0
                                    border.color: accentGlow
                                    opacity: delegateItem.isFocused ? 0.5 : 0

                                    Behavior on opacity {
                                        NumberAnimation { duration: 150 }
                                    }
                                }
                            }

                            Rectangle {
                                id: card
                                anchors.fill: parent
                                radius: radiusSmall
                                color: delegateItem.isFocused ? cardFocus : (delegateItem.isHovered ? cardHover : cardBg)

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                // Thumbnail
                                Image {
                                    id: thumbnail
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: fileUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true

                                    // Rounded corners via layer
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                        maskSource: ShaderEffectSource {
                                            sourceItem: Rectangle {
                                                width: thumbnail.width
                                                height: thumbnail.height
                                                radius: radiusSmall - 2
                                            }
                                        }
                                    }
                                }

                                // Hover border (only when not focused)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: radiusSmall
                                    color: "transparent"
                                    border.width: (!delegateItem.isFocused && delegateItem.isHovered) ? 1 : 0
                                    border.color: Qt.rgba(1, 1, 1, 0.3)
                                    visible: !delegateItem.isFocused

                                    Behavior on border.width {
                                        NumberAnimation { duration: 100 }
                                    }
                                }

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        listView.currentIndex = index
                                        root.applyWallpaper(filePath)
                                    }
                                }

                                // Subtle scale on hover/focus
                                transform: Scale {
                                    origin.x: card.width / 2
                                    origin.y: card.height / 2
                                    xScale: (delegateItem.isHovered || delegateItem.isFocused) ? 1.02 : 1.0
                                    yScale: (delegateItem.isHovered || delegateItem.isFocused) ? 1.02 : 1.0

                                    Behavior on xScale {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on yScale {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }

                        // Filename
                        Text {
                            width: 180
                            text: fileBaseName
                            color: delegateItem.isFocused ? accentColor : (delegateItem.isSelected ? textPrimary : textSecondary)
                            font.pixelSize: 11
                            font.weight: delegateItem.isFocused ? Font.Medium : Font.Normal
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }
                }

                Keys.onLeftPressed: decrementCurrentIndex()
                Keys.onRightPressed: incrementCurrentIndex()
                Keys.onTabPressed: {
                    if (currentIndex < count - 1) {
                        incrementCurrentIndex()
                    }
                }
                Keys.onBacktabPressed: {
                    if (currentIndex > 0) {
                        decrementCurrentIndex()
                    }
                }
                Keys.onReturnPressed: {
                    if (currentIndex >= 0 && currentIndex < count) {
                        root.applyWallpaper(folderModel.get(currentIndex, "filePath"))
                    }
                }
                Keys.onEscapePressed: root.hide()
            }
        }
    }
}
