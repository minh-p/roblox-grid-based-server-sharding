local REGION_RADIUS = 100
local PLAYER_SOFT_CAP = 80

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Types = require(ReplicatedStorage.Shared.Types)
local RegionMath = require(ServerScriptService.Server.Region.RegionMath)
local TeleportService = game:GetService("TeleportService")
type HexAxis = Types.HexAxis
type SerializedPosition = Types.SerializedPosition
local OOP = require(ReplicatedStorage.Shared.OOP)

--- @class RegionManager
--- @server
--- Class managing Region operations
local RegionManager = OOP.class{
  _dataStoreNamePrefix = "RegionDataStore",
  _memoryStorePrefix = "RegionMemStore",
  _playerLocationStoreName = "PlayerLocationDataStore"
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
--- How each _regionLive member should look like:
--- ```lua
--- regionLive['w1:0,0']{
---   playerCount = 70,
---   status = "active" | "idle" | "booting" | "full",
---   -- TODO: need some caching of world state changes
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
  self._playerTeleportQueue = {}
end

--- Run function
function RegionManager:run(): nil
  self._worldStore = DataStoreService:GetDataStore(`{self._dataStoreNamePrefix}_WorldStore`)
  self._regionStore = DataStoreService:GetDataStore(`{self._dataStoreNamePrefix}_RegionStore`)
  self._regionLive = MemoryStoreService:GetHashMap(`{self._memoryStorePrefix}_RegionLive`)
  self._playerLocationStore = DataStoreService:GetDataStore(self._playerLocationStoreName)
  self._regionIsLoaded = false
  self._gridPos = {r=0, q=0}
  self._worldId = "w1"

  self.openNavMenuRemoteEvent = ReplicatedStorage:FindFirstChild("NavMenu") or Instance.new("RemoteEvent")
  self.openNavMenuRemoteEvent.Name = "NavMenu"
  self.openNavMenuRemoteEvent.Parent = ReplicatedStorage

  self.getGridPosRemoteFunction = ReplicatedStorage:FindFirstChild("RegionInfo") or Instance.new("RemoteFunction")
  self.getGridPosRemoteFunction.Name = "RegionInfo"
  self.getGridPosRemoteFunction.Parent = ReplicatedStorage

  self.sendTeleportStatusRemoteEvent = ReplicatedStorage:FindFirstChild("TeleportStatus") or Instance.new("RemoteEvent")
  self.sendTeleportStatusRemoteEvent.Name = "TeleportStatus"
  self.sendTeleportStatusRemoteEvent.Parent = ReplicatedStorage

  OOP.Utility.eventListener(self, Players.PlayerAdded, "_onJoin")
  OOP.Utility.eventListener(self, Players.PlayerRemoving, "_onLeave")
  OOP.Utility.eventListener(self, Players.PlayerRemoving, "_onLeave")
  OOP.Utility.bindToClose(self, "_onGameClose")
  OOP.Utility.cycle(self, 30, "_cycleRegionLive")
  OOP.Utility.cycle(self, 1, "_cyclePlayerPositionUpdating")
  OOP.Utility.cycle(self, 5, "_cyclePlayerRegionCrossingCheck")
  OOP.Utility.remoteFunctionListener(self, self.getGridPosRemoteFunction, "_onGetRegionInfo")

  return nil
end

--- @private
function RegionManager:_onJoin(player: Player): nil
  local teleportData = player:GetJoinData().TeleportData
  local localPos: SerializedPosition = nil
  if RunService:IsStudio() then
    teleportData = {
      worldId = "w1",
      gridPos = {r = 0, q = 0},
      accessCode = "0"
    }
  else
    if game.PrivateServerId == "" then
      self.openNavMenuRemoteEvent:FireClient(player)
      return nil
    end
  end

  if teleportData then
    if teleportData.localPos then
      localPos = teleportData.localPos
    end
    if teleportData.worldId and teleportData.gridPos then
      if self._regionIsLoaded then
        if RunService:IsStudio() then
          print("Region is already loaded!")
        else
          player:Kick("Region has already loaded. Your state in the last region should be saved. Otherwise, submit a ticket.")
        end
      else
        self._gridPos = teleportData.gridPos
        self._worldId = teleportData.worldId
        self:loadRegion(player, localPos, teleportData.accessCode)
      end
    end
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
function RegionManager:_cyclePlayerPositionUpdating(): nil
  for _, player in ipairs(Players:GetPlayers()) do
    local playerCharacter = player.Character or player.CharacterAdded:Wait()
    self._playerPositions[player.UserId] = playerCharacter:WaitForChild("HumanoidRootPart").Position
  end
  return nil
end

--- @private
function RegionManager:_cyclePlayerRegionCrossingCheck(): nil
  if not self._regionMath then return end
  for _, player in ipairs(Players:GetPlayers()) do
    local crossed, axisHex, fractionalAxisHex = self:regionCrossEval(self._playerPositions[player.UserId])
    if not crossed then continue end
    local new_region_q = self._gridPos.q + axisHex.q
    local new_region_r = self._gridPos.r + axisHex.r
    self.sendTeleportStatusRemoteEvent:FireClient(player, `Teleporting to region ({new_region_r},{new_region_q})`)
    local positionRelativeToNewRegion = self._regionMath:getCartesianPositionRelativeToNewRegion(fractionalAxisHex, axisHex)
    local getRegionLiveSuccess, regionLiveVal = pcall(function()
    local accessCode = TeleportService:ReserveServerAsync(game.PlaceId)
    return self._regionLive:UpdateAsync(`{self._worldId}:{new_region_q},{new_region_r}`, function(old)
        if not old or old.status == "idle" then
        return {
            accessCode = accessCode
        }
        end
        return old
    end, 30)
    end)

    if not getRegionLiveSuccess then
    warn(regionLiveVal)
    continue
    end
    self:teleportPlayerToRegion(player, {q = new_region_q, r = new_region_r}, positionRelativeToNewRegion, regionLiveVal.accessCode)
  end
  return nil
end

--- @private
function RegionManager:_cycleRegionLive(): nil
  if not self._regionIsLoaded then return end
  self._regionLive:UpdateAsync(`{self._worldId}:{self._gridPos.r},{self._gridPos.q}`, function(old)
    local playerCount = #Players:GetPlayers()
    local status = old.status
    if status ~= "booting" and playerCount < PLAYER_SOFT_CAP then
      status = "active"
    end
    return {
      playerCount = playerCount,
      status = status,
      accessCode = old.accessCode
    }
  end, 30)
  return nil
end

--- Teleport to player to region grid
---
--- @param player Player -- The player being teleported
--- @param hexAxis HexAxis -- The grid's coordinate in hex axial coordinate
--- @param relativePosition SerializedPosition -- The player's new position relative to new region.
--- @param accessCode string -- Private server access code
function RegionManager:teleportPlayerToRegion(player: Player, hexAxis: HexAxis, relativePosition: SerializedPosition, accessCode: string): nil
  if self._playerTeleportQueue[player.UserId] then return end
  self._playerTeleportQueue[player.UserId] = true
  self.sendTeleportStatusRemoteEvent:FireClient(player, "Teleporting...")
  if not self:evaluateTeleportable(hexAxis) then
    self.sendTeleportStatusRemoteEvent:FireClient(player, "Teleporting Failed")
  else
    TeleportService:TeleportToPrivateServer(game.PlaceId, accessCode, { player }, nil, {
      accessCode = accessCode,
      localPos = relativePosition
    })
  end
  if Players:FindFirstChild(player.Name) then
    -- Debug purposes
    self.sendTeleportStatusRemoteEvent:FireClient(player, "")
  end
  self._playerTeleportQueue[player.UserId] = nil
  return nil
end

--- Evalute of region is teleportable to
---
--- @param hexAxis HexAxis -- The region grid to find or create new
function RegionManager:evaluateTeleportable(hexAxis: HexAxis): (boolean, boolean | nil)
  local key = `{self._worldId}:{hexAxis.r},{hexAxis.q}`
  local getSuccess, val = pcall(function()
    return self._regionLive:GetAsync(key)
  end)
  print(val)
  if not getSuccess then
    warn(("RegionLive:GetAsync failed for %s: %s"):format(key, tostring(val)))
    return false
  elseif val == nil or val.status == "idle" then
    -- Teleportable, player carries load packet information
    return true, true
  else
    if val.status ~= "active" or val.playerCount >= PLAYER_SOFT_CAP then return false end
    return true
  end
end

--- Check if position has crossed region.
function RegionManager:regionCrossEval(position: Vector3): boolean
  if not self._regionMath then return false end
  local fractionalHexAxis = self._regionMath:getFractionalAxisHex(position.X, position.Z)
  local cubeHexRounded = self._regionMath.cubeHexRoundedFromFractionalAxisHex(fractionalHexAxis)
  local axisHex = self._regionMath.getAxisFromHexCube(cubeHexRounded)
  return self._regionMath.regionCrossingCheck(axisHex), axisHex, fractionalHexAxis
end

--- @private
function RegionManager:_onLeave(player: Player): nil
  local playerCharacterPosition = self._playerPositions[player.UserId]
  local regionLiveUpdateSuccess, regionLiveUpdateError = pcall(function()
    self._regionLive:UpdateAsync(`{self._worldId}:{self._gridPos.r},{self._gridPos.q}`, function(old)
      if old and old.playerCount then
        old.playerCount = math.clamp(old.playerCount-1, 0, PLAYER_SOFT_CAP)
      end
      return old
    end, 30)
  end)

  if not regionLiveUpdateSuccess then
    warn(regionLiveUpdateError)
  end

  if not playerCharacterPosition then
    warn("No saved player position for " .. player.UserId)
    return
  end
  local locationUpdateSuccess, locationUpdateError = pcall(function()
    -- TODO: make system more robust. What if player crashes?
    self._playerLocationStore:UpdateAsync(player.UserId, function(old)
      old[self._worldId]['localPos'] = {x=playerCharacterPosition.X, y=playerCharacterPosition.Y, z=playerCharacterPosition.Z}
      return old
    end)
  end)
  if not locationUpdateSuccess then
    warn(locationUpdateError)
  end

  self._playerPositions[player.UserId] = nil
  return nil
end

function RegionManager:_onGameClose(): nil
  self._regionLive:UpdateAsync(`{self._worldId}:{self._gridPos.r},{self._gridPos.q}`, function(old)
    local new = old or {}
    new.status = "idle"
    new.playerCount = 0
    return old
  end, 30)
  return nil
end

--- @private
function RegionManager:_onGetRegionInfo(player: Player)
  if not self._regionMath then return end
  local playerCharacter = player.Character or player.CharacterAdded:Wait()
  local humanoidRootPart = playerCharacter.HumanoidRootPart or playerCharacter:WaitForChild("HumanoidRootPart")
  local regionCrossed, axisHex, fractionalAxisHex = self:regionCrossEval(humanoidRootPart.Position)
  local positionRelativeToNewRegion = self._regionMath:getCartesianPositionRelativeToNewRegion(fractionalAxisHex, axisHex)
  return self._worldId, self._gridPos, regionCrossed, axisHex, positionRelativeToNewRegion
end

--- Load region from data store, use standalone only for debug
---
--- @param player Player -- Player carrying the region loading data
--- @param localPos SerializedPosition -- Position to pass to already existing region instance, region load fail.
--- @param accessCode string -- Region's private server access code.
function RegionManager:loadRegion(player: Player, localPos: SerializedPosition, accessCode: string): nil
  local key = `{self._worldId}:{self._gridPos.r},{self._gridPos.q}`
  local updateSuccess, val = pcall(function()
    return self._regionLive:UpdateAsync(key, function(old)
      local new = old or {}
      new.status = "booting"
      return new
    end, 60)
  end)
  if not updateSuccess then
    player:Kick("Attempting to load region failed. Submit a ticket to report. Your state in the last region should still be saved. Here's the error message regarding MemoryStoreHashmap: " .. tostring(val))
    return nil
  end
  print(val)
  self._regionMath = RegionMath(REGION_RADIUS, self._gridPos)
  self._regionIsLoaded = true
  val = self._regionLive:UpdateAsync(key, function(old)
    old.status = "active"
    return old
  end, 60)
  print(val)
  return nil
end

return RegionManager
