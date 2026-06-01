local ReplicatedStorage = game:GetService('ReplicatedStorage')
local U3 = require(ReplicatedStorage.Shared.DataStructures.U3)
local Knit, Signal = U3.Knit, U3.Signal

local ExampleService = Knit.CreateService {
	Name = "ExampleService",
	Client = {},
}

function ExampleService:KnitInit()
	print("ExampleService initialized")
end

function ExampleService:KnitStart()
	print("ExampleService started")
end

return ExampleService
