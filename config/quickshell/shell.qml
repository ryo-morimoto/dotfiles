import Quickshell
import Quickshell.Io
import QtQuick
import "WallpaperPicker" as WallpaperPicker

ShellRoot {
    WallpaperPicker.Main {
        id: picker
    }

    IpcHandler {
        target: "wallpaper"

        function toggle() {
            picker.toggle()
        }

        function open() {
            picker.show()
        }

        function close() {
            picker.hide()
        }
    }
}
