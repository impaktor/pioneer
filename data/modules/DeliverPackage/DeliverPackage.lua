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
local EquipDef = import("EquipDef")
local ShipDef = import("ShipDef")
local Ship = import("Ship")
local utils = import("utils")

local InfoFace = import("ui/InfoFace")

local l = Lang.GetResource("module-deliverpackage")

-- Get the UI class
local ui = Engine.ui

-- don't produce missions for further than this many light years away
local max_delivery_dist = 30

-- typical time for travel to a system max_delivery_dist away
--	Irigi: ~ 4 days for in-system travel, the rest is FTL travel time
local typical_travel_time = (1.6 * max_delivery_dist + 4) * 24 * 60 * 60

-- typical reward for delivery to a system max_delivery_dist away
local typical_reward = 25 * max_delivery_dist

local num_pirate_taunts = 10

-- parameter for each flavour to match in data/lang/module-deliverpackage/
local flavours = {
	{
		urgency = 0,
		risk = 0,
		localdelivery = 0,
	}, {
		urgency = 0.1,
		risk = 0,
		localdelivery = 0,
	}, {
		urgency = 0.6,
		risk = 0,
		localdelivery = 0,
	}, {
		urgency = 0.4,
		risk = 0.75,
		localdelivery = 0,
	}, {
		urgency = 0.1,
		risk = 0.1,
		localdelivery = 0,
	}, {
		urgency = 0.1,
		risk = 0,
		localdelivery = 1,
	}, {
		urgency = 0.2,
		risk = 0,
		localdelivery = 1,
	}, {
		urgency = 0.4,
		risk = 0,
		localdelivery = 1,
	}, {
		urgency = 0.6,
		risk = 0,
		localdelivery = 1,
	}, {
		urgency = 0.8,
		risk = 0,
		localdelivery = 1,
	}
}

-- add strings to flavours,
for i = 1,#flavours do
	local f = flavours[i]
	f.adtext        = l["FLAVOUR_" .. i-1 .. "_ADTEXT"]
	f.introtext     = l["FLAVOUR_" .. i-1 .. "_INTROTEXT"]
	f.whysomuchtext = l["FLAVOUR_" .. i-1 .. "_WHYSOMUCHTEXT"]
	f.successmsg    = l["FLAVOUR_" .. i-1 .. "_SUCCESSMSG"]
	f.failuremsg    = l["FLAVOUR_" .. i-1 .. "_FAILUREMSG"]
end

-- store ads on the BBS and missions player is playing. Will be used
-- for saving and loading.
local ads = {}
local missions = {}

-- function will run when an advert is chosen, or rerun if any of the
-- options of the form clicked. ref is a unique identifier of the chosen
-- advert
local onChat = function (form, ref, option)

    -- get the advert that was clicked. ref is the unique number
    -- associated with the clicked ad.
	local ad = ads[ref]

    -- todo: have not understood this yet, but probably related to the
    -- fact that we run this function for each option we click.
	form:Clear()

	if option == -1 then
		form:Close()
		return
	end

	if option == 0 then
		form:SetFace(ad.client)

        -- destination of mission
		local sys   = ad.location:GetStarSystem()
		local sbody = ad.location:GetSystemBody()

		local introtext = string.interp(flavours[ad.flavour].introtext, {
			name     = ad.client.name,
			cash     = Format.Money(ad.reward),
			starport = sbody.name,
			system   = sys.name,
			sectorx  = ad.location.sectorX,
			sectory  = ad.location.sectorY,
			sectorz  = ad.location.sectorZ,
			dist     = string.format("%.2f", ad.dist),
		})

		form:SetMessage(introtext)

	elseif option == 1 then
		form:SetMessage(flavours[ad.flavour].whysomuchtext)

	elseif option == 2 then
		form:SetMessage(l.IT_MUST_BE_DELIVERED_BY..Format.Date(ad.due))

	elseif option == 4 then
		if ad.risk <= 0.1 then
			form:SetMessage(l.I_HIGHLY_DOUBT_IT)
		elseif ad.risk > 0.1 and ad.risk <= 0.3 then
			form:SetMessage(l.NOT_ANY_MORE_THAN_USUAL)
		elseif ad.risk > 0.3 and ad.risk <= 0.6 then
			form:SetMessage(l.THIS_IS_A_VALUABLE_PACKAGE_YOU_SHOULD_KEEP_YOUR_EYES_OPEN)
		elseif ad.risk > 0.6 and ad.risk <= 0.8 then
			form:SetMessage(l.IT_COULD_BE_DANGEROUS_YOU_SHOULD_MAKE_SURE_YOURE_ADEQUATELY_PREPARED)
		elseif ad.risk > 0.8 and ad.risk <= 1 then
			form:SetMessage(l.THIS_IS_VERY_RISKY_YOU_WILL_ALMOST_CERTAINLY_RUN_INTO_RESISTANCE)
		end

	elseif option == 3 then
		form:RemoveAdvertOnClose()

		ads[ref] = nil

		local mission = {
			type	 = "Delivery",
			client	 = ad.client,
			location = ad.location,
			risk	 = ad.risk,
			reward	 = ad.reward,
			due	 = ad.due,
			flavour	 = ad.flavour
		}

		table.insert(missions,Mission.New(mission))

		form:SetMessage(l.EXCELLENT_I_WILL_LET_THE_RECIPIENT_KNOW_YOU_ARE_ON_YOUR_WAY)

		return
	end

	form:AddOption(l.WHY_SO_MUCH_MONEY, 1)
	form:AddOption(l.HOW_SOON_MUST_IT_BE_DELIVERED, 2)
	form:AddOption(l.WILL_I_BE_IN_ANY_DANGER, 4)
	form:AddOption(l.COULD_YOU_REPEAT_THE_ORIGINAL_REQUEST, 0)
	form:AddOption(l.OK_AGREED, 3)
end

-- when the advert is removed, whether explicitly (RemoveAdvert), or
-- implicit by the player hyperspacing away.
local onDelete = function (ref)
	ads[ref] = nil
end

-- This will have a list of all the nearby systems from our current
-- one. Reset it if we change system. By defining it outside of
-- makeAdvert we don't have to recreate it for every advert in the
-- system.
local nearbysystems

-- create the actual mission specs and flavour, destination, etc.
-- will be called each time we want to place an advert on the BBS,
-- whether on onCreateBB or onUpdateBB.
local makeAdvert = function (station)
	local reward, due, location, nearbysystem, dist
	local client = Character.New()
	local flavour = Engine.rand:Integer(1,#flavours)
	local urgency = flavours[flavour].urgency
	local risk = flavours[flavour].risk

	if flavours[flavour].localdelivery == 1 then
        -- get the system player is currently in
		nearbysystem = Game.system

        -- contains X,Y,Z of sector, system number in that sector, and
        -- an index to a SystemBody (space stations) in the system.
		local nearbystations = Game.system:GetStationPaths()

        -- randomly choose a destination target for the mission
		location = nearbystations[Engine.rand:Integer(1,#nearbystations)]

        -- scrap mission if destination is same as origin (current station)
        -- todo what happens when the funciton is aborted? no advert created?
		if location == station.path then
            return
        end

        -- get the distance to the mission target
		local locdist = Space.GetBody(location.bodyIndex)
		dist = station:DistanceTo(locdist)

		--scrap the mission if too close
        if dist < 1000 then
            return
        end

		reward = 25 + (math.sqrt(dist) / 15000) * (1+urgency)
		due = Game.time + ((4*24*60*60) * (Engine.rand:Number(1.5,3.5) - urgency))
	else
        -- if it's the first advert we're making in this system then we
        -- need to check which worlds are close
		if nearbysystems == nil then
            -- use an optional filter, to only include systems with more
            -- than zero (paths to) space stations.
			nearbysystems = Game.system:GetNearbySystems(max_delivery_dist, function (s) return #s:GetStationPaths() > 0 end)
		end

        -- scrap mission if no populated ones can be found
		if #nearbysystems == 0 then
            return
        end

        -- pick one of the systems fulfilling the requirements, get distance.
		nearbysystem = nearbysystems[Engine.rand:Integer(1,#nearbysystems)]
		dist = nearbysystem:DistanceTo(Game.system)

        -- get station in that system
		local nearbystations = nearbysystem:GetStationPaths()
		location = nearbystations[Engine.rand:Integer(1,#nearbystations)]
		reward = ((dist / max_delivery_dist) * typical_reward * (1+risk) * (1.5+urgency) * Engine.rand:Number(0.8,1.2))
		due = Game.time + ((dist / max_delivery_dist) * typical_travel_time * (1.5-urgency) * Engine.rand:Number(0.9,1.1))
	end

	local ad = {
		station		= station,
		flavour		= flavour,
		client		= client,
		location	= location,
		dist        = dist,
		due	    	= due,
		risk		= risk,
		urgency		= urgency,
		reward		= reward,
		isfemale	= isfemale,
		faceseed	= Engine.rand:Integer(),
	}

	local sbody = ad.location:GetSystemBody()

	ad.desc = string.interp(flavours[flavour].adtext, {
		system	= nearbysystem.name,
		cash	= Format.Money(ad.reward),
		starport = sbody.name,
	})

    -- create the advert, and save it for saving/loading game restore
	local ref = station:AddAdvert(ad.desc, onChat, onDelete)
	ads[ref] = ad
end

-- when we enter system, create all ads we need on all BBS
local onCreateBB = function (station)
    -- number of _attempts_ to create an advert.
	local num = Engine.rand:Integer(0, math.ceil(Game.system.population))

	for i = 1,num do
		makeAdvert(station)
	end
end

-- continuously remove old and place new ads, as they expire.
local onUpdateBB = function (station)
	for ref,ad in pairs(ads) do
		if flavours[ad.flavour].localdelivery == 0
			and ad.due < Game.time + 5*60*60*24 then -- five day timeout for inter-system
			ad.station:RemoveAdvert(ref)
		elseif flavours[ad.flavour].localdelivery == 1
			and ad.due < Game.time + 2*60*60*24 then -- two day timeout for locals
			ad.station:RemoveAdvert(ref)
		end
	end
	if Engine.rand:Integer(12*60*60) < 60*60 then -- roughly once every twelve hours
		makeAdvert(station)
	end
end

-- set up enemy ships to attack player
local onEnterSystem = function (player)
	if (not player:IsPlayer()) then return end

	local syspath = Game.system.path

    -- for all active? (todo) delivery mission in system, spawn necessary ships.
	for ref,mission in pairs(missions) do
		if mission.status == "ACTIVE" and mission.location:IsSameSystem(syspath) then
			local risk = flavours[mission.flavour].risk
			local ships = 0

			local riskmargin = Engine.rand:Number(-0.3,0.3) -- Add some random luck
			if risk >= (1 + riskmargin) then ships = 3
			elseif risk >= (0.7 + riskmargin) then ships = 2
			elseif risk >= (0.5 + riskmargin) then ships = 1
			end

			-- if there is some risk and still no ships, flip a tricoin
			if ships < 1 and risk >= 0.2 and Engine.rand:Integer(2) == 1 then ships = 1 end

			-- XXX hull mass is a bad way to determine suitability for role
			local shipdefs = utils.build_array(utils.filter(function (k,def)
                                                                return def.tag == 'SHIP' and def.hullMass <= 400
                                                            end,
                                                            pairs(ShipDef)))
			if #shipdefs == 0 then return end

			local ship

            -- each enemy ship is equipped with engine, weapons, and a temper
			while ships > 0 do
				ships = ships-1

				if Engine.rand:Number(1) <= risk then
					local shipdef = shipdefs[Engine.rand:Integer(1,#shipdefs)]
					local default_drive = shipdef.defaultHyperdrive

					local max_laser_size = shipdef.capacity - EquipDef[default_drive].mass
                    local laserdefs = utils.build_array(utils.filter(
                        function (k,def) return def.slot == 'LASER' and def.mass <= max_laser_size and string.sub(def.id,0,11) == 'PULSECANNON' end,
                        pairs(EquipDef)
                    ))
                    local laserdef = laserdefs[Engine.rand:Integer(1,#laserdefs)]

					ship = Space.SpawnShipNear(shipdef.id, Game.player, 50, 100)
					ship:SetLabel(Ship.MakeRandomLabel())
					ship:AddEquip(default_drive)
					ship:AddEquip(laserdef.id)
					ship:AIKill(Game.player)
				end
			end

            -- unless ship==nil, send a taunting message, depending on flavour.
			if ship then
				local pirate_greeting = string.interp(l["PIRATE_TAUNTS_"..Engine.rand:Integer(1,num_pirate_taunts)-1], {
					client = mission.client.name, location = mission.location,})
				Comms.ImportantMessage(pirate_greeting, ship.label)
			end
		end

        -- if mission expired, set it as failed.
		if mission.status == "ACTIVE" and Game.time > mission.due then
			mission.status = 'FAILED'
		end
	end
end

-- If we leave the system we must reset the nearbysystems list, since
-- that is now outdated.
local onLeaveSystem = function (ship)
	if ship:IsPlayer() then
		nearbysystems = nil
	end
end

-- if the docked ship is the player, check which missions are relevant
-- to the station, and remove (either failed or completed)
local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end

	for ref,mission in pairs(missions) do

		if mission.location == station.path then

            -- which message to send to player
			if Game.time > mission.due then
				Comms.ImportantMessage(flavours[mission.flavour].failuremsg, mission.client.name)
			else
				Comms.ImportantMessage(flavours[mission.flavour].successmsg, mission.client.name)
				player:AddMoney(mission.reward)
			end

			mission:Remove()
			missions[ref] = nil

            -- we're out of time, at the wrong station, mark mission as failed
		elseif mission.status == "ACTIVE" and Game.time > mission.due then
			mission.status = 'FAILED'
		end

	end
end

-- variable to put the table of data into when player loads a game.
local loaded_data

-- restore necessary data if anything saved, restore ads on the BBS and
-- restore player missions
local onGameStart = function ()
	ads = {}
	missions = {}

	if not loaded_data then return end

	for k,ad in pairs(loaded_data.ads) do
		local ref = ad.station:AddAdvert(ad.desc, onChat, onDelete)
		ads[ref] = ad
	end

	missions = loaded_data.missions

	loaded_data = nil
end

-- Display mission details when we click the "More info..." button in
-- the mission roster.
local onClick = function (mission)
	local dist = Game.system and string.format("%.2f", Game.system:DistanceTo(mission.location)) or "???"

	if mission.risk <= 0.1 then
		danger = (l.I_HIGHLY_DOUBT_IT)
	elseif mission.risk > 0.1 and mission.risk <= 0.3 then
		danger = (l.NOT_ANY_MORE_THAN_USUAL)
	elseif mission.risk > 0.3 and mission.risk <= 0.6 then
		danger = (l.THIS_IS_A_VALUABLE_PACKAGE_YOU_SHOULD_KEEP_YOUR_EYES_OPEN)
	elseif mission.risk > 0.6 and mission.risk <= 0.8 then
		danger = (l.IT_COULD_BE_DANGEROUS_YOU_SHOULD_MAKE_SURE_YOURE_ADEQUATELY_PREPARED)
	elseif mission.risk > 0.8 and mission.risk <= 1 then
		danger = (l.THIS_IS_VERY_RISKY_YOU_WILL_ALMOST_CERTAINLY_RUN_INTO_RESISTANCE)
	end

	return ui:Grid(2,1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((flavours[mission.flavour].introtext):interp({
														name   = mission.client.name,
														starport = mission.location:GetSystemBody().name,
														system = mission.location:GetStarSystem().name,
														sectorx = mission.location.sectorX,
														sectory = mission.location.sectorY,
														sectorz = mission.location.sectorZ,
														cash   = Format.Money(mission.reward),
														dist  = dist})
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
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.DANGER)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(danger)
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

-- remove list of nearbysystems, since the Lua virtual machine is not
-- reset between games we must clean up after us. (Note: this will
-- certainly change in the future.)
local onGameEnd = function ()
	nearbysystems = nil
end

-- function to run when player saves the game.
local serialize = function ()
    -- must return a table, that contains all that is needed for a
    -- reload.
	return { ads = ads, missions = missions }
end

-- Is run after game is loaded, immediately before the onGameStart event
-- is triggered.  take the table that was saved by serialize as input
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

Mission.RegisterType('Delivery',l.DELIVERY,onClick)

Serializer:Register("DeliverPackage", serialize, unserialize)
