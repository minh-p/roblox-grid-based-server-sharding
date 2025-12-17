local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Types = require(ReplicatedStorage.Shared.Types)
type HexAxis = Types.HexAxis
type HexCube = Types.HexCube
type SerializedVector3 = Types.SerializedVector3

--- @class RegionMath
--- @server
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
  if error_x > error_y and error_x > error_z then
    rounded_x = -rounded_y - rounded_z
  elseif error_y > error_x and error_y > error_z then
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
--- @param hexAxis HexAxis -- Hex axial coordinate snapped to nearest grid.
function RegionMath.regionCrossingCheck(hexAxis: HexAxis): boolean
  if hexAxis.r ~= 0 or hexAxis.q ~= 0 then return true end
  return false
end

--- Return hex axial coordinate from hex cubic coordinate snapped to nearest grid.
---
--- @param hexCube HexCube -- Hex cubic coordinate snapped to nearest grid.
function RegionMath.getAxisFromHexCube(hexCube: HexCube): HexAxis
  return {r=hexCube.x, q = hexCube.z}
end

--- Return cartesian position relative to region they are crossing to
---
--- @param frHexCoord HexAxis -- Fractional hex axis coordinate.
--- @param snHexCoord HexAxis -- Snapped hex axis coordinate.
function RegionMath:getCartesianPositionRelativeToNewRegion(frHexCoord: HexAxis, snHexCoord: HexAxis): SerializedVector3
  local dq = frHexCoord.q - snHexCoord.q
  local dr = frHexCoord.r - snHexCoord.r
  local x_new = self.radius * math.sqrt(3) * (dq + dr/2)
  local z_new = self.radius * 3 / 2 * dr
  return {x=x_new, y=0, z=z_new}
end

--- Return hex-edge direction index from 0-5
--- ```
--- (+1,0)→0
--- (+1,−1)→1
--- (0,−1)→2
--- (−1,0)→3
--- (−1,+1)→4
--- (0,+1)→5
--- ```
---
--- @param dAxialHex HexAxis -- Axial neighbor deltas
function RegionMath.getEnterDir(dAxialHex: HexAxis): number
  local dr = dAxialHex.r
  local dq = dAxialHex.q
  if dr ==  0 and dq ==  1 then return 0 end
  if dr == -1 and dq ==  1 then return 1 end
  if dr == -1 and dq ==  0 then return 2 end
  if dr ==  0 and dq == -1 then return 3 end
  if dr ==  1 and dq == -1 then return 4 end
  if dr ==  1 and dq ==  0 then return 5 end
  error(("not a neighbor delta: dr=%d dq=%d"):format(dr, dq))
end
return RegionMath
