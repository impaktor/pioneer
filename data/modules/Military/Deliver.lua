-- Copyright © 2008-2023 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Engine = require 'Engine'
local Lang = require 'Lang'
local Game = require 'Game'
local Space = require 'Space'
local Comms = require 'Comms'
local Event = require 'Event'
local Mission = require 'Mission'
local Format = require 'Format'
local Rand = require 'Rand'
local Serializer = require 'Serializer'
local Character = require 'Character'
local Equipment = require 'Equipment'
local ShipDef = require 'ShipDef'
local Ship = require 'Ship'
local utils = require 'utils'

local lm = Lang.GetResource("module-military")
local ld = Lang.GetResource("module-military-delivery")

local lc = Lang.GetResource 'core'

-- don't produce missions for further than this many light years away
local max_delivery_dist = 30
-- typical time for travel to a system max_delivery_dist away
--	Irigi: ~ 4 days for in-system travel, the rest is FTL travel time
local typical_travel_time = (1.6 * max_delivery_dist + 4) * 24 * 60 * 60
-- typical reward for delivery to a system max_delivery_dist away
local typical_reward = 25 * max_delivery_dist
-- typical reward for delivery to a local port
local typical_reward_local = 25
-- Minimum amount paid for very close deliveries
local min_local_dist_pay = 8

local flavours = {
	{
		urgency = 0,      -- 0
		medal = nil,
	}, {
		urgency = 0,      -- 1
		medal = nil,
	}, {
		urgency = 0.1,    -- 2
		medal = nil,
	}, {
		urgency = 0.2,    -- 3
		medal = nil,
	}, {
		urgency = 0.3,    -- 4
		medal = nil,
	}, {
		urgency = 0.3,    -- 5
		medal = nil,
	}, {
		urgency = 0.3,    -- 6
		medal = nil,
	}, {
		urgency = 0.4,    -- 7
		medal = nil,
	}, {
		urgency = 0.6,    -- 8
		medal = nil,
	}, {
		urgency = 0.7,    -- 9
		medal = nil,
	}, {
		urgency = 07,    -- 10
		medal = 0,
	}, {
		urgency = 0.8,   -- 11
		medal = 1,
	   }
}

-- add strings to flavours
for i = 1,#flavours do
	local f = flavours[i]
	f.adtitle       = ld["FLAVOUR_ADTITLE"]
	f.adtext        = ld["FLAVOUR_ADTEXT"]
	f.introtext     = ld["FLAVOUR_" .. i-1 .. "_INTROTEXT_FIRST"] .. ld["FLAVOUR_INTROTEXT_REST"]
	f.successmsg    = lm["MSG_SUCCESS"]
	f.failuremsg    = lm["MSG_FAILURE"]
end

local ads = {}
local missions = {}

local isQualifiedFor = function(reputation, ad)
	-- delivery missions are allways qualified
	return true
end

local onChat = function (form, ref, option)
	local ad = ads[ref]

	form:Clear()

	if option == -1 then
		form:Close()
		return
	end

	form:SetFace(ad.client)

	form:AddNavButton(ad.location)

	if option == 0 then

		local sys   = ad.location:GetStarSystem()
		local sbody = ad.location:GetSystemBody()

		local introtext = string.interp(flavours[ad.flavour].introtext, {
			type     = "FOO",
			cash     = Format.Money(ad.reward,false),
			starport = sbody.name,
			system   = sys.name,
			sectorx  = ad.location.sectorX,
			sectory  = ad.location.sectorY,
			sectorz  = ad.location.sectorZ,
			dist     = string.format("%.2f", ad.dist),
			date     = Format.Date(ad.due),
		})
		form:SetMessage(introtext)

	elseif option == 1 then
		form:SetMessage(lm.WHAT_IF_FAIL_A)

	elseif option == 2 then
		form:SetMessage(lm.NOT_ANY_MORE_THAN_USUAL)

	elseif option == 3 then
		form:RemoveAdvertOnClose()

		ads[ref] = nil

		local mission = {
			type	 = "MilitaryDelivery",
			client	 = ad.client,
			location = ad.location,
			reward	 = ad.reward,
			due	 = ad.due,
			flavour	 = ad.flavour
		}

		table.insert(missions,Mission.New(mission))

		form:SetMessage(string.interp(ld.EXCELLENT_ACCEPT, {
			cash     = Format.Money(ad.reward, false),
			system   = sys.name,
		}))

		return
	end

	form:AddOption(lm.WHAT_IF_FAIL_Q, 1)
	form:AddOption(lm.WILL_I_BE_IN_ANY_DANGER, 2)
	form:AddOption(lm.COULD_YOU_REPEAT_THE_ORIGINAL_REQUEST, 0)
	form:AddOption(lm.OK_AGREED, 3)
end

local onDelete = function (ref)
	ads[ref] = nil
end

local isEnabled = function (ref)
	return ads[ref] ~= nil and isQualifiedFor(Character.persistent.player.reputation, ads[ref])
end

local nearbysystems

local findNearbyMilitaryDestinations = function (station, minDist, maxDist)
	local nearbystations = {}
	for _,s in ipairs(Game.system:GetStationPaths()) do
		if s ~= station.path then
			local dist = station:DistanceTo(Space.GetBody(s.bodyIndex))
			if dist >= minDist and dist <= maxDist then
				table.insert(nearbystations, { s, dist })
			end
		end
	end
	return nearbystations
end

local placeAdvert = function (station, ad)
	ad.desc = string.interp(flavours[ad.flavour].adtext, {
		system	= ad.location:GetStarSystem().name,
		cash	= Format.Money(ad.reward,false),
		starport = ad.location:GetSystemBody().name,
	})

	local ref = station:AddAdvert({
		title       = flavours[ad.flavour].adtitle,
		description = ad.desc,
		icon        = ad.urgency >=  0.8 and "delivery_urgent" or "delivery",
		due         = ad.due,
		reward      = ad.reward,
		location    = ad.location,
		onChat      = onChat,
		onDelete    = onDelete,
		isEnabled   = isEnabled })
	ads[ref] = ad
end

-- return statement nil if no advert created
local makeAdvert = function (station, militarystations)
	local reward, due, location, nearbysystem, dist
	local rand = Rand.New(station.seed)
	local client = Character.New({ title = "Ubersturmfuhrer" }, rand)

	local flavour = Engine.rand:Integer(1,#flavours)

	local urgency = flavours[flavour].urgency

	if nearbysystems == nil then
		nearbysystems = Game.system:GetNearbySystems(max_delivery_dist, function (s) return #s:GetStationPaths() > 0 end)
	end
	if #nearbysystems == 0 then return nil end
	nearbysystem = nearbysystems[Engine.rand:Integer(1,#nearbysystems)]
	dist = nearbysystem:DistanceTo(Game.system)
	local militarystations = nearbysystem:GetStationPaths()
	location = militarystations[Engine.rand:Integer(1,#militarystations)]
	reward = ((dist / max_delivery_dist) * typical_reward * (1.5+urgency) * Engine.rand:Number(0.8,1.2))
	due = Game.time + ((dist / max_delivery_dist) * typical_travel_time * (1.5-urgency) * Engine.rand:Number(0.9,1.1))
	reward = utils.round(reward, 5)

	local ad = {
		station		= station,
		flavour		= flavour,
		client		= client,
		location	= location,
		localdelivery = flavours[flavour].localdelivery,
		dist        = dist,
		due			= due,
		urgency		= urgency,
		reward		= reward,
		faceseed	= Engine.rand:Integer(),
	}

	placeAdvert(station, ad)

	-- successfully created an advert, return non-nil
	return ad
end

local onCreateBB = function (station)
	if nearbysystems == nil then
		nearbysystems = Game.system:GetNearbySystems(max_delivery_dist, function (s) return #s:GetStationPaths() > 0 end)
	end

	local num = Engine.rand:Integer(0, math.ceil(Game.system.population)) + 10      -- XXXX

	for i = 1,num do
		local ad = makeAdvert(station, nearbysystems)
	end
end

local onUpdateBB = function (station)
	for ref,ad in pairs(ads) do
		if flavours[ad.flavour].localdelivery then
			if ad.due < Game.time + 2*60*60*24 then -- two day timeout for locals
				ad.station:RemoveAdvert(ref)
			end
		else
			if ad.due < Game.time + 5*60*60*24 then -- five day timeout for inter-system
				ad.station:RemoveAdvert(ref)
			end
		end
	end
	if Engine.rand:Integer(12*60*60) < 60*60 then -- roughly once every twelve hours
		makeAdvert(station)
	end
end

local onEnterSystem = function (player)
	if (not player:IsPlayer()) then return end

	local syspath = Game.system.path

	for ref,mission in pairs(missions) do
		if mission.status == "ACTIVE" and Game.time > mission.due then
			mission.status = 'FAILED'
		end
	end
end

local onLeaveSystem = function (ship)
	if ship:IsPlayer() then
		nearbysystems = nil
	end
end

local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end

	for ref,mission in pairs(missions) do

		if mission.location == station.path then
			local oldRank = Character.persistent.player.rank
			if Game.time > mission.due then
				Comms.ImportantMessage(flavours[mission.flavour].failuremsg, mission.client.name)
				Character.persistent.player.rank = oldRank - 1
			else
				Comms.ImportantMessage(flavours[mission.flavour].successmsg, mission.client.name)
				player:AddMoney(mission.reward)
				Character.persistent.player.rank = oldRank + 1
			end

			mission:Remove()
			missions[ref] = nil

		elseif mission.status == "ACTIVE" and Game.time > mission.due then
			mission.status = 'FAILED'
		end

	end
end

local loaded_data

local onGameStart = function ()
	ads = {}
	missions = {}

	if not loaded_data or not loaded_data.ads then return end

	for k,ad in pairs(loaded_data.ads) do
		placeAdvert(ad.station, ad)
	end

	missions = loaded_data.missions

	loaded_data = nil
end

local buildMissionDescription = function(mission)
	local ui = require 'pigui'
	local desc = {}

	local dist = Game.system and string.format("%.2f", Game.system:DistanceTo(mission.location)) or "???"

	desc.description = (flavours[mission.flavour].introtext):interp({
		name		= mission.client.name,
		starport	= mission.location:GetSystemBody().name,
		system		= mission.location:GetStarSystem().name,
		sectorx		= mission.location.sectorX,
		sectory		= mission.location.sectorY,
		sectorz		= mission.location.sectorZ,
		cash		= ui.Format.Money(mission.reward,false),
		dist		= dist})

	desc.details = {
		{ lm.SPACEPORT, mission.location:GetSystemBody().name },
		{ lm.SYSTEM, ui.Format.SystemPath(mission.location) },
		{ lm.DEADLINE, ui.Format.Date(mission.due) },
		{ lm.DISTANCE, dist.." "..lc.UNIT_LY }
	}

	desc.location = mission.location
	desc.client = mission.client

	return desc;
end

local onGameEnd = function ()
	nearbysystems = nil
end

local serialize = function ()
	return { ads = ads, missions = missions }
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onLeaveSystem", onLeaveSystem)
Event.Register("onShipDocked", onShipDocked)
Event.Register("onGameStart", onGameStart)
Event.Register("onGameEnd", onGameEnd)

Mission.RegisterType('MilitaryDelivery', ld.DELIVERY, buildMissionDescription)

-- Doesn't need to be same as Mission.RegisterType (I think)
Serializer:Register("MilitaryDelivery", serialize, unserialize)
