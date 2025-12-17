--- @class Types
---
--- Project defined types
local Types = {}

--- @type List {T}
--- @within Types
--- A list of any type

export type List<T> = {T}
--- @type HexAxis {r: number, q: number}
--- @within Types
--- A struct with r, q hex axial coordinate components

export type HexAxis = {
  q: number,
  r: number
}

--- @type HexCube {x: number, y: number, z: number}
--- @within Types
--- A struct with x, y, z hex cubic coordinate components

export type HexCube = {
  x: number,
  y: number,
  z: number
}

--- @type SerializedVector3 {x: number, y: number, z: number}
--- @within Types
--- A struct with x, y, z serialized position components

export type SerializedVector3 = {
  x: number,
  y: number,
  z: number
}

return Types
