-- Copyright © 2008-2024 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

-- This module is based on Advice.lua, but aims to look like a "News"
-- bulletin, however, it's not actionable beyond learning / lore. This
-- module publishes obituareis to.

local Engine = require 'Engine'
local Event = require 'Event'
local Game = require 'Game'
local Lang = require 'Lang'
local Rand = require 'Rand'
local Serializer = require 'Serializer'

local debugView = require 'pigui.views.debug'
local ui = require 'pigui'

local l = Lang.GetResource("module-newsobituary")
local ln = Lang.GetResource("module-newseventcommodity")

-- ln.NEWSPAPER_CIW
-- ln.NEWSPAPER_FED
-- ln.NEWSPAPER_IMP
-- ln.NEWSPAPER_IND_0
-- ln.NEWSPAPER_IND_9

-- ln.ADTITLE_1
-- ln.ADTITLE_2
-- ln.ADTITLE_3
-- ln.ADTITLE_4

-- number of adverts
local news_indicies = 9

-- probability to have one advice/rumour (per BBS):
local news_probability = .2

-- Hold all different types of advice/rumours available:
local flavours = {}

-- Hold the ones published on the BBS:
local ads = {}

-- Holds flavour index to all active news (of this module)
-- xxx to replace the ads
local active_news = {}

local interacted = {}

-- add Traveller strings to flavours-table:
for i = 1,news_indicies do
	table.insert(flavours, {
		headline = l["NEWS_" .. i .. "_HEADLINE"],
		bodytext = l["NEWS_" .. i .. "_BODYTEXT"],
		description = l["NEWS_" .. i .. "_DESCRIPTION"],
	})

	-- keep track of if we have clicked the advert before or not
	table.insert(interacted, false)
end


local createNewsEvent = function (date)
	-- xxx date fix?

	local n = Engine.rand:Integer(1, news_indicies)-1

	for i, n in pairs(flavours) do
		if not interacted[i] then
			table.insert(active_news, i)
			interacted[i] = true
		end
	end
end


-- Print ad to BBS
local onChat = function (form, ref, option)
	form:Clear()
	form:SetTitle(flavours[ref].headline)

	local faction = Game.system.faction.name

	if option == 0 then
		form:SetMessage(flavours[ref].bodytext)
		interacted[ref] = true
	end
end

local onDelete = function (ref)
	ads[ref] = nil
end

-- when we enter a system the BBS is created and this function is called
local onCreateBB = function (station)
	local rand = Rand.New(station.seed)
	-- local n = rand:Integer(1, #flavours)

	local ad = {
		station = station,
	}

	-- only create one per BBS, with advice_probability
	local ref

	-- if rand:Number() < news_probability or true then --xxx
	for i=1,news_indicies do
		n = i
		ad.n = i
		print("N: ", n, i)
		ref = station:AddAdvert({
			title       = flavours[n].headline,
			description = flavours[n].description,
			icon        = "news",
			onChat      = onChat,
			onDelete    = onDelete})
		ads[ref] = ad
	end
end


local loaded_data

local onGameStart = function ()
	ads = {}

	if not loaded_data or not loaded_data.ads then return end

	for k,ad in pairs(loaded_data.ads or {}) do
		local ref = ad.station:AddAdvert({
			title       = flavours[ad.n].headline,
			description = flavours[ad.n].description,
			icon        = "news",
			onChat      = onChat,
			onDelete    = onDelete})
		ads[ref] = ad
	end

	loaded_data = nil
end

local serialize = function ()
	return { ads = ads }
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onGameStart", onGameStart)

Serializer:Register("Obituary", serialize, unserialize)


debugView.registerTab(
	"Obituary", function ()
		if Game.player == nil then return end
		if not ui.beginTabItem("Obituary") then return end

		if ui.button("Render", Vector2(100, 0)) then
			createNewsEvent(0)
		end

		for i, n in pairs(interacted) do
			ui.text("Flavour:\t" ..  i .. "\t" .. tostring(interacted[i]))
		end
end)
