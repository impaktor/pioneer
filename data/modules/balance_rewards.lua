local Engine = import("Engine")
local Game = import("Game")
local Event = import("Event")
local Space = import("Space")

local iterations = 10000
local nearbysystems

-- assassin, deliverlocal, deliverfar, taxi, cargorun, cargorundistant, cargorun...

local assassin = function ()
	local file = io.open("assassin", "w")
	io.output(file)
	local max_ass_dist = 30
	for i=1,iterations do
		local time = Engine.rand:Number(0.3, 3)
		local due = Game.time + Engine.rand:Number(7*60*60*24, time * 31*60*60*24)
		local danger = Engine.rand:Integer(1,4)
		local reward = Engine.rand:Number(2100, 7000) * danger
		file:write(reward.."\n")
	end
	file:close()
end


local taxi = function ()
	local file = io.open("taxi", "w")
	io.output(file)
	local max_taxi_dist = 40
	local max_group = 10

	local flavours = {{urgency = 0, risk = 0.001}, {urgency = 0, risk = 0}, {urgency = 0, risk = 0}, {urgency = 0.13, risk = 0.73}, {
		urgency = 0.3, risk = 0.02}, {urgency = 0.1, risk = 0.05}, {urgency = 0.02, risk = 0.07}, {urgency = 0.15, risk = 1}, {urgency = 0.5, risk = 0.001}, {urgency = 0.85, risk = 0.20}, {urgency = 0.9, risk = 0.40}, {urgency = 1, risk = 0.31}, {urgency = 0, risk = 0.17}}

	local typical_travel_time = (2.0 * max_taxi_dist + 4) * 24 * 60 * 60
	local typical_reward = 75 * max_taxi_dist
	if not nearbysystems then
		nearbysystems = Game.system:GetNearbySystems(max_taxi_dist, function (s) return #s:GetStationPaths() > 0 end)
	end
	assert(nearbysystems ~= 0)
	for i=1,iterations do
		local flavour = Engine.rand:Integer(1,#flavours)
		local urgency = flavours[flavour].urgency
		local risk = flavours[flavour].risk

		-- there are 3 group flavours, and 7 single transport missions
		local group = 1
		if Engine.rand:Number(0, 1) < 3.0 / 10.0 then
			group = Engine.rand:Integer(2,max_group)
		end

		local location = nearbysystems[Engine.rand:Integer(1,#nearbysystems)]
		local dist = location:DistanceTo(Game.system)
		local reward = ((dist / max_taxi_dist) * typical_reward * (group / 2) * (1+risk) * (1+3*urgency) * Engine.rand:Number(0.8,1.2))
		local due = Game.time + ((dist / max_taxi_dist) * typical_travel_time * (1.5-urgency) * Engine.rand:Number(0.9,1.1))
		file:write(reward.."\n")
	end
	file:close()
end



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

local deliverpackage = function ()

	local flavours = {{ urgency = 0, risk = 0, localdelivery = false}, {urgency = 0.1, risk = 0, localdelivery = false}, {urgency = 0.6, risk = 0, localdelivery = false}, {urgency = 0.4, risk = 0.75, localdelivery = false}, {urgency = 0.1, risk = 0.1, localdelivery = false}, {urgency = 0.1, risk = 0, localdelivery = true}, {urgency = 0.2, risk = 0, localdelivery = true}, {urgency = 0.4, risk = 0, localdelivery = true}, {urgency = 0.6, risk = 0, localdelivery = true}, {urgency = 0.8, risk = 0, localdelivery = true}}

	local file = io.open("deliverpackage", "w")
	io.output(file)
	local max_delivery_dist = 30
	local typical_travel_time = (1.6 * max_delivery_dist + 4) * 24 * 60 * 60
	local typical_reward = 25 * max_delivery_dist

	local station = Game.player:GetDockedWith()
	local nearbystations = findNearbyStations(station, 1000)
	assert(#nearbystations ~= 0)
	if not nearbysystems then
		nearbysystems = Game.system:GetNearbySystems(max_delivery_dist, function (s) return #s:GetStationPaths() > 0 end)
	end
	assert(#nearbysystems ~= 0)

	for i=1,iterations do
		local dist, location, reward, due
		local flavour = Engine.rand:Integer(1,#flavours)
		local urgency = flavours[flavour].urgency
		local risk = flavours[flavour].risk
		local localdelivery = flavours[flavour].localdelivery
		local nearbysystem = nearbysystems[Engine.rand:Integer(1,#nearbysystems)]

		if localdelivery then
			location, dist = table.unpack(nearbystations[Engine.rand:Integer(1,#nearbystations)])
			reward = 25 + (math.sqrt(dist) / 15000) * (1+urgency)
			due = Game.time + ((4*24*60*60) * (Engine.rand:Number(1.5,3.5) - urgency))
		else
			nearbysystem = nearbysystems[Engine.rand:Integer(1,#nearbysystems)]
			dist = nearbysystem:DistanceTo(Game.system)
			reward = ((dist / max_delivery_dist) * typical_reward * (1+risk) * (1.5+urgency) * Engine.rand:Number(0.8,1.2))
			due = Game.time + ((dist / max_delivery_dist) * typical_travel_time * (1.5-urgency) * Engine.rand:Number(0.9,1.1))
		end
		file:write(reward.."\n")
	end
	file:close()
end



-- CARGORUN

local cargorun = function ()
	file = io.open("cargorun", "w")
	io.output(file)

	local max_cargo_wholesaler = 100
	local max_price = 300
	local max_delivery_dist = 15
	local typical_reward = 35 * max_delivery_dist
	local typical_reward_local = 35
	local typical_travel_time = (2.5 * max_delivery_dist + 8) * 24 * 60 * 60
	local pickup_factor = 1.75
	local max_cargo = 10 -- max cargo per trip

	local station = Game.player:GetDockedWith()
	local nearbystations = findNearbyStations(station, 1000)

	local dist, location, reward, due, pickup

	local cargotype = {{price=1}, {price=175}, {price=125}, {price=150}, {price=250}, {price=10}, {price=200}, {price=200}, {price=10}, {price=100}, {price=20}, {price=15}, {price=50}, {price=150}, {price=10}, {price=300}, {price=50}, {price=20}, {price=200}, {price=15}}
	for i = 1,iterations do
		location, dist = table.unpack(nearbystations[Engine.rand:Integer(1,#nearbystations)])
		local urgency = Engine.rand:Number(0, 1)

		local localdelivery = Engine.rand:Number(0, 1) > 0.5

		if localdelivery then
			local amount = Engine.rand:Integer(1, max_cargo)
			local risk = 0 -- no risk for local delivery
			pickup = Engine.rand:Number(0, 1) > 0.75
			reward = typical_reward_local + (math.sqrt(dist) / 15000) * (1+urgency) * (1+amount/max_cargo)
			due = (4*24*60*60) + (24*60*60 * (dist / (1.49*10^11))) * (1.5 - urgency)
			if pickup then
				reward = reward * pickup_factor
				due = due * pickup_factor + Game.time
			else
				due = due + Game.time
			end
		else
			if not nearbysystems then
				nearbysystem = nearbysystems[Engine.rand:Integer(1,#nearbysystems)]
			end
			dist = nearbysystem:DistanceTo(Game.system)
			local wholesaler = Engine.rand:Number(0, 1) > 0.75
			if wholesaler then
				amount = Engine.rand:Integer(max_cargo, max_cargo_wholesaler)
				pickup = false
			else
				amount = Engine.rand:Integer(1, max_cargo)
				pickup = Engine.rand:Number(0, 1) > 0.75
			end
			-- goods with price max_price have a risk of 0.75 to 1
			local price = cargotype[Engine.rand:Integer(1, #cargotype)].price
			local risk = 0.75 * price / max_price + Engine.rand:Number(0, 0.25)
			reward = (dist / max_delivery_dist) * typical_reward * (1+risk) * (1.5+urgency) * (1+amount/max_cargo_wholesaler) * Engine.rand:Number(0.8,1.2)
			due = (dist / max_delivery_dist) * typical_travel_time * (1.5 - urgency)
			if pickup then
				reward = reward * pickup_factor
				due = due * pickup_factor + Game.time
			else
				due = due + Game.time
			end
		end

		file:write(reward.."\n")
	end
	file:close()
end



-- TRADE
local e = import("Equipment")

local getprice = function (equip, system)
	-- Hack: taken from libs/SpaceStation.lua, to check without needing a "station" object
	return equip.price * ((100 + system:GetCommodityBasePriceAlterations(equip)) / 100.0)
end

-- Print the most profitable trade (in absolute numbers) for each
-- system in a "from all systems to all systems" trade route check
-- within max_dist raduis of current system
local checkTraderoute = function (file, f)

	local max_dist = 30			-- how far the player can travel
	local cargo_capacity = 10   -- how much the player can carry

	-- Always recompute for new system
	nearbysystems = Game.system:GetNearbySystems(max_dist, function (s) return #s:GetStationPaths() > 0 end)

	-- For each star system, consider buying its exports, and selling to random system that imports it
	for key1, export_sys in pairs(nearbysystems) do
		-- We've filtered out inhabited systems
		assert(#export_sys:GetStationPaths() > 0)

		for key2, import_sys in pairs(nearbysystems) do
			if import_sys.path ~= export_sys.path then

				local profit, name = 0, ""
				local relativeprofit = 0

				-- find out the maximum profit from current system to sys
				for key, equip in pairs(e.cargo) do
					local local_profit = 0
					if equip.price > 0 and f(export_sys:IsCommodityLegal(equip)) then
						local price_diff = (getprice(equip,import_sys) - getprice(equip, export_sys))
						local_profit = price_diff * cargo_capacity
						if local_profit > profit then
							profit = local_profit
							name = equip:GetName()
							relativeprofit = price_diff / getprice(equip, export_sys)
						end
					end
				end
				file:write(profit.."\t"..relativeprofit.."\t"..name.."\n")
			else
				print("excluding: "..export_sys.name.." comared to "..import_sys.name)
			end
		end
	end
end


local checkTrades = function ()
	local sysname = string.gsub(Game.system.name, " ", "_")

	local file_legal = io.open("trade_legal_"..sysname, "w")
	io.output(file_legal)
	checkTraderoute(file_legal,  function (s) return s end)
	file_legal:close()

	local file_ilegal = io.open("trade_ilegal_"..sysname, "w")
	io.output(file_ilegal)
	checkTraderoute(file_ilegal, function (s) return not s end)
	file_ilegal:close()
end



local onGameStart = function ()
	-- assassin()
	-- taxi()
	-- deliverpackage()
	-- cargorun()
	checkTrades()
end

-- Good to have, if I want to jump to a system and check it out
local onEnterSystem = function (ship)
	checkTrades()
end

Event.Register("onGameStart", onGameStart)

-- this is not run onGameStart!
Event.Register("onEnterSystem", onEnterSystem)
