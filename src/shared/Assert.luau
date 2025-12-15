--- @class Assert
---
--- Collection of unbounded methods for value assertion for unit testing.
local Assert = {}

--- Make sure two values are strictly equal to each other
---
--- @param a any -- Value being tested
--- @param b any -- Expected result
--- @param msg string | nil -- Custom message
function Assert.equal(a: any, b: any, msg: string | nil)
  if a ~= b then
    error(msg or (`Expected {b} == {a}`), 2)
  end
end

--- If the value should be truthy (not nil or False)
---
--- @param value any -- Value being tested
--- @param msg string | nil -- Custom message
function Assert.truthy(value: any, msg: string | nil)
  if not value then
    error(msg or "Expected value to be truthy", 2)
  end
end

--- If two numbers are approximately equal or near each other.
---
--- @param a number -- Number being tested
--- @param b number -- Number expected
--- @param epsilon number | nil -- Constraint default is 1e-4
function Assert.near(a: number, b: number, epsilon: number | nil, msg: string | nil)
  epsilon = epsilon or 1e-4
  if math.abs(a - b) > epsilon then
    error(msg or (`Expected {b} ≈ {a}`), 2)
  end
end

return Assert
