-- Copyright © 2008-2025 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Engine = require 'Engine'
local Lang = require 'Lang'
local Game = require 'Game'
local l = Lang.GetResource("module-newsevent")

local NewsEvent = {
	maxIndexOfIndNewspapers = 10,
	maxIndexOfAdTitles = 3,
	maxIndexOfTitles = 4,
}

-- Headline shown in the BBS listing
NewsEvent.get_headline = function (self)
	return l["ADTITLE_"..Engine.rand:Integer(self.maxIndexOfAdTitles)]
end

NewsEvent.get_paper = function (self, faction)
	local newspaper
	if faction == "Solar Federation" then
		newspaper = l.NEWSPAPER_FED
	elseif faction == "Commonwealth of Independent Worlds" then
		newspaper = l.NEWSPAPER_CIW
	elseif faction == "Haber Corporation" then
		newspaper = l.NEWSPAPER_HAB
	elseif faction == "Empire" then
		newspaper = l.NEWSPAPER_IMP
	else
		newspaper = l["NEWSPAPER_IND_"..Engine.rand:Integer(0,self.maxIndexOfIndNewspapers)]
	end
	return newspaper
end

-- Headline when opened the news, contains name of newspaper
NewsEvent.get_title = function(self, faction)
	return string.interp(l["TITLE_"..Engine.rand:Integer(0, self.maxIndexOfTitles)] , {
		 newspaper = self.get_paper(faction),
	})
end


-- check if we should remove any ads
NewsEvent.checkAdvertsRemove = function(self, news)
	for ref, ad in pairs(news) do
		if ad.n.expires < Game.time then
			ad.station:RemoveAdvert(ref)
		end
	end
end

-- go through news table and remove any expired entry
NewsEvent.checkOldNews = function (self, news)
	print("--, news2:", news)

	for i,n in pairs(news) do
		if n.expires < Game.time then
			table.remove(news, i)
		end
	end
end

return NewsEvent
