{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mapAttrsToList;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (pkgs)
    anime4k
    writeText
    ;

  whisperPkg = pkgs.unstable.whisper-cpp-vulkan;

  whisperSubs =
    let
      modelType = "large-v3-turbo";
      model = pkgs.stdenv.mkDerivation {
        name = "whisper-ggml-${modelType}";

        src = pkgs.fetchurl {
          url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${modelType}.bin";
          sha256 = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
        };

        dontUnpack = true;

        installPhase = ''
          dest=$out/
          mkdir -p $dest
          cp $src $dest/ggml-${modelType}.bin
        '';

        passthru.modelPath = "${placeholder "out"}/ggml-${modelType}.bin";
      };
      script =
        writeText "whispersubs"
          # lua
          ''
            -- This is the main variable you will want to modify
            -- Set things like the model location and language, just avoid setting any input or output options
            local WHISPER_CMD = "${
              lib.getExe (
                pkgs.openai-whisper.override {
                  triton = null;
                }
              )
            } --model tiny --language English --device cuda --verbose False"

            -- Additional variables
            local CHUNK_SIZE = 15 * 1000 		 -- the amount of subs to process at a time in ms
            local WAV_CHUNK_SIZE = CHUNK_SIZE + 1000 -- pad the wav time
            local START_AT_ZERO = true		 -- start creating subs from 00:00:00 rather than the current time position (local files only)
            local SAVE_SRT = true			 -- save srt file when finished processing (local files only)
            local SHOW_PROGRESS = false		 -- visual aid to see where it's still processing subtitles

            -- These are just some temp files in order to process the subs
            -- pid must be used in case multiple instances of the script are running at once
            local pid = mp.get_property_native('pid')
            local TMP_WAV_PATH = "/tmp/mpv_whisper_tmp_wav_"..pid..".wav"
            local TMP_SUB_PATH = "/tmp/mpv_whisper_tmp_sub_"..pid -- without file ext "srt"
            local TMP_CACHE_PATH = "/tmp/mpv_whisper_tmp_cache_"..pid..".mkv"

            local running = false
            local chunk_dur

            local function formatProgress(ms)
            	local seconds = math.floor(ms / 1000)
            	local minutes = math.floor(seconds / 60)
            	local hours = math.floor(minutes / 60)

            	local seconds = seconds % 60 local minutes = minutes % 60
            	local hours = hours % 24

            	return string.format("%02d:%02d:%02d.%03d", hours, minutes, seconds, ms % 1000)
            end

            local function cleanup()
            	os.execute('rm '..TMP_WAV_PATH, 'r')
            	os.execute('rm '..TMP_SUB_PATH..'*', 'r')
            	os.execute('rm '..TMP_CACHE_PATH..'*', 'r')
            end

            local function stop()
            	running = false
            	mp.unregister_event(stop)
            	cleanup()
            end

            local function saveSubs(media_path)
            	local sub_path = media_path:match("(.+)%..+$") -- remove file ext from media
            	sub_path = sub_path..'.srt'..'"' -- add the file ext back with the "

            	mp.commandv('show-text', 'Whisper: Subtitles finished processing, saving to'..sub_path, 5000)

            	os.execute('cp '..TMP_SUB_PATH..'.srt '..sub_path, 'r')
            end


            local function appendSubs(current_pos)
              local base = TMP_WAV_PATH:gsub("%.wav$", "")  -- /tmp/mpv_whisper_tmp_wav_71288
              os.execute( WHISPER_CMD .. " --output_format srt --output_dir /tmp " .. TMP_WAV_PATH .. " && mv " .. base .. ".srt " .. TMP_SUB_PATH .. "_append.srt")
            	-- offset srt timings to current_pos
            	os.execute('ffmpeg -hide_banner -loglevel error -itsoffset '..current_pos..'ms -i '..TMP_SUB_PATH..'_append.srt'..' -c copy -y '..TMP_SUB_PATH..'_append_offset.srt', 'r')

            	-- Append subs manually because whisper won't
            	os.execute('cat '..TMP_SUB_PATH..'_append_offset.srt'..' >> '..TMP_SUB_PATH..'.srt', 'r')

            	if SHOW_PROGRESS then
            		mp.commandv('show-text','Whisper: '..formatProgress(current_pos + chunk_dur))
            	end

            	mp.command('sub-reload')

            	return current_pos + chunk_dur
            end

            local function createSubs(current_pos)
            	mp.commandv('show-text','Whisper: Generating initial subtitles')

            	current_pos = appendSubs(current_pos)

            	mp.commandv('sub-add', TMP_SUB_PATH..'.srt')

            	return current_pos
            end

            local function createWAV(media_path, current_pos)
            	local handle = io.popen('ffmpeg -hide_banner -loglevel error -ss '..current_pos..'ms -t '..WAV_CHUNK_SIZE..'ms '..'-i '..media_path..' -ar 16000 -ac 1 -c:a pcm_s16le -y '..TMP_WAV_PATH..' 2>&1', 'r')

            	if handle then
            		local output = handle:read('*all')
            		print(output)
            		handle:close()

            		if output:find 'No such file' then
            			return false
            		elseif output:find 'Invalid' then
            			return false
            		end

            		return true
            	else
            		return false
            	end
            end

            local function runCache(current_pos)
            	if running then
            		local cache_end = mp.get_property_native('demuxer-cache-time')
            		if cache_end == nil then
            			mp.add_timeout(0.1, function() runCache(current_pos) end)
            			return
            		else
            			cache_end = cache_end * 1000
            		end

            		if (current_pos + chunk_dur) > cache_end then
            			mp.add_timeout(0.1, function() runCache(current_pos) end)
            			return
            		end

            		local new_pos = mp.get_property_native('time-pos/full')
            		if new_pos == nil then
            			mp.add_timeout(0.1, function() runCache(current_pos) end)
            			return
            		else
            			new_pos = new_pos * 1000
            		end

            		if new_pos > (current_pos + chunk_dur) then
            			current_pos = new_pos - (new_pos % chunk_dur)
            			mp.commandv('show-text','Whisper: User skipped ahead, generating new subtitles starting at '..formatProgress(current_pos), 3000)
            		end

            		mp.commandv("dump-cache", current_pos / 1000, (current_pos + chunk_dur) / 1000, TMP_CACHE_PATH)

            		if (createWAV(TMP_CACHE_PATH, 0)) then
            			current_pos = appendSubs(current_pos)
            		end

            		-- Callback
            		mp.add_timeout(0.1, function() runCache(current_pos) end)
            	end
            end

            local function runLocal(media_path, file_length, current_pos)
            	if running then
            		-- Towards the end of the file lets just process the time left if smaller than CHUNK_SIZE
            		local time_left = file_length - current_pos
            		if (time_left < CHUNK_SIZE) then
            			chunk_dur = time_left
            		end

            		if (time_left > 0) then
            			if (createWAV(media_path..'*', current_pos)) then
            				current_pos = appendSubs(current_pos)
            			end

            			-- Callback
            			mp.add_timeout(0.1, function() runLocal(media_path, file_length, current_pos) end)
            		else
            			if SAVE_SRT then
            				saveSubs(media_path)
            			else
            				mp.commandv('show-text', 'Whisper: Subtitles finished processing', 3000)
            			end

            			stop()
            		end
            	end
            end

            local function start()
            	-- init vars
            	local current_pos = mp.get_property_native('time-pos/full') * 1000
            	chunk_dur = CHUNK_SIZE

            	-- use dump-cache for network streams and stdin
            	if mp.get_property('demuxer-via-network') == 'yes' or mp.get_property('filename') == '-' then
            		mp.set_property_bool("cache", true)
            		mp.commandv("dump-cache", current_pos / 1000, (current_pos + chunk_dur) / 1000, TMP_CACHE_PATH)
            		createWAV(TMP_CACHE_PATH, 0)
            		current_pos = createSubs(current_pos)
            		mp.add_timeout(0.1, function() runCache(current_pos) end)
            	else
            		local file_length = mp.get_property_number('duration/full') * 1000
            		local media_path = mp.get_property('path')
            		media_path = '"'..media_path..'"' -- fix spaces

            		-- only local files can start subtitling from 00:00:00
            		if START_AT_ZERO then
            			current_pos = 0
            		end

            		createWAV(media_path, current_pos)
            		current_pos = createSubs(current_pos)
            		mp.add_timeout(0.1, function() runLocal(media_path, file_length, current_pos) end)
            	end
            end

            local function toggle()
            	if running then
            		mp.commandv('show-text', 'Whisper: Off')
            		stop()
            	else
            		running = true
            		mp.commandv('show-text', 'Whisper: On')
            		mp.register_event('end-file', stop)
            		start()
            	end
            end
            mp.register_event("file-loaded", toggle)
            mp.add_key_binding('ctrl+.', 'whisper_subs', toggle)
          '';
    in
    pkgs.mpvScripts.buildLua (finalAttrs: {
      pname = "whisper-subs";
      version = "721f97adb70a04bb62fd6c134b3b0b6441e6cf75";

      src = pkgs.runCommandLocal "whisper-subs-src" { } ''
        mkdir -p $out
        cp ${script} $out/whispersubs.lua
      '';

      scriptPath = "whispersubs.lua";

      extraWrapperArgs = [
        "--set"
        "PATH"
        "${lib.makeBinPath [
          pkgs.ffmpeg
          pkgs.yt-dlp
          pkgs.unstable.uutils-coreutils-noprefix
        ]}"
      ];
    });

  low1k = import ./low1k.nix { inherit anime4k; };
  low1kParsed =
    low1k |> mapAttrsToList (k: v: "${k} ${v}") |> concatStringsSep "\n" |> writeText "inputs.conf";

  mpv = pkgs.mpv.override {
    scripts = builtins.attrValues {
      inherit (pkgs.mpvScripts)
        sponsorblock
        thumbfast
        mpv-webm
        uosc
        ;
      # inherit whisperSubs;
    };
  };
  config = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "mpv-config";
    version = "0.0.1";

    src = ./config;
    buildPhase =
      # sh
      ''
        mkdir -p $out/
        cp -r $src/* $out/
        cp ${low1kParsed} $out/input.conf
      '';
  });
in
mkWrapper pkgs mpv ''
  wrapProgram $out/bin/mpv \
   --add-flags '--config-dir=${config}' \
   --add-flags '--hwdec=vaapi-copy' \
   --prefix PATH ":" ${
     lib.makeBinPath [
       pkgs.ffmpeg
       pkgs.yt-dlp
     ]
   }
''
