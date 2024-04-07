--[[
# DESCRIPTION

Script to create and color multiple tracks at once, based on the text file "tracks.txt", created by the user.

The structure is simple: UPPERCASE names will be the track folders,
and the lowercases will be the tracks of audio.

**Line breaks will be ignored, but whitespaces don't.

The file name must to be "tracks.txt", and the content must be like this:

TRACK FOLDER NAME
track name
track name

ANOTHER TRACK FOLDER NAME
another track name
another track name


Put the text file in your project folder, or in the Reaper default project folder (to work on new unsaved projects). 
Example:
C:\User\Documents\REAPER Media\


* Author: Joabe Lopes
* Github repo: https://github.com/joabeslopes/Reaper-scripts-multitrack-creation/
* Licence: GPL v3
* Extensions required: None
]]
--[[

  * Changelog:
  * v1.3 (2024-04-06)
    Improved way of opening files and folders

  * v1.2 (2023-11-15)
    Add MacOS support

  * v1.1 (2023-11-15)
    Improve logic and clean code
  
  * v1.0 (2023-07-25)
    Initial release

]]


-- get the tracks.txt file inside the project folder
function getTracksFileProject(OSName)
  local path = reaper.GetProjectPath()
  local folder, folderItems, tracksTextfile

  if (OSName == "Other" or OSName == "OSX64") then -- Linux or MacOS

    folder = io.popen('ls "'..path..'"', 'r')
    folderItems = splitContent(folder)
    folder:close()

    for f=1, #folderItems do
      if string.find(folderItems[f], "tracks%ptxt") then
        tracksTextfile = path.."/tracks.txt"
        return tracksTextfile
      end
    end

  elseif (OSName == "Win64" or OSName == "Win32") then -- Windows

    folder = io.popen('dir /b "'..path..'"', 'r')
    folderItems = splitContent(folder)
    folder:close()

    for f=1, #folderItems do
      if string.find(folderItems[f], "tracks%ptxt") then
        tracksTextfile = path.."\\tracks.txt"
        return tracksTextfile
      end
    end
  end

end


-- get the tracks.txt file inside the folder of this script
function getTracksFileScript(OSName)
  local path = debug.getinfo(2, "S").source:sub(2):match(".*[/\\]")
  if (OSName == "Other" or OSName == "OSX64") then -- Linux or MacOSs

    folder = io.popen('ls "'..path..'"', 'r')
    folderItems = splitContent(folder)
    folder:close()

    for f=1, #folderItems do
      if string.find(folderItems[f], "tracks%ptxt") then
        tracksTextfile = path.."tracks.txt"
        return tracksTextfile
      end
    end

  elseif (OSName == "Win64" or OSName == "Win32") then -- Windows

    folder = io.popen('dir /b "'..path..'"', 'r')
    folderItems = splitContent(folder)
    folder:close()

    for f=1, #folderItems do
      if string.find(folderItems[f], "tracks%ptxt") then
        tracksTextfile = path.."tracks.txt"
        return tracksTextfile
      end
    end
  end

end


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


---------------------- Main function ----------------------

allTracks = nil
OSName = reaper.GetOS()
filePath = nil

-- open the file
if getTracksFileProject(OSName) then
  filePath = getTracksFileProject(OSName)

elseif getTracksFileScript(OSName) then
  filePath = getTracksFileScript(OSName)
end


if filePath then
  tracksFile = io.open(filePath, 'r')
  allTracks = splitContent(tracksFile)
  tracksFile:close()
end


if allTracks then

  -- create all tracks and color them
  for i = 1, #allTracks do

  --create the tracks
  reaper.InsertTrackAtIndex(i-1, true)
  track = reaper.GetTrack(0,i-1)
  trackName = allTracks[i]
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", trackName, true)

  --color the folder tracks
  if string.find(trackName,"^%L") then
    for n = 100, math.random(150,200) do
          math.randomseed(os.time()..n..n)
          math.random(); math.random();
          r = math.random(0,255)
          g = math.random(0,255)
          b = math.random(0,255)
        end
        color = reaper.ColorToNative(r,g,b)
        reaper.SetTrackColor(track, color)
  end
  end

else
    reaper.ShowConsoleMsg("File \"tracks.txt\" not found.\nPlease create it on the project folder, or on the scripts folder")
end