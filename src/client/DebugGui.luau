local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Pract = require(Players.LocalPlayer.PlayerScripts.Client.Pract)
local PractTypes = require(Players.LocalPlayer.PlayerScripts.Client.Pract.Types)
type PractElement = PractTypes.Element
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local OOP = require(ReplicatedStorage.Shared.OOP)
local Types = require(ReplicatedStorage.Shared.Types)
type HexAxis = Types.HexAxis
type SerializedVector3 = Types.SerializedVector3
--- @class DebugGui
--- @client
--- DebugGui made with Pract library. Monitor world and region grid.
local DebugGui = OOP.class{}

--- Constructor
function DebugGui:__init()
  self._regionInfoRemoteFunction = ReplicatedStorage:FindFirstChild("RegionInfo") or ReplicatedStorage:WaitForChild("RegionInfo")
  self._sendTeleportStatusRemoteEvent = ReplicatedStorage:FindFirstChild("TeleportStatus") or ReplicatedStorage:WaitForChild("TeleportStatus")
  self._teleportStatus = ""
end

--- Construct Gui method
function DebugGui.constructGui(props: {worldId: string, gridPos: HexAxis, regionCrossed: boolean, axisHex: HexAxis, posRel: SerializedVector3, teleportStatus: string}): PractElement
  if not props.worldId then
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
        Text = `Region Info: {props.worldId}: ({props.gridPos.r}, {props.gridPos.q}), Crossed Region: {props.regionCrossed}`,
        TextSize = 24,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.6, 0.1),
        AnchorPoint = Vector2.new(0.5, 0.5)
      }),
      RegionCoordinatesLabel = Pract.create("TextLabel", {
        Text = `Hex Axial ({props.axisHex.r}, {props.axisHex.q}) Cartesian relative to current region: ({math.round(props.posRel.x)}, {math.round(props.posRel.z)})` ,
        TextSize = 24,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.6, 0.2),
        AnchorPoint = Vector2.new(0.5, 0.5)
      }),
      TeleportStatusLabel = Pract.create("TextLabel", {
        Text = `{props.teleportStatus or ""}`,
        TextSize = 24,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.6, 0.3),
        AnchorPoint = Vector2.new(0.5, 0.5)
      })
    })
  end
end

--- Gnerate PractClassComponent
function DebugGui:generateClassComponent()
  return Pract.classComponent {
    init = function(cls)
      cls:setState {
        worldId = "",
        gridPos = {r=0, y=0},
        crossedRegion = false,
        axisHex = {r=0, q=0},
        posRel = {x=0, y=0, z=0},
        teleportStatus = ""
      }
      cls.mounted = true
      task.spawn(function()
        repeat
          local worldId, gridPos, regionCrossed, axisHex, posRel = self._regionInfoRemoteFunction:InvokeServer()
          task.wait(1)
          cls:setState {
            worldId = worldId,
            gridPos = gridPos,
            regionCrossed = regionCrossed,
            axisHex = axisHex,
            posRel = posRel,
            teleportStatus = self._teleportStatus
          }
        until not cls.mounted
      end)
    end,
    willUnmount = function(cls)
      cls.mounted = false
    end,
    render = function(cls)
      return Pract.create(self.constructGui, {
        worldId = cls.state.worldId,
        gridPos = cls.state.gridPos,
        regionCrossed = cls.state.regionCrossed,
        axisHex = cls.state.axisHex,
        posRel = cls.state.posRel,
        teleportStatus = cls.state.teleportStatus
      })
    end
  }
end

--- Run function
function DebugGui:run(): nil
  OOP.Utility.remoteEventListener(self, self._sendTeleportStatusRemoteEvent, "_onSentTeleportStatus")
  self._handle = Pract.mount(Pract.create(self:generateClassComponent()), PlayerGui, "NavMenuGui")
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
  print("status received " .. teleportStatus)
  self._teleportStatus = teleportStatus
end

return DebugGui
