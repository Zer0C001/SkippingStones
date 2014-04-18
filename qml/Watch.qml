/*
 * Copyright 2014 Ruediger Gad
 *
 * This file is part of SkippingStones.
 *
 * SkippingStones is largely based on libpebble by Liam McLoughlin
 * https://github.com/Hexxeh/libpebble
 *
 * SkippingStones is published under the same license as libpebble (as of 10-02-2014):
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 */

import QtQuick 2.0
import harbour.skippingstones 1.0

Item {
    id: watch

    property bool uploadInProgress: putBytes.state !== "NotStarted"

    signal appBankListReceived(variant appBankList)
    signal installedAppsListReceived(variant InstalledAppsList)
    signal musicControlReply(int code)
    signal textReply(string text)

    state: "NotConnected"

    states: [
        State {
            name: "Connected"
        },
        State {
            name: "Connecting"
        },
        State {
            name: "NotConnected"
        }
    ]

    function addApp(targetIndex) {
        console.log("Adding app at target index: " + targetIndex)

        var msg = Qt.createQmlObject('import harbour.skippingstones 1.0; BtMessage {}', parent);
        msg.appendInt16(5)
        msg.appendInt16(BtMessage.AppManager)
        msg.appendInt8(3)
        msg.appendInt32(targetIndex)

        btConnectorSerialPort.sendMsg(msg)
    }

    function connect(address) {
        watch.state = "Connecting"
        btConnectorSerialPort.connect(address, 1)
        btConnectorAVRemoteControl.connect(address, 23)
    }

    function disconnect() {
        btConnectorSerialPort.disconnect()
        btConnectorAVRemoteControl.disconnect()
    }

    function getAppBankStatus() {
        sendInt8(1, BtMessage.AppManager)
    }

    function incomingCall(number, name) {
        var msg = Qt.createQmlObject('import harbour.skippingstones 1.0; BtMessage {}', parent);
        msg.appendInt16(number.length + name.length + 7)
        msg.appendInt16(BtMessage.PhoneControl)
        msg.appendInt8(BtMessage.IncomingCall)
        msg.appendInt32(0)
        msg.appendInt8(number.length)
        msg.appendString(number)
        msg.appendInt8(name.length)
        msg.appendString(name)
        btConnectorSerialPort.sendMsg(msg)
    }

    function listAppsByUuid() {
        sendInt8(5, BtMessage.AppManager)
    }

    function musicNowPlaying(track, album, artist) {
        var data = [track.substring(0, 30), album.substring(0, 30), artist.substring(0, 30)]
        sendTextArray(data, BtMessage.MusicControl, BtMessage.NowPlayingData)
    }

    function notificationEmail(sender, subject, body) {
        var data = [sender, body, "" + new Date().getTime(), subject]
        sendTextArray(data, BtMessage.Notification, BtMessage.Email)
    }

    function notificationSms(sender, body) {
        var data = [sender, body, "" + new Date().getTime()]
        sendTextArray(data, BtMessage.Notification, BtMessage.SMS)
    }

    function removeApp(appId, index) {
        console.log("removeApp(appId=" + appId + ", index=" + index)
        var msg = Qt.createQmlObject('import harbour.skippingstones 1.0; BtMessage {}', parent);
        msg.appendInt16(9)
        msg.appendInt16(BtMessage.AppManager)
        msg.appendInt8(2)
        msg.appendInt32(appId)
        msg.appendInt32(index)
        btConnectorSerialPort.sendMsg(msg)
    }

    function uploadFile(targetIndex, transferType, fileName) {
        var data = fileSystemHelper.readHex(fileName)
        putBytes.uploadData(targetIndex, transferType, data)
    }

    function sendHex(hexCommand) {
        btConnectorSerialPort.sendHex(hexCommand)
    }

    function sendInt8(data, endpoint) {
        console.log("Sending int8: " + data + " Endpoint:" + endpoint)
        var msg = Qt.createQmlObject('import harbour.skippingstones 1.0; BtMessage {}', parent);

        msg.appendInt16(1)
        msg.appendInt16(endpoint)
        msg.appendInt8(data)

        btConnectorSerialPort.sendMsg(msg)
    }

    function sendTextArray(data, endpoint, prefix) {
        console.log("Sending data: " + data + " Endpoint:" + endpoint + " Prefix:" + prefix)
        var msg = Qt.createQmlObject('import harbour.skippingstones 1.0; BtMessage {}', parent);

        msg.appendInt16(endpoint)
        if (prefix !== BtMessage.InvalidPrefix) {
            msg.appendInt8(prefix)
        }

        for (var i = 0; i < data.length; ++i) {
            var d = data[i]
            var len = msg.stringLength(d)
            console.log("Adding text \"" + d + "\" with length " + len + ".")
            msg.appendInt8(len)
            msg.appendString(d)
        }
        msg.prependInt16(msg.size() - 2)

        btConnectorSerialPort.sendMsg(msg)
    }

    function sendTextString(message, endpoint, prefix) {
        console.log("Sending message: " + message + " Endpoint:" + endpoint + " Prefix:" + prefix)
        sendTextArray(message.split("|"), endpoint, prefix)
    }

    function _processAppsInstalledMask(appsInstalledMask) {
        console.log("_processAppsInstalledMask")

        appBankListModel.clear()
        for (var i = 0; i < 8; i++) {
            if ((appsInstalledMask & (1 << i)) != 0) {
                console.log("App installed on bank: " + i)
                appBankListModel.append({bank: i, free: false})
            } else {
                console.log("Bank is free: " + i)
                appBankListModel.append({bank: i, free: true})
            }
        }
        appBankListReceived(appBankListModel)
    }

    function _processInstalledAppsMessage(message) {
        console.log("_processInstalledAppsMessage")
        var appsInstalled = message.readInt32(5)
        var offset = 9
        var uuidSize = 16
        for (var i = 0; i < appsInstalled; i++) {
            var uuid = message.readHexString(((uuidSize * i) + offset), uuidSize)
            console.log("Got uuid: " + uuid)
        }
    }

    function _sendPhoneVersionResponse() {
        console.log("Sending phone version response.")

        var msg = Qt.createQmlObject('import harbour.skippingstones 1.0; BtMessage {}', parent);
        msg.appendInt16(13)
        msg.appendInt16(BtMessage.PhoneVersion)
        msg.appendInt8(1)
        msg.appendInt32(0xffffffff)
        msg.appendInt32(BtMessage.GammaRay)
        msg.appendInt32(BtMessage.Telephony | BtMessage.CapSMS | BtMessage.Android)
        btConnectorSerialPort.sendMsg(msg)
    }

    BtConnector {
        id: btConnectorSerialPort

        onConnected: {
            console.log("BtConnectorSerialPort connected.")
            watch.state = "Connected"
        }

        onDisconnected: {
            console.log("BtConnectorSerialPort disconnected.")
            watch.state = "NotConnected"
        }

        onError: {
            console.log("BtConnectorSerialPort error: " + errorCode)
            watch.state = "NotConnected"
        }

        onMessageReceived: {
            console.log("Received message: " + message.toHexString())

            var appsInstalled = ""

            switch (message.endpoint()) {
            case BtMessage.MusicControl:
                console.log("Received music control message.")
                musicControlReply(message.readInt8(4))
                break
            case BtMessage.PhoneVersion:
                console.log("Received phone version message.")
                _sendPhoneVersionResponse()
                break
            case BtMessage.Time:
                console.log("Received a time message.")
                var date = new Date(message.readInt32(5) * 1000)
                console.log("Got date: " + date)
                watch.textReply("" + date)
                break
            case BtMessage.AppManager:
                console.log("Received an AppManager message.")
                var prefix = message.readInt8(4)
                console.log("Got prefix: " + prefix)

                switch(prefix) {
                case 1:
                    console.log("Got app bank status.")
                    var appBanks = message.readInt32(5)
                    appsInstalled = message.readInt32(9)
                    console.log("AppBanks: " + appBanks + "; AppsInstalled: " + appsInstalled)
                    _processAppsInstalledMask(appsInstalled)
                    break
                case 2:
                    console.log("Got app install message: " + message.readInt32(5))
                    break
                case 5:
                    console.log("Got apps installed status.")
                    appsInstalled = message.readInt32(5)
                    console.log("AppsInstalled: " + appsInstalled)
                    _processAppsInstalledMask(appsInstalled)
                    _processInstalledAppsMessage(message)
                    break
                default:
                    console.log("Unknown prefix: " + prefix)
                }
                break
            case BtMessage.PutBytes:
                putBytes.messageReceived(message)
                break
            case BtMessage.Logs:
                console.log("Log message received.")
                var ts = new Date(message.readInt32(4) * 1000)
                console.log("Timestamp: " + ts)
                var logLevel = message.readInt8(8)
                console.log("Log level: " + logLevel)
                var length = message.readInt8(9)
                console.log("Length: " + length)
                var line = message.readInt16(10)
                console.log("Line: " + line)
                var fileName = message.readString(12, 16)
                console.log("File name: " + fileName)
                var logMessage = message.readString(28, length)
                console.log("Log message: " + logMessage)

                if (fileName === "put_bytes.c" && logMessage === "PutBytes command 0x5 not permitted in current state 0x2") {
                    console.log("Using hack for incorrectly reported commit/complete error.")
                    putBytesHackTimer.start()
                }

                break
            default:
                console.log("Unknown endpoint: " + message.endpoint())
                watch.textReply(message.toHexString())
            }
        }

        function sendMsg(msg) {
            if (watch.state === "Connected") {
                send(msg)
            } else {
                console.log("Not sending data because watch is not connected.")
            }
        }
    }

    BtConnector {
        id: btConnectorAVRemoteControl

        onConnected: {
            console.log("BtConnectorAVRemoteControl connected.")
        }

        onDisconnected: {
            console.log("BtConnectorAVRemoteControl disconnected.")
        }

        onError: {
            console.log("BtConnectorAVRemoteControl error: " + errorCode)
        }
    }

    FileSystemHelper {
        id: fileSystemHelper
    }

    ListModel {
        id: appBankListModel
    }

    ListModel {
        id: installedAppsListModel
    }

    PutBytes {
        id: putBytes
    }

    Timer {
        id: putBytesHackTimer

        interval: 20000
        repeat: false

        onTriggered: putBytes._notifySuccess()
    }
}
