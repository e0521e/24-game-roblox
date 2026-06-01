local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService("RunService")
local Signal = require(ReplicatedStorage.Packages.Signal)

local function GetDynamics()
    local dynamics = {
        _signals = {},
        Get = function(self, eventName)
            if not self._signals[eventName] then
                self._signals[eventName] = Signal.new()
            end
            return self._signals[eventName]
        end
    }
    return dynamics
end

local EventBus = {
    _signals = {},
    Dynamic = GetDynamics(),
}

local Signals = {}
if RunService:IsClient() then
    Signals = {'Roll', 'MatchCd', 'ReadyCd'}
elseif RunService:IsServer() then
    Signals = {'ReadyUp'}
end

for _, signalName in ipairs(Signals) do
    table.insert(EventBus._signals, signalName)
end

for _, signalName in ipairs(EventBus._signals) do
    EventBus[signalName] = Signal.new()
end

return EventBus
