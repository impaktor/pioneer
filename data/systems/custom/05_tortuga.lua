-- Copyright © 2008-2024 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

-- A pirate system!
local s = CustomSystem:new('Tortuga',{'WHITE_DWARF'}):other_names({'Gliese 339.1'})
	:govtype('NONE')
	:lawlessness(f(1,1))
	:short_desc('Pirate system')
	:long_desc([[The orbiting outpost of Tortuga was once known as Windward Forward Outpost, established in 2305 to act as the final stepping stone into new frontiers. However, as exploration started to shift elsewhere, the station became economically unfeasible and was eventually abandoned and faded from memories. These days Tortuga it a place of legends, and tales about space buccaneers and ships vanishing mysteriously.]])
	:seed(42)

s:add_to_sector(1,1,3,v(0.647,0.896,0.387))

-- TODO: have a world: Arkona, Threepwood
-- Zaporizhian Sich var öst-europas piratfäste  https://en.wikipedia.org/wiki/Zaporizhian_Sich
-- station: Port Royal -> Port Regal
