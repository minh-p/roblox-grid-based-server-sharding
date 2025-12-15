local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Types = require(ReplicatedStorage.Shared.Types)
type HexAxis = Types.HexAxis
type HexCube = Types.HexCube

--- @class RegionMath
---
--- Process mathematical calculations to calculate region player is crossing to
local RegionMath = require(ReplicatedStorage.Shared.OOP).class{radius = 10, gridPos = {0, 0}}

--- Constructor
---
--- @param radius number -- Hexagonal radius of region
--- @param gridPos HexAxis -- Struct HexAxis r, q coordinate of grid
function RegionMath:__init(radius: number, gridPos: HexAxis)
  self.radius = radius
  self.gridPos = gridPos
end

function RegionMath:__tostring(): string
  return `Region r={self.radius}, gridPos=({self.gridPos.r}, {self.gridPos.q})`
end

--- Get hex axial coordinates from x,z cartesian coords
---
--- @param cartesianX number -- Normal Roblox x-coordinate
--- @param cartesianZ number -- Normal Roblox y-coordinate
function RegionMath:getFractionalAxisHex(cartesianX: number, cartesianZ: number): HexAxis
  local q = math.sqrt(3) * cartesianX / (3 * self.radius) - cartesianZ / (3 * self.radius)
  local r = 2 * cartesianZ / (3 * self.radius)
  return {q=q, r=r}
end

--- Derive hex cubic coordinate snapped to nearest grid from hex fractional axial coordinate.
---
--- @param hexAxis HexAxis -- Hex fractional axial coordinate.
function RegionMath.cubeHexRoundedFromFractionalAxisHex(hexAxis: HexAxis): HexCube
  -- Cube Hex
  local x = hexAxis.r
  local z = hexAxis.q
  local y = -x - z

  local rounded_x = math.round(x)
  local rounded_z = math.round(z)
  local rounded_y = math.round(y)

  -- Round to nearest grid (integer)
  local error_x = math.abs(rounded_x - x)
  local error_y = math.abs(rounded_y - y)
  local error_z = math.abs(rounded_z - z)

  -- Constraint Enforcement
  local max_error = math.max(error_x, error_y, error_z)
  if max_error == error_x then
    rounded_x = -rounded_y - rounded_z
  elseif max_error == error_y then
    rounded_y = -rounded_x - rounded_z
  else
    rounded_z = -rounded_x - rounded_y
  end

  return {
    x = rounded_x,
    y = rounded_y,
    z = rounded_z
  }
end

--- Returns true if region has been crossed.
---
--- @param hexCube HexCube -- Hex cubic coordinate snapped to nearest grid.
function RegionMath.regionCrossingCheck(hexCube: HexCube): boolean
  if hexCube.x ~= 0 or hexCube.z ~= 0 then return true end
  return false
end

--- Return hex axial coordinate from hex cubic coordinate snapped to nearest grid.
---
--- @param hexCube HexCube -- Hex cubic coordinate snapped to nearest grid.
function RegionMath.getAxisFromHexCube(hexCube: HexCube): HexAxis
  return {r=hexCube.x, q = hexCube.z}
end

return RegionMath
