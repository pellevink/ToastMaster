local _G = getfenv(0)
local debugEnable = false

local function print(...)
	-- local helper function to print to system console
	local text = Utils.ArgsToStr(unpack(arg))
	_G["ChatFrame1"]:AddMessage(text)
end

local function debug(...)
	ScriptEditor:Log(Utils.ArgsToStr(unpack(arg)))
end

local function CreateToast(parent, title, text)
	local ftoast = CreateFrame("Frame", nil, parent)
	ftoast:SetBackdrop({bgFile = "Interface/ChatFrame/ChatFrameBackground"})
	ftoast:SetBackdropColor(0,0,0,1.0)
	ftoast:SetWidth(ftoast:GetParent():GetWidth())
	ftoast:SetHeight(60)
	
	ftoast.title = ftoast:CreateFontString("FontString")
	ftoast.title:SetFont("Fonts\\ARIALN.TTF", 12, "BOLD")
	ftoast.title:SetJustifyV("TOP")
	ftoast.title:SetJustifyH("LEFT")
	ftoast.title:SetPoint("TOPLEFT", ftoast, "TOPLEFT", 2, -2)
	ftoast.title:SetPoint("RIGHT", ftoast, "RIGHT", -2)
	ftoast.title:SetText(title)
		
	ftoast.closeStr = ftoast:CreateFontString("FontString")
	ftoast.closeStr:SetFont("Fonts\\ARIALN.TTF", 8, "NORMAL")
	ftoast.closeStr:SetPoint("BOTTOMLEFT", 2, 2)
	ftoast.closeStr:SetPoint("RIGHT", ftoast, "RIGHT", -2)
	ftoast.closeStr:SetText("|cFF00FF00click to close|r")
	ftoast.closeStr:Hide()
	
	ftoast.msg = ftoast:CreateFontString("FontString")
	ftoast.msg:SetFont("Fonts\\ARIALN.TTF", 10, "NORMAL")
	ftoast.msg:SetPoint("TOPLEFT", ftoast.title, "BOTTOMLEFT", 0, -5)
	ftoast.msg:SetPoint("BOTTOMRIGHT", ftoast.closeStr, "TOPRIGHT", 0, -2)
	ftoast.msg:SetJustifyV("TOP")
	ftoast.msg:SetJustifyH("LEFT")
	ftoast.msg:SetText(text)
		
	ftoast:EnableMouse(true)
	ftoast.nextBlinkUpdate = {}	
	ftoast.fblink = CreateFrame("Frame", nil, ftoast)
	ftoast.fblink:SetBackdrop({bgFile = "Interface/ChatFrame/ChatFrameBackground"})
	ftoast.fblink:SetBackdropColor(0,0,0,0)
	ftoast.fblink:SetAllPoints(ftoast.fblink:GetParent())
	ftoast:Hide()
	ftoast.SetToastText = function(this, title, text)
		this.title:SetText(title)
		this.msg:SetText(text)
	end
	ftoast.StartBlink = function(this)		
		-- create time intervals where the blinks occur
		local curtime = GetTime()
		this:StopBlink()
		for i=1,10 do
			table.insert(this.nextBlinkUpdate, curtime + i*0.5)
		end
	end
	ftoast.StopBlink = function(this)
		this.fblink:SetBackdropColor(0,0,0,0) -- end black
		this.nextBlinkUpdate = {}
	end
	ftoast.AdjustPoint = function(this, pointName, xoff, yoff)
		local fp = Utils.GetFramePoint(this, pointName)
		if fp ~= nil then
			this:SetPoint(fp[1], fp[2], fp[3], fp[4] + xoff, fp[5] + yoff)
		end
	end
	ftoast:SetScript("OnUpdate",function()
		if this.nextBlinkUpdate[1] ~= nil and GetTime() >= this.nextBlinkUpdate[1] then
			if this.fblink:GetBackdropColor() == 0 then
				this.fblink:SetBackdropColor(1,1,0,0.2)
			else
				this.fblink:SetBackdropColor(0,0,0,0)
			end
			table.remove(this.nextBlinkUpdate, 1)
			if this.nextBlinkUpdate[1] == nil then
				this:StopBlink()
				if this.settings.persistent == false then
					this.closeStr:Hide()
					this:GetParent():RemoveToast(this)
				end
			end
		end
	end)
	ftoast:SetScript("OnMouseUp", function()
		if this.settings.onclick ~= nil and arg1 ~= "RightButton" then
			this.settings.onclick(this.settings.onclickParam)
		else
			this.closeStr:Hide()
			this:GetParent():RemoveToast(this)
			PlaySound("igMiniMapZoomIn")
		end
	end)
	ftoast:SetScript("OnEnter", function()
		this:StopBlink()
		this:SetBackdropColor(0.15,0.15,0.15,1)
		this.closeStr:Show()
	end)
	ftoast:SetScript("OnLeave", function()
		this:SetBackdropColor(0,0,0,1.0)
		this.closeStr:Hide()
	end)

	return ftoast
end

local fToastMasterFrame = CreateFrame("ScrollFrame", nil, UIParent)
fToastMasterFrame.reminders = {} -- map id:reminder
fToastMasterFrame:SetWidth(UIParent:GetWidth()*0.3)
fToastMasterFrame:SetHeight(UIParent:GetHeight()*0.90)
fToastMasterFrame:SetFrameStrata("DIALOG")
fToastMasterFrame:SetPoint("CENTER",0,0)
fToastMasterFrame:Show()
fToastMasterFrame:GetTop()
fToastMasterFrame.container = Utils.FrameCreator({"Frame", "", fToastMasterFrame}, function(frame)		
	frame:SetBackdrop({bgFile = "Interface/ChatFrame/ChatFrameBackground"})
	frame:SetBackdropColor(0,0,0,0.0)
	frame.title = frame:CreateFontString("FontString")
	frame.title:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
	frame.title:SetText("Toast Frame")
	frame.title:SetPoint("TOP",frame,"TOP",0,0)
	frame.title:Hide()
	fToastMasterFrame:SetScrollChild(frame)	
	fToastMasterFrame.container = frame
	frame:SetAllPoints(fToastMasterFrame)
	frame:SetWidth(frame:GetParent():GetWidth())
	frame.activeToasts = Utils.NTable() -- a list in order from the topmost to the bottommost
	frame.baggedToasts = Utils.NTable() -- a list of unordered, recyclable toasts
	frame:Show()
	frame.nextAnimationUpdate = 0
	frame.nextSoundAlert = nil
	Utils.CreateTimer(frame, "targetUpdate", 1.0)
	frame.RemoveToast = function(this, toast)
		-- the new top position will be the current minus the width
		local topFp = {this.activeToasts:front():GetPoint("TOP")}
		topFp[5] = topFp[5] - toast:GetHeight()
				
		-- remove a toast from the toast list
		toast:Hide()
		this.activeToasts:erase(toast)
		toast:SetPoint("TOP", UIParent, "BOTTOM", 0, 100)
		this.baggedToasts:append(toast)

		-- then go through the toast list and link each one with the next one
		-- ensure the top is adjusted
		if this.activeToasts:size() == 0 then
			return
		end

		this.activeToasts:front():SetPoint(unpack(topFp))
		for i=2,this.activeToasts:size() do
			this.activeToasts[i]:SetPoint("TOP",this.activeToasts[i-1],"BOTTOM", 0, 0 )
		end
				
	end
	frame.AddToast = function(this, title, text, settings)
		-- add the new toast to the bottom of the list of active toasts
		-- when a toast is added, we then scroll the topmost toast upward lifting all toasts		
		
		debug("adding toast!")		
		
		local toast = nil
		if this.baggedToasts:size() > 0 then
			toast = this.baggedToasts:front()
			this.baggedToasts:popfront()
			toast:SetToastText(title, text)
		else			
			toast = CreateToast(this, title, text)
		end		
		toast:SetPoint("CENTER", 0, 0)
		if this.activeToasts:size() == 0 then						
			toast:SetPoint("TOP", toast:GetParent(), "BOTTOM", 0, 0)
		else
			toast:SetPoint("TOP", this.activeToasts:back(), "BOTTOM", 0, 0 )
		end

		debug( "center", this:GetTop() )
		toast.settings = {
			persistent = true
		}
		if settings then
			for k,v in pairs(settings) do
				toast.settings[k] = v
			end			
		end

		if toast.settings.onclick ~= nil then
			toast.closeStr:SetText("|cFF00FF00right-click to close|r")
		else
			toast.closeStr:SetText("|cFF00FF00click to close|r")
		end


		this.activeToasts:append(toast)
		toast:StartBlink()		
		toast:Show()
		this.nextSoundAlert = 0 -- instantly play a sound next OnUpdate	
	end
	frame:SetScript("OnUpdate", function()
		local topToast = this.activeToasts:front()
		local bottomToast = this.activeToasts:back()
		
		if Utils.UpdateReady(this, "targetUpdate") == true then
			for name,data in pairs(fToastMasterFrame.targets) do
				if (data == true or GetTime() >= data)  then
					if UnitAffectingCombat("player") and UnitName("Target") then
						-- we do not want to swap targets mid fight
					else
						local currentTarget = UnitName("Target")
						TargetByName(name, true)
						local targetName = UnitName("Target")					
						if targetName == name then
							if currentTarget ~= targetName then
								TargetLastTarget()
							end
							fToastMasterFrame.targets[name] = GetTime() + 5
							this:AddToast("Located Target!", "The unit '"..name.."' is now targettable!\nclick to target", {onclickParam=name,onclick=function(name)
								TargetByName(name, true)
							end})
						end
					end
				end
			end
		end

		-- is it time to make some noise?
		if topToast ~= nil and this.nextSoundAlert ~= nil and GetTime() >= this.nextSoundAlert then
			PlaySoundFile("Interface\\AddOns\\ToastMaster\\sounds\\boing1.mp3")
			for i,toast in ipairs(this.activeToasts) do
				toast:StartBlink()
			end
			this.nextSoundAlert = GetTime() + 10 -- schedule next sound alert in 10 seconds
		end

		-- if our bottom active toast is below our frame border, the row needs to be scrolled up		
		if topToast ~= nil and bottomToast ~= nil and GetTime() >= this.nextAnimationUpdate then
			if bottomToast:GetBottom() < this:GetBottom() then
				local topFp = Utils.GetFramePoint(topToast,"TOP")
				topToast:SetPoint("TOP", this, "BOTTOM", topFp[4], topFp[5] + 10)
				this.nextAnimationUpdate = GetTime() + 0.01
			end
		end
		
		-- if our top active toast has scolled off the window, remove it		
		if topToast ~= nil then
			if topToast:GetTop() > this:GetTop() then
				this:RemoveToast(topToast)
			end
		end
	end)
end)

fToastMasterFrame.UnlockFrame = function(this)
	this.container:SetBackdropColor(0,0,0,0.4)
	this.container.title:Show()
	this:EnableMouse(true)
	this:RegisterForDrag("LeftButton")
	this:SetMovable()
end
fToastMasterFrame.LockFrame = function(this)
	this.container:SetBackdropColor(0,0,0,0.0)
	this.container.title:Hide()
	this:EnableMouse(false)
	local _,_,anchor,xpos,ypos = this:GetPoint("CENTER")
	Utils.SetDBCharVar(ToastMasterDB, {anchor,xpos,ypos}, "ToastFrame", "pos")
end
fToastMasterFrame:SetScript("OnDragStart",function()	
	this:StartMoving()
end)
fToastMasterFrame:SetScript("OnDragStop",function()
	this:StopMovingOrSizing()
end)
fToastMasterFrame:RegisterEvent("ADDON_LOADED")
fToastMasterFrame:RegisterEvent("CHAT_MSG_WHISPER")
fToastMasterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
local ZONE_CHANGE_EVENTS = {ZONE_CHANGED_INDOORS=true,ZONE_CHANGED_NEW_AREA=true, ZONE_CHANGED=true, ZONE_CHANGED_NEW_AREA=true}
for event_name,v in pairs(ZONE_CHANGE_EVENTS) do
	fToastMasterFrame:RegisterEvent(event_name)
end
fToastMasterFrame.CheckLocation = function(this)
	debug("checking reminders" )
	for id,rem in pairs(this.reminders) do
		debug("checking id=", id, "=", rem)
		local mismatch = false
		if rem.zone ~= nil then
			local zone = string.lower(GetRealZoneText())			
			if string.find(zone, rem.zone) == nil then				
				mismatch = true
			end
			debug("checking zone", rem.zone, "?", zone, "=", mismatch)			
		end
		if rem.area ~= nil then
			local area = string.lower(GetSubZoneText())			
			if string.find(area, rem.area) == nil then
				mismatch = true
			end
			debug("checking area", rem.area, "?", area, "=", mismatch)
		end
		if rem.location ~= nil then
			local location = string.lower(GetSubZoneText().." "..GetRealZoneText())
			
			if string.find(location, rem.location) == nil then
				mismatch = true
			end
			debug("checking loc", rem.location, "?", location, "=", mismatch)
		end
		debug("mismatch",mismatch)
		if mismatch == false then
			fToastMasterFrame.container:AddToast("Arrived!", 
				"Message to remind you when arriving in '"..GetRealZoneText().."', '"..GetSubZoneText().."': "..rem.message)
		end
	end
end

ToastMaster = nil
local function CreateToastMasterAPI()
	return {
		AddToast = function(this, title, text, settings)
			fToastMasterFrame.container:AddToast(title, text, settings)
		end,
		UnlockFrame = function(this)
			fToastMasterFrame:UnlockFrame()
		end,
		LockFrame = function(this)
			fToastMasterFrame:LockFrame()
		end,
		ListReminders = function(this)
			local remList = {}
			for id,rem in pairs(fToastMasterFrame.reminders) do
				table.insert(remList, id)
			end
			return remList
		end,
		RemoveReminder = function(this, id)
			if fToastMasterFrame.reminders[id] == nil then
				return false
			else
				table.remove(fToastMasterFrame.reminders, id)
				Utils.SetDBCharVar(ToastMasterDB,fToastMasterFrame.reminders,"reminders")
				return true			
			end
		end,
		AddTarget = function(this, target)
			fToastMasterFrame.targets[target] = true
			Utils.SetDBCharVar(ToastMasterDB, fToastMasterFrame.targets, "targets")
		end,
		RemoveTarget = function(this, target)
			fToastMasterFrame.targets[target] = nil
			Utils.SetDBCharVar(ToastMasterDB, fToastMasterFrame.targets, "targets")
		end,
		AddReminder = function(this, location, message)

			local newReminder = {
				zone = nil,
				area = nil,
				location = nil,
				message = message
			}

			-- <zone>,<area>
			local m = {string.find(location, "([^,]+),(.+)")}
			if m[3] and m[4] then
				newReminder.zone = m[3]
				newReminder.area = m[4]
			else			
				-- z[one]=<zone> or a[rea]=<area>
				local m = {string.find(location, "([^=]+)=(.+)")}
				if m[3] and m[4] then
					if string.find("zone", "^"..m[3] ) == 1 then
						newReminder.zone = m[4]
					elseif string.find("area", "^"..m[3] ) == 1 then
						newReminder.area = m[4]
					end
				else
					newReminder.location = location
				end
			end

			local nextId = 1
			while fToastMasterFrame.reminders[nextId] ~= nil do
				nextId = nextId + 1
			end
					
			debug("new reminder=",newReminder, ", id=", nextId )
			fToastMasterFrame.reminders[nextId] = newReminder
			Utils.SetDBCharVar(ToastMasterDB,fToastMasterFrame.reminders,"reminders")
			return nextId
		end	
	}
end

fToastMasterFrame:SetScript("OnEvent", function()
	if event == "ADDON_LOADED" and arg1 == "ToastMaster" then
		if ToastMasterDB == nil then
			ToastMasterDB = {}
		end
		local toastPos = Utils.GetDBCharVar(ToastMasterDB,"ToastFrame","pos")
		if toastPos ~= nil then
			this:ClearAllPoints()
			this:SetPoint(unpack(toastPos))
		end

		this.reminders = Utils.GetDBCharVar(ToastMasterDB, "reminders")
		if this.reminders == nil then
			this.reminders = {}
		end

		this.targets = Utils.GetDBCharVar(ToastMasterDB, "targets")
		if this.targets == nil then
			this.targets = {}
		end

		if ToastMaster == nil then
			ToastMaster = CreateToastMasterAPI()
		end
		
	elseif event == "CHAT_MSG_WHISPER" then
		this.container:AddToast("@"..arg2, arg1, {onclick=function()
			-- click to start chat TODO
		end})
	elseif ZONE_CHANGE_EVENTS[event] ~= nil then
		this:CheckLocation()		
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- drop in a chat frame spy
		if DEFAULT_CHAT_FRAME then
			fToastMasterFrame.DEFAULT_CHAT_FRAME_AddMessage = DEFAULT_CHAT_FRAME.AddMessage
			DEFAULT_CHAT_FRAME.AddMessage = function(...)
				
				-- unitscan spy
				if string.find(arg[2], "<unitscan>") then
					if string.find(arg[2], "!!!!!!!!!!!") then					
						if fToastMasterFrame.unitscanAlert == nil then
							fToastMasterFrame.unitscanAlert = true
						else
							fToastMasterFrame.unitscanAlert = nil
						end					
					elseif fToastMasterFrame.unitscanAlert == true then
						_,_,name = string.find(arg[2], "<unitscan>%s*(.+)")
						ToastMaster:AddToast("UnitScan Found", name .. "\nclick to target", {onclickParam=name,onclick=function(name)
							TargetByName(name, true)
						end})
					end
				end

				fToastMasterFrame.DEFAULT_CHAT_FRAME_AddMessage(unpack(arg))
			end
		end
	end
end)


SLASH_TOASTMASTER_SLASH1 = "/toast"
SlashCmdList["TOASTMASTER_SLASH"] = function(input)	
	local params = Utils.NTable()
	local appending = false
	for k in string.gfind(input, "%S+") do
		params:append(k)
	end

	if params:size() == 0 then
		print([[ToastMaster
		Available commands
		/toast me in <Location> <message>
		will toast you a notification each time entering the location specified.
		location can be comma separated in which case the addon will find the string within [zone],[area]. e.g. barrens,ratchet
		]])
		return
	end

	if params:size() == 1 and params[1] == "me" then
		fToastMasterFrame:CheckLocation()
		print("Active reminders" )
		local any = false
		for id,rem in pairs(fToastMasterFrame.reminders) do
			print("id", id, ":", rem)
			any = true
		end
		if any == false then
			print("<no active reminders>")
		end
	elseif params[1] == "rf" then
		-- reset frame
		fToastMasterFrame:ClearAllPoints()
		fToastMasterFrame:SetPoint("CENTER", 0, 0)
	elseif params:size() == 2 and params[1] == "del" then
		params[2] = tonumber(params[2])
		if ToastMaster:RemoveReminder(params[2]) then			
			print("reminder with id",id,"removed")
		else
			print("No reminder with id", id)
		end
	elseif params:size() >= 2 and string.find("target", "^"..params[1]) then
		table.remove(params, 1)
		local target = table.concat(params, " ")
		ToastMaster:AddTarget(target)
		print("Will toast you on when '"..target.."' is targettable.")
	elseif params:size() >= 3 and params[1] == "rm" and string.find("target", "^"..params[2]) then
		table.remove(params, 1)
		table.remove(params, 1)
		local target = table.concat(params, " ")
		ToastMaster:RemoveTarget(target)
		print("Will not notify you when '"..target.."' is targettable.")
	elseif params:size() >= 3 and params[1] == "in" then
		-- 1:in 2...:loc
		table.remove(params, 1)
		local msg = table.concat(params, " ")		
		local nextId = ToastMaster:AddReminder(params[3], table.concat(msg," "))
		if nextId ~= nil then
			print("added reminder id", nextId )
		else
			print("unable to add reminder")
		end
	else
		print("unable to parse /toast command")
	end

end
