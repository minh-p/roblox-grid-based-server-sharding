local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TestRunner = require(ReplicatedStorage.Shared.TestRunner)

if RunService:IsStudio() then
  testRunner = TestRunner(script.Parent)
  testRunner:run()
end
