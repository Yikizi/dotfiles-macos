-- Notification Manager
-- Interact with macOS notifications via keyboard shortcuts
-- Hyper+N: click latest, Hyper+Shift+N: dismiss latest, Hyper+Ctrl+N: chooser

local M = {}

local ax = require("hs.axuielement")

local NC_BUNDLE_ID = "com.apple.notificationcenterui"

---------------------------------------------------------
-- Accessibility Helpers
---------------------------------------------------------

local function getNotificationCenterApp()
	local apps = hs.application.runningApplications()
	for _, app in ipairs(apps) do
		if app:bundleID() == NC_BUNDLE_ID then
			return app
		end
	end
	return nil
end

local function getNotificationCenterElement()
	local app = getNotificationCenterApp()
	if not app then
		return nil
	end
	return ax.applicationElementForPID(app:pid())
end

-- Recursively search for notification elements
local function findNotificationsRecursive(element, notifications, depth)
	if depth > 15 then
		return
	end -- Prevent infinite recursion

	local role = element:attributeValue("AXRole")
	local subrole = element:attributeValue("AXSubrole")

	-- Check if this is a notification
	if
		subrole == "AXNotificationCenterBanner"
		or subrole == "AXNotificationCenterAlert"
		or (role == "AXGroup" and subrole == "AXNotificationCenterAlertStack")
	then
		table.insert(notifications, element)
		return -- Don't recurse into notifications
	end

	-- Also check for clickable groups that might be notifications
	if role == "AXButton" or role == "AXGroup" then
		local desc = element:attributeValue("AXDescription") or ""
		local title = element:attributeValue("AXTitle") or ""
		if desc:find("notification") or title:find("notification") then
			table.insert(notifications, element)
			return
		end
	end

	-- Recurse into children
	local children = element:attributeValue("AXChildren")
	if children then
		for _, child in ipairs(children) do
			findNotificationsRecursive(child, notifications, depth + 1)
		end
	end
end

local function findNotifications()
	local ncElement = getNotificationCenterElement()
	if not ncElement then
		return {}
	end

	local notifications = {}
	local seen = {} -- Track seen elements to avoid duplicates

	local function addIfNew(element)
		-- Use element's memory address as unique ID
		local id = tostring(element)
		if not seen[id] then
			seen[id] = true
			table.insert(notifications, element)
		end
	end

	-- Modified recursive search that uses addIfNew
	local function findNotificationsDedup(element, depth)
		if depth > 15 then return end

		local role = element:attributeValue("AXRole")
		local subrole = element:attributeValue("AXSubrole") or ""

		-- Check if this is a notification or group
		if subrole == "AXNotificationCenterBanner"
			or subrole == "AXNotificationCenterAlert"
			or subrole == "AXNotificationCenterAlertStack"
			or subrole == "AXNotificationCenterBannerStack" then
			addIfNew(element)
			return -- Don't recurse into notifications
		end

		-- Recurse into children
		local children = element:attributeValue("AXChildren") or {}
		for _, child in ipairs(children) do
			findNotificationsDedup(child, depth + 1)
		end
	end

	-- Only search windows (not root, to avoid duplicates)
	local windows = ncElement:attributeValue("AXWindows") or {}
	for _, window in ipairs(windows) do
		local title = window:attributeValue("AXTitle") or ""
		-- Only search the Notification Center window
		if title == "Notification Center" then
			findNotificationsDedup(window, 0)
		end
	end

	return notifications
end

local function getLatestNotification()
	local notifications = findNotifications()
	return notifications[1]
end

---------------------------------------------------------
-- Notification Info Extraction
---------------------------------------------------------

local function getNotificationInfo(element)
	local info = {
		element = element,
		title = "",
		appName = "",
		isGroup = false,
	}

	local subrole = element:attributeValue("AXSubrole") or ""
	info.isGroup = (subrole == "AXNotificationCenterAlertStack" or subrole == "AXNotificationCenterBannerStack")

	-- Try various attributes for the title
	info.title = element:attributeValue("AXDescription")
		or element:attributeValue("AXTitle")
		or element:attributeValue("AXValue")
		or "Notification"

	-- Try to find app name from static text children
	local children = element:attributeValue("AXChildren") or {}
	for _, child in ipairs(children) do
		local role = child:attributeValue("AXRole")
		if role == "AXStaticText" then
			local value = child:attributeValue("AXValue")
			if value and value ~= "" and #value < 50 then
				info.appName = value
				break
			end
		end
	end

	return info
end

-- Expand a notification group by clicking it
local function expandGroup(element)
	return element:performAction("AXPress")
end

-- Find and click the Clear button for the current expanded group
local function clearExpandedGroup()
	local ncElement = getNotificationCenterElement()
	if not ncElement then return false end

	-- Find the Clear button (should be visible after expanding)
	local function findClearButton(el, depth)
		if depth > 10 then return nil end

		local role = el:attributeValue("AXRole")
		local desc = (el:attributeValue("AXDescription") or ""):lower()

		if role == "AXButton" and desc == "clear" then
			return el
		end

		local children = el:attributeValue("AXChildren") or {}
		for _, child in ipairs(children) do
			local found = findClearButton(child, depth + 1)
			if found then return found end
		end
		return nil
	end

	local windows = ncElement:attributeValue("AXWindows") or {}
	for _, win in ipairs(windows) do
		local clearBtn = findClearButton(win, 0)
		if clearBtn then
			return clearBtn:performAction("AXPress")
		end
	end
	return false
end

---------------------------------------------------------
-- Actions
---------------------------------------------------------

local function clickNotification(element)
	local result = element:performAction("AXPress")
	return result ~= nil and result ~= false
end

local function dismissNotification(element)
	local children = element:attributeValue("AXChildren") or {}
	for _, child in ipairs(children) do
		local role = child:attributeValue("AXRole")
		local desc = (child:attributeValue("AXDescription") or ""):lower()

		if role == "AXButton" then
			if desc:find("close") or desc:find("clear") or desc:find("dismiss") then
				return child:performAction("AXPress")
			end
		end
	end

	local actions = element:actionNames() or {}
	for _, action in ipairs(actions) do
		local actionLower = action:lower()
		if actionLower:find("cancel") or actionLower:find("close") or actionLower:find("clear") then
			return element:performAction(action)
		end
	end

	return element:performAction("AXCancel")
end

local function dismissAllNotifications()
	local ncElement = getNotificationCenterElement()
	if not ncElement then return 0 end

	local clearButtons = {}

	-- Find all "Clear" buttons in the NC tree
	local function findClearButtons(element, depth)
		if depth > 10 then return end

		local role = element:attributeValue("AXRole")
		local desc = (element:attributeValue("AXDescription") or ""):lower()

		-- Look for Clear/Clear All buttons
		if role == "AXButton" and (desc == "clear" or desc:find("clear all")) then
			table.insert(clearButtons, element)
		end

		local children = element:attributeValue("AXChildren") or {}
		for _, child in ipairs(children) do
			findClearButtons(child, depth + 1)
		end
	end

	-- Search from NC windows
	local windows = ncElement:attributeValue("AXWindows") or {}
	for _, win in ipairs(windows) do
		findClearButtons(win, 0)
	end

	-- Click all Clear buttons found
	local count = 0
	for _, btn in ipairs(clearButtons) do
		if btn:performAction("AXPress") then
			count = count + 1
			hs.timer.usleep(100000) -- 100ms between clicks
		end
	end

	return count
end

---------------------------------------------------------
-- PUBLIC API
---------------------------------------------------------

function M.clickLatest()
	if not hs.accessibilityState() then
		hs.alert.show("Accessibility permission required", 2)
		return
	end

	local notif = getLatestNotification()
	if notif then
		if clickNotification(notif) then
			hs.alert.show("✓", 0.3)
		else
			hs.alert.show("Click failed", 0.5)
		end
	else
		hs.alert.show("No notifications", 0.5)
	end
end

function M.dismissLatest()
	if not hs.accessibilityState() then
		hs.alert.show("Accessibility permission required", 2)
		return
	end

	local notif = getLatestNotification()
	if notif then
		if dismissNotification(notif) then
			hs.alert.show("✕", 0.3)
		else
			hs.alert.show("Dismiss failed", 0.5)
		end
	else
		hs.alert.show("No notifications", 0.5)
	end
end

-- Toggle Notification Center (click on clock)
local function toggleNotificationCenter()
	hs.osascript.applescript([[
		tell application "System Events"
			click (first menu bar item whose description is "Clock") of menu bar 1 of process "ControlCenter"
		end tell
	]])
end

-- Check if NC is currently open
local function isNotificationCenterOpen()
	local ncElement = getNotificationCenterElement()
	if not ncElement then return false end
	local windows = ncElement:attributeValue("AXWindows") or {}
	for _, win in ipairs(windows) do
		local title = win:attributeValue("AXTitle") or ""
		if title == "Notification Center" then
			return true
		end
	end
	return false
end

-- Ensure NC is open
local function ensureNotificationCenterOpen()
	if not isNotificationCenterOpen() then
		toggleNotificationCenter()
	end
end

-- Ensure NC is closed
local function ensureNotificationCenterClosed()
	if isNotificationCenterOpen() then
		toggleNotificationCenter()
	end
end

function M.show()
	if not hs.accessibilityState() then
		hs.alert.show("Accessibility permission required", 2)
		return
	end

	-- Open NC first so notifications are in the AX tree
	ensureNotificationCenterOpen()

	-- Delay to let NC load (keep short for responsiveness)
	hs.timer.doAfter(0.25, function()
		local chooser
		local ctrlXTap
		-- Store elements separately (hs.chooser can't serialize axuielement objects)
		local notificationElements = {}
		local notificationInfo = {}

		local function closeAndCleanup()
			if ctrlXTap then
				ctrlXTap:stop()
			end
			ensureNotificationCenterClosed()
		end

		local function buildChoices()
			local choices = {}
			notificationElements = findNotifications()
			notificationInfo = {}

			if #notificationElements == 0 then
				return { { text = "No notifications", subText = "Press Escape to close", noAction = true } }
			end

			-- Add "Dismiss All" at top
			table.insert(choices, {
				text = "⊘ Dismiss All",
				subText = string.format("%d item(s) - clears all groups", #notificationElements),
				action = "dismiss_all",
			})

			-- Add notifications (store index and info)
			for i, notif in ipairs(notificationElements) do
				local info = getNotificationInfo(notif)
				notificationInfo[i] = info

				if info.isGroup then
					table.insert(choices, {
						text = "📁 " .. info.title,
						subText = "Enter=expand, Ctrl+X=clear group",
						idx = i,
						action = "expand_group",
					})
				else
					table.insert(choices, {
						text = info.title,
						subText = info.appName .. " (Ctrl+X to dismiss)",
						idx = i,
						action = "click",
					})
				end
			end

			return choices
		end

		chooser = hs.chooser.new(function(choice)
			if ctrlXTap then
				ctrlXTap:stop()
			end

			if not choice or choice.noAction then
				ensureNotificationCenterClosed()
				return
			end

			if choice.action == "dismiss_all" then
				local count = dismissAllNotifications()
				hs.alert.show(string.format("Cleared %d group(s)", count), 0.5)
				ensureNotificationCenterClosed()
			elseif choice.action == "expand_group" and choice.idx then
				-- Expand the group and refresh chooser (don't close NC)
				local element = notificationElements[choice.idx]
				if element then
					expandGroup(element)
					-- Refresh and reshow chooser after expansion
					hs.timer.doAfter(0.2, function()
						local newChoices = buildChoices()
						chooser:choices(newChoices)
						ctrlXTap:start()
						chooser:show()
					end)
					return -- Don't close NC
				end
			elseif choice.action == "click" and choice.idx then
				local element = notificationElements[choice.idx]
				if element and clickNotification(element) then
					hs.alert.show("✓", 0.3)
				else
					ensureNotificationCenterClosed()
				end
			end
		end)

		-- Ctrl+X to dismiss selected notification/group inline
		ctrlXTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
			local flags = event:getFlags()
			local key = hs.keycodes.map[event:getKeyCode()]

			if flags.ctrl and key == "x" then
				local selected = chooser:selectedRowContents()
				if selected and selected.idx then
					local element = notificationElements[selected.idx]
					local info = notificationInfo[selected.idx]

					if element then
						if info and info.isGroup then
							-- For groups: expand first, then clear
							expandGroup(element)
							hs.timer.doAfter(0.15, function()
								clearExpandedGroup()
								hs.alert.show("Group cleared", 0.3)
								hs.timer.doAfter(0.1, function()
									chooser:choices(buildChoices())
								end)
							end)
						else
							-- For individual: dismiss directly
							dismissNotification(element)
							hs.alert.show("Dismissed", 0.3)
							hs.timer.doAfter(0.1, function()
								chooser:choices(buildChoices())
							end)
						end
					end
				end
				return true
			end
			return false
		end)

		chooser:searchSubText(true)
		chooser:placeholderText("Select notification... (Ctrl+X to dismiss)")
		chooser:choices(buildChoices())
		ctrlXTap:start()
		chooser:show()
	end)
end

-- Debug helper to inspect notification structure
function M.debug()
	local ncElement = getNotificationCenterElement()
	if not ncElement then
		print("NotificationCenter not running")
		return
	end

	local function printTree(element, indent)
		indent = indent or 0
		local prefix = string.rep("  ", indent)
		local role = element:attributeValue("AXRole") or "?"
		local subrole = element:attributeValue("AXSubrole") or ""
		local desc = element:attributeValue("AXDescription") or ""
		local title = element:attributeValue("AXTitle") or ""

		print(string.format("%s%s [%s] desc='%s' title='%s'", prefix, role, subrole, desc:sub(1, 50), title:sub(1, 50)))

		if indent < 6 then
			local children = element:attributeValue("AXChildren") or {}
			for _, child in ipairs(children) do
				printTree(child, indent + 1)
			end
		end
	end

	print("\n=== NotificationCenter Accessibility Tree ===")
	printTree(ncElement)
	print("=== End ===\n")
end

return M
