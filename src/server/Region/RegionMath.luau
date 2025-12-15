local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RegionMath = require(ReplicatedStorage.Shared.OOP).class{radius = 10, gridPos = {0, 0}}
local Types = require(ReplicatedStorage.Shared.Types)

function RegionMath:__init(radius: number, gridPos: Types.List<number>)
  self.radius = radius
  self.gridPos = gridPos
end

function RegionMath:__tostring(): string
  return `Region r={self.radius}, gridPos=({self.gridPos[1]}, {self.gridPos[2]})`
end

function RegionMath:getFractionalAxisHex(cartesianX: number, cartesianZ: number): Types.HexAxis
  local q = math.sqrt(3) * cartesianX / (3 * self.radius) - cartesianZ / (3 * self.radius)
  local r = 2 * cartesianZ / (3 * self.radius)
  return {q=q, r=r}
end

return RegionMath
