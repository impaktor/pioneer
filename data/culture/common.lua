-- Copyright © 2008-2021 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local utils = require 'utils'

local CultureName = {
	male = {},     -- List of 100 most common male first names
	female = {},   -- List of 100 most common female first names
	surname = {},  -- List of 100 most common last names
	name = "Name", -- Name of language / culture
	code = "xx",   -- ISO ISO 639-1 language code
}

-- local ascii_replacement = {}
--- xxx todo / fix
ascii_replacement = {}
ascii_replacement["ä"] = "ae"
ascii_replacement["è"] = "e"
ascii_replacement["à"] = "a"
ascii_replacement["ò"] = "o"
ascii_replacement["ò"] = "o"
ascii_replacement["à"] = "a"
ascii_replacement["ù"] = "u"
ascii_replacement["è"] = "e"
ascii_replacement["ì"] = "i"
ascii_replacement["ì"] = "i"
ascii_replacement["ù"] = "u"
ascii_replacement["ü"] = "u"
ascii_replacement["å"] = "aa"
ascii_replacement["ä"] = "ae"
ascii_replacement["ö"] = "o"
ascii_replacement["ø"] = "o"
ascii_replacement["æ"] = "ae"


function CultureName:New (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function CultureName:FirstName (isFemale, rand)
	local array = isFemale and self.female or self.male
	return utils.chooseEqual(array, rand)
end

-- Some cultures have gender specific surnames
function CultureName:Surname (isFemale, rand)
	return utils.chooseEqual(self.surname, rand)
end

function CultureName:FullName (isFemale, rand)
	return self:FirstName(isFemale, rand) .. " " .. self:Surname(isFemale, rand)
end

return CultureName
