import QtQuick
import QtQuick.Window
import QtQml

Window {
    id: root

    property bool settingsOpen: false
    property bool configRestored: false
    property string mainStatusMessage: ""
    readonly property int compactHeight: 400
    readonly property int settingsHeight: 580

    width: 400
    height: compactHeight
    visible: true
    title: "Forzassist - Qt text renderer"
    color: "transparent"

    flags: Qt.FramelessWindowHint | Qt.Window | Qt.WindowSystemMenuHint | Qt.WindowMinimizeButtonHint

    Component.onCompleted: {
        centerOnAvailableScreen()
        backend.loadConfig()
    }

    function saveUserConfig() {
        if (!configRestored)
            return

        if (typeof backend === "undefined")
            return

        backend.saveConfig(
            Math.round(arcControl.progress * 100),
            doubleShiftToggle.checked,
            upshiftBindButton.bindButtonId,
            downshiftBindButton.bindButtonId,
            pedalOverlayToggle.checked,
            dataOutIpAddressEditor.savedValue,
            dataOutIpPortEditor.savedValue,
            pedalOverlayWindow.x,
            pedalOverlayWindow.y,
            pedalOverlayWindow.overlayScale
        )
    }

    function centerOnAvailableScreen() {
        x = Math.round((Screen.desktopAvailableWidth - width) / 2)
        y = Math.round((Screen.desktopAvailableHeight - height) / 2)
    }

    function setSettingsOpen(open) {
        if (settingsOpen === open)
            return

        var currentCenterY = y + height / 2
        var targetHeight = open ? settingsHeight : compactHeight
        var targetY = Math.round(currentCenterY - targetHeight / 2)

        settingsOpen = open

        resizeHeight.stop()
        resizeY.stop()

        resizeHeight.from = height
        resizeHeight.to = targetHeight

        resizeY.from = y
        resizeY.to = targetY

        resizeHeight.start()
        resizeY.start()
    }

    function toggleSettingsOpen() {
        setSettingsOpen(!settingsOpen)
    }

    NumberAnimation {
        id: resizeHeight
        target: root
        property: "height"
        duration: 520
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: resizeY
        target: root
        property: "y"
        duration: 520
        easing.type: Easing.InOutCubic
    }

    onActiveChanged: {
        if (!active && typeof panel !== "undefined") {
            panel.commitAllEditorsIfNeeded()
            saveUserConfig()
        }
    }

    onClosing: {
        panel.commitAllEditorsIfNeeded()
        saveUserConfig()
    }

    readonly property string regularFontFamily: typeof interRegularFamily !== "undefined" ? interRegularFamily : "Inter"
    readonly property string mediumFontFamily: typeof interMediumFamily !== "undefined" ? interMediumFamily : regularFontFamily
    readonly property string boldFontFamily: typeof interBoldFamily !== "undefined" ? interBoldFamily : regularFontFamily

    function controllerButtonIconSource(displayName) {
        if (displayName === "A")
            return "assets/controller_buttons/a.png"
        if (displayName === "B")
            return "assets/controller_buttons/b.png"
        if (displayName === "X")
            return "assets/controller_buttons/x.png"
        if (displayName === "Y")
            return "assets/controller_buttons/y.png"
        if (displayName === "BACK")
            return "assets/controller_buttons/back.png"
        if (displayName === "START")
            return "assets/controller_buttons/start.png"
        if (displayName === "LS")
            return "assets/controller_buttons/ls.png"
        if (displayName === "RS")
            return "assets/controller_buttons/rs.png"
        if (displayName === "LB")
            return "assets/controller_buttons/lb.png"
        if (displayName === "RB")
            return "assets/controller_buttons/rb.png"
        if (displayName === "↑")
            return "assets/controller_buttons/dpad_up.png"
        if (displayName === "↓")
            return "assets/controller_buttons/dpad_down.png"
        if (displayName === "←")
            return "assets/controller_buttons/dpad_left.png"
        if (displayName === "→")
            return "assets/controller_buttons/dpad_right.png"

        return ""
    }

    Connections {
        target: backend

        function onOverlayValuesChanged(clutch, brake, throttle, handbrake, playerSteer, assistSteer) {
            pedalOverlayContent.clutchValue = clutch
            pedalOverlayContent.footbrakeValue = brake
            pedalOverlayContent.throttleValue = throttle
            pedalOverlayContent.handbrakeValue = handbrake
            pedalOverlayContent.playerSteer = playerSteer
            pedalOverlayContent.assistSteer = assistSteer
        }

        function onBindCaptured(which, displayName, buttonId) {
            if (which === "upshift") {
                upshiftBindButton.bindText = displayName
                upshiftBindButton.bindButtonId = buttonId
                upshiftBindButton.bindIconSource = controllerButtonIconSource(displayName)
                upshiftBindButton.waitingForInput = false
            } else if (which === "downshift") {
                downshiftBindButton.bindText = displayName
                downshiftBindButton.bindButtonId = buttonId
                downshiftBindButton.bindIconSource = controllerButtonIconSource(displayName)
                downshiftBindButton.waitingForInput = false
            }

            saveUserConfig()
        }

        function onBindCaptureCancelled(which) {
            if (which === "upshift")
                upshiftBindButton.waitingForInput = false
            else if (which === "downshift")
                downshiftBindButton.waitingForInput = false
        }

        function onConfigLoaded(
            steeringResponsePercent,
            doubleShiftEnabled,
            upshiftDisplayName,
            upshiftButtonId,
            downshiftDisplayName,
            downshiftButtonId,
            pedalOverlayEnabled,
            telemetryIp,
            telemetryPort,
            overlayX,
            overlayY,
            overlayScale
        ) {
            arcControl.progress = Math.max(0.0, Math.min(1.0, steeringResponsePercent / 100.0))

            doubleShiftToggle.checked = doubleShiftEnabled
            backend.setDoubleShiftFixChecked(doubleShiftEnabled)

            upshiftBindButton.bindText = upshiftDisplayName
            upshiftBindButton.bindButtonId = upshiftButtonId
            upshiftBindButton.bindIconSource = controllerButtonIconSource(upshiftDisplayName)

            downshiftBindButton.bindText = downshiftDisplayName
            downshiftBindButton.bindButtonId = downshiftButtonId
            downshiftBindButton.bindIconSource = controllerButtonIconSource(downshiftDisplayName)

            pedalOverlayToggle.checked = pedalOverlayEnabled

            dataOutIpAddressEditor.savedValue = telemetryIp
            dataOutIpAddressEditor.editValue = telemetryIp
            backend.setTelemetryIp(telemetryIp)

            dataOutIpPortEditor.savedValue = telemetryPort.toString()
            dataOutIpPortEditor.editValue = dataOutIpPortEditor.savedValue
            backend.setTelemetryPort(dataOutIpPortEditor.savedValue)

            pedalOverlayWindow.overlayScale = overlayScale

            if (overlayX >= 0 && overlayY >= 0) {
                pedalOverlayWindow.x = overlayX
                pedalOverlayWindow.y = overlayY
                pedalOverlayWindow.overlayPositionInitialized = true
            }

            root.configRestored = true
            saveUserConfig()
        }

        function onBackendError(message) {
            console.log(message)

            if (message.indexOf("No XInput controller found") !== -1)
                root.mainStatusMessage = "No controller found"
        }

        function onStatusChanged(message) {
            console.log(message)

            if (message.indexOf("Assist started") !== -1)
                root.mainStatusMessage = ""
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 36
        color: "#0F0F0F"
        clip: true
        focus: true

        function commitPercentEditIfNeeded() {
            if (typeof percentEditor !== "undefined" && percentEditor.editingValue)
                percentEditor.commitEdit()
        }

        function commitSettingsEditorsIfNeeded() {
            if (typeof dataOutIpAddressEditor !== "undefined" && dataOutIpAddressEditor.editingValue)
                dataOutIpAddressEditor.commitEdit()

            if (typeof dataOutIpPortEditor !== "undefined" && dataOutIpPortEditor.editingValue)
                dataOutIpPortEditor.commitEdit()
        }

        function commitAllEditorsIfNeeded() {
            commitPercentEditIfNeeded()
            commitSettingsEditorsIfNeeded()
        }

        function mainOpacity() {
            return root.settingsOpen ? 0.0 : 1.0
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            z: -1
            onPressed: panel.commitAllEditorsIfNeeded()
        }

        MouseArea {
            id: windowDragArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            z: -0.5
            cursorShape: Qt.ArrowCursor

            onPressed: function(mouse) {
                panel.commitAllEditorsIfNeeded()

                root.startSystemMove()
                mouse.accepted = true
            }
        }

        Image {
            source: "assets/rendered/logo_124.png"
            width: 31
            height: 31
            x: 24
            y: 19

            sourceSize.width: 124
            sourceSize.height: 124
            smooth: true
            mipmap: true
            antialiasing: true
            fillMode: Image.PreserveAspectFit
        }

        Item {
            id: arcControl
            width: 260
            height: 176
            x: 70
            y: 88
            opacity: panel.mainOpacity()
            enabled: !root.settingsOpen

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            property real progress: 0.50
            property bool hoveringArc: false

            onProgressChanged: {
                if (typeof backend !== "undefined")
                    backend.setDriftStylePercent(Math.round(progress * 100))
                saveUserConfig()
            }

            readonly property real strokeW: 17
            readonly property real radius: 105
            readonly property real cx: width / 2
            readonly property real cy: 150
            readonly property real knobSize: 29
            readonly property real knobRadius: knobSize / 2
            readonly property real knobAngle: Math.PI + Math.PI * progress
            readonly property real knobCenterX: cx + Math.cos(knobAngle) * radius
            readonly property real knobCenterY: cy + Math.sin(knobAngle) * radius

            function clamp(v, lo, hi) {
                return Math.max(lo, Math.min(hi, v))
            }

            function isPointNearArc(px, py) {
                var dx = px - cx
                var dy = py - cy
                var distance = Math.sqrt(dx * dx + dy * dy)
                var distanceToStroke = Math.abs(distance - radius)

                var angle = Math.atan2(dy, dx)
                if (angle < 0)
                    angle += Math.PI * 2

                var onTopHalf = angle >= Math.PI && angle <= Math.PI * 2
                var withinStroke = distanceToStroke <= strokeW * 1.65

                return onTopHalf && withinStroke
            }

            function isPointNearKnob(px, py) {
                var dx = px - knobCenterX
                var dy = py - knobCenterY
                var distance = Math.sqrt(dx * dx + dy * dy)

                return distance <= knobRadius + 6
            }

            function isPointInteractive(px, py) {
                return isPointNearArc(px, py) || isPointNearKnob(px, py)
            }

            function updateHover(px, py) {
                hoveringArc = isPointInteractive(px, py)
            }

            function updateFromPoint(px, py) {
                var dx = px - cx
                var dy = py - cy

                var angle = Math.atan2(dy, dx)
                if (angle < 0)
                    angle += Math.PI * 2

                if (angle < Math.PI) {
                    progress = dx >= 0 ? 1.0 : 0.0
                } else {
                    progress = (angle - Math.PI) / Math.PI
                }

                progress = clamp(progress, 0.0, 1.0)
                arcCanvas.requestPaint()
            }

            function setPercent(percentValue) {
                var parsed = parseInt(percentValue)
                if (isNaN(parsed))
                    parsed = Math.round(progress * 100)

                parsed = clamp(parsed, 0, 100)
                progress = parsed / 100
                arcCanvas.requestPaint()
            }

            Canvas {
                id: arcCanvas
                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()

                    ctx.lineWidth = arcControl.strokeW
                    ctx.lineCap = "butt"

                    ctx.strokeStyle = "#422928"
                    ctx.beginPath()
                    ctx.arc(arcControl.cx, arcControl.cy, arcControl.radius, Math.PI, Math.PI * 2, false)
                    ctx.stroke()

                    ctx.strokeStyle = "#FC3610"
                    ctx.beginPath()
                    ctx.arc(
                        arcControl.cx,
                        arcControl.cy,
                        arcControl.radius,
                        Math.PI,
                        Math.PI + Math.PI * arcControl.progress,
                        false
                    )
                    ctx.stroke()
                }
            }

            Rectangle {
                id: arcKnob
                width: arcControl.knobSize
                height: arcControl.knobSize
                radius: width / 2
                color: "#FC3610"
                x: arcControl.knobCenterX - width / 2
                y: arcControl.knobCenterY - height / 2
                opacity: arcControl.hoveringArc || arcMouseArea.pressed ? 1.0 : 0.0
                visible: opacity > 0.01
                antialiasing: true

                Behavior on opacity {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: arcMouseArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                preventStealing: true
                cursorShape: arcControl.hoveringArc || pressed
                             ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                             : Qt.ArrowCursor

                onExited: {
                    arcControl.hoveringArc = false
                }

                onPositionChanged: function(mouse) {
                    arcControl.updateHover(mouse.x, mouse.y)

                    if (pressed) {
                        arcControl.updateFromPoint(mouse.x, mouse.y)
                        mouse.accepted = true
                    }
                }

                onPressed: function(mouse) {
                    panel.commitAllEditorsIfNeeded()
                    arcControl.updateHover(mouse.x, mouse.y)

                    if (arcControl.isPointInteractive(mouse.x, mouse.y)) {
                        arcControl.updateFromPoint(mouse.x, mouse.y)
                        mouse.accepted = true
                    }
                }

                onReleased: function(mouse) {
                    arcControl.updateHover(mouse.x, mouse.y)
                }
            }
        }

        Item {
            id: percentEditor
            width: 160
            height: 52
            x: (panel.width - width) / 2
            y: 173
            opacity: panel.mainOpacity()
            enabled: !root.settingsOpen

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            property int percentFontSize: 40
            property bool editingValue: false
            property string editValue: Math.round(arcControl.progress * 100).toString()

            function beginEdit() {
                editValue = Math.round(arcControl.progress * 100).toString()
                editingValue = true
                editInput.forceActiveFocus()
                editInput.selectAll()
            }

            function commitEdit() {
                arcControl.setPercent(editValue)
                editValue = Math.round(arcControl.progress * 100).toString()
                editingValue = false
                editInput.deselect()
                editInput.focus = false
                panel.forceActiveFocus()
            }

            function cancelEdit() {
                editValue = Math.round(arcControl.progress * 100).toString()
                editingValue = false
                editInput.deselect()
                editInput.focus = false
                panel.forceActiveFocus()
            }

            Text {
                id: percentDisplay
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
                text: Math.round(arcControl.progress * 100) + "%"
                color: "#FFFFFF"
                font.family: root.boldFontFamily
                font.pixelSize: percentEditor.percentFontSize
                font.weight: Font.Bold
                renderType: Text.NativeRendering
                visible: !percentEditor.editingValue
            }

            TextInput {
                id: editInput
                anchors.fill: parent
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignTop
                text: percentEditor.editValue
                color: "#FFFFFF"
                font.family: root.boldFontFamily
                font.pixelSize: percentEditor.percentFontSize
                font.weight: Font.Bold
                renderType: TextInput.NativeRendering
                visible: percentEditor.editingValue
                activeFocusOnPress: false
                selectByMouse: false
                selectedTextColor: "#FFFFFF"
                selectionColor: "#FC3610"
                cursorVisible: percentEditor.editingValue && activeFocus

                cursorDelegate: Rectangle {
                    width: 2
                    color: "#FC3610"
                }

                validator: IntValidator {
                    bottom: 0
                    top: 100
                }

                onTextEdited: {
                    percentEditor.editValue = text
                }

                onActiveFocusChanged: {
                    if (!activeFocus && percentEditor.editingValue)
                        percentEditor.commitEdit()
                }

                Keys.onReturnPressed: function(event) {
                    percentEditor.commitEdit()
                    event.accepted = true
                }

                Keys.onEnterPressed: function(event) {
                    percentEditor.commitEdit()
                    event.accepted = true
                }

                Keys.onEscapePressed: function(event) {
                    percentEditor.cancelEdit()
                    event.accepted = true
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: !percentEditor.editingValue
                cursorShape: Qt.IBeamCursor
                acceptedButtons: Qt.LeftButton

                onClicked: function(mouse) {
                    percentEditor.beginEdit()
                    mouse.accepted = true
                }
            }
        }

        Text {
            id: driftAggressionText
            width: 200
            horizontalAlignment: Text.AlignHCenter
            x: (panel.width - width) / 2
            opacity: panel.mainOpacity()

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            font.pixelSize: Math.round(percentEditor.percentFontSize / 3)

            y: arcControl.y + arcControl.cy - height

            text: "Steering Response"
            color: "#FFFFFF"
            font.family: root.mediumFontFamily
            font.weight: Font.Medium
            renderType: Text.QtRendering
        }

        Rectangle {
            id: startAssistButton
            width: 138
            height: 38
            radius: 200
            x: (panel.width - width) / 2
            y: driftAggressionText.y + driftAggressionText.height + 33
            color: backend.assistRunning ? "#332C29" : (startButtonMouse.containsMouse ? "#FF7257" : "#FC3610")
            scale: bounceScale
            transformOrigin: Item.Center
            opacity: panel.mainOpacity()
            enabled: !root.settingsOpen

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            property real bounceScale: 1.0

            function toggleAssist() {
                panel.commitAllEditorsIfNeeded()
                backend.setDriftStylePercent(Math.round(arcControl.progress * 100))
                backend.setDoubleShiftFixChecked(doubleShiftToggle.checked)
                backend.setTelemetryIp(dataOutIpAddressEditor.savedValue)
                backend.setTelemetryPort(dataOutIpPortEditor.savedValue)
                backend.toggleAssist()
                clickBounce.restart()
            }

            Behavior on color {
                ColorAnimation {
                    duration: 170
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                id: clickBounce
                NumberAnimation {
                    target: startAssistButton
                    property: "bounceScale"
                    to: 0.955
                    duration: 145
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: startAssistButton
                    property: "bounceScale"
                    to: 1.030
                    duration: 185
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: startAssistButton
                    property: "bounceScale"
                    to: 0.990
                    duration: 165
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: startAssistButton
                    property: "bounceScale"
                    to: 1.000
                    duration: 170
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                anchors.centerIn: parent
                text: backend.assistRunning ? "Stop Assist" : "Start Assist"
                color: "#FFFFFF"
                font.family: root.mediumFontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
                renderType: Text.QtRendering
            }

            MouseArea {
                id: startButtonMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: function(mouse) {
                    startAssistButton.toggleAssist()
                    mouse.accepted = true
                }
            }
        }

        
        Text {
            id: mainStatusText
            width: panel.width - 48
            x: 24
            y: root.compactHeight - 24 - implicitHeight
            text: root.mainStatusMessage
            color: "#FFFFFF"
            opacity: (!root.settingsOpen && root.mainStatusMessage.length > 0) ? 0.50 : 0.0
            visible: opacity > 0.01
            horizontalAlignment: Text.AlignHCenter
            font.family: root.mediumFontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            renderType: Text.QtRendering

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }

Text {
            id: doubleShiftFixTitle
            x: 24
            y: 75
            text: "Double-Shift Fix"
            color: "#FC3610"
            font.family: root.boldFontFamily
            font.pixelSize: 16
            font.weight: Font.Bold
            renderType: Text.QtRendering
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            id: doubleShiftToggle
            width: 44
            height: 16
            x: doubleShiftFixTitle.x + doubleShiftFixTitle.implicitWidth + 10
            y: doubleShiftFixTitle.y + (doubleShiftFixTitle.implicitHeight - height) / 2
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.settingsOpen

            property bool checked: false

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: doubleShiftToggleTrack
                anchors.fill: parent
                radius: 20
                color: doubleShiftToggle.checked ? "#FC3610" : "#332C29"

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                id: doubleShiftOnText
                text: "ON"
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                color: "#FFFFFF"
                opacity: doubleShiftToggle.checked ? 1.0 : 0.0
                font.family: root.mediumFontFamily
                font.pixelSize: 7
                font.weight: Font.Medium
                renderType: Text.QtRendering

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                id: doubleShiftOffText
                text: "OFF"
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                color: "#FFFFFF"
                opacity: doubleShiftToggle.checked ? 0.0 : 1.0
                font.family: root.mediumFontFamily
                font.pixelSize: 7
                font.weight: Font.Medium
                renderType: Text.QtRendering

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                id: doubleShiftToggleKnob
                width: 14
                height: 14
                radius: 7
                x: doubleShiftToggle.checked ? 29 : 1
                y: 1
                color: "#FFFFFF"

                Behavior on x {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    doubleShiftToggle.checked = !doubleShiftToggle.checked
                    backend.setDoubleShiftFixChecked(doubleShiftToggle.checked)
                    saveUserConfig()
                }
            }
        }

        Text {
            id: doubleShiftDescription
            x: 24
            y: doubleShiftFixTitle.y + doubleShiftFixTitle.implicitHeight + 14
            width: panel.width - 48
            text: "Set your in-game binds here to prevent double shifts when\nForza detects inputs from both controllers."
            color: "#FFFFFF"
            font.family: root.mediumFontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            renderType: Text.QtRendering
            horizontalAlignment: Text.AlignLeft
            wrapMode: Text.NoWrap
            lineHeightMode: Text.FixedHeight
            lineHeight: 16
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            id: upshiftBindButton
            width: 28
            height: 28
            radius: 6
            x: 24
            y: doubleShiftDescription.y + doubleShiftDescription.implicitHeight + 18
            color: upshiftBindMouse.containsMouse ? "#FF7257" : "#FC3610"
            scale: bindBounceScale
            transformOrigin: Item.Center
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.settingsOpen

            property bool waitingForInput: false
            property string bindText: "B"
            property int bindButtonId: 1
            property string bindIconSource: controllerButtonIconSource("B")
            property real bindBounceScale: 1.0

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                id: upshiftBindBounce
                NumberAnimation {
                    target: upshiftBindButton
                    property: "bindBounceScale"
                    to: 0.92
                    duration: 85
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: upshiftBindButton
                    property: "bindBounceScale"
                    to: 1.08
                    duration: 135
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: upshiftBindButton
                    property: "bindBounceScale"
                    to: 1.00
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Image {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: upshiftBindButton.bindIconSource
                visible: !upshiftBindButton.waitingForInput && upshiftBindButton.bindIconSource !== ""
                smooth: true
                mipmap: true
                antialiasing: true
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.centerIn: parent
                text: upshiftBindButton.waitingForInput ? "..." : upshiftBindButton.bindText
                color: "#FFFFFF"
                font.family: root.mediumFontFamily
                font.pixelSize: upshiftBindButton.bindText.length > 2 ? 8 : 12
                font.weight: Font.Medium
                renderType: Text.QtRendering
                visible: upshiftBindButton.waitingForInput || upshiftBindButton.bindIconSource === ""
            }

            MouseArea {
                id: upshiftBindMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: function(mouse) {
                    upshiftBindButton.waitingForInput = true
                    upshiftBindBounce.restart()
                    backend.startBinding("upshift")
                    mouse.accepted = true
                }
            }
        }

        Text {
            id: upshiftBindLabel
            x: upshiftBindButton.x + upshiftBindButton.width + 11
            y: upshiftBindButton.y + (upshiftBindButton.height - implicitHeight) / 2
            text: "Upshift"
            color: "#FFFFFF"
            font.family: root.mediumFontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            renderType: Text.QtRendering
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            id: downshiftBindButton
            width: 28
            height: 28
            radius: 6
            x: upshiftBindButton.x
            y: upshiftBindButton.y + upshiftBindButton.height + 13
            color: downshiftBindMouse.containsMouse ? "#FF7257" : "#FC3610"
            scale: bindBounceScale
            transformOrigin: Item.Center
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.settingsOpen

            property bool waitingForInput: false
            property string bindText: "X"
            property int bindButtonId: 2
            property string bindIconSource: controllerButtonIconSource("X")
            property real bindBounceScale: 1.0

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                id: downshiftBindBounce
                NumberAnimation {
                    target: downshiftBindButton
                    property: "bindBounceScale"
                    to: 0.92
                    duration: 85
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: downshiftBindButton
                    property: "bindBounceScale"
                    to: 1.08
                    duration: 135
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: downshiftBindButton
                    property: "bindBounceScale"
                    to: 1.00
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Image {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: downshiftBindButton.bindIconSource
                visible: !downshiftBindButton.waitingForInput && downshiftBindButton.bindIconSource !== ""
                smooth: true
                mipmap: true
                antialiasing: true
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.centerIn: parent
                text: downshiftBindButton.waitingForInput ? "..." : downshiftBindButton.bindText
                color: "#FFFFFF"
                font.family: root.mediumFontFamily
                font.pixelSize: downshiftBindButton.bindText.length > 2 ? 8 : 12
                font.weight: Font.Medium
                renderType: Text.QtRendering
                visible: downshiftBindButton.waitingForInput || downshiftBindButton.bindIconSource === ""
            }

            MouseArea {
                id: downshiftBindMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: function(mouse) {
                    downshiftBindButton.waitingForInput = true
                    downshiftBindBounce.restart()
                    backend.startBinding("downshift")
                    mouse.accepted = true
                }
            }
        }

        Text {
            id: downshiftBindLabel
            x: downshiftBindButton.x + downshiftBindButton.width + 11
            y: downshiftBindButton.y + (downshiftBindButton.height - implicitHeight) / 2
            text: "Downshift"
            color: "#FFFFFF"
            font.family: root.mediumFontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            renderType: Text.QtRendering
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            id: telemetryTitle
            x: 24
            y: downshiftBindButton.y + downshiftBindButton.height + 30
            text: "Telemetry"
            color: "#FC3610"
            font.family: root.boldFontFamily
            font.pixelSize: 16
            font.weight: Font.Bold
            renderType: Text.QtRendering
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            id: dataOutIpAddressLabel
            x: 24
            y: telemetryTitle.y + telemetryTitle.implicitHeight + 18
            text: "Data Out IP Address"
            color: "#FFFFFF"
            font.family: root.mediumFontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
            renderType: Text.QtRendering
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
        }

                        Rectangle {
            id: dataOutIpAddressBox
            x: 24
            y: dataOutIpAddressLabel.y + dataOutIpAddressLabel.implicitHeight + 18
            width: 124
            height: 32
            radius: 5
            color: "#1E1E1E"
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.settingsOpen

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                id: dataOutIpAddressEditor
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                property bool editingValue: false
                property string savedValue: "127.0.0.1"
                property string editValue: savedValue

                function isValidIPv4(value) {
                    var parts = value.split(".")
                    if (parts.length !== 4)
                        return false

                    for (var i = 0; i < parts.length; i++) {
                        if (parts[i].length < 1 || parts[i].length > 3)
                            return false

                        var n = parseInt(parts[i], 10)
                        if (isNaN(n) || n < 0 || n > 255)
                            return false
                    }

                    return true
                }

                function beginEdit() {
                    editValue = savedValue
                    editingValue = true
                    ipEditInput.forceActiveFocus()
                    ipEditInput.selectAll()
                }

                function commitEdit() {
                    if (isValidIPv4(ipEditInput.text))
                        savedValue = ipEditInput.text

                    backend.setTelemetryIp(savedValue)
                    editValue = savedValue
                    saveUserConfig()
                    editingValue = false
                    ipEditInput.deselect()
                    ipEditInput.focus = false
                    panel.forceActiveFocus()
                }

                function cancelEdit() {
                    editValue = savedValue
                    editingValue = false
                    ipEditInput.deselect()
                    ipEditInput.focus = false
                    panel.forceActiveFocus()
                }

                Text {
                    id: ipDisplayText
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                    text: dataOutIpAddressEditor.savedValue
                    color: "#FFFFFF"
                    font.family: root.mediumFontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    renderType: Text.QtRendering
                    visible: !dataOutIpAddressEditor.editingValue
                }

                TextInput {
                    id: ipEditInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignLeft
                    text: dataOutIpAddressEditor.editValue
                    color: "#FFFFFF"
                    font.family: root.mediumFontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    renderType: TextInput.QtRendering
                    visible: dataOutIpAddressEditor.editingValue
                    enabled: dataOutIpAddressEditor.editingValue
                    maximumLength: 15
                    activeFocusOnPress: true
                    selectByMouse: true
                    selectedTextColor: "#FFFFFF"
                    selectionColor: "#FC3610"
                    cursorVisible: dataOutIpAddressEditor.editingValue && activeFocus
                    cursorDelegate: Rectangle {
                        width: 1
                        color: "#FC3610"
                    }

                    validator: RegularExpressionValidator {
                        regularExpression: /^[0-9.]{0,15}$/
                    }

                    onTextEdited: {
                        dataOutIpAddressEditor.editValue = text
                    }

                    onActiveFocusChanged: {
                        if (!activeFocus && dataOutIpAddressEditor.editingValue)
                            dataOutIpAddressEditor.commitEdit()
                    }

                    Keys.onReturnPressed: function(event) {
                        dataOutIpAddressEditor.commitEdit()
                        event.accepted = true
                    }

                    Keys.onEnterPressed: function(event) {
                        dataOutIpAddressEditor.commitEdit()
                        event.accepted = true
                    }

                    Keys.onEscapePressed: function(event) {
                        dataOutIpAddressEditor.cancelEdit()
                        event.accepted = true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !dataOutIpAddressEditor.editingValue
                    cursorShape: Qt.IBeamCursor
                    acceptedButtons: Qt.LeftButton

                    onClicked: function(mouse) {
                        dataOutIpAddressEditor.beginEdit()
                        mouse.accepted = true
                    }
                }
            }
        }

        
        Text {
            id: dataOutIpPortLabel
            x: 24
            y: dataOutIpAddressBox.y + dataOutIpAddressBox.height + 18
            text: "Data Out IP Port"
            color: "#FFFFFF"
            font.family: root.mediumFontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
            renderType: Text.QtRendering
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
        }

                        Rectangle {
            id: dataOutIpPortBox
            x: 24
            y: dataOutIpPortLabel.y + dataOutIpPortLabel.implicitHeight + 18
            width: 60
            height: 32
            radius: 5
            color: "#1E1E1E"
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.settingsOpen

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                id: dataOutIpPortEditor
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                property bool editingValue: false
                property string savedValue: "5600"
                property string editValue: savedValue
                readonly property int numericValue: parseInt(savedValue, 10)
                readonly property bool reservedPort: !isNaN(numericValue) && numericValue >= 5200 && numericValue <= 5300

                function beginEdit() {
                    editValue = savedValue
                    editingValue = true
                    portEditInput.forceActiveFocus()
                    portEditInput.selectAll()
                }

                function commitEdit() {
                    if (portEditInput.text.length > 0) {
                        var parsed = parseInt(portEditInput.text, 10)
                        if (!isNaN(parsed)) {
                            if (parsed < 0)
                                parsed = 0
                            if (parsed > 99999)
                                parsed = 99999
                            savedValue = parsed.toString()
                        }
                    }

                    editValue = savedValue
                    editingValue = false
                    portEditInput.deselect()
                    portEditInput.focus = false
                    panel.forceActiveFocus()
                }

                function cancelEdit() {
                    editValue = savedValue
                    editingValue = false
                    portEditInput.deselect()
                    portEditInput.focus = false
                    panel.forceActiveFocus()
                }

                Text {
                    id: portDisplayText
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                    text: dataOutIpPortEditor.savedValue
                    color: "#FFFFFF"
                    font.family: root.mediumFontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    renderType: Text.QtRendering
                    visible: !dataOutIpPortEditor.editingValue
                }

                TextInput {
                    id: portEditInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignLeft
                    text: dataOutIpPortEditor.editValue
                    color: "#FFFFFF"
                    font.family: root.mediumFontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    renderType: TextInput.QtRendering
                    visible: dataOutIpPortEditor.editingValue
                    enabled: dataOutIpPortEditor.editingValue
                    maximumLength: 5
                    activeFocusOnPress: true
                    selectByMouse: true
                    selectedTextColor: "#FFFFFF"
                    selectionColor: "#FC3610"
                    cursorVisible: dataOutIpPortEditor.editingValue && activeFocus
                    cursorDelegate: Rectangle {
                        width: 1
                        color: "#FC3610"
                    }

                    validator: IntValidator {
                        bottom: 0
                        top: 99999
                    }

                    onTextEdited: {
                        dataOutIpPortEditor.editValue = text
                    }

                    onActiveFocusChanged: {
                        if (!activeFocus && dataOutIpPortEditor.editingValue)
                            dataOutIpPortEditor.commitEdit()
                    }

                    Keys.onReturnPressed: function(event) {
                        dataOutIpPortEditor.commitEdit()
                        event.accepted = true
                    }

                    Keys.onEnterPressed: function(event) {
                        dataOutIpPortEditor.commitEdit()
                        event.accepted = true
                    }

                    Keys.onEscapePressed: function(event) {
                        dataOutIpPortEditor.cancelEdit()
                        event.accepted = true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !dataOutIpPortEditor.editingValue
                    cursorShape: Qt.IBeamCursor
                    acceptedButtons: Qt.LeftButton

                    onClicked: function(mouse) {
                        dataOutIpPortEditor.beginEdit()
                        mouse.accepted = true
                    }
                }
            }
        }

        Text {
            id: dataOutIpPortWarning
            x: dataOutIpPortBox.x + dataOutIpPortBox.width + 8
            y: dataOutIpPortBox.y + (dataOutIpPortBox.height - implicitHeight) / 2
            text: "Avoid 5200–5300"
            color: "#FC3610"
            font.family: root.mediumFontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            renderType: Text.QtRendering
            opacity: root.settingsOpen && dataOutIpPortEditor.reservedPort ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            id: overlayTitle
            x: 24
            y: dataOutIpPortBox.y + dataOutIpPortBox.height + 30
            text: "Pedal Overlay"
            color: "#FC3610"
            font.family: root.boldFontFamily
            font.pixelSize: 16
            font.weight: Font.Bold
            renderType: Text.QtRendering
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            id: pedalOverlayToggle
            width: 44
            height: 16
            x: overlayTitle.x + overlayTitle.implicitWidth + 10
            y: overlayTitle.y + (overlayTitle.implicitHeight - height) / 2
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.settingsOpen

            property bool checked: false

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: pedalOverlayToggleTrack
                anchors.fill: parent
                radius: 20
                color: pedalOverlayToggle.checked ? "#FC3610" : "#332C29"

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                id: pedalOverlayOnText
                text: "ON"
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                color: "#FFFFFF"
                opacity: pedalOverlayToggle.checked ? 1.0 : 0.0
                font.family: root.mediumFontFamily
                font.pixelSize: 7
                font.weight: Font.Medium
                renderType: Text.QtRendering

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                id: pedalOverlayOffText
                text: "OFF"
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                color: "#FFFFFF"
                opacity: pedalOverlayToggle.checked ? 0.0 : 1.0
                font.family: root.mediumFontFamily
                font.pixelSize: 7
                font.weight: Font.Medium
                renderType: Text.QtRendering

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                id: pedalOverlayToggleKnob
                width: 14
                height: 14
                radius: 7
                x: pedalOverlayToggle.checked ? 29 : 1
                y: 1
                color: "#FFFFFF"

                Behavior on x {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    pedalOverlayToggle.checked = !pedalOverlayToggle.checked
                    saveUserConfig()
                }
            }
        }

        Text {
            id: pedalOverlayDescription
            x: 24
            width: panel.width - 48
            y: overlayTitle.y + overlayTitle.implicitHeight + 14
            text: "Show your clutch, brake, throttle, and handbrake inputs as\na clean in-game overlay."
            color: "#FFFFFF"
            font.family: root.mediumFontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            renderType: Text.QtRendering
            horizontalAlignment: Text.AlignLeft
            wrapMode: Text.NoWrap
            lineHeightMode: Text.FixedHeight
            lineHeight: 15
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
        }

Item {
            id: minimizeButton
            width: 24
            height: 24
            x: 291
            y: 19
            property real hoverAmount: minimizeMouse.containsMouse ? 1.0 : 0.0

            Image {
                source: "assets/rendered/minimize_64x8.png"
                width: 16
                height: 2
                x: 4
                y: 11
                smooth: true
                antialiasing: true
                fillMode: Image.PreserveAspectFit
            }

            Image {
                source: "assets/rendered/minimize_red_64x8.png"
                width: 16
                height: 2
                x: 4
                y: 11
                opacity: minimizeButton.hoverAmount
                smooth: true
                antialiasing: true
                fillMode: Image.PreserveAspectFit
            }

            Behavior on hoverAmount {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: minimizeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    panel.commitAllEditorsIfNeeded()
                    root.showMinimized()
                }
            }
        }

        Item {
            id: settingsButton
            width: 24
            height: 24
            x: 326
            y: 19
            property real hoverAmount: settingsMouse.containsMouse ? 1.0 : 0.0

            Image {
                source: root.settingsOpen ? "assets/rendered/home_56.png" : "assets/rendered/settings_56.png"
                width: 14
                height: 14
                x: 5
                y: 5
                smooth: true
                antialiasing: true
                fillMode: Image.PreserveAspectFit
            }

            Image {
                source: root.settingsOpen ? "assets/rendered/home_red_56.png" : "assets/rendered/settings_red_56.png"
                width: 14
                height: 14
                x: 5
                y: 5
                opacity: settingsButton.hoverAmount
                smooth: true
                antialiasing: true
                fillMode: Image.PreserveAspectFit
            }

            Behavior on hoverAmount {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: settingsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    panel.commitAllEditorsIfNeeded()
                    root.toggleSettingsOpen()
                }
            }
        }

        Item {
            id: closeButton
            width: 24
            height: 24
            x: 359
            y: 19
            property real hoverAmount: closeMouse.containsMouse ? 1.0 : 0.0

            Image {
                source: "assets/rendered/close_44.png"
                width: 11
                height: 11
                x: 6.5
                y: 6.5
                smooth: true
                antialiasing: true
                fillMode: Image.PreserveAspectFit
            }

            Image {
                source: "assets/rendered/close_red_44.png"
                width: 11
                height: 11
                x: 6.5
                y: 6.5
                opacity: closeButton.hoverAmount
                smooth: true
                antialiasing: true
                fillMode: Image.PreserveAspectFit
            }

            Behavior on hoverAmount {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    panel.commitAllEditorsIfNeeded()
                    Qt.quit()
                }
            }
        }
    }

    Window {
        id: pedalOverlayWindow

        property real overlayScale: 1.0
        property bool overlayPositionInitialized: false
        property bool overlayControlsVisible: false
        readonly property int baseWidth: 215

        onOverlayScaleChanged: saveUserConfig()
        onXChanged: saveUserConfig()
        onYChanged: saveUserConfig()
        readonly property int baseHeight: 209

        function clamp(v, lo, hi) {
            return Math.max(lo, Math.min(hi, v))
        }

        function setDefaultPosition() {
            x = Math.min(
                root.x + root.width + 20,
                Screen.desktopAvailableWidth - width - 20
            )
            y = Math.max(
                20,
                Math.min(
                    root.y + Math.round((root.height - height) / 2),
                    Screen.desktopAvailableHeight - height - 20
                )
            )
            overlayPositionInitialized = true
            saveUserConfig()
        }

        width: Math.round(baseWidth * overlayScale)
        height: Math.round(baseHeight * overlayScale)
        visible: typeof pedalOverlayToggle !== "undefined" && pedalOverlayToggle.checked
        color: "transparent"
        title: "Forzassist Pedal Overlay"

        flags: Qt.FramelessWindowHint
               | Qt.WindowStaysOnTopHint
               | Qt.Tool

        onVisibleChanged: {
            if (visible && !overlayPositionInitialized)
                setDefaultPosition()

            if (!visible)
                overlayControlsVisible = false
        }

        Item {
            id: pedalOverlayRoot
            anchors.fill: parent

            MouseArea {
                id: overlayHoverWatcher
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                z: 0
                onEntered: pedalOverlayWindow.overlayControlsVisible = true
                onExited: {
                    if (!resizeHandleMouse.containsMouse && !overlayResizeMouse.pressed)
                        pedalOverlayWindow.overlayControlsVisible = false
                }
            }

            Rectangle {
                id: overlayHoverBackdrop
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.14)
                border.width: Math.max(1, Math.round(1 * pedalOverlayWindow.overlayScale))
                border.color: Qt.rgba(1, 1, 1, 0.22)
                opacity: pedalOverlayWindow.overlayControlsVisible ? 1.0 : 0.0
                visible: opacity > 0.01
                z: 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: overlayDragArea
                anchors.fill: parent
                z: 2
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.SizeAllCursor

                onPressed: function(mouse) {
                    if (resizeHandleMouse.containsMouse)
                        return

                    pedalOverlayWindow.overlayControlsVisible = true
                    pedalOverlayWindow.startSystemMove()
                    mouse.accepted = true
                }
            }

            Item {
                id: pedalOverlayContent
                width: pedalOverlayWindow.baseWidth
                height: pedalOverlayWindow.baseHeight
                scale: pedalOverlayWindow.overlayScale
                transformOrigin: Item.TopLeft
                z: 3

                property real clutchValue: 0.0
                property real footbrakeValue: 0.0
                property real throttleValue: 0.0
                property real handbrakeValue: 0.0
                property real playerSteer: 0.0
                property real assistSteer: 0.0

                Rectangle {
                    id: steeringTrack
                    x: 0
                    y: 0
                    width: 215
                    height: 24
                    color: Qt.rgba(0, 0, 0, 0.25)

                    Rectangle {
                        id: assistSteerBar
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: Math.abs(pedalOverlayContent.assistSteer) * (parent.width / 2)
                        x: pedalOverlayContent.assistSteer >= 0
                           ? parent.width / 2
                           : parent.width / 2 - width
                        color: "#00C8FF"
                        opacity: Math.abs(pedalOverlayContent.assistSteer) > 0.01 ? 0.85 : 0.0
                    }

                    Rectangle {
                        id: playerSteerMarker
                        width: 7
                        height: 24
                        y: 0
                        x: Math.max(0, Math.min(parent.width - width,
                            (parent.width - width) / 2
                            + pedalOverlayContent.playerSteer * ((parent.width - width) / 2)))
                        color: "#FFFFFF"
                    }
                }

                component PedalBar: Item {
                    id: pedal
                    property real value: 0.0
                    property color fillColor: "#FFFFFF"

                    width: 35
                    height: 167
                    z: 4

                    readonly property int capHeight: 8
                    readonly property real clampedValue: Math.max(0.0, Math.min(1.0, value))
                    readonly property real capY: (height - capHeight) * (1.0 - clampedValue)

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.25)
                    }

                    Rectangle {
                        x: 0
                        y: pedal.capY + pedal.capHeight
                        width: parent.width
                        height: parent.height - y
                        color: pedal.fillColor
                    }

                    Rectangle {
                        x: 0
                        y: pedal.capY
                        width: parent.width
                        height: pedal.capHeight
                        color: "#FFFFFF"
                    }

                }

                PedalBar {
                    id: clutchBar
                    x: 0
                    y: 42
                    value: pedalOverlayContent.clutchValue
                    fillColor: "#D8D8D8"
                    onValueChanged: pedalOverlayContent.clutchValue = value
                }

                PedalBar {
                    id: footbrakeBar
                    x: 60
                    y: 42
                    value: pedalOverlayContent.footbrakeValue
                    fillColor: "#FF0000"
                    onValueChanged: pedalOverlayContent.footbrakeValue = value
                }

                PedalBar {
                    id: throttleBar
                    x: 120
                    y: 42
                    value: pedalOverlayContent.throttleValue
                    fillColor: "#86FF68"
                    onValueChanged: pedalOverlayContent.throttleValue = value
                }

                PedalBar {
                    id: handbrakeBar
                    x: 180
                    y: 42
                    value: pedalOverlayContent.handbrakeValue
                    fillColor: "#FF6060"
                    onValueChanged: pedalOverlayContent.handbrakeValue = value
                }
            }

            Item {
                id: resizeHandleArea
                width: 24
                height: 24
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                z: 10

                Rectangle {
                    id: resizeHandleVisual
                    width: 18
                    height: 18
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.30)
                    opacity: pedalOverlayWindow.overlayControlsVisible ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        width: 9
                        height: 2
                        radius: 1
                        color: Qt.rgba(1, 1, 1, 0.65)
                        rotation: -45
                        x: 5
                        y: 11
                    }

                    Rectangle {
                        width: 6
                        height: 2
                        radius: 1
                        color: Qt.rgba(1, 1, 1, 0.65)
                        rotation: -45
                        x: 9
                        y: 7
                    }
                }

                MouseArea {
                    id: resizeHandleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    cursorShape: Qt.SizeFDiagCursor
                    onEntered: pedalOverlayWindow.overlayControlsVisible = true
                    onExited: {
                        if (!overlayResizeMouse.pressed && !overlayHoverWatcher.containsMouse)
                            pedalOverlayWindow.overlayControlsVisible = false
                    }
                }

                MouseArea {
                    id: overlayResizeMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.SizeFDiagCursor

                    property real startScale: 1.0
                    property real startMouseX: 0.0
                    property real startMouseY: 0.0

                    onPressed: function(mouse) {
                        pedalOverlayWindow.overlayControlsVisible = true
                        startScale = pedalOverlayWindow.overlayScale
                        startMouseX = mouse.x
                        startMouseY = mouse.y
                        mouse.accepted = true
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            var delta = Math.max(mouse.x - startMouseX, mouse.y - startMouseY)
                            pedalOverlayWindow.overlayScale = pedalOverlayWindow.clamp(
                                startScale + delta / pedalOverlayWindow.baseWidth,
                                0.35,
                                2.00
                            )
                            mouse.accepted = true
                        }
                    }

                    onReleased: function(mouse) {
                        if (!overlayHoverWatcher.containsMouse && !resizeHandleMouse.containsMouse)
                            pedalOverlayWindow.overlayControlsVisible = false
                        mouse.accepted = true
                    }
                }
            }
        }
    }

}
