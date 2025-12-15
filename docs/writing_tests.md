# Writing Tests
A spec is a module script that holds the tests.
## Specs Implementation
There are three ways to write specs that is compatible with the [TestRunner](/api/TestRunner) class. For the assertions, use the [Assert](/api/Assert) module.

1. Spec returns a function. Headless test.
```lua
return function()
  -- assertions...
end
```

2. Spec returns the test's name and the function to run:
```lua
return {
  name = "Test",
  run = function()
    -- assertions
  end
}
```

3. Spec returns test's name functions as different test steps:
```lua
return {
  name = "Test",
  steps = {
    function()
      -- assertions
    end,
    function()
      -- assertions
    end
  }
}
```
## TestRunner Example
```lua
--- src/server/Tests/Tester.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TestRunner = require(ReplicatedStorage.Shared.TestRunner)

if RunService:IsStudio() then
  testRunner = TestRunner(script.Parent)
  testRunner:run()
end
```
