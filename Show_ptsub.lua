
------ Mpv Show Subs Local Subs v. 0.01
------ cassio018@hotmail.com 
------ I just copied and pasted code and create this script :)
-----  to do
------ ( ) show local and target subs in the same time.
------ ( ) show subs in a box, is possible ?
------ ( )  Anki integratioons:
-------------( ) export notes with local and target subs.



------ How to use:
------ Copy this script for Mpv Script folder 
------ Set .srt subs in the local language
SRT_FILE_EXTENSIONS = {".pt-BR.srt"}
------ Press Ctrl+S 







 
---------------------------------------------------------------


utils = require 'mp.utils'



function srt_time_to_seconds(time)
    major, minor = time:match("(%d%d:%d%d:%d%d),(%d%d%d)")
    hours, mins, secs = major:match("(%d%d):(%d%d):(%d%d)")
    return hours * 3600 + mins * 60 + secs + minor / 1000
end

function seconds_to_time(time, delimiter)
    hours = math.floor(time / 3600)
    mins = math.floor(time / 60) % 60
    secs = math.floor(time % 60)
    milliseconds = (time * 1000) % 1000

    return string.format("%02d:%02d:%02d%s%03d", hours, mins, secs, delimiter, milliseconds)
end

function seconds_to_ffmpeg_time(time)
    return seconds_to_time(time, '.')
end

function set_start_timestamp()
    start_timestamp = mp.get_property_number("time-pos") + AUDIO_CLIP_PADDING

    if end_timestamp == nil then
        local sub_start, sub_end = get_current_sub_timing()
        end_timestamp = sub_end + AUDIO_CLIP_PADDING
    end

    
end

function set_end_timestamp()
    end_timestamp = mp.get_property_number("time-pos") - AUDIO_CLIP_PADDING
    
    if start_timestamp == nil then
        local sub_start, sub_end = get_current_sub_timing()
        start_timestamp = sub_start - AUDIO_CLIP_PADDING
    end

    
end

function get_current_sub_timing()
    local time_pos = mp.get_property_number("time-pos")

    local sub_start, sub_end
    for i, sub_text in ipairs(sentences) do
        sub_start = sentences_start[i]
        sub_end = sentences_end[i]

        if sub_start <= time_pos and time_pos <= sub_end then
            break
        end

        if sentences_start[i] > time_pos then
            break
        end
    end

    return sub_start, sub_end
end

function set_start_end_timestamps()
    local time_pos = mp.get_property_number("time-pos")

    for i, sub_text in ipairs(sentences) do
        start_timestamp = sentences_start[i]
        end_timestamp = sentences_end[i]

        if i < #sentences and sentences_start[i+1] > time_pos then
            break
        end
    end

    mp.osd_message(string.format("%s - %s", seconds_to_ffmpeg_time(start_timestamp), seconds_to_ffmpeg_time(end_timestamp)))
end

function pause_player()
    mp.set_property("pause", "yes")
end



function on_playback_restart()
    if timer ~= nil then
        timer:kill()
    end

    if player_state == "replay from the end" then
        timer = mp.add_timeout(REPLAY_TIME + AUDIO_CLIP_PADDING, pause_player)
        player_state = nil
    elseif player_state == "replay from the start" then
        timer = mp.add_timeout(end_timestamp - start_timestamp + 2 * AUDIO_CLIP_PADDING, pause_player)
        player_state = nil
    end
end

function open_subtitles_file(srt_file_exts)
    local srt_filename = mp.get_property("working-directory") .. "/" .. mp.get_property("filename/no-ext")
    
    for i, ext in ipairs(srt_file_exts) do
        local f, err = io.open(srt_filename .. ext, "r")
        
        if f then
            return f
        end
    end

    return false
end

function read_subtitles(srt_file_exts)
    local f = open_subtitles_file(srt_file_exts)

    if not f then
        return false
    end

    local data = f:read("*all")
    data = string.gsub(data, "\r\n", "\n")
    f:close()
    
    subs = {}
    subs_start = {}
    subs_end = {}
    for start_time, end_time, text in string.gmatch(data, "(%d%d:%d%d:%d%d,%d%d%d) %-%-> (%d%d:%d%d:%d%d,%d%d%d)\n(.-)\n\n") do
      table.insert(subs, text)
      table.insert(subs_start, srt_time_to_seconds(start_time))
      table.insert(subs_end, srt_time_to_seconds(end_time))
    end

    return true
end

function convert_into_sentences()
    sentences = {}
    sentences_start = {}
    sentences_end = {}

    for i, sub_text in ipairs(subs) do
        sub_start = subs_start[i]
        sub_end = subs_end[i]
        sub_text = string.gsub(sub_text, "<[^>]+>", "")

        if sub_text:find("^- ") ~= nil and sub_text:sub(3,3) ~= sub_text:sub(3,3):upper() then
           sub_text = string.gsub(sub_text, "^- ", "")
        end

        if #sentences > 0 then
            prev_sub_start = sentences_start[#sentences]
            prev_sub_end = sentences_end[#sentences]
            prev_sub_text = sentences[#sentences]

            if JOIN_SUBTITLES_INTO_SENTENCES and (sub_start - prev_sub_end) <= 2 and sub_text:sub(1,1) ~= '-' and 
                    sub_text:sub(1,1) ~= '"' and sub_text:sub(1,1) ~= "'" and sub_text:sub(1,1) ~= '(' and
                    (prev_sub_text:sub(prev_sub_text:len()) ~= "." or prev_sub_text:sub(prev_sub_text:len()-2) == "...") and
                    prev_sub_text:sub(prev_sub_text:len()) ~= "?" and prev_sub_text:sub(prev_sub_text:len()) ~= "!" and
                    (sub_text:sub(1,1) == sub_text:sub(1,1):lower() or prev_sub_text:sub(prev_sub_text:len()) == ",") then
                local text = prev_sub_text .. " " .. sub_text
                text = string.gsub(text, "\n", "#")
                text = string.gsub(text, "%.%.%. %.%.%.", " ")
                text = string.gsub(text, "#%-", "\n-")
                text = string.gsub(text, "#", " ")
                if text:match("\n%-") ~= nil and text:match("^%-") == nil then
                    text = "- " .. text
                end
                
                sentences[#sentences] = text
                sentences_end[#sentences] = sub_end
            else
                table.insert(sentences, sub_text)
                table.insert(sentences_start, sub_start)
                table.insert(sentences_end, sub_end)    
            end
        else
            table.insert(sentences, sub_text)
            table.insert(sentences_start, sub_start)
            table.insert(sentences_end, sub_end)
        end
    end
end



function get_subtitles_fragment(subtitles, subtitles_start, subtitles_end)
    local time_pos = mp.get_property_number("time-pos")

    local subtitles_fragment = {}
    local subtitles_fragment_start_time = nil
    local subtitles_fragment_end_time = nil
    local subtitles_fragment_prev = " "
    local subtitles_fragment_next = " "

    if start_timestamp ~= nil then
        start_timestamp = start_timestamp - AUDIO_CLIP_PADDING
        end_timestamp = end_timestamp + AUDIO_CLIP_PADDING
    end

    for i, sub_text in ipairs(subtitles) do
        local sub_start = subtitles_start[i]
        local sub_end = subtitles_end[i]

        if (start_timestamp ~= nil and (start_timestamp <= sub_start and sub_end <= end_timestamp)) or
            (start_timestamp == nil and (sub_start <= time_pos and time_pos <= sub_end))
        then
            table.insert(subtitles_fragment, sub_text)

            if subtitles_fragment_start_time == nil then
                subtitles_fragment_start_time = sub_start
                
                if i ~= 1 then
                    subtitles_fragment_prev = subtitles[i-1]
                end
            end

            subtitles_fragment_end_time = sub_end

            if i ~= #subtitles then
                subtitles_fragment_next = subtitles[i+1]
            end
        end

        if end_timestamp ~= nil then
            if sub_start > end_timestamp then
                break
            end
        elseif sub_start > time_pos then
            break
        end
    end

    if start_timestamp ~= nil then
        start_timestamp = start_timestamp + AUDIO_CLIP_PADDING
        end_timestamp = end_timestamp - AUDIO_CLIP_PADDING
    end

    if start_timestamp ~= nil then
        subtitles_fragment_start_time = start_timestamp
        subtitles_fragment_end_time = end_timestamp
    end

    return table.concat(subtitles_fragment, "<br />"), subtitles_fragment_start_time, subtitles_fragment_end_time, subtitles_fragment_prev, subtitles_fragment_next
end

function show_subs()
    local subtitles_fragment, subtitles_fragment_start_time, subtitles_fragment_end_time, subtitles_fragment_prev, subtitles_fragment_next = get_subtitles_fragment(sentences, sentences_start, sentences_end)
    
    if subtitles_fragment == "" then
        mp.osd_message("no text")
        return
    end

    local video_filename = mp.get_property("filename/no-ext")
    



   
    
    local time = seconds_to_ffmpeg_time(subtitles_fragment_start_time)
    
    
    local target_line = subtitles_fragment
    local target_line_before = subtitles_fragment_prev
    local target_line_after = subtitles_fragment_next

  
    mp.osd_message(subtitles_fragment)
   










 


end

function init()
    ret = read_subtitles(SRT_FILE_EXTENSIONS)

    if ret == false or #subs == 0 then
        return
    end
    
    convert_into_sentences()

    mp.add_key_binding("ctrl+s", "show-subs", show_subs)
   
end

mp.register_event("file-loaded", init)
