-- Promoted every i^4 rank score, i in [0,12]
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

return was_promoted
