import QtQuick

// ---------------------------------------------------------------------------
// AskAiView.qml
//
// Menu › opencode
//
// Three tabs, all backed by the OpenCode service:
//
//   Ask       type a question, `opencode run` answers in place. If a session
//             is selected the question continues that session.
//   Sessions  recent sessions from opencode's database with token counts.
//             Click one to continue it, or start a fresh one.
//   Usage     token totals: today and all time (input, output, reasoning,
//             cache, cost) as simple bars.
//
// Keyboard: Enter sends, Esc goes back, Ctrl+1/2/3 switch tabs.
// ---------------------------------------------------------------------------
Item {
    id: view

    NotchIcons {
        id: icons
    }

    property var host: null
    property var oc: null            // OpenCode service
    property bool active: false

    readonly property real islandWidth: 500
    readonly property real islandHeight: 454
    readonly property bool wantsKeyboard: true

    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property color accentColor: host ? host.colorAccent : "#7aa2f7"
    readonly property color accentText: host ? host.colorAccentText : "#000000"
    readonly property color urgentColor: host ? host.colorUrgent : "#ff5555"
    readonly property real speed: host ? host.motionScale : 1
    readonly property string fontFamily: host ? host.fontFamily : "monospace"
    readonly property color brand: host ? host.colorAccent : "#7aa2f7"

    width: islandWidth
    height: islandHeight

    property int tab: 0               // 0 ask, 1 sessions, 2 usage
    readonly property var tabNames: ["Ask", "Sessions", "Usage"]

    onActiveChanged: {
        if (active) {
            if (oc) oc.refresh()
            Qt.callLater(function() { input.forceActiveFocus() })
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (host) host.close()
            event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
            view.tab = event.key - Qt.Key_1
            event.accepted = true
        }
    }

    // ---- header --------------------------------------------------------------------
    Breadcrumbs {
        id: crumbs
        host: view.host
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        crumbs: ["Menu", "opencode"]
        onCrumbClicked: function(i) { if (view.host) view.host.open("menu") }
        onCloseRequested: if (view.host) view.host.close()

        // open the full TUI from the header
        Rectangle {
            height: 24
            width: tuiText.implicitWidth + 18
            radius: 12
            color: tuiArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)

            Text {
                id: tuiText
                anchors.centerIn: parent
                text: "open TUI"
                color: view.textColor
                font.pixelSize: 11
                font.family: view.fontFamily
            }

            MouseArea {
                id: tuiArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (view.oc) view.oc.openTui()
                    if (view.host) view.host.close()
                }
            }
        }
    }

    // ---- tab bar -------------------------------------------------------------------------
    Row {
        id: tabs
        anchors.top: crumbs.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        spacing: 6

        Repeater {
            model: view.tabNames

            delegate: Rectangle {
                id: tabChip
                required property int index
                required property string modelData

                readonly property bool selected: view.tab === index

                height: 26
                width: tabLabel.implicitWidth + 22
                radius: 13
                color: selected ? view.brand : (tabArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))

                Behavior on color {
                    ColorAnimation { duration: 140 * view.speed }
                }

                Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: tabChip.modelData
                    color: tabChip.selected ? view.accentText : view.textColor
                    font.pixelSize: 12
                    font.weight: tabChip.selected ? Font.DemiBold : Font.Normal
                    font.family: view.fontFamily
                }

                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.tab = tabChip.index
                }
            }
        }
    }

    // current session label on the right of the tab bar
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.verticalCenter: tabs.verticalCenter
        width: 200
        layoutDirection: Qt.RightToLeft
        spacing: 6

        Rectangle {
            visible: !!(view.oc && view.oc.selected)
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 3.5
            color: view.brand
        }

        Text {
            width: parent.width - 13
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: view.oc && view.oc.selected ? view.oc.selected.title : "new session"
            color: view.oc && view.oc.selected ? view.brand : view.mutedColor
            font.pixelSize: 11
            font.family: view.fontFamily
        }
    }

    // ---- body area: pages stack, only the current one is visible ---------------------------
    Item {
        id: body
        anchors.top: tabs.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: popupNav.top
        anchors.bottomMargin: 8

        // ------------------------------------------------------------- ASK
        Item {
            id: askPage
            anchors.fill: parent
            visible: view.tab === 0
            opacity: visible ? 1 : 0

            Rectangle {
                id: inputBox
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                radius: 22
                color: Qt.rgba(1, 1, 1, 0.07)
                border.width: input.activeFocus ? 1 : 0
                border.color: Qt.rgba(view.brand.r, view.brand.g, view.brand.b, 0.8)

                NotchIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    name: icons.openCode
                    family: "brand"
                    size: 20
                    color: view.brand
                }

                TextInput {
                    id: input
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.right: sendButton.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: view.textColor
                    font.pixelSize: 14
                    font.family: view.fontFamily
                    clip: true
                    selectByMouse: true
                    enabled: !!(view.oc && view.oc.enabled)
                    onAccepted: {
                        if (view.oc && text.trim() !== "") {
                            view.oc.ask(text)
                            text = ""
                        }
                    }

                    Text {
                        visible: !parent.text && !parent.activeFocus
                        text: "Ask opencode\u2026"
                        color: view.mutedColor
                        font: parent.font
                    }
                }

                Rectangle {
                    id: sendButton
                    width: 32
                    height: 32
                    radius: 16
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: view.oc && view.oc.asking ? view.urgentColor : view.brand

                    NotchIcon {
                        anchors.centerIn: parent
                        name: view.oc && view.oc.asking ? icons.stop : icons.send
                        size: 17
                        color: view.accentText
                        weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!view.oc) return
                            if (view.oc.asking) view.oc.cancel()
                            else input.accepted()
                        }
                    }
                }
            }

            // answer area
            Flickable {
                id: answerFlick
                anchors.top: inputBox.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                contentWidth: width
                contentHeight: answerColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // stick to the bottom while text streams in
                onContentHeightChanged: {
                    if (view.oc && view.oc.asking) contentY = Math.max(0, contentHeight - height)
                }

                Column {
                    id: answerColumn
                    width: answerFlick.width
                    spacing: 10

                    Text {
                        visible: view.oc && view.oc.question !== ""
                        width: parent.width
                        text: view.oc ? view.oc.question : ""
                        color: view.brand
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.family: view.fontFamily
                        wrapMode: Text.Wrap
                    }

                    Text {
                        visible: view.oc && view.oc.asking && view.oc.answer === ""
                        text: "thinking\u2026"
                        color: view.mutedColor
                        font.pixelSize: 12
                        font.italic: true
                        font.family: view.fontFamily

                        SequentialAnimation on opacity {
                            running: parent.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: view.oc ? view.oc.answer : ""
                        color: view.textColor
                        font.pixelSize: 13
                        font.family: view.fontFamily
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }

                    Text {
                        width: parent.width
                        visible: view.oc && view.oc.error !== ""
                        text: view.oc ? view.oc.error : ""
                        color: view.urgentColor
                        font.pixelSize: 12
                        font.family: view.fontFamily
                        wrapMode: Text.Wrap
                    }

                    // empty state
                    Column {
                        width: parent.width
                        spacing: 6
                        visible: view.oc && view.oc.question === "" && !view.oc.asking

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Ask a quick question without leaving what you are doing."
                            color: view.mutedColor
                            font.pixelSize: 12
                            font.family: view.fontFamily
                            wrapMode: Text.Wrap
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Pick a session under Sessions to continue it."
                            color: view.mutedColor
                            opacity: 0.6
                            font.pixelSize: 11
                            font.family: view.fontFamily
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ SESSIONS
        Item {
            id: sessionsPage
            anchors.fill: parent
            visible: view.tab === 1

            // "new session" row
            Rectangle {
                id: newRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 36
                radius: 12
                color: view.oc && view.oc.selectedSession === "" ? Qt.rgba(view.brand.r, view.brand.g, view.brand.b, 0.22)
                     : newArea.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+  New session"
                    color: view.textColor
                    font.pixelSize: 13
                    font.family: view.fontFamily
                }

                MouseArea {
                    id: newArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.oc) { view.oc.selectedSession = ""; view.oc.clearAnswer() }
                        view.tab = 0
                    }
                }
            }

            ListView {
                id: sessionList
                anchors.top: newRow.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 4
                clip: true
                model: view.oc ? view.oc.sessions : []
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: sessionRow
                    required property var modelData

                    readonly property bool isSelected: view.oc && view.oc.selectedSession === modelData.id

                    width: sessionList.width
                    height: 46
                    radius: 12
                    color: isSelected ? Qt.rgba(view.brand.r, view.brand.g, view.brand.b, 0.22)
                         : sessionArea.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)

                    Behavior on color {
                        ColorAnimation { duration: 120 * view.speed }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: tokenText.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: sessionRow.modelData.title
                            color: view.textColor
                            font.pixelSize: 13
                            font.family: view.fontFamily
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: view.oc.ago(sessionRow.modelData.updated) + "  \u00B7  "
                                  + sessionRow.modelData.messages + " msgs  \u00B7  "
                                  + String(sessionRow.modelData.directory).split("/").pop()
                            color: view.mutedColor
                            font.pixelSize: 10
                            font.family: view.fontFamily
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        id: tokenText
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: view.oc.compact(view.oc.sessionTokens(sessionRow.modelData)) + " tok"
                        color: view.brand
                        font.pixelSize: 12
                        font.family: view.fontFamily
                    }

                    MouseArea {
                        id: sessionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.oc.selectedSession = sessionRow.modelData.id
                            view.oc.clearAnswer()
                            view.tab = 0
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: sessionList.count === 0
                    text: "No sessions found in the opencode database."
                    color: view.mutedColor
                    font.pixelSize: 12
                    font.family: view.fontFamily
                }
            }
        }

        // ---------------------------------------------------------- USAGE
        Item {
            id: usagePage
            anchors.fill: parent
            visible: view.tab === 2

            readonly property var t: view.oc ? view.oc.totals : ({})
            readonly property real allTotal: Number(t.input || 0) + Number(t.output || 0) + Number(t.reasoning || 0)
                                            + Number(t.cacheRead || 0) + Number(t.cacheWrite || 0)

            Column {
                anchors.fill: parent
                spacing: 12

                // today card
                Rectangle {
                    width: parent.width
                    height: 70
                    radius: 16
                    color: Qt.rgba(1, 1, 1, 0.05)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 0

                        Repeater {
                            model: [
                                { label: "Today in", value: view.oc ? view.oc.compact(usagePage.t.todayInput) : "0" },
                                { label: "Today out", value: view.oc ? view.oc.compact(usagePage.t.todayOutput) : "0" },
                                { label: "Today cost", value: view.oc ? view.oc.money(usagePage.t.todayCost) : "$0" },
                                { label: "Sessions", value: String(usagePage.t.sessions || 0) }
                            ]

                            delegate: Column {
                                required property var modelData
                                width: (parent.width) / 4
                                spacing: 3

                                Text {
                                    text: modelData.value
                                    color: view.brand
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                    font.family: view.fontFamily
                                }

                                Text {
                                    text: modelData.label
                                    color: view.mutedColor
                                    font.pixelSize: 10
                                    font.family: view.fontFamily
                                }
                            }
                        }
                    }
                }

                // all-time breakdown bars
                Repeater {
                    model: [
                        { label: "Input", key: "input", color: "#8ab4f8" },
                        { label: "Output", key: "output", color: "#34c759" },
                        { label: "Reasoning", key: "reasoning", color: "#bf5af2" },
                        { label: "Cache read", key: "cacheRead", color: view.accentColor },
                        { label: "Cache write", key: "cacheWrite", color: "#ff6482" }
                    ]

                    delegate: Item {
                        id: barRow
                        required property var modelData

                        readonly property real amount: Number(usagePage.t[modelData.key] || 0)

                        width: parent.width
                        height: 20

                        Text {
                            id: barLabel
                            width: 84
                            anchors.verticalCenter: parent.verticalCenter
                            text: barRow.modelData.label
                            color: view.mutedColor
                            font.pixelSize: 11
                            font.family: view.fontFamily
                        }

                        Rectangle {
                            anchors.left: barLabel.right
                            anchors.right: barValue.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: 6
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Rectangle {
                                height: parent.height
                                radius: 3
                                color: barRow.modelData.color
                                width: usagePage.allTotal > 0 ? parent.width * (barRow.amount / usagePage.allTotal) : 0

                                Behavior on width {
                                    NumberAnimation { duration: 320 * view.speed; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        Text {
                            id: barValue
                            width: 52
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: view.oc ? view.oc.compact(barRow.amount) : "0"
                            color: view.textColor
                            font.pixelSize: 11
                            font.family: view.fontFamily
                        }
                    }
                }

                Text {
                    text: "All time cost  " + (view.oc ? view.oc.money(usagePage.t.cost) : "$0")
                          + "   \u00B7   " + (usagePage.t.messages || 0) + " messages"
                    color: view.mutedColor
                    font.pixelSize: 11
                    font.family: view.fontFamily
                }
            }
        }
    }

    // ---- footer navbar: same shared chrome as every other popup ---------------------------
    PopupNav {
        id: popupNav
        host: view.host
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
