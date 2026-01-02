hs.loadSpoon("Hammerflow")

-- iTerm Tab Picker
local itermTabPicker = require("iterm-tab-picker")

-- Notification Manager
local notificationManager = require("notification-manager")

-- Hyper key = cmd+alt+shift+ctrl
local hyper = {"cmd", "alt", "shift", "ctrl"}

-- Notification hotkeys (all use Hyper + different keys)
hs.hotkey.bind(hyper, "n", notificationManager.clickLatest)       -- Hyper+N: click/open notification
hs.hotkey.bind(hyper, "m", notificationManager.dismissLatest)     -- Hyper+M: dismiss notification
hs.hotkey.bind(hyper, "i", notificationManager.show)              -- Hyper+I: browse notifications (I for Inspect)

-- Project picker using hs.chooser
local projectAction = "term"

local function getGitProjects()
    local projects = {}
    local handle = io.popen("/opt/homebrew/bin/zoxide query -l 2>/dev/null")
    if handle then
        for line in handle:lines() do
            local gitDir = line .. "/.git"
            local f = io.open(gitDir, "r")
            if f then
                f:close()
                local name = line:match("([^/]+)$") or line
                table.insert(projects, {
                    text = name,
                    subText = line,
                    path = line,
                })
            end
        end
        handle:close()
    end
    return projects
end

local function executeProjectAction(path)
    if projectAction == "open" then
        hs.execute(string.format("open '%s'", path))
    elseif projectAction == "term" then
        hs.osascript.applescript(string.format([[
            tell application "iTerm2"
                create window with default profile
                tell current session of current window
                    write text "cd '%s'"
                end tell
            end tell
        ]], path))
    elseif projectAction == "nvim" then
        hs.osascript.applescript(string.format([[
            tell application "iTerm2"
                create window with default profile
                tell current session of current window
                    write text "cd '%s' && nvim ."
                end tell
            end tell
        ]], path))
    end
end

local function showProjectPicker(action)
    projectAction = action or "term"
    local chooser
    local ctrlXTap

    local function refreshChoices()
        chooser:choices(getGitProjects())
    end

    chooser = hs.chooser.new(function(choice)
        if ctrlXTap then ctrlXTap:stop() end
        if choice then
            executeProjectAction(choice.path)
        end
    end)

    -- Listen for ctrl-x to remove selected entry from zoxide
    ctrlXTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
        local flags = event:getFlags()
        local key = hs.keycodes.map[event:getKeyCode()]

        if flags.ctrl and key == "x" then
            local selected = chooser:selectedRowContents()
            if selected and selected.path then
                hs.execute(string.format("/opt/homebrew/bin/zoxide remove '%s'", selected.path))
                hs.alert.show("Removed: " .. selected.text, 1)
                refreshChoices()
            end
            return true  -- consume the event
        end
        return false
    end)

    chooser:searchSubText(true)
    chooser:placeholderText("Select project... (ctrl-x to remove)")
    chooser:choices(getGitProjects())
    ctrlXTap:start()
    chooser:show()
end

-- Register functions for Hammerflow
spoon.Hammerflow.registerFunctions({
    projectPicker = showProjectPicker,
    itermTabPicker = itermTabPicker.show,
})

spoon.Hammerflow.loadFirstValidTomlFile({
	"home.toml",
	"work.toml",
	"Spoons/Hammerflow.spoon/sample.toml",
})
-- optionally respect auto_reload setting in the toml config.
if spoon.Hammerflow.auto_reload then
	hs.loadSpoon("ReloadConfiguration")
	-- set any paths for auto reload
	-- spoon.ReloadConfiguration.watch_paths = {hs.configDir, "~/path/to/my/configs/"}
	spoon.ReloadConfiguration:start()
end
