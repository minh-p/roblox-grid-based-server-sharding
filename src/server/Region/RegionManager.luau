local REGION_RADIUS = 100

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Types = require(ReplicatedStorage.Shared.Types)
local RegionMath = require(ServerScriptService.Server.Region.RegionMath)
type HexAxis = Types.HexAxis
type SerializedPosition = Types.SerializedPosition
local OOP = require(ReplicatedStorage.Shared.OOP)

--- @class RegionManager
--- @server
--- Class managing Region operations
local RegionManager = OOP.class{
  dataStoreName = "RegionDataStore",
  memoryStorePrefix = "RegionMemStore",
  playerLocationStoreName = "PlayerLocationDataStore"
}

--- RegionManager's Constructor. Also, the actual names for data store, memory sorted map:
--- ```lua
--- worldStoreName = dataStoreNamePrefix .. "_WorldStore"
--- regionStoreName = dataStoreNamePrefix .. "_RegionStore"
--- regionLiveName = memoryStorePrefix .. "_RegionLive"
--- ```
--- How each WorldStore member should look like:
--- ```lua
--- worldStore['w1'] = {
---   name = "Westmarch",
---   maxRegions = 10,
---   seedGen = 12345,
--- }
--- ```
---
--- How RegionStore member should look like:
--- ```lua
--- regionStore['w1:0,0']{
---   -- Example for domination
---   owner = "Korblox",
---   contester = "Redcliff",
---   captureProgress = 50
--- }
--- ```
---
--- How _playerLocationStore member should look like:
--- ```lua
--- playerLocationStore[player.UserId] = {
---   ['w1'] = {
---     r = 0,
---     q = 0,
---     x = 0, y = 0, z = 0
---   }
--- }
--- ```
---
--- @param dataStoreNamePrefix string -- Prefix for data store name
--- @param memoryStorePrefix string -- Prefix for data store sorted map name
--- @param playerLocationStoreName string -- Data store name for player location
function RegionManager:__init(dataStoreNamePrefix: string | nil, memoryStorePrefix: string | nil, playerLocationStoreName: string | nil)
  self._dataStoreNamePrefix = dataStoreNamePrefix
  self._memoryStorePrefix = memoryStorePrefix
  self._playerLocationStoreName = playerLocationStoreName
  self._playerPositions = {}
end

--- Run function
function RegionManager:run(): nil
  self._worldStore = DataStoreService:GetDataStore(`{self._dataStoreNamePrefix}_WorldStore`)
  self._regionStore = DataStoreService:GetDataStore(`{self._dataStoreNamePrefix}_RegionStore`)
  self._regionLive = MemoryStoreService:GetHashMap(`{self._memoryStorePrefix}_RegionLive`)
  self._playerLocationStore = DataStoreService:GetDataStore(self.playerLocationStoreName)
  self._regionIsLoaded = false
  self._gridPos = {r=0, q=0}
  self._worldId = "w1"

  self.getGridPosRemoteFunction = ReplicatedStorage:FindFirstChild("RegionInfo") or Instance.new("RemoteFunction", ReplicatedStorage)
  self.getGridPosRemoteFunction.Name = "RegionInfo"

  OOP.Utility.eventListener(self, Players.PlayerAdded, "_onJoin")
  OOP.Utility.eventListener(self, Players.PlayerRemoving, "_onLeave")
  OOP.Utility.eventListener(self, Players.PlayerRemoving, "_onLeave")
  OOP.Utility.eventListener(self, RunService.Heartbeat, "_onHeartbeat")
  OOP.Utility.remoteFunctionListener(self, self.getGridPosRemoteFunction, "_onGetRegionInfo")

  return nil
end

--- @private
function RegionManager:_onJoin(player: Player): nil
  local teleportData = player:GetJoinData().TeleportData
  local localPos: SerializedPosition = nil
  if teleportData and teleportData._gridPos and teleportData._worldId and teleportData.localPos then
    self._gridPos = teleportData.gridPos
    self._worldId = teleportData.worldId
    localPos = teleportData.localPos
  end
  if not self._regionIsLoaded then
    -- In production, there should be always teleportData
    -- As players should join from a separate place that's the game menu.
    -- Setting it to (0,0) and assuming otherwise it's testing
    self:loadRegion()
    self._regionMath = RegionMath(REGION_RADIUS, self._gridPos)
    self._regionIsLoaded = true
  end
  -- Update player's location to that of region.
  local success, err = pcall(function()
    self._playerLocationStore:UpdateAsync(player.UserId, function(old)
      local new = old or {}
      if not new[self._worldId] then
        new[self._worldId] = {
          q = self._gridPos.q,
          r = self._gridPos.r,
        }
      end
      if localPos then
        new[self._worldId]['localPos'] = localPos
      else
        localPos = new[self._worldId]['localPos']
      end
      return new
    end)
  end)
  if not success then
    warn(err)
    player:Kick("Problem with region data store. Your data should be safe. If not, contact us with this screenshot")
  else
    local playerCharacter = player.Character or player.CharacterAdded:Wait()
    playerCharacter:MoveTo(Vector3.new(localPos.x, localPos.y, localPos.z))
  end
  return nil
end

--- @private
function RegionManager:_onHeartbeat(): nil
  -- Player position tracking
  for _, player in ipairs(Players:GetPlayers()) do
    local playerCharacter = player.Character or player.CharacterAdded:Wait()
    self._playerPositions[player.UserId] = playerCharacter:WaitForChild("HumanoidRootPart").Position
    self:regionCrossEval(player, self._playerPositions[player.UserId])
  end
  return nil
end

function RegionManager:regionCrossEval(player: Player, position: Vector3): boolean
  if not self._regionMath then return false end
  local fractionalHexAxis = self._regionMath:getFractionalAxisHex(position.X, position.Z)
  local cubeHexRounded = self._regionMath.cubeHexRoundedFromFractionalAxisHex(fractionalHexAxis)
  local axisHex = self._regionMath.getAxisFromHexCube(cubeHexRounded)
  return self._regionMath.regionCrossingCheck(axisHex), axisHex
end

--- @private
function RegionManager:_onLeave(player: Player): nil
  local playerCharacterPosition = self._playerPositions[player.UserId]
  if not playerCharacterPosition then
    warn("No saved player position for " .. player.UserId)
  end
  local success, err = pcall(function()
    self._playerLocationStore:UpdateAsync(player.UserId, function(old)
      old[self._worldId]['localPos'] = {x=playerCharacterPosition.X, y=playerCharacterPosition.Y, z=playerCharacterPosition.Z}
      return old
    end)
  end)
  if not success then
    warn(err)
  end
  self._playerPositions[player.UserId] = nil
  return nil
end

--- @private
function RegionManager:_onGetRegionInfo(player: Player)
  local playerCharacter = player.Character or player.CharacterAdded:Wait()
  local humanoidRootPart = playerCharacter.HumanoidRootPart or playerCharacter:WaitForChild("HumanoidRootPart")
  local regionCrossed, axisHex = self:regionCrossEval(player, humanoidRootPart.Position)
  return self._worldId, self._gridPos, regionCrossed, axisHex 
end

--- Load region from data store, use standalone only for debug
---
function RegionManager:loadRegion(): nil
  print(`{self._worldId}:({self._gridPos.q}, {self._gridPos.r})`)
  return nil
end

return RegionManager
