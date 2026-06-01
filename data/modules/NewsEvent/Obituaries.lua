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

local eventProbability = 0.2 -- probability of news generated when entering system
local maxNumberNews = 1      -- max one (obituary) news at any given time
local minTime = 2592000      -- no news the first 1 month of a new game (sec)

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

	local faction = Game.system.faction.name
	local title = NewsEvent:get_title(faction)

	-- local date = Game.time - Engine.rand:Number(0.1,0.9)*(*24*3600)
	-- Format.DateOnly(date)

	form:SetTitle(title)

	if option == 0 then
		form:SetMessage(flavours[ad.n].bodytext)
		interacted[ad.n] = true
	end
end

local onDelete = function (ref)
	ads[ref] = nil
end

local onCreateBB = function (station)
	-- create ads, (if any news)

	for i, _ in pairs(news) do
		local idx = news[i].flavour_id
		local ref = station:AddAdvert({
			title       = flavours[idx].headline,
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
	NewsEvent:checkOldNews(news)

	-- publication date, between 10 and 1 days ago
	local date = Game.time - (60*60*24) * Engine.rand:Number(0.1,0.9)

	-- create a news event with low probability
	if Engine.rand:Number(0,1) < eventProbability and
		#news < maxNumberNews and Game.GetStartTime() > minTime then
		createNewsEvent(date)
	end
end


local loaded_data

local onGameStart = function ()
	ads = {}

	if not loaded_data or not loaded_data.ads then return end

	for _, ad in pairs(loaded_data.ads or {}) do
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


local idx = 1
debugView.registerTab("Obituary", {
	icon = ui.theme.icons.news,
	label = "News Obituary",
	show = function() return Game.player ~= nil end,
	draw = function ()
		ui.text("BBS Obituary debug")

		ui.text("#flavour: ".. #flavours)
		ui.text("#ads: " .. #ads)                   -- 0 ?
		ui.text("#news: " .. #news)                 -- 0 ?
		ui.text("#interacted: ".. #interacted)
		ui.text("news_indicies: ".. news_indicies)

		if ui.button("Make news " .. idx, Vector2(100, 0)) then
			local newsevent = {
				flavour_id = idx,
				expires = 0, --- xxx
				publication_date = 0 ---xxx
			}
			table.insert(news, newsevent)
			idx = idx + 1
		end

		if idx == news_indicies then
			idx = 1
		end

		for i, _ in pairs(interacted) do
			ui.text("Interacted with flavour:\t" ..  i .. "\t" .. tostring(interacted[i]))
		end
	end
})
