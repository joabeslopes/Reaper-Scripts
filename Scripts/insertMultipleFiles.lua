--[[
# DESCRIPTION

Add multiple instruments from multiple musics on multiple tracks at once.

It will read all the folders inside the project folder, all the files inside then, and add the correct audio files into the correct tracks, based on the name of the file, the name of the track folder, and the search table.

The audio file name will be compared with the elements of the "searchTable", using regex pattern, so if something match, the audio will be added.

The searchTable is a matrix of arrays. 
Each array has the following elements: {"pattern of the name", trackFolderNumber}

* The first element (string) is required; 
* The second element (number) is optional in case you don't have a track base (with UPPERCASE name) that matches the pattern;


For example, you want to add all the guitar files (from all folders inside the project folder) on the project:
* add inside the searchTable: ..., {"guitar"}, ...
* add the following tracks on the project:

GUITARS
guitar base 1
guitar base 2
guitar solo 1
guitar solo 2


* Author: Joabe Lopes
* Github repo: https://github.com/joabeslopes/Reaper-scripts-multitrack-creation/
* Licence: GPL v3
* Extensions required: None
]]
--[[
  * Changelog:
  * v2.0 (2024-04-07)
    Files are inserted aligned with the marker, and code cleaning

  * v1.2 (2023-11-15)
    Add MacOS support

  * v1.1 (2023-11-15)
    Improve logic and clean code
  
  * v1.0 (2023-07-25)
    Initial release

]]


-- adjust this table according to your needs
searchTable = { {"cli",0},{"regencia",2},{"guia"},{"bass"},{"baixo"},{"guita"},{"vio"},{"perc"},{"sanf"},{"acordeon"},{"key"},{"tecla"},{"piano"},{"org"},{"fx"},{"sax"},{"trompete"} }


-- read a folder or file, split the content by line breaks, store in a table
function splitContent(pointer)
    local content = {}

    local item = pointer:read("l")
    while item ~= nil do
      if item ~= "" then
        table.insert(content, item)
      end
      item = pointer:read("l")
    end

    return content
end

-- read all folder content and register it in an table
function readFolderContent(folderPath)

    local folderContent = {}
    local openedFolder

    if (OSName == "Other" or OSName == "OSX64") then -- Linux or MacOS
        openedFolder = io.popen('ls "'..folderPath..'"', 'r')
        folderContent = splitContent(openedFolder)
        openedFolder:close()
    elseif (OSName == "Win64" or OSName == "Win32") then -- Windows
        openedFolder = io.popen('dir /b "'..folderPath..'"', 'r')
        folderContent = splitContent(openedFolder)
        openedFolder:close()
    end

    return folderContent

end


function mysub(file, fileRegex, musicPath)
    if musicPath == nil then
        musicPath = ""
    end
    return musicPath..string.sub(file, string.find(file, fileRegex))

end

-- search for the file and it's corresponding track
function regexFullSearch(musicPath, file, originalRegex, trackFolder)

    local audioPath, trackNumb = nil, nil

    local variationsL = {{".*_L.*", ".*%pL.*", ".*_l.*", ".*%pl.*"}, 1}
    local variationsR = {{".*_R.*", ".*%pR.*", ".*_r.*", ".*%pr.*", ".*_2.*"}, 2}
    local variationsLR = {variationsL, variationsR}

    local variationsBase = { {".*BASE.*", ".*base.*"}, 1}
    local variationsSolo = { {".*SOLO.*", ".*solo.*"}, 3}
    local variationsBS = { variationsBase, variationsSolo }

    -- check if track is BASE or SOLO, and then if is L or R
    for _, item in ipairs(variationsBS) do

        for __, bs in ipairs(item[1]) do
            if string.find(file, bs) then
                trackNumb = trackFolder + item[2]
                audioPath = mysub(file, bs, musicPath)

                for ___, r in ipairs(variationsR[1]) do
                    if string.find(audioPath, r) then
                        audioPath = mysub(audioPath, r, musicPath)
                        trackNumb = trackNumb + 1
                        break
                    end
                end

                break
            end
        end
    end

    -- now check if track is just L or R
    if audioPath == nil then

        for _, item in ipairs(variationsLR) do

            for __, lr in ipairs(item[1]) do
                if string.find(file, lr) then
                    trackNumb = trackFolder + item[2]
                    audioPath = mysub(file, lr, musicPath)
                    break
                end
            end
        end
    end

    -- finally
    if audioPath == nil then

        audioPath = mysub(file, originalRegex, musicPath)
        trackNumb = trackFolder

    end

    return audioPath, trackNumb
end


-- insert the audio files in the project
function insertAudioTake(audioPath, trackNumber)

    track = reaper.GetTrack(0, trackNumber)
    reaper.SetOnlyTrackSelected(track)
    reaper.InsertMedia(audioPath, 0)

end

-- search the corresponding folder of the track and adjust it in the search table
function fillSearchTable(searchTable)
    for i = 1, reaper.CountTracks(0) do
        track = reaper.GetTrack(0,i-1)
        local nothing, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        for j =1, #searchTable do
            nameSearch = string.upper(searchTable[j][1])
            if string.find(trackName, ".*"..nameSearch..".*") then
                searchTable[j][2] = i
            end
        end
    end
end


---------------------- Main function ----------------------

OSName = reaper.GetOS()

-- correct the search table
fillSearchTable(searchTable)

-- insert the media files in the project
projectPath = reaper.GetProjectPath()

foldersNames = readFolderContent(projectPath)

cursor = reaper.GetCursorPosition() - 700

if foldersNames then

    for folder = 1, #foldersNames do
        if (not string.find(foldersNames[folder], "[.]+")) then -- ignore names with dot (files and folders)

            musicPath = projectPath.. '/' ..foldersNames[folder].. '/'
            filesNames = readFolderContent(musicPath)

            cursor = cursor + 700
            reaper.AddProjectMarker(0, false, cursor, 0, foldersNames[folder], -1)

            for file = 1, #filesNames do
                if string.find(filesNames[file], ".*%pwav$") or string.find(filesNames[file], ".*%pmp3$") then --select only audio files (.wav or .mp3)

                    for _, s in ipairs(searchTable) do -------
                        regex = ".*"..s[1]..".*"
                        trackFolder = s[2]

                        if string.find(filesNames[file],regex) then
                            finalaudioPath, finalTrackNumber = regexFullSearch(musicPath, filesNames[file], regex, trackFolder)

                            reaper.SetEditCurPos(cursor, false, false)
                            insertAudioTake(finalaudioPath, finalTrackNumber)

                        elseif string.find(string.upper(filesNames[file]),string.upper(regex)) then
                            finalaudioPath, finalTrackNumber = regexFullSearch(musicPath, filesNames[file], string.upper(regex), trackFolder)

                            reaper.SetEditCurPos(cursor, false, false)
                            insertAudioTake(finalaudioPath, finalTrackNumber)

                        end

                    end

                end
            end
        end
    end
else
    reaper.ShowConsoleMsg("Folder read error")
end