-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Engine = import("Engine")
local Lang = import("Lang")
local Game = import("Game")
local Space = import("Space")
local Comms = import("Comms")
local Event = import("Event")
local Mission = import("Mission")
local NameGen = import("NameGen")
local Format = import("Format")
local Serializer = import("Serializer")
local Character = import("Character")
local utils = import("utils")

local InfoFace = import("ui/InfoFace")

local l = Lang.GetResource("module-delivermessage")

-- Get the UI class
local ui = Engine.ui

-- don't produce missions for further than this many light years away
local max_delivery_dist = 30
-- typical time for travel to a system max_delivery_dist away
--	Irigi: ~ 4 days for in-system travel, the rest is FTL travel time
local typical_travel_time = (2.2 * max_delivery_dist + 4) * 24 * 60 * 60
-- typical reward for delivery to a system max_delivery_dist away
local typical_reward = 25 * max_delivery_dist

-- the number of different flavours of text strings to choose from:
local n_flavour_successmsg = 4
local n_flavour_failmsg = 3
local n_flavour_messages = 70
local n_flavour_adtext = 7
local n_flavour_missiontxt = 6

local ads = {}
local missions = {}


local isQualifiedFor = function(reputation, ad)
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

	if option == 0 then
		local introtext = string.interp(l[ad.flavour], {
			client    = ad.client.name,
			recipient = ad.recipient.name,
			message   = l[ad.message],
			cash      = Format.Money(ad.reward),
			starport  = ad.location:GetSystemBody().name,
			system    = ad.location:GetStarSystem().name,
			sectorx   = ad.location.sectorX,
			sectory   = ad.location.sectorY,
			sectorz   = ad.location.sectorZ
		})
		form:SetMessage(introtext)

	elseif option == 1 then
		form:SetMessage(l.IT_MUST_BE_DELIVERED_BY..Format.Date(ad.due))

	elseif option == 2 then
		form:RemoveAdvertOnClose()

		ads[ref] = nil

		local mission = {
			type	  = "DeliverMessage",
			client	  = ad.client,
			message   = ad.message,
			recipient = ad.recipient,
			location  = ad.location,
			reward	  = ad.reward,
			due		  = ad.due,
			flavour	  = ad.flavour,
		}

		-- cash      = Format.Money(mission.reward),
		-- dist      = dist})

		table.insert(missions,Mission.New(mission))

		form:SetMessage(l.AGREED)

		return
	end

	form:AddOption(l.COULD_YOU_REPEAT_THE_ORIGINAL_REQUEST, 0)
	form:AddOption(l.HOW_SOON_MUST_IT_BE_DELIVERED, 1)
	form:AddOption(l.OK_AGREED, 2)
end


local onDelete = function (ref)
	ads[ref] = nil
end


local nearbysystems

local findNearbyStations = function (station, minDist)
	local nearbystations = {}
	for _,s in ipairs(Game.system:GetStationPaths()) do
		if s ~= station.path then
			local dist = station:DistanceTo(Space.GetBody(s.bodyIndex))
			if dist >= minDist then
				table.insert(nearbystations, { s, dist })
			end
		end
	end
	return nearbystations
end


-- return statement is nil if no advert was created, else it is bool:
local makeAdvert = function (station)
	if nearbysystems == nil then
		nearbysystems = Game.system:GetNearbySystems(max_delivery_dist, function (s) return #s:GetStationPaths() > 0 end)
	end
	if #nearbysystems == 0 then return nil end
	local nearbysystem = nearbysystems[Engine.rand:Integer(1,#nearbysystems)]
	local dist = nearbysystem:DistanceTo(Game.system)
	local stations = nearbysystem:GetStationPaths()
	local location = stations[Engine.rand:Integer(1,#stations)]
	local reward = ((dist / max_delivery_dist) * typical_reward  * Engine.rand:Number(0.8,1.2))
	local due = Game.time + ((dist / max_delivery_dist) * typical_travel_time * Engine.rand:Number(0.9,1.1))

	-- compose a flavour
	local mission_text = "FLAVOUR_"..Engine.rand:Integer(1,n_flavour_missiontxt).."_MISSIONTXT"
	local message      = "MESSAGE_"..Engine.rand:Integer(1, n_flavour_messages)

	local ad = {
		flavour       = mission_text,    -- Contract "frame"
		message       = message,         -- which message to pair the flavour up with
		station		  = station,         -- station the BBS advert is at
		client		  = Character.New(), -- sender
		recipient     = Character.New(), -- receiver
		location	  = location,        -- target station
		dist          = dist,
		due			  = due,
		reward		  = reward,
		faceseed	  = Engine.rand:Integer(),
	}

	ad.desc = string.interp(l["ADTEXT_"..Engine.rand:Integer(1, n_flavour_adtext)], {
		system	 = nearbysystem.name,
		cash	 = Format.Money(ad.reward),
		starport = ad.location:GetSystemBody().name, -- xxx augh to be system?
	})

	local ref = station:AddAdvert({
		description = ad.desc,
		icon        = "delivery",
		onChat      = onChat,
		onDelete    = onDelete })
	ads[ref] = ad
end


local onCreateBB = function (station)
	local num = Engine.rand:Integer(0, math.ceil(Game.system.population))
	for i = 1,num do
		makeAdvert(station)
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
			local reward = 0.5

			local deliverMessage = string.interp(l["FINALMESSAGE"], {
									client    = mission.client.name,
									recipient = mission.recipient.name,
									message   = l[mission.message] })
			Comms.Message(deliverMessage)

			local oldReputation = Character.persistent.player.reputation
			if Game.time > mission.due then
				Comms.ImportantMessage(l["FAILUREMSG_"..Engine.rand:Integer(1,n_flavour_failmsg)], mission.recipient.name)
				Character.persistent.player.reputation = Character.persistent.player.reputation - reward
			else
				Comms.ImportantMessage(l["SUCCESSMSG_"..Engine.rand:Integer(1,n_flavour_successmsg)], mission.recipient.name)
				player:AddMoney(mission.reward)
				Character.persistent.player.reputation = Character.persistent.player.reputation + reward
			end
			Event.Queue("onReputationChanged", oldReputation, Character.persistent.player.killcount,
				Character.persistent.player.reputation, Character.persistent.player.killcount)

			mission:Remove()
			missions[ref] = nil

		elseif mission.status == "ACTIVE" and Game.time > mission.due then
			mission.status = 'FAILED'
		end

	end
end


-- xxx
local onReputationChanged = function (oldRep, oldKills, newRep, newKills)
	for ref,ad in pairs(ads) do
		local oldQualified = isQualifiedFor(oldRep, ad)
		if isQualifiedFor(newRep, ad) ~= oldQualified then
			Event.Queue("onAdvertChanged", ad.station, ref);
		end
	end
end


local loaded_data

local onGameStart = function ()
	ads = {}
	missions = {}

	if not loaded_data then return end

	for k,ad in pairs(loaded_data.ads) do
		local ref = ad.station:AddAdvert({
			description = ad.desc,
			icon        = "delivery",
			onChat      = onChat,
			onDelete    = onDelete })
		ads[ref] = ad
	end

	missions = loaded_data.missions

	loaded_data = nil
end


local onClick = function (mission)
	local dist = Game.system and string.format("%.2f", Game.system:DistanceTo(mission.location)) or "???"

	return ui:Grid(2,1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((l[mission.flavour]):interp({  --- introtext xxx
														client    = mission.client.name,
														recipient = mission.recipient.name,
														message   = l[mission.message],
														starport  = mission.location:GetSystemBody().name,
														system    = mission.location:GetStarSystem().name,
														sectorx   = mission.location.sectorX,
														sectory   = mission.location.sectorY,
														sectorz   = mission.location.sectorZ,
														cash      = Format.Money(mission.reward),
														dist      = dist})
										),
										ui:Margin(10),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.SPACEPORT)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(mission.location:GetSystemBody().name)
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.SYSTEM)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(mission.location:GetStarSystem().name.." ("..mission.location.sectorX..","..mission.location.sectorY..","..mission.location.sectorZ..")")
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.DEADLINE)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(Format.Date(mission.due))
												})
											}),
										ui:Margin(5),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.DISTANCE)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(dist.." "..l.LY)
												})
											}),
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
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
Event.Register("onReputationChanged", onReputationChanged)

Mission.RegisterType('DeliverMessage',l.DELIVERY, onClick) -- "Delivery" string, same as DeliverPackage

Serializer:Register("DeliverMessage", serialize, unserialize)
