local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

--- 2 三方
local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Tree = require(ReplicatedStorage.Packages.Tree)
local Component = require(ReplicatedStorage.Packages.Component)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Zone = require(ReplicatedStorage.Zone)
local Sift = require(ReplicatedStorage.Packages.Sift)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Timer = require(ReplicatedStorage.Packages.Timer)
local Input = require(ReplicatedStorage.Packages.Input)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Observers = require(ReplicatedStorage.Packages.Observers)

--- 3 已方
local Config = require(ReplicatedStorage.Shared.Configuration.Config)
local Utils = require(ReplicatedStorage.Shared.DataStructures.Utils)
local EventBus = require(ReplicatedStorage.Shared.DataStructures.EventBus)
local Icon, localPlayer, PlayerGui
local PlayerData = require(ReplicatedStorage.Shared.DataStructures.PlayerData)

if Config.isClient then
	--- Icon = require(ReplicatedStorage.Packages.Topbarplus)
	localPlayer = Players.LocalPlayer
end

--- 4.1. Tree
local UTree = {__index = Tree}
setmetatable(UTree, UTree)

function UTree.Awaits(parent: Instance, paths: {string}, timeout: number?, assertIsA: string?): {Instance}
	local instances = {}
	for _, p in paths do
        local path = p:gsub("%.", "/")
		local instance = Tree.Await(parent, path, timeout, assertIsA)
        if instance then
            table.insert(instances, instance)
        end
	end

	return instances
end

function UTree.Pwaits(parents: {Instance}, path: string, timeout: number?, assertIsA: string?): {Instance}
	local instances = {}
    local _path = path:gsub("%.", "/")
	for _, parent in parents do
		local instance = Tree.Await(parent, _path, timeout, assertIsA)
        if instance then
            table.insert(instances, instance)
        end
	end

	return instances
end

--- 4.2. Observers
local Obs = {__index = Observers}
setmetatable(Obs, Obs)
function Obs.observeUITag(tag, callback, ancestors: { Instance }?)
	if ancestors == nil then -- 自动过滤：只处理当前玩家PlayerGui下的UI
		if not PlayerGui then
			PlayerGui = localPlayer:WaitForChild('PlayerGui') -- 改为懒加载
		end
		ancestors = {PlayerGui}
	end
    return Observers.observeTag(tag, function(instance)     
        -- 调用原始回调
        return callback(instance)
    end, ancestors)
end

function Obs.observeWkTag(tag, callback, ancestors: { Instance }?)
	if ancestors == nil then -- 自动过滤：只处理当前玩家PlayerGui下的UI
		ancestors = {workspace}
	end
    return Observers.observeTag(tag, function(instance)     
        -- 调用原始回调
        return callback(instance)
    end, ancestors)
end

--- 聚合U3，再导出
local U3 = {
	--- 1 官方（）

	--- 2 三方（）
	['Knit'] = Knit,
	['Component'] = Component,
	['Trove'] = Trove,
    ['Tree'] = UTree,
	['TableUtil'] = TableUtil,
	['Zone'] = Zone,
	['Icon'] = Icon,
	['Sift'] = Sift,
	['Signal'] = Signal,
	['Timer'] = Timer,
	['Keyboard'] = Input.Keyboard,
	['Mouse'] = Input.Mouse,
	['Touch'] = Input.Touch,
	['Promise'] = Promise,
	['Obs'] = Obs,

	--- 3 已方（）
	['Config'] = Config,
	['Constants'] = Constants,
	['Utils'] = Utils,
	['EventBus'] = EventBus,
	['PlayerData'] = PlayerData,
	['F'] = nil,
}

return U3
