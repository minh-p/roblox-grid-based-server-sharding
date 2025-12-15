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
  self.regionInfoRemoteFunction = ReplicatedStorage.RegionInfo or ReplicatedStorage:WaitForChild("RegionInfo")
  local element = self:constructGui()
  self.handle = Pract.mount(element, PlayerGui, "DebugGui")
end

--- Construct Gui method
function DebugGui:constructGui(): PractElement
  local worldId, gridPos, crossedRegion, axisHex = self.regionInfoRemoteFunction:InvokeServer()
  return Pract.create("ScreenGui", {ResetOnSpawn = false}, {
    RegionInfoLabel = Pract.create("TextLabel", {
      Text = `Region Info: {worldId}: ({gridPos.q}, {gridPos.r}), Crossed Region: {crossedRegion}: Hex Axial ({axisHex.r}, {axisHex.q})`,
      TextSize = 24,
      BackgroundTransparency = 1,
      Position = UDim2.fromScale(0.6, 0.1),
      AnchorPoint = Vector2.new(0.5, 0.5)
  })})
end

--- Run function
function DebugGui:run(): nil
  while true do
    task.wait(1)
    Pract.update(self.handle, self:constructGui())
  end
  return nil
end

return DebugGui
