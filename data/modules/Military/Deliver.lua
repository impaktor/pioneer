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
local utils = require 'utils'
local PlayerState = require 'PlayerState'
local MissionUtils = require 'modules.MissionUtils'

local lc = Lang.GetResource 'core'
local lf = Lang.GetResource("factions")

local lm = Lang.GetResource("module-military")
local ld = Lang.GetResource("module-military-delivery")

-- for building translation keys:
local faction_short = {
	["Solar Federation"] = "FED",
	["Commonwealth of Independent Worlds"] = "CIW",
	["Tolan Kingdom"] = "TOLAN",
	["Haber Corporation"] = "HABER",
}

-- don't produce missions for further than this many light years away
local max_delivery_dist = 30
-- typical time for travel to a system max_delivery_dist away
--	Irigi: ~ 4 days for in-system travel, the rest is FTL travel time
local typical_travel_time = (1.6 * max_delivery_dist + 4) * 24 * 60 * 60
-- typical reward for delivery to a system max_delivery_dist away
local typical_reward = 25 * max_delivery_dist
-- typical reward for delivery to a local port

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
		urgency = 0.7,    -- 10
		medal = 0,
	}, {
		urgency = 0.8,   -- 11
		medal = 1,
	   }
}

-- add strings to flavours
for i = 1,#flavours do
	local f = flavours[i]
	f.adtext        = ld["FLAVOUR_ADTEXT"]
	f.introtext     = ld["FLAVOUR_" .. i-1 .. "_INTROTEXT_FIRST"] .. ld["FLAVOUR_INTROTEXT_REST"]
	f.successmsg    = ld["MSG_SUCCESS"]
	f.failuremsg    = ld["MSG_FAILURE"]
end

local ads = {}
local missions = {}

local isQualifiedFor = function(rank, ad)
	return
		(ad.urgency < 0.1) or
		(ad.urgency < 0.4 and rank >= 4) or
		(ad.urgency < 0.6 and rank >= 8) or
		(rank >= 16)
end

local onChat = function (form, ref, option)
	local ad = ads[ref]

	form:Clear()

	if option == -1 then
		form:Close()
		return
	end

	form:SetFace(ad.client)

	form:AddNavButton(ad.destination)

	local sys = ad.destination:GetStarSystem()

	if option == 0 then

		local introtext = string.interp(flavours[ad.flavour].introtext, {
			starport = ad.destination:GetSystemBody().name,
			system   = sys.name,
			sectorx  = ad.destination.sectorX,
			sectory  = ad.destination.sectorY,
			sectorz  = ad.destination.sectorZ,
			dist     = string.format("%.2f", ad.dist),
			date     = Format.Date(ad.due),
			cash     = Format.Money(ad.reward,false),
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
			type        = "MilitaryDelivery",
			client      = ad.client,
			destination = ad.destination,
			reward      = ad.reward,
			due         = ad.due,
			faction     = faction_short[sys.faction.name],
			flavour     = ad.flavour
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

	if ad.client.female then
		form:AddOption(lm.OK_AGREED_MADAM, 3)
	else
		form:AddOption(lm.OK_AGREED_SIR, 3)
	end
end

local onDelete = function (ref)
	ads[ref] = nil
end

local isEnabled = function (ref)
	if ads[ref] == nil then
		return false
	end
	local rank = Character.persistent.player.rank[ads[ref].faction]
	return isQualifiedFor(rank, ads[ref])
end

local nearbysystems

local findNearbyMilitaryDestinations = function (station, minDist, maxDist)
	local nearbystations = {}
	for _,s in ipairs(Game.system:GetStationPaths()) do
		if s ~= station.path then
			-- station.techLevel
			-- path:GetSystemBody()

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
		system	= ad.destination:GetStarSystem().name,
		cash	= Format.Money(ad.reward,false),
		starport = ad.destination:GetSystemBody().name,
	})

	local military_name = string.upper(lf['MILITARY_NAME_' .. ad.faction])

	local ref = station:AddAdvert({
		title       = military_name .. ": " .. lf["FACTION_RECRUITMENT_" .. ad.faction],
		description = ad.desc,
		icon        = ad.urgency >= 0.8 and "delivery_urgent" or "delivery",
		due         = ad.due,
		reward      = ad.reward,
		destination = ad.destination,
		onChat      = onChat,
		onDelete    = onDelete,
		isEnabled   = isEnabled })
	ads[ref] = ad
end

-- return statement nil if no advert created
local makeAdvert = function (station, militarystations)
	local reward, due, destination, nearbysystem, dist
	local rand = Rand.New(station.seed)
	local client = Character.New({ title = "Ubersturmfuhrer" }, rand) --- xxx always same sex / station?

	local flavour = Engine.rand:Integer(1,#flavours)

	local urgency = flavours[flavour].urgency


	local military_ports = MissionUtils.GetNearbyStationPaths(Game.system, 30, nil, function(station)
																  -- station is station_path:GetSystemBody()
																  print("STATION type: ", type(station))
																  print("STATION.name: ", station.name)	-- should be label for starport
																  print("STATION.type: ", station.type)	-- STARPORT_SURFACE
																  print("STATION.superType: ", station.superType)	-- STARPORT
																  print("station.parent:", station.parent)	--  userdata [SystemBody]
																  print("station.parent.name:", station.parent.name)
																  print("station.techLevel:", station.techLevel)	-- nil
																  return station.techLevel == 11 end, true)
	for k, v in pairs(military_ports) do
		print("FILTER:", k, v)
	end

	if nearbysystems == nil then
		nearbysystems = Game.system:GetNearbySystems(max_delivery_dist, function (s) return #s:GetStationPaths() > 0 end)
	end
	if #nearbysystems == 0 then return nil end
	nearbysystem = nearbysystems[Engine.rand:Integer(1,#nearbysystems)]
	dist = nearbysystem:DistanceTo(Game.system)
	local militarystations = nearbysystem:GetStationPaths()
	destination = militarystations[Engine.rand:Integer(1,#militarystations)]
	reward = ((dist / max_delivery_dist) * typical_reward * (1.5+urgency) * Engine.rand:Number(0.8,1.2))
	due = Game.time + ((dist / max_delivery_dist) * typical_travel_time * (1.5-urgency) * Engine.rand:Number(0.9,1.1))
	reward = utils.round(reward, 5)

	local faction = station.path:GetStarSystem().faction

	local ad = {
		station		= station,
		flavour		= flavour,
		client		= client,
		destination	= destination,
		dist        = dist,
		due			= due,
		urgency		= urgency,
		reward		= reward,
		faceseed    = Engine.rand:Integer(),
		faction     = faction_short[faction.name],
	}

	placeAdvert(station, ad)

	-- successfully created an advert, return non-nil
	return ad
end

local onCreateBB = function (station)

	local current_faction = station.path:GetSystemBody().system.faction
	print("faction1?", current_faction.name)
	local has_military = false

	for key, _ in pairs(faction_short) do
		print("key", key, current_faction.name, has_military)
		if current_faction.name == key then
			has_military = true
			print("BREAK")
			break
		end
	end

	if not has_military then
		return
	end

	if nearbysystems == nil then
		nearbysystems = Game.system:GetNearbySystems(max_delivery_dist, function (s) return #s:GetStationPaths() > 0 end)
	end

	--- scale to how much "military" is on the base
	local num = Engine.rand:Integer(0, math.ceil(Game.system.population)) + 10

	for _ = 1,num do
		makeAdvert(station, nearbysystems)
	end
end

local onUpdateBB = function (station)
	for ref,ad in pairs(ads) do
		if ad.due < Game.time + 5*60*60*24 then -- five day timeout for inter-system
			ad.station:RemoveAdvert(ref)
		end
	end
	if Engine.rand:Integer(12*60*60) < 60*60 then -- roughly once every twelve hours
		makeAdvert(station)
	end
end

local onEnterSystem = function (player)
	if (not player:IsPlayer()) then return end

	for _, mission in pairs(missions) do
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

local was_promoted = function(rank)
	local x = rank ^ (1 / 4)

	if x > 12 then return false end

	for i = 0, 12 do
		if x % i == 0 then
			return true
		end
	end
	return false
end

local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end

	for ref,mission in pairs(missions) do

		if mission.destination == station.path then
			local oldRank = Character.persistent.player.rank[mission.faction]
			if Game.time > mission.due then
				Comms.ImportantMessage(flavours[mission.flavour].failuremsg, mission.client.name)
				Character.persistent.player.rank[mission.faction] = oldRank - 1
			else
				Comms.ImportantMessage(flavours[mission.flavour].successmsg, mission.client.name)
				PlayerState.AddMoney(mission.reward)
				Character.persistent.player.rank[mission.faction] = oldRank + 1

				if was_promoted(Character.persistent.player.rank[mission.faction]) then
					Comms.ImportantMessage(lf["MILITARY_PROMOTION_" .. mission.faction], mission.client.name)
				end

				if flavours[mission.flavour].medal then
					local medal = ld["MEDAL_" .. flavours[mission.flavour].medal .. "_" .. mission.faction]
					Character.persistent.player.medals[medal] = true
					Comms.ImportantMessage(ld['MEDAL_AWARDED_' .. mission.faction], mission.client.name)
				end
			end

			mission:Remove()
			missions[ref] = nil
		end

		if mission.status == "ACTIVE" and Game.time > mission.due then
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

	local dist = Game.system and string.format("%.2f", Game.system:DistanceTo(mission.destination)) or "???"

	desc.description = (flavours[mission.flavour].introtext):interp({
		starport	= mission.destination:GetSystemBody().name,
		system		= mission.destination:GetStarSystem().name,
		sectorx		= mission.destination.sectorX,
		sectory		= mission.destination.sectorY,
		sectorz		= mission.destination.sectorZ,
		dist		= dist,
		date        = Format.Date(mission.due),
		cash		= ui.Format.Money(mission.reward,false),
})

	desc.details = {
		{ lm.SPACEPORT, mission.destination:GetSystemBody().name },
		{ lm.SYSTEM, ui.Format.SystemPath(mission.destination) },
		{ lm.DEADLINE, ui.Format.Date(mission.due) },
		{ lm.DISTANCE, dist.." "..lc.UNIT_LY }
	}

	desc.destination = mission.destination
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
