-- Config.luau
local RunService = game:GetService("RunService")

local Config = {
	isClient = RunService:IsClient(),
    isServer = RunService:IsServer(),
}

return Config
