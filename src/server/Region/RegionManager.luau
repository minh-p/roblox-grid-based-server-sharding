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
type HexAxial = Types.HexAxial
type SerializedVector3 = Types.SerializedVector3
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
---   accessCode = "string containing private server access code"
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
  self._playerLookAts = {}
  self._playerTeleportQueue = {}
end

--- Run function
function RegionManager:run(): nil
  if not RunService:IsStudio() and game.PrivateServerId == "" then
    Players.CharacterAutoLoads = false
  end
  self._worldStore = DataStoreService:GetDataStore(`{self._dataStoreNamePrefix}_WorldStore`)
  self._regionStore = DataStoreService:GetDataStore(`{self._dataStoreNamePrefix}_RegionStore`)
  self._regionLive = MemoryStoreService:GetHashMap(`{self._memoryStorePrefix}_RegionLive`)
  self._playerLocationStore = DataStoreService:GetDataStore(self._playerLocationStoreName)
  self._regionIsLoaded = false
  self._gridPos = {r=0, q=0}
  self._worldId = "w1"

  self._openNavMenuRemoteEvent = ReplicatedStorage:FindFirstChild("NavMenu") or Instance.new("RemoteEvent")
  self._openNavMenuRemoteEvent.Name = "NavMenu"
  self._openNavMenuRemoteEvent.Parent = ReplicatedStorage

  self._getGridPosRemoteFunction = ReplicatedStorage:FindFirstChild("RegionInfo") or Instance.new("RemoteFunction")
  self._getGridPosRemoteFunction.Name = "RegionInfo"
  self._getGridPosRemoteFunction.Parent = ReplicatedStorage

  self._sendTeleportStatusRemoteEvent = ReplicatedStorage:FindFirstChild("TeleportStatus") or Instance.new("RemoteEvent")
  self._sendTeleportStatusRemoteEvent.Name = "TeleportStatus"
  self._sendTeleportStatusRemoteEvent.Parent = ReplicatedStorage

  self._requestTeleportRemoteEvent = ReplicatedStorage:FindFirstChild("TeleportRequest") or Instance.new("RemoteEvent")
  self._requestTeleportRemoteEvent.Name = "TeleportRequest"
  self._requestTeleportRemoteEvent.Parent = ReplicatedStorage

  OOP.Utility.eventListener(self, Players.PlayerAdded, "_onJoin")
  OOP.Utility.eventListener(self, Players.PlayerRemoving, "_onLeave")
  OOP.Utility.eventListener(self, Players.PlayerRemoving, "_onLeave")
  OOP.Utility.bindToClose(self, "_onGameClose")
  OOP.Utility.cycle(self, 10, "_cycleRegionLive")
  OOP.Utility.cycle(self, 1, "_cyclePlayerPositionUpdating")
  OOP.Utility.cycle(self, 5, "_cyclePlayerRegionCrossingCheck")
  OOP.Utility.remoteFunctionListener(self, self._getGridPosRemoteFunction, "_onGetRegionInfo")
  OOP.Utility.remoteEventListener(self, self._requestTeleportRemoteEvent, "_onTeleportRequest")

  return nil
end

--- @private
function RegionManager:_onJoin(player: Player): nil
  local teleportData = player:GetJoinData().TeleportData
  local localPos: SerializedVector3 = nil
  local lookAt: SerializedVector3 = nil
  local enterDir: number = -1
  if RunService:IsStudio() then
    teleportData = {
      worldId = "w1",
      gridPos = {r = 0, q = 0},
      accessCode = "0",
    }
    self._openNavMenuRemoteEvent:FireClient(player)
  else
    if game.PrivateServerId == "" then
      self._openNavMenuRemoteEvent:FireClient(player)
      return nil
    end
  end

  if teleportData then
    if teleportData.localPos and teleportData.lookAt then
      localPos = teleportData.localPos
      lookAt = teleportData.lookAt
      enterDir = teleportData.enterDir or -1
    end
    if teleportData.worldId and teleportData.gridPos and not self._regionIsLoaded then
      self._gridPos = teleportData.gridPos
      self._worldId = teleportData.worldId
      self:loadRegion(player, teleportData.accessCode)
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
      if localPos and lookAt then
        new[self._worldId].localPos = localPos
        new[self._worldId].lookAt = localPos
      else
        localPos = new[self._worldId].localPos or {x=0, y=0, z=0}
        lookAt = new[self._worldId].lookAt or {x=0, y=0, z=0}
      end
      return new
    end)
  end)
  if not success then
    warn(err)
    player:Kick("Problem with region data store. Your data should be safe. If not, contact us with this screenshot")
  else
    local playerCharacter = player.Character or player.CharacterAdded:Wait()
    local position = Vector3.new(localPos.x, localPos.y, localPos.z)
    local lookAtVector = Vector3.new(lookAt.x, lookAt.y, lookAt.z)
    local cf = CFrame.lookAt(position , position + lookAtVector)

    if enterDir ~= -1 then
      cf *= CFrame.Angles(0, enterDir * math.pi/3, 0)
    end

    playerCharacter:MoveTo(position)
    task.wait()
    playerCharacter:PivotTo(cf)
  end
  return nil
end

--- @private
function RegionManager:_cyclePlayerPositionUpdating(): nil
  for _, player in ipairs(Players:GetPlayers()) do
    local playerCharacter = player.Character or player.CharacterAdded:Wait()
    local hrp = playerCharacter:WaitForChild("HumanoidRootPart")
    self._playerPositions[player.UserId] = hrp.Position
    self._playerLookAts[player.UserId] = hrp.CFrame.LookVector
  end
  return nil
end

--- @private
--- @param player Player -- Player requesting to teleport
function RegionManager:_onTeleportRequest(player, worldNumber: number)
  if type(worldNumber) ~= "number" or worldNumber < 1 or worldNumber > 2 then return end
  local getLocationSuccess, locationVal = pcall(function()
    return self._playerLocationStore:GetAsync(player.UserId)[`w{worldNumber}`]
  end)

  if not getLocationSuccess then return end
  local r = 0
  local q = 0
  local localPos = {x=0, y=0, z=0}
  local lookAt = {x=0, y=0, z=0}
  local enterDir = -1
  if locationVal and locationVal.localPos and locationVal.lookAt then
    r = locationVal.r
    q = locationVal.q
    localPos = locationVal.localPos
    lookAt = locationVal.localPos
  end

  local getRegionLiveSuccess, regionLiveVal = pcall(function()
    return self._regionLive:GetAsync(`w{worldNumber}:{r},{q}`)
  end)
  if not getRegionLiveSuccess then
    warn(regionLiveVal)
  end
  if not regionLiveVal or not regionLiveVal.accessCode then
    regionLiveVal = regionLiveVal or {}
    regionLiveVal.playerCount = 0
    regionLiveVal.accessCode = TeleportService:ReserveServerAsync(game.PlaceId)
    regionLiveVal.status = "booting"
    local getRegionLiveUpdatedSuccess, regionLiveUpdatedVal = pcall(function()
      return self._regionLive:UpdateAsync(`w{worldNumber}:{r},{q}`, function(old)
        return regionLiveVal
      end, 60)
    end)
    if not getRegionLiveUpdatedSuccess then
      warn(regionLiveUpdatedVal)
      return
    end
  end
  self:teleportPlayerToRegion(player, {q = q, r = r}, localPos, lookAt, enterDir, regionLiveVal.accessCode)
end

--- Function to get player's orientation
--- @within RegionManager
local function getPlayerLookAt(player: Player): SerializedVector3
  local character = player.Character or player.CharacterAdded:Wait()
  local hrp = character:WaitForChild("HumanoidRootPart")
  return {
    x = hrp.CFrame.LookVector.X,
    y = hrp.CFrame.LookVector.Y,
    z = hrp.CFrame.LookVector.Z
  }
end

--- @private
function RegionManager:_cyclePlayerRegionCrossingCheck(): nil
  if not self._regionMath then return end
  for _, player in ipairs(Players:GetPlayers()) do
    if not self._playerPositions[player.UserId] then return end
    local crossed, hexAxial, fractionalHexAxial = self:regionCrossEval(self._playerPositions[player.UserId])
    if not crossed then continue end
    local new_region_q = self._gridPos.q + hexAxial.q
    local new_region_r = self._gridPos.r + hexAxial.r
    local enterDir = self._regionMath.getEnterDir(hexAxial)
    self._sendTeleportStatusRemoteEvent:FireClient(player, `Teleporting to region ({new_region_r},{new_region_q})`)
    local positionRelativeToNewRegion = self._regionMath:getCartesianPositionRelativeToNewRegion(fractionalHexAxial, hexAxial)
    local getRegionLiveSuccess, regionLiveVal = pcall(function()
      return self._regionLive:GetAsync(`{self._worldId}:{new_region_r},{new_region_q}`)
    end)
    if not getRegionLiveSuccess then
      warn(regionLiveVal)
    end
    if not regionLiveVal or not regionLiveVal.accessCode then
      regionLiveVal = regionLiveVal or {}
      regionLiveVal.playerCount = 0
      regionLiveVal.accessCode = TeleportService:ReserveServerAsync(game.PlaceId)
      regionLiveVal.status = "booting"
      local getRegionLiveUpdatedSuccess, regionLiveUpdatedVal = pcall(function()
        return self._regionLive:UpdateAsync(`{self._worldId}:{new_region_r},{new_region_q}`, function(old)
          return regionLiveVal
        end, 60)
      end)
      if not getRegionLiveUpdatedSuccess then
        warn(regionLiveUpdatedVal)
        return
      end
    end
    self:teleportPlayerToRegion(player, {q = new_region_q, r = new_region_r}, positionRelativeToNewRegion, getPlayerLookAt(player), enterDir, regionLiveVal.accessCode)
  end
  return nil
end

--- @private
function RegionManager:_cycleRegionLive(): nil
  if not self._regionIsLoaded then return end
  self._regionLive:UpdateAsync(`{self._worldId}:{self._gridPos.r},{self._gridPos.q}`, function(old)
    local playerCount = #Players:GetPlayers()
    local status = ""
    if old then status = old.status end
    if status ~= "booting" then
      if playerCount < PLAYER_SOFT_CAP then
        status = "active"
      else
        status = "full"
      end
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
--- @param hexAxial HexAxial -- The grid's coordinate in hex axial coordinate
--- @param relativePosition SerializedVector3 -- The player's new position relative to new region.
--- @param lookAt SerializedVector3 -- The player's lookAt or orientation
--- @param accessCode string -- Private server access code
function RegionManager:teleportPlayerToRegion(player: Player, hexAxial: HexAxial, relativePosition: SerializedVector3, lookAt: SerializedVector3, enterDir: number, accessCode: string): nil
  if self._playerTeleportQueue[player.UserId] then return end
  self._playerTeleportQueue[player.UserId] = true
  self._sendTeleportStatusRemoteEvent:FireClient(player, "Teleporting...")
  if not self:evaluateTeleportable(hexAxial) then
    self._sendTeleportStatusRemoteEvent:FireClient(player, "Teleporting Failed")
  else
    TeleportService:TeleportToPrivateServer(game.PlaceId, accessCode, { player }, nil, {
      worldId = self._worldId,
      gridPos = hexAxial,
      localPos = relativePosition,
      lookAt = lookAt,
      accessCode = accessCode,
      enterDir = enterDir
    })
  end
  if Players:FindFirstChild(player.Name) then
    -- Debug purposes
    self._sendTeleportStatusRemoteEvent:FireClient(player, "You're still here? Lol oops")
  end
  self._playerTeleportQueue[player.UserId] = nil
  return nil
end

--- Evalute of region is teleportable to
---
--- @param hexAxial HexAxial -- The region grid to find or create new
function RegionManager:evaluateTeleportable(hexAxial: HexAxial): (boolean, boolean | nil)
  local key = `{self._worldId}:{hexAxial.r},{hexAxial.q}`
  local getSuccess, val = pcall(function()
    return self._regionLive:GetAsync(key)
  end)
  if not getSuccess then
    warn(("RegionLive:GetAsync failed for %s: %s"):format(key, tostring(val)))
    return false
  elseif val == nil or val.status == "idle" then
    -- Teleportable, player carries load packet information
    return true, true
  else
    if val.status == "full" then
      return false
    end
    return true
  end
end

--- Check if position has crossed region.
function RegionManager:regionCrossEval(position: Vector3): boolean
  if not self._regionMath then return false end
  local fractionalHexAxial = self._regionMath:getFractionalHexAxial(position.X, position.Z)
  local cubeHexRounded = self._regionMath.cubeHexRoundedFromFractionalHexAxial(fractionalHexAxial)
  local hexAxial = self._regionMath.getAxisFromHexCubic(cubeHexRounded)
  return self._regionMath.regionCrossingCheck(hexAxial), hexAxial, fractionalHexAxial
end

--- @private
function RegionManager:_onLeave(player: Player): nil
  local playerCharacterPosition = self._playerPositions[player.UserId]
  local playerCharacterLookAt = self._playerLookAts[player.UserId]
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
      old[self._worldId].localPos = {x=playerCharacterPosition.X, y=playerCharacterPosition.Y, z=playerCharacterPosition.Z}
      old[self._worldId].r = self._gridPos.r
      old[self._worldId].q = self._gridPos.q
      old[self._worldId].lookAt = {x = playerCharacterLookAt.X, y = playerCharacterLookAt.Y, z = playerCharacterLookAt.Z}
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
  local humanoidRootPart = playerCharacter:WaitForChild("HumanoidRootPart")
  local regionCrossed, hexAxial, fractionalHexAxial = self:regionCrossEval(humanoidRootPart.Position)
  local positionRelativeToNewRegion = self._regionMath:getCartesianPositionRelativeToNewRegion(fractionalHexAxial, hexAxial)
  return self._worldId, self._gridPos, regionCrossed, hexAxial, positionRelativeToNewRegion
end

--- Load region from data store, use standalone only for debug
---
--- @param player Player -- Player carrying the region loading data
--- @param accessCode string -- Region's private server access code.
function RegionManager:loadRegion(player: Player, accessCode: string): nil
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
  self._regionMath = RegionMath(REGION_RADIUS, self._gridPos)
  self._regionIsLoaded = true
  val = self._regionLive:UpdateAsync(key, function(old)
    old.status = "active"
    return old
  end, 60)
  return nil
end

return RegionManager
