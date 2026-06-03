local NUMBERS = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
local OPERATORS = { "+", "-", "*", "/" }

local DISPLAY_OP = {
	["+"] = "+",
	["-"] = "-",
	["*"] = "*",
	["/"] = "÷",
}

local OPERATOR_FN = {
	["+"] = function(a, b) return a + b end,
	["-"] = function(a, b) return a - b end,
	["*"] = function(a, b) return a * b end,
	["/"] = function(a, b) return math.floor(a / b) end,
}

local function generate()
	local all = {}
	local byOperator = {}
	local byValue = {}

	for _, op in OPERATORS do
		byOperator[op] = {}
		for _, n in NUMBERS do
			local fn = OPERATOR_FN[op]
			local card = {
				display = DISPLAY_OP[op] .. tostring(n),
				operator = op,
				value = n,
				apply = function(v)
					return fn(v, n)
				end,
			}
			table.insert(all, card)
			table.insert(byOperator[op], card)
			if not byValue[n] then
				byValue[n] = {}
			end
			table.insert(byValue[n], card)
		end
	end

	return {
		All = all,
		ByOperator = byOperator,
		ByValue = byValue,
	}
end

return generate()
