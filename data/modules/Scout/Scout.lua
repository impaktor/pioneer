-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local StarSystem = import("StarSystem")
local Space      = import("Space")
local Comms      = import("Comms")
local Event      = import("Event")
local Mission    = import("Mission")
local NameGen    = import("NameGen")
local Format     = import("Format")
local Serializer = import("Serializer")
local Character  = import("Character")
local InfoFace   = import("ui/InfoFace")
local Timer      = import("Timer")
local Eq         = import("Equipment")

local l = Lang.GetResource("module-scout")

 -- don't produce missions for further than this many light years away
local max_scout_dist = 30

-- scanning time 600 = 10 minutes
local scan_time = 600  -- uuu

-- CallEvery(xTimeUp,....
local xTimeUp = 10     -- uuu
local radius_min = 1.5
local radius_max = 1.6

-- minimum $350 reward in local missions
local local_reward = 350

-- Get the UI class
local ui = Engine.ui

local flavours = {
	{                          -- flavour 1
		localscout = false,    -- is in same system?
		urgency    = 0.0,      -- deadline, [0,1]
		difficulty = 0,        -- altitude, [0,1]
		reward     = 1,        -- reward multiplier, 1=none. (unrelated to "urgency")
	}, {
		localscout = false,    -- 2
		urgency    = 0.0,
		difficulty = 1,        -- low altitude flying
		reward     = 1,
	}, {
		localscout = false,    -- 3
		urgency    = 0.1,
		difficulty = 1,
		reward     = 1.2,      -- rich pirate hiring
	}, {
		localscout = false,    -- 4
		urgency    = 1.0,
		difficulty = 2,
		reward     = 1,
	}, {
		localscout = false,    -- 5
		urgency    = 0.4,
		difficulty = 0,
		reward     = 1,
	}, {
		localscout = true,     -- 6
		urgency    = 0.1,
		difficulty = 0,
		reward     = 1.5,      -- government pays well
	}, {
		localscout = true,     -- 7
		urgency    = 1,        -- urgent
		difficulty = 0,
		reward     = 0.5,      -- because local
	}, {
		localscout = true,     -- 8
		urgency    = 0,
		difficulty = 0,
		reward     = 0.5,      -- because local
	}, {
		localscout = false,    -- 9
		urgency    = 0.9,
		difficulty = 0,
		reward     = 1,
	}
}

-- add strings to scout flavours
for i = 1,#flavours do
	local f = flavours[i]
	f.adtext     = l["ADTEXT_"..i]
	f.introtext  = l["ADTEXT_"..i.."_INTRO"]
	f.introtext2 = l["INTROTEXT_COMPLETED_"..i]   -- xxx
	f.whysomuch	 = l["ADTEXT_"..i.."_WHYSOMUCH"]
	f.successmsg = l["ADTEXT_"..i.."_SUCCESSMSG"]
	f.failmsg	 = l["ADTEXT_"..i.."_FAILMSG"]
end

local ads      = {}
local missions = {}

local onChat = function (form, ref, option)
	local ad          = ads[ref]
	local backstation = Game.player:GetDockedWith().path
	local faction     = Game.system.faction
	form:Clear()
	if option == -1 then
		form:Close()
		return
	end

	if option == 0 then
		form:SetFace(ad.client)

		local sys   = ad.location:GetStarSystem()     -- mission system
		local sbody = ad.location:GetSystemBody()     -- mission body

		local introtext = string.interp(flavours[ad.flavour].introtext, {
			name       = ad.client.name,
--			police     = faction.policeName,  -- add a new flavour when faction police name is translated
			cash       = Format.Money(ad.reward),
			systembody = sbody.name,
			system     = sys.name,
			sectorx    = ad.location.sectorX,
			sectory    = ad.location.sectorY,
			sectorz    = ad.location.sectorZ,
			dist       = string.format("%.2f", ad.dist),
		})
		form:SetMessage(introtext)

	elseif option == 1 then
		form:SetMessage(flavours[ad.flavour].whysomuch)

	elseif option == 2 then
		form:SetMessage(string.interp(l.PLEASE_HAVE_THE_DATA_BACK_BEFORE, {date = Format.Date(ad.due)}))

	elseif option == 4 then
			form:SetMessage(l.ADDITIONAL_INFORMATION)

	elseif option == 3 then

		-- använd något annat!
		if Game.player:CountEquip(Eq.misc.radar_mapper) == 0 then
			form:SetMessage(l.YOU_NEED_RADAR_MAPPER)
			return
		end
		form:RemoveAdvertOnClose()
		ads[ref] = nil
		local mission = {
			type        = "Scout",
			faction     = faction.name,
			police      = faction.policeName,  -- bortkommenterad tidigare?
			backstation = backstation,
			client      = ad.client,
			location    = ad.location,
			difficulty  = ad.difficulty,
			reward      = ad.reward,
			due         = ad.due,
			flavour     = ad.flavour,
			status      = 'ACTIVE',
		}

		table.insert(missions,Mission.New(mission))
		Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
		form:SetMessage(l.EXCELLENT_I_AWAIT_YOUR_REPORT)
		return
	end

	form:AddOption(l.WHY_SO_MUCH_MONEY, 1)
	form:AddOption(l.WHEN_DO_YOU_NEED_THE_DATA, 2)
	form:AddOption(l.HOW_DOES_IT_WORK, 4)             --- foo xxx
	form:AddOption(l.REPEAT_THE_ORIGINAL_REQUEST, 0)
	form:AddOption(l.ACCEPT_AND_SET_SYSTEM_TARGET, 3)
end


local onDelete = function (ref)
	ads[ref] = nil
end

-- store once for the system player is in
local nearbysystems

local makeAdvert = function (station)
	local reward, due, nearbysystem
	local location						  -- mission body
	local client = Character.New()
	local flavour = Engine.rand:Integer(1,#flavours)
	local urgency = flavours[flavour].urgency
	local difficulty = flavours[flavour].difficulty
	local faction = Game.system.faction   -- xxx

	if flavours[flavour].localscout then  -- local system

		nearbysystem = Game.system        -- i.e. this system
		local nearbybodies = nearbysystem:GetBodyPaths()
		local checkedBodies = 0
		while checkedBodies <= #nearbybodies do -- check, at most, all nearbybodies
			location = nearbybodies[Engine.rand:Integer(1,#nearbybodies)]
			local currentBody = location:GetSystemBody()   -- go from syspath to sysbody
			if currentBody.superType == "ROCKY_PLANET" and currentBody.type ~= "PLANET_ASTEROID" then
				break  --- xxx why SUPER type? only allow satelites?
			end
			checkedBodies = checkedBodies + 1
		end

		-- no missions in the backyard please
		local dist = station:DistanceTo(Space.GetBody(location.bodyIndex))
		if dist < 1000 then return end

		reward = local_reward + (math.sqrt(dist) / 15000) * (1.5+urgency) * (1+Game.system.lawlessness)
		due = Game.time + ((4*24*60*60) * (Engine.rand:Number(1.5,3.5) - urgency))
	else                                   -- remote system
		if nearbysystems == nil then       -- only uninhabited systems
			nearbysystems =	Game.system:GetNearbySystems(max_scout_dist,
				function (s) return #s:GetBodyPaths() > 0 and s.population == 0 end)
		end
		if #nearbysystems == 0 then return end
		nearbysystem = nearbysystems[Engine.rand:Integer(1,#nearbysystems)]
		local dist = nearbysystem:DistanceTo(Game.system)
		local nearbybodies = nearbysystem:GetBodyPaths()

		local checkedBodies = 0
		while checkedBodies <= #nearbybodies do -- check, at most, all nearbybodies
			location = nearbybodies[Engine.rand:Integer(1,#nearbybodies)]
			local currentBody = location:GetSystemBody()
			if currentBody.superType == "ROCKY_PLANET" and currentBody.type ~= "PLANET_ASTEROID" then
				break
			end
			checkedBodies = checkedBodies + 1
		end

		-- Compute reward for mission
		local multiplier = Engine.rand:Number(1.5,1.6)
		if Game.system.faction ~= location:GetStarSystem().faction then
			multiplier = multiplier * Engine.rand:Number(1.3,1.5)
		end
--		reward = tariff(dist,difficulty,urgency,location)*2*multiplier
		reward = 100  -- todo xxx
--		due = Game.time + ((2 * dist * 86400)/(1 + urgency))
		due = 1e8 -- todo xxx
	end

	local ad = {
		station    = station,
		flavour    = flavour,
		client     = client,
		location   = location,
		dist       = Game.system:DistanceTo(location),
		due        = due,
		difficulty = difficulty,
		urgency    = urgency,
		reward     = reward,
		isfemale   = isfemale,
		faceseed   = Engine.rand:Integer(),
	}

	ad.desc = string.interp(flavours[flavour].adtext, {
		system     = nearbysystem.name,
		cash       = Format.Money(ad.reward),
		dist       = string.format("%.2f", ad.dist),
		systembody = ad.location:GetSystemBody().name
	})

	local ref = station:AddAdvert({
		description = ad.desc,
		icon        = "scout",
		onChat      = onChat,
		onDelete    = onDelete})

	ads[ref] = ad
end


local onCreateBB = function (station)
	local num = Engine.rand:Integer(math.ceil(Game.system.population)) / 2
	for i = 1,num do
		makeAdvert(station)
	end
end


local onUpdateBB = function (station)
	for ref,ad in pairs(ads) do
		if not flavours[ad.flavour].localscout
			and ad.due < Game.time + 432000 then -- 5 days
			ad.station:RemoveAdvert(ref)
		elseif flavours[ad.flavour].localscout
			and ad.due < Game.time + 172800 then -- 2 days
			ad.station:RemoveAdvert(ref)
		end
	end
	if Engine.rand:Integer(43200) < 3600 then    -- 12 h < 1 h
		makeAdvert(station)
	end
end


local onEnterSystem = function (playership)
	if not playership:IsPlayer() then return end
	nearbysystems = nil

	for ref,mission in pairs(missions) do
		if mission.status == "ACTIVE" and Game.time > mission.due then
			mission.status = 'FAILED'
		end
	end
end


local mapped = function(body)
	local CurBody = Game.player.frameBody or body
	if not CurBody then return end
	local faction = Game.system.faction -- xxx
	local mission
	for ref,mission in pairs(missions) do
		if Game.time > mission.due then mission.status = "FAILED" end
		if Game.system == mission.location:GetStarSystem() then

			if mission.status == "COMPLETED" then return end -- borde det inte vara continue? uuu

			local PhysBody = CurBody.path:GetSystemBody()
			if PhysBody and CurBody.path == mission.location then
				local TimeUp = 0
				if DangerLevel == 2 then
					radius_min = 1.3
					radius_max = 1.4
				else
					radius_min = 1.5
					radius_max = 1.6
				end

				Timer:CallEvery(xTimeUp, function ()
					if not CurBody or not CurBody:exists() or mission.status == "COMPLETED" then return 1 end
					local Dist = CurBody:DistanceTo(Game.player)
					if Dist < PhysBody.radius * radius_min
					and (mission.status == 'ACTIVE' or mission.status == "SUSPENDED") then
						print("DIST1:", PhysBody.radius * radius_min)
						local lapse = scan_time / 60
						Comms.ImportantMessage(l.Distance_reached .. lapse .. l.minutes, l.COMPUTER)
						print(l.Distance_reached .. lapse .. l.minutes, l.COMPUTER)
						-- Music.Play("music/core/radar-mapping/mapping-on")
						mission.status = "MAPPING"
					elseif Dist > PhysBody.radius * radius_max and mission.status == "MAPPING" then
						-- Music.Play("music/core/radar-mapping/mapping-off",false)
						print("DIST1:", PhysBody.radius * radius_max)
						Comms.ImportantMessage(l.MAPPING_INTERRUPTED, l.COMPUTER)
						print(l.MAPPING_INTERRUPTED)
						mission.status = "SUSPENDED"
						TimeUp = 0
						return 1
					end
					if mission.status == "MAPPING" then
						TimeUp = TimeUp + xTimeUp
						if TimeUp >= scan_time then
							mission.status = "COMPLETED"
							-- Music.Play("music/core/radar-mapping/mapping-off",false)
							Comms.ImportantMessage(l.MAPPING_COMPLETED, l.COMPUTER)

							-- decide delivery location:

							--- uuu if we're changing location, that's silly -> remove
							--- or is it a "hack" that a delivery location might not be there?
							--- I know I can always return to the same station, as where I picked up the mission, right.
							local newlocation = mission.backstation
							if not flavours[mission.flavour].localscout
								and (((mission.faction == faction.name)
								and Engine.rand:Integer(2) > 1)
								or Engine.rand:Integer(2) > 1)
							then
								-- XXX-TODO GetNearbyStationPaths triggers bug in Gliese 190 mission. Empty system!
								local nearbystations =
									StarSystem:GetNearbyStationPaths(Engine.rand:Integer(10,20), nil, function (s) return
										(s.type ~= 'STARPORT_SURFACE') or (s.parent.type ~= 'PLANET_ASTEROID') end)
								if nearbystations and #nearbystations > 0 then
									newlocation = nearbystations[Engine.rand:Integer(1,#nearbystations)]
									Comms.ImportantMessage(l.YOU_WILL_BE_PAID_ON_MY_BEHALF_AT_NEW_DESTINATION,
												mission.client.name)
								end
							end
							mission.location = newlocation
							Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
						end
					end
					if mission.status == "COMPLETED" then return 1 end
				end)
			end
		end
	end
end


local onFrameChanged = function (body)
	if not body:isa("Ship") or not body:IsPlayer() then return end
	if body.frameBody == nil then return end
	local target = Game.player:GetNavTarget()
	if target == nil then return end
	local closestPlanet = Game.player:FindNearestTo("PLANET")
	if closestPlanet ~= target then return end
	local dist
	dist = Format.Distance(Game.player:DistanceTo(target))
	mapped(body)
end


local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end

	local mission
	for ref, mission in pairs(missions) do

		if station.path == mission.location then
			if Game.time > mission.due then
				Comms.ImportantMessage((flavours[mission.flavour].failmesg), mission.client.name)
				Character.persistent.player.reputation = Character.persistent.player.reputation - 1
			else
				Comms.ImportantMessage((flavours[mission.flavour].successmsg), mission.client.name)
				Character.persistent.player.reputation = Character.persistent.player.reputation + 1
				player:AddMoney(mission.reward)
			end
			mission:Remove()
			missions[ref] = nil
		elseif mission.status == "ACTIVE" and Game.time > mission.due then -- or not COPMLEATED? is ACTIVE a state?
			mission.status = "FAILED"
		end
	end
end


local loaded_data

local onGameStart = function ()
	ads = {}
	missions = {}

	if loaded_data then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
				description = ad.desc,
				icon        = "scout",
				onChat      = onChat,
				onDelete    = onDelete})] = ad
		end
		missions = loaded_data.missions
		loaded_data = nil
	end

	local currentBody = Game.player.frameBody
	local mission
	for ref,mission in pairs(missions) do
		if currentBody and currentBody.path ~= mission.location then return end
		if Game.time > mission.due then
			mission.status = "FAILED"
			mission:Remove()
			missions[ref] = nil
			return
		end
		mapped(currentBody)
	end
end


local onClick = function (mission)
	local dist = Game.system and string.format("%.2f", Game.system:DistanceTo(mission.location)) or "zzz"

	local danger
	if mission.difficulty == 0 then
		---danger = (l["MessageRisk3_" .. Engine.rand:Integer(1,2)])
	end

	if mission.status =="ACTIVE" or mission.status =="MAPPING" then
		return ui:Grid(2,1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((flavours[mission.flavour].introtext):interp(
						{
							name       = mission.client.name,
							faction    = mission.faction,
							police     = mission.police,
							systembody = mission.location:GetSystemBody().name,
							system     = mission.location:GetStarSystem().name,
							sectorx    = mission.location.sectorX,
							sectory    = mission.location.sectorY,
							sectorz    = mission.location.sectorZ,
							dist       = dist,
							cash       = Format.Money(mission.reward),
						})
					),
					"",
						ui:Grid(2,1)
							:SetColumn(0,{
								ui:VBox():PackEnd({
													ui:Label(l.Objective)
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
													ui:Label(l.System)
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
													ui:Label(l.Deadline)
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
													ui:Label(l.Danger)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(danger)
												})
											}),
										"",
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.Distance)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(dist.." ly")
												})
											}),
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
	elseif mission.status =="COMPLETED" then
		return ui:Grid(2,1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((flavours[mission.flavour].introtext2):interp(
						{
							name       = mission.client.name,
							faction    = mission.faction,
							police     = mission.police,
							systembody = mission.location:GetSystemBody().name,
							system     = mission.location:GetStarSystem().name,
							sectorx    = mission.location.sectorX,
							sectory    = mission.location.sectorY,
							sectorz    = mission.location.sectorZ,
							cash       = Format.Money(mission.reward),
							dist       = dist})
					),
					"",
						ui:Grid(2,1)
							:SetColumn(0,{
								ui:VBox():PackEnd({
													ui:Label(l.Station)
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
													ui:Label(l.System)
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
													ui:Label(l.Deadline)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(Format.Date(mission.due))
												})
											}),
--[[										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.Danger)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(danger)
												})
											}),
										"",--]]
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.Distance)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(dist.." ly")
												})
											}),
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
	elseif mission.status =="SUSPENDED" then
		return ui:Grid(2,1):SetColumn(0,{ui:VBox(10)
			:PackEnd({ui:MultiLineText(l.suspended_mission)})})
	elseif mission.status =="FAILED" then
		return ui:Grid(2,1):SetColumn(0,{ui:VBox(10)
			:PackEnd({ui:MultiLineText(l.failed_mission)})})
	else
		return ui:Grid(2,1):SetColumn(0,{ui:VBox(10)
			:PackEnd({ui:Label("ERROR")})})
	end
end


local serialize = function ()
	return { ads = ads, missions = missions }
end


local unserialize = function (data)
	loaded_data = data
end

local onGameEnd = function ()
	nearbysystems = nil
end

Event.Register("onGameEnd", onGameEnd)
Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
--Event.Register("onLeaveSystem", onLeaveSystem)
Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onFrameChanged", onFrameChanged)
Event.Register("onShipDocked", onShipDocked)
Event.Register("onGameStart", onGameStart)

Mission.RegisterType('Scout', l.SCOUT, onClick)

Serializer:Register("Scout", serialize, unserialize)
