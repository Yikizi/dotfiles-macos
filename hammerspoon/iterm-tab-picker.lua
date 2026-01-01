-- iTerm Tab Picker
-- Brings any iTerm tab to the currently focused window using hs.chooser

local M = {}

local SCRIPT_PATH = os.getenv("HOME") .. "/scripts/python/iterm-tabs/iterm-tabs"

local function getItermTabs()
    local tabs = {}
    local handle = io.popen(SCRIPT_PATH .. " list 2>/dev/null")
    if handle then
        local output = handle:read("*a")
        handle:close()

        -- Parse JSON
        local ok, data = pcall(function()
            return hs.json.decode(output)
        end)

        if ok and data then
            -- Get current window to filter it out
            local currentWindowId = nil
            local focusedApp = hs.application.frontmostApplication()
            if focusedApp and focusedApp:name() == "iTerm2" then
                -- Get focused window's ID via AppleScript
                local _, result = hs.osascript.applescript([[
                    tell application "iTerm"
                        if (count of windows) > 0 then
                            return id of current window
                        end if
                    end tell
                ]])
                currentWindowId = result
            end

            for _, tab in ipairs(data) do
                -- Include all tabs (user can bring any tab to current window)
                local inCurrentWindow = (tab.window_id == currentWindowId)

                -- Build display text: prefer cwd, fall back to name
                local displayText
                if tab.cwd_short and tab.cwd_short ~= "" then
                    -- Show job + path, e.g. "node: .../android-project"
                    if tab.job and tab.job ~= "" and tab.job ~= "-zsh" and tab.job ~= "zsh" then
                        displayText = tab.job .. ": " .. tab.cwd_short
                    else
                        displayText = tab.cwd_short
                    end
                else
                    displayText = tab.name
                end

                -- Build subtext: window label + current indicator
                local subText
                if inCurrentWindow then
                    subText = "📍 Current window"
                else
                    subText = "📁 " .. (tab.window_label or "Unknown window")
                end

                table.insert(tabs, {
                    text = displayText,
                    subText = subText,
                    tab_id = tab.tab_id,
                    window_id = tab.window_id,
                    is_current = inCurrentWindow,
                })
            end
        end
    end
    return tabs
end

local function moveTabToCurrentWindow(tabId)
    -- First focus iTerm to ensure we have a "current window"
    local iterm = hs.application.get("iTerm2")
    if iterm then
        iterm:activate()
        -- Small delay to ensure window focus
        hs.timer.usleep(100000) -- 100ms
    end

    local handle = io.popen(SCRIPT_PATH .. " move '" .. tabId .. "' 2>/dev/null")
    if handle then
        local output = handle:read("*a")
        handle:close()

        local ok, result = pcall(function()
            return hs.json.decode(output)
        end)

        if ok and result then
            if result.status == "moved" then
                hs.alert.show("Tab moved!", 0.5)
            elseif result.status == "already_in_window" then
                hs.alert.show("Tab already in this window", 0.5)
            elseif result.error then
                hs.alert.show("Error: " .. result.error, 2)
            end
        end
    end
end

function M.show()
    local chooser = hs.chooser.new(function(choice)
        if choice then
            moveTabToCurrentWindow(choice.tab_id)
        end
    end)

    local tabs = getItermTabs()

    -- Sort: other windows first, current window tabs at the end
    table.sort(tabs, function(a, b)
        if a.is_current ~= b.is_current then
            return not a.is_current
        end
        return a.text < b.text
    end)

    chooser:searchSubText(true)
    chooser:placeholderText("Select tab to bring here...")
    chooser:choices(tabs)
    chooser:show()
end

-- For Hammerflow registration
function M.registerWithHammerflow(hammerflow)
    hammerflow.registerFunctions({
        itermTabPicker = M.show
    })
end

return M
