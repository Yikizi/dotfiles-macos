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

	-- Get windows
	local windows = ncElement:attributeValue("AXWindows") or {}
	for _, window in ipairs(windows) do
		findNotificationsRecursive(window, notifications, 0)
	end

	-- Also search from root
	findNotificationsRecursive(ncElement, notifications, 0)

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
	}

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
	local notifications = findNotifications()
	local count = 0

	for _, notif in ipairs(notifications) do
		if dismissNotification(notif) then
			count = count + 1
		end
		hs.timer.usleep(50000)
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

function M.show()
	if not hs.accessibilityState() then
		hs.alert.show("Accessibility permission required", 2)
		return
	end

	local chooser
	local ctrlXTap

	local function buildChoices()
		local choices = {}
		local notifications = findNotifications()

		if #notifications == 0 then
			return { { text = "No notifications", subText = "Press Escape to close", noAction = true } }
		end

		-- Add "Dismiss All" at top
		table.insert(choices, {
			text = "Dismiss All",
			subText = string.format("%d notification(s)", #notifications),
			action = "dismiss_all",
		})

		-- Add individual notifications
		for _, notif in ipairs(notifications) do
			local info = getNotificationInfo(notif)
			table.insert(choices, {
				text = info.title,
				subText = info.appName .. " (Ctrl+X to dismiss)",
				element = notif,
				action = "click",
			})
		end

		return choices
	end

	chooser = hs.chooser.new(function(choice)
		if ctrlXTap then
			ctrlXTap:stop()
		end

		if not choice or choice.noAction then
			return
		end

		if choice.action == "dismiss_all" then
			local count = dismissAllNotifications()
			hs.alert.show(string.format("Dismissed %d", count), 0.5)
		elseif choice.action == "click" and choice.element then
			if clickNotification(choice.element) then
				hs.alert.show("✓", 0.3)
			end
		end
	end)

	-- Ctrl+X to dismiss selected notification inline
	ctrlXTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
		local flags = event:getFlags()
		local key = hs.keycodes.map[event:getKeyCode()]

		if flags.ctrl and key == "x" then
			local selected = chooser:selectedRowContents()
			if selected and selected.element then
				dismissNotification(selected.element)
				hs.alert.show("Dismissed", 0.3)
				-- Refresh choices
				hs.timer.doAfter(0.1, function()
					chooser:choices(buildChoices())
				end)
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
