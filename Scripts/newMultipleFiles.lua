--[[
# DESCRIPTION

Same functionalites of the "insertMultipleFiles.lua" script, but this time you just want to add some new musics to the project, instead of all the musics of the folder.

How do you do that? You create a file named "musics.txt", and put inside it the names of the folders that you want to pull the instruments, separating by line breaks.

You don't need to write the exact folder name, just the enough to the computer find it.

## Examples of content:
First music
second_music
THIRD MUSIC

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

function getNewMusics(projPath)

    local filePath = projPath.."/musics.txt"
    local file = io.open(filePath, "r")
    local newMusics
    if file then
        newMusics = splitContent(file)
        file:close()
    end
    return newMusics
end
---------------------- Main function ----------------------

OSName = reaper.GetOS()

-- correct the search table
fillSearchTable(searchTable)

-- insert the media files in the project
projectPath = reaper.GetProjectPath()

-- read musics.txt file
newMusics = getNewMusics(projectPath)

foldersNames = readFolderContent(projectPath)

cursor = reaper.GetCursorPosition() - 700

if newMusics then
    if foldersNames then
        for folder = 1, #foldersNames do
            if (not string.find(foldersNames[folder], "[.]+")) then -- ignore names with dot (files and folders)
                for music=1, #newMusics do
                    -- folder name matches the music in the list
                    if string.find(foldersNames[folder]:upper(), ".*"..newMusics[music]:upper()..".*" ) then
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
            end
        end
    else
        reaper.ShowConsoleMsg("Folder read error")
    end
else
    reaper.ShowConsoleMsg("File \"musics.txt\" not found, you need to create it and name it exactly that way")
end