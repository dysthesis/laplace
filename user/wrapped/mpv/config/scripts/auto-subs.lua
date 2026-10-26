local mp = require("mp")
local options = { enabled = true, language = "auto" }
require("mp.options").read_options(options, "auto-subs")

-- FFmpeg owns chunking, inference and timestamps. The child mpv reuses the
-- resolved input (including yt-dlp EDLs), without touching playback's audio.
local job, loaded, blocked, duration

local function tracks()
    local audio, generated
    local provided = false
    for _, track in ipairs(mp.get_property_native("track-list", {})) do
        if track.type == "sub" then
            if job and track["external-filename"] == job.subs then
                generated = track
            else
                provided = true
            end
        elseif track.type == "audio" and track.selected then
            audio = track
        end
    end
    return provided, audio, generated
end

local function stop()
    if not job then return end
    local _, _, generated = tracks()
    local old = job
    job = nil -- Ignore callbacks from an aborted/previous file's subprocess.
    old.timer:kill()
    if old.process then mp.abort_async_command(old.process) end
    if generated then mp.commandv("sub-remove", generated.id) end
    os.remove(old.raw)
    os.remove(old.subs)
    os.remove(old.dir)
end

local function refresh(current)
    if job ~= current then return end
    local file = io.open(current.raw, "rb")
    if not file then return end
    local size = file:seek("end")
    if size == current.size then file:close(); return end
    file:seek("set")
    local data = file:read("*a")
    file:close()
    current.size = size
    -- Never expose a partially written SRT cue to mpv's subtitle demuxer.
    local complete = data:match("^(.*\n\n)")
    if not complete or #complete == current.published then return end
    local output, err = io.open(current.subs, "wb")
    if not output then
        mp.msg.error("Cannot write Whisper subtitles: " .. err)
        stop()
        return
    end
    local ok, write_error = output:write(complete)
    output:close()
    if not ok then
        mp.msg.error("Cannot write Whisper subtitles: " .. write_error)
        stop()
        return
    end
    current.published = #complete
    local provided, _, generated = tracks()
    if provided then blocked = true; stop(); return end
    if generated then
        -- These commands default to async. Wait before restoring selection.
        local sid = mp.get_property_native("sid")
        local secondary = mp.get_property_native("secondary-sid")
        mp.commandv("sync", "sub-reload", generated.id)
        -- Reload changes the selected track but can leave options/sid at "no".
        -- Force an option change so restoring "no" actually deselects it.
        mp.set_property_number("sid", generated.id)
        mp.set_property_native("sid", sid)
        mp.set_property_native("secondary-sid", false)
        mp.set_property_native("secondary-sid", secondary)
    else
        mp.commandv("sync", "sub-add", current.subs, "select", "Whisper (generated)")
    end
end

local function start()
    if not loaded or blocked or not options.enabled then return end
    local provided, audio = tracks()
    if provided then blocked = true; stop(); return end
    stop()
    if not audio then return end

    local source = audio["external-filename"] or mp.get_property("stream-open-filename")
    -- Reopening stdin/live input cannot preserve the player's timeline. Do not
    -- display plausible-looking but incorrectly synchronized subtitles for it.
    if not source or source == "-" or source:match("^fdclose://") or source:match("^fd://")
        or not duration or duration <= 0
        or not mp.get_property_native("seekable")
        or mp.get_property_native("partially-seekable") then
        mp.msg.warn("Whisper needs a replayable, seekable input with a known duration")
        blocked = true
        return
    end
    if not options.language:match("^[a-z]+$") then
        mp.msg.error("auto-subs-language must be a Whisper language code or auto")
        blocked = true
        return
    end

    local temp = mp.command_native({
        name = "subprocess", args = { "@mktemp@", "-d", "/tmp/mpv-whisper.XXXXXXXXXX" },
        capture_stdout = true,
    })
    if temp.status ~= 0 then mp.msg.error("Cannot create Whisper temporary directory"); return end
    local dir = temp.stdout:gsub("\n$", "")
    local current = { dir = dir, raw = dir .. "/output.srt", subs = dir .. "/Whisper (generated).srt", aid = audio.id }
    job = current
    current.timer = mp.add_periodic_timer(0.25, function() refresh(current) end)

    local aid = audio.id
    if audio.external then
        -- External audio IDs in the parent include the main file's tracks.
        aid = 0
        for _, track in ipairs(mp.get_property_native("track-list", {})) do
            if track.type == "audio" and track["external-filename"] == source then aid = aid + 1 end
            if track.type == "audio" and track.id == audio.id then break end
        end
    end
    -- Whisper imitates transcript context rather than obeying instructions.
    -- Bias English spelling without forcing English recognition or translation.
    local prompt = ""
    if options.language == "auto" or options.language == "en" then
        prompt = ":prompt=My favourite colour is grey. The neighbours organised a programme at the theatre."
            .. " We travelled to the town centre and enjoyed the flavour."
    end
    local args = {
        "@transcriber@", "--no-config", "--load-scripts=no", "--ytdl=no",
        "--vid=no", "--sid=no", "--sub-auto=no", "--audio-file-auto=no",
        "--ao=null", "--ao-null-untimed", "--input-terminal=no", "--resume-playback=no",
        "--msg-level=all=warn", "--aid=" .. aid,
        "--start=" .. math.max(0, (mp.get_property_number("time-pos") or 0) - 1),
        "--af=lavfi=[whisper=model=@model@:language=" .. options.language
            .. prompt .. ":queue=5:use_gpu=false:destination=" .. current.raw .. ":format=srt]:o=[threads=4]",
    }
    -- Preserve authentication and demuxer settings for the already resolved URL.
    for _, name in ipairs({ "user-agent", "referrer", "http-proxy", "cookies", "cookies-file",
        "tls-verify", "tls-ca-file", "demuxer-lavf-o", "rebase-start-time" }) do
        local value = mp.get_property(name)
        if value and value ~= "" then args[#args + 1] = "--" .. name .. "=" .. value end
    end
    for _, header in ipairs(mp.get_property_native("http-header-fields", {})) do
        args[#args + 1] = "--http-header-fields-append=" .. header
    end
    args[#args + 1] = "--"
    args[#args + 1] = source
    mp.msg.info("Generating subtitles with Whisper (CPU)")
    current.process = mp.command_native_async({
        name = "subprocess", args = args, playback_only = true,
        capture_stdout = true, capture_stderr = true,
    }, function(success, result, err)
        if job ~= current then return end
        current.process = nil
        refresh(current)
        current.timer:kill()
        if not success or result.status ~= 0 then
            mp.msg.error("Whisper transcription failed: " .. (err or "")
                .. (result and ((result.stderr or "") .. (result.stdout or "")) or ""))
        end
    end)
end

-- Debounce seek/track events; never restart just because sub-reload changed sid.
local restart = mp.add_timeout(0.2, start)
restart:kill()
local function schedule()
    restart:kill()
    if loaded and not blocked and options.enabled then restart:resume() end
end

-- After decoding starts, mpv estimates even live-stream durations from cached
-- packets. Only trust the duration present before playback starts.
mp.add_hook("on_preloaded", 50, function()
    duration = mp.get_property_number("duration")
end)

mp.register_event("file-loaded", function()
    loaded = true
    blocked = tracks() -- Any supplied track blocks the entire file, even sid=no.
    schedule()
end)
mp.observe_property("track-list", "native", function()
    if not loaded then return end
    local provided, audio = tracks()
    if provided then
        blocked = true
        restart:kill()
        stop()
    elseif job and (not audio or audio.id ~= job.aid) then
        stop()
        schedule()
    end
end)
mp.observe_property("aid", "native", function() if loaded then schedule() end end)
mp.register_event("seek", function()
    stop()
    schedule()
end)
local function unload()
    loaded = false
    duration = nil
    restart:kill()
    stop()
end
mp.register_event("start-file", unload)
mp.register_event("end-file", unload)
mp.register_event("shutdown", unload)
