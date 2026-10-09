import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

ShellButton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink && sink.ready ? sink.audio : null
    text: audio ? (audio.muted ? "Muted" : Math.round(audio.volume * 100) + "%") : "Audio —"
    numeric: audio !== null && !audio.muted
    marked: audio !== null && audio.muted
    markColor: Theme.warning
    helpText: "Audio · click to mute · scroll to adjust · right-click for mixer"
    Accessible.name: audio ? "Output audio " + (audio.muted ? "muted" : text) : "Audio unavailable"

    PwObjectTracker { objects: [root.sink] }

    function adjust(delta) {
        if (audio)
            audio.volume = Math.max(0, Math.min(1, audio.volume + delta));
    }

    onClicked: {
        if (audio)
            audio.muted = !audio.muted;
    }
    onContextRequested: Quickshell.execDetached([Theme.audioMixer])
    onSecondaryClicked: Quickshell.execDetached([Theme.audioMixer])
    onScrolled: (delta, horizontal) => {
        if (!horizontal)
            adjust(delta / 120 * 0.05);
    }
    Keys.onUpPressed: adjust(0.05)
    Keys.onDownPressed: adjust(-0.05)
}
