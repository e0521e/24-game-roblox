local ReplicatedStorage = game:GetService('ReplicatedStorage')
local U3 = require(ReplicatedStorage.Shared.DataStructures.U3)
local Knit, Signal = U3.Knit, U3.Signal

local ExampleController = Knit.CreateController {
	Name = "ExampleController",
}

function ExampleController:KnitInit()
	print("ExampleController initialized")
end

function ExampleController:KnitStart()
	print("ExampleController started")
end

return ExampleController
