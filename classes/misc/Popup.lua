--[[
Copyright 2008-2023 João Cardoso
Sushi is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Sushi.

Sushi is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Sushi is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Sushi. If not, see <http://www.gnu.org/licenses/>.
--]]

local Popup = LibStub('Sushi-3.1').Group:NewSushi('Popup', 3)
if not Popup then return end
local Defaults = StaticPopup_DisplayedFrames

if not rawget(Popup, 'Layout') or not Popup.Active then
	hooksecurefunc('StaticPopup_CollapseTable', function() Popup:Organize() end)
	hooksecurefunc('StaticPopup_Show', function() Popup:Organize() end)
end

Popup.Active = Popup.Active or {}
Popup.Size = 420
Popup.Max = 6


--[[ Manage ]]--

function Popup:External(url)
	return self:New {id = url, icon = 'communities-icon-searchmagnifyingglass', text = 'Copy this url into your browser', editBoxText = url, button1 = OKAY}
end

function Popup:Toggle(input)
	return self:Cancel(input) or self:New(input)
end

function Popup:Cancel(input)
	local f = self:GetActive(input)
	return f and (f:Release() or true)
end

function Popup:Organize()
	for i, f in self:IterateActive() do
		local anchor = i == 1 and Defaults[#Defaults] or self.Active[i-1]
		if anchor then
			f:SetPoint('TOP', anchor, 'BOTTOM', 0, -15)
		else
			f:SetPoint('TOP', UIParent, 'TOP', 0, -135)
		end
	end
end

function Popup:GetActive(target)
	for i, f in self:IterateActive() do
		if f == target or f.id == target then
			return f, i
		end
	end
end

function Popup:IterateActive()
	return ipairs(self.Active)
end


--[[ Construct ]]--

function Popup:Construct()
	local f = self:Super(Popup):Construct()
	f:SetScript('OnKeyDown', f.OnKeyDown)

	local icon = f:CreateTexture()
	icon:SetSize(36,36)
	icon:SetPoint('LEFT', 24,0)

	f.Icon = icon
	return f
end

function Popup:New(input)
	local info = type(input) == 'table' and input or CopyTable(StaticPopupDialogs[input])
	local id = info.id or input

	if UnitIsDeadOrGhost('player') and not info.whileDead then
		return info.OnCancel and info.OnCancel(nil, 'dead')
	elseif InCinematic() and not info.interruptCinematic then
		return info.OnCancel and info.OnCancel(nil, 'cinematic')
	elseif id and self:GetActive(id) then
		return info.OnCancel and info.OnCancel(nil, 'duplicate')
	elseif #self.Active >= self.Max then
		return info.OnCancel and info.OnCancel(nil, 'overflow')
	elseif info.exclusive then
		for i, f in ipairs(CopyTable(self.Active, true)) do
			f:Release('override')
		end
	elseif info.cancels then
		local f = self:GetActive(info.cancels)
		if f then f:Release('override') end
	end

	local f = self:Super(Popup):New(UIParent)
	f.text, f.button1, f.button2, f.hideOnEscape = info.text, info.button1, info.button2, f.hideOnEscape
	f.id, f.editBoxText = id, '' and (info.editBoxText or info.hasEditBox)
	f:SetBackdrop('DialogBorderDarkTemplate')
	f:SetCall('OnAccept', info.OnAccept)
	f:SetCall('OnCancel', info.OnCancel)
	f:SetChildren(self.Populate)
	f:Show()

	local icon = info.icon or (info.showAlert and 357854) or (info.showAlertGear and 357855)
	if tonumber(icon) then
		f.Icon:SetTexture(icon)
	else
		f.Icon:SetAtlas(icon)
	end

	tinsert(self.Active, f)
	self:Organize()
	return f
end

function Popup:Populate()
	if self.text then
		self:Add('Header', self.text, GameFontHighlightLeft):SetJustifyH('CENTER')
	end

	if self.editBoxText then
		local edit = self:Add('BoxEdit', nil, self.editBoxText)
		edit.centered, edit.top, edit.left, edit.right, edit.bottom = true, -6,-3,-3,-3
		edit:SetWidth(240)
	end

	if self.button1 or self.button2 then
		local buttons = self:Add('Group', function(group)
			if self.button1 then
				local b = group:Add('RedButton', self.button1)
				b:SetSize(118, 20)
				b:SetCall('OnClick', function()
					self:FireCalls('OnAccept')
					self:Release()
				end)
				b.right = 0
			end

			if self.button2 then
				local b = group:Add('RedButton', self.button2)
				b:SetCall('OnClick', function()
					self:FireCalls('OnCancel')
					self:Release()
				end)
				b:SetSize(118, 20)
				b.right = 0
			end
		end)

		buttons.centered, buttons.top = true, 2
		buttons:SetWidth(136 * ((self.button1 and 1 or 0) + (self.button2 and 1 or 0)))
		buttons:SetOrientation('HORIZONTAL')
	end
end

function Popup:Release(reason)
	local _, i = self:GetActive(self)
	if i then
		tremove(self.Active, i)

		self:FireCalls('OnCancel', nil, reason or 'closed')
		self:Super(Popup):Release()
		self:Organize()
		self:Hide()
	end
end


--[[ Events ]]--

function Popup:OnKeyDown(key)
	if self.hideOnEscape ~= false and GetBindingFromClick(key) == 'TOGGLEGAMEMENU' then
		self:SetPropagateKeyboardInput(false)
		return self:Release()
	end

	self:SetPropagateKeyboardInput(true)
end