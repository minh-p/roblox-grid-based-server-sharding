--[[
  Example Specs:

  OPTION #1
  return function()
	-- assertions...
  end

  OPTION #2
  return {
    name = "Test",
    run = function()
      -- assertions
    end
  }

  OPTION #3
  return {
    name = "Test",
    steps = {
      function()
      end,
      function()
      end
    }
  }
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestService = game:GetService("TestService")
local TestRunner = require(ReplicatedStorage.Shared.OOP).class{}

function TestRunner:__init(testsFolder: Folder)
  self.testsFolder = testsFolder
end

local function runSpec(specValue)
  if type(specValue) == "function" then
    return specValue()
  end

  if type(specValue) == "table" and type(specValue.run) == "function" then
  	return specValue.run()
  end

  if type(specValue) == "table" and type(specValue.steps) == "table" then
  	for i, stepFn in ipairs(specValue.steps) do
  		if type(stepFn) ~= "function" then
  			error(("steps[%d] is not a function"):format(i), 2)
  		end
  		stepFn()
  	end
  	return
  end
  
  error("Spec must return a function, or a table with `run`, or a table with `steps`", 2)
end

function TestRunner:run(): nil
  local failed = 0
  local passed = 0
  for _, mod in ipairs(self.testsFolder:GetChildren()) do
    if mod:IsA("ModuleScript") and mod.Name:match("%.spec$") then
      local ok, val = pcall(require, mod)

      if not ok then
        TestService:Error(`Failed to load {mod.Name}`)
        failed += 1
        continue
      end

      local label = mod.Name
      if type(val) == "table" and type(val.name) == "string" then
        label = (`{mod.Name} - {val.name}`)
      end

      local success, err = pcall(runSpec, val)
      if success then
        TestService:Message(`✔ {label}`)
        passed += 1
      else
        TestService:Fail(`✘ {label}\n{err}`)
        failed += 1
      end
    end
  end
  TestService:Message(`Tests complete: {passed} passed, {failed} failed`)
  return nil
end

return TestRunner
