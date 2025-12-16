local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Pract = require(Players.LocalPlayer.PlayerScripts.Client.Pract)
local PractTypes = require(Players.LocalPlayer.PlayerScripts.Client.Pract.Types)
type PractElement = PractTypes.Element
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local OOP = require(ReplicatedStorage.Shared.OOP)
local Types = require(ReplicatedStorage.Shared.Types)
type HexAxis = Types.HexAxis
--- @class DebugGui
--- @client
--- DebugGui made with Pract library. Monitor world and region grid.
local DebugGui = OOP.class{}

--- Constructor
function DebugGui:__init()
  self._regionInfoRemoteFunction = ReplicatedStorage:FindFirstChild("RegionInfo") or ReplicatedStorage:WaitForChild("RegionInfo")
  self._sendTeleportStatusRemoteEvent = ReplicatedStorage:FindFirstChild("TeleportStatus") or ReplicatedStorage:WaitForChild("TeleportStatus")
  local element = self:constructGui()
  self._handle = Pract.mount(element, PlayerGui, "DebugGui")
  self._playerTeleportQueue = {}
end

--- Construct Gui method
function DebugGui:constructGui(): PractElement
  local worldId, gridPos, crossedRegion, axisHex, posRel = self._regionInfoRemoteFunction:InvokeServer()
  if not worldId then
    return Pract.create("ScreenGui", {ResetOnSpawn = false}, {
      Label = Pract.create("TextLabel", {
        Text = "Uninitialized",
        TextSize = 24,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.6, 0.1),
        AnchorPoint = Vector2.new(0.5, 0.5)
      })
    })
  else
    return Pract.create("ScreenGui", {ResetOnSpawn = false}, {
      RegionInfoLabel = Pract.create("TextLabel", {
        Text = `Region Info: {worldId}: ({gridPos.q}, {gridPos.r}), Crossed Region: {crossedRegion}`,
        TextSize = 24,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.6, 0.1),
        AnchorPoint = Vector2.new(0.5, 0.5)
      }),
      RegionCoordinatesLabel = Pract.create("TextLabel", {
        Text = `Hex Axial ({axisHex.r}, {axisHex.q}) Cartesian relative to current region: ({math.round(posRel.x)}, {math.round(posRel.z)})` ,
        TextSize = 24,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.6, 0.2),
        AnchorPoint = Vector2.new(0.5, 0.5)
      }),
      TeleportStatusLabel = Pract.create("TextLabel", {
        Text = `{self.teleportStatus or ""}`,
        TextSize = 24,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.6, 0.3),
        AnchorPoint = Vector2.new(0.5, 0.5)
      })
    })
  end
end

--- Run function
function DebugGui:run(): nil
  OOP.Utility.remoteEventListener(self, self._sendTeleportStatusRemoteEvent, "_onSentTeleportStatus")
  OOP.Utility.cycle(self, 1, "_onUpdate")
  return nil
end

--- @private
function DebugGui:_onUpdate(): nil
  Pract.update(self._handle, self:constructGui())
  return nil
end

--- @private
---
--- @param teleportStatus string -- Status given by server.
function DebugGui:_onSentTeleportStatus(teleportStatus: string)
  self.teleportStatus = teleportStatus
end

return DebugGui
