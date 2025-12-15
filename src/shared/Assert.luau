local Assert = {}

function Assert.equal(a, b, msg)
  if a ~= b then
    error(msg or (`Expected {a} == {b}`), 2)
  end
end

function Assert.truthy(value, msg)
  if not value then
    error(msg or "Expected value to be truthy", 2)
  end
end

function Assert.near(a, b, epsilon, msg)
  epsilon = epsilon or 1e-4
  if math.abs(a - b) > epsilon then
    error(msg or (`Expected {b} ≈ {a}`), 2)
  end
end

return Assert
