-- Copyright © 2008-2015 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local s = CustomSystem:new("Arkanoid",{'STAR_M'})
	:govtype('PLUTOCRATIC')
	:short_desc('Important outpost')
	:long_desc([[The system was first colonized by the ship Vaus, who managed to escape the explosion of her mother ship Akranoid, from which the system was named.

Although the system was ill suited for colonization, the survivors managed to stay self-sufficient, and became an important outpost in man's reach for the stars.]])

local arkanoid = CustomSystemBody:new("Arkanoid",'STAR_M')
   :radius(f(11,10))
   :mass(f(11,10))
   :temp(5750)

local taito = CustomSystemBody:new('Taito', 'PLANET_GAS_GIANT')
   :seed(-2039)
   :axial_tilt(fixed.deg2rad(f(2344,100)))

-- Some cities inspired by old school games
local taito_stations = {
	CustomSystemBody:new('Pong City', 'STARPORT_ORBITAL')
		:semi_major_axis(f(30803,100000000))
		:rotation_period(f(14,24)),
	CustomSystemBody:new('Zorkygrad', 'STARPORT_ORBITAL')
		:semi_major_axis(f(9840,100000000))
		:rotation_period(f(11,21)),
}

-- Taito was the Japanese creator of Arkanoid
local taito = CustomSystemBody:new('Taito', 'PLANET_GAS_GIANT')
   :seed(873)
   :radius(f(101,100))
   :mass(f(120,1000))
   :temp(300)
   :semi_major_axis(f(120,100))
   :eccentricity(f(2,10))
   :rotation_period(f(8,10))
   :axial_tilt(fixed.deg2rad(f(2344,100)))
	:metallicity(f(1,2))
	:volcanicity(f(1,10))
	:atmos_density(f(1,1))
	:atmos_oxidizing(f(8,10))
	:ocean_cover(f(6,10))
	:ice_cover(f(7,10))
	:life(f(8,10))


-- radius, mass, exxentricity, tilt, all default to 0.

-- Klax is a arkade game.
local klax = CustomSystemBody:new('Klax', 'PLANET_GAS_GIANT')
	:seed(2030)
	:semi_major_axis(f(210,100))
-- radius in Earth radii
	:radius(f(101,10))
	:eccentricity(f(21,1000))
-- mass in earth mass
	:mass(f(417,10))
-- degrees
	:axial_tilt(fixed.deg2rad(f(333,10)))



-- Darkmoon, sounds dark. Also Eye of the Beholder: Legend of Darkmoon
local darkmoon = {
	CustomSystemBody:new('Darkmoon', 'PLANET_ASTEROID')
		:temp(094)
		:metallicity(f(1,2))
		:volcanicity(f(1,10))
		:semi_major_axis(f(154,10)),
	{
		-- Fort DOH was the boss in Arkanoid, level 33.
		CustomSystemBody:new('Fort Doh', 'STARPORT_SURFACE')
			:latitude(math.deg2rad(0.5))
			:longitude(math.deg2rad(10.0))
	},
}


s:bodies(arkanoid, {
	taito,
		taito_stations,
	klax,
		darkmoon,
})

s:add_to_sector(1,1,0,v(0.307,0.025,0.81))
