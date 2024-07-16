-- Copyright © 2008-2025 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

-- This module is based on Advice.lua, but aims to look like a "News"
-- bulletin, however, it's not actionable beyond learning / lore. This
-- module publishes obituareis to.

local Engine = require 'Engine'
local Event = require 'Event'
local Game = require 'Game'
local Lang = require 'Lang'
local Serializer = require 'Serializer'
local NewsEvent = require 'modules.NewsEvent.NewsEvent'

local debugView = require 'pigui.views.debug'
local ui = require 'pigui'

local l = Lang.GetResource("module-newsobituary")

-- number of adverts, indexed in en.json 1,...,9
local news_indicies = 9

-- Hold all different types of advice/rumours available:
local flavours = {}

-- Hold the ones published on the BBS:
local ads = {}

-- Active news to be displayed on all BBS-es
local news = {}

-- track if player has viewed this news before
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

	-- only one news of this flavour at a time
	if #news > 0 then return end

	-- create news with some probability (depending on who triggers this method?)
	if Engine.rand:Number(0, 1) > 0.5 then return	end

	-- determine which flavour of news to generate
	local n = Engine.rand:Integer(1, #flavours)

	local newsevent = {
		flavour_id = n,
		expires = 0, --- xxx
		publication_date = 0 ---xxx
	}

	table.insert(news, newsevent)
end


-- Print ad to BBS
local onChat = function (form, ref, option)
	local ad = ads[ref]

	form:Clear()
	form:SetTitle(flavours[ad.n].headline)

	local faction = Game.system.faction.name

	if option == 0 then
		form:SetMessage(flavours[ad.n].bodytext)
		interacted[ad.n] = true
	end
end

local onDelete = function (ref)
	ads[ref] = nil
end

-- when we enter a system the BBS is created and this function is called
local onCreateBB = function (station)
	-- create ads, (if any news)
	for i, n in pairs(news) do
		local idx = news[i].flavour_id
		local ref = station:AddAdvert({
			title       = flavours[idx].title,
			description = flavours[idx].description,
			icon        = "news",
			onChat      = onChat,
			onDelete    = onDelete
			})
		-- xxx möjligen fel
		ads[ref] = {n=idx, station=station}
	end
end


-- onPlayerDocked
local onEnterSystem = function (player)
	if (not player:IsPlayer()) then return end

	-- remove old news before making new
	NewsEvent.checkOldNews(news)

	-- publication date, between 10 and 1 days ago
	local date = NewsEvent.event_date()

	-- create a news event with low probability
	if Engine.rand:Number(0,1) < NewsEvent.eventProbability and
		#news < NewsEvent.maxNumberNews and Game.GetStartTime() > NewsEvent.minTime then
		createNewsEvent(date)
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
Event.Register("onEnterSystem", onEnterSystem)
Serializer:Register("Obituary", serialize, unserialize)


debugView.registerTab("Obituary", {
	icon = ui.theme.icons.news,
	label = "News Obituary",
	show = function() return Game.player ~= nil end,
	draw = function ()
		ui.text("BBS Obituary debug")

		ui.text("falvour: ".. #flavours)
		ui.text("ads: " .. #ads)                   -- 0 ?
		ui.text("news: " .. #news)                 -- 0 ?
		ui.text("interacted: ".. #interacted)
		ui.text("news_indicies: ".. news_indicies)

		if ui.button("Render", Vector2(100, 0)) then
			createNewsEvent(0)
		end

		for i, n in pairs(interacted) do
			ui.text("Flavour:\t" ..  i .. "\t" .. tostring(interacted[i]))
		end
	end
})
