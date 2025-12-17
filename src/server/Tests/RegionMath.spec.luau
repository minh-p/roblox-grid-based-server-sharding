local Assert = require(game:GetService("ReplicatedStorage").Shared.Assert)
local RegionMath = require(game:GetService("ServerScriptService").Server.Region.RegionMath)

return {
  name = "RegionMath Tests",
  steps = {
    function()
      local regionMath = RegionMath(10, {0, 0})
      Assert.equal(regionMath.radius, 10, "RegionMath init failed: radius not set or incorrect")
      Assert.equal(regionMath.gridPos[1], 0, "RegionMath init failed: gridPosX not set or incorrect")
      Assert.equal(regionMath.gridPos[2], 0, "RegionMath init failed: gridPosY not set or incorrect")
    end,
    function()
      -- Testing getFractionalHexAxial
      -- Exact center
      local regionMath = RegionMath(10, {0, 0})
      -- Center
      local result = regionMath:getFractionalHexAxial(0, 0)
      Assert.near(result.q, 0.0000)
      Assert.near(result.r, 0.0000)
      
      -- Pure X movement (z = 0)
      result = regionMath:getFractionalHexAxial(10, 0)
      Assert.near(result.q, 0.5774)
      Assert.near(result.r, 0.0000)
      
      result = regionMath:getFractionalHexAxial(-10, 0)
      Assert.near(result.q, -0.5774)
      Assert.near(result.r, 0.0000)
      
      -- Pure Z movement (x = 0)
      result = regionMath:getFractionalHexAxial(0, 10)
      Assert.near(result.q, -0.3333)
      Assert.near(result.r, 0.6667)
      
      result = regionMath:getFractionalHexAxial(0, -10)
      Assert.near(result.q, 0.3333)
      Assert.near(result.r, -0.6667)
      
      -- Diagonal-ish
      result = regionMath:getFractionalHexAxial(-8, 10)
      Assert.near(result.q, -0.7952)
      Assert.near(result.r, 0.6667)
      
      result = regionMath:getFractionalHexAxial(8, 10)
      Assert.near(result.q, 0.1285)
      Assert.near(result.r, 0.6667)
      
      result = regionMath:getFractionalHexAxial(-8, -10)
      Assert.near(result.q, -0.1285)
      Assert.near(result.r, -0.6667)
      
      result = regionMath:getFractionalHexAxial(8, -10)
      Assert.near(result.q, 0.7952)
      Assert.near(result.r, -0.6667)
      
      -- Interior sanity checks
      result = regionMath:getFractionalHexAxial(3, 4)
      Assert.near(result.q, 0.0399)  -- (sqrt3/3*0.3) - (1/3*0.4) ≈ 0.0399
      Assert.near(result.r, 0.2667)
      
      result = regionMath:getFractionalHexAxial(-4, 2)
      Assert.near(result.q, -0.2976) -- (sqrt3/3*-0.4) - (1/3*0.2) ≈ -0.2976
      Assert.near(result.r, 0.1333)
      
      result = regionMath:getFractionalHexAxial(5, 5)
      Assert.near(result.q, 0.1220)  -- (sqrt3/3*0.5) - (1/3*0.5) ≈ 0.1220
      Assert.near(result.r, 0.3333)

      -- Boundary stress test
      local z = 5 * math.sqrt(3) -- ≈ 8.660254...
      
      result = regionMath:getFractionalHexAxial(-5, z)
      Assert.near(result.q, -0.5774)
      Assert.near(result.r, 0.5774)
      
      result = regionMath:getFractionalHexAxial(5, z)
      Assert.near(result.q, 0.0000)
      Assert.near(result.r, 0.5774)
    end,
    function()
      local function assertCube(cube, ex, ey, ez, msg)
        Assert.equal(cube.x, ex, msg)
        Assert.equal(cube.y, ey, msg)
        Assert.equal(cube.z, ez, msg)
        Assert.equal(cube.x + cube.y + cube.z, 0, "Cube constraint violated: x+y+z must be 0")
      end
      
      local function assertIntegers(cube)
        Assert.equal(cube.x, math.floor(cube.x), "cube.x must be integer")
        Assert.equal(cube.y, math.floor(cube.y), "cube.y must be integer")
        Assert.equal(cube.z, math.floor(cube.z), "cube.z must be integer")
      end
      
      -- 1) Trivial exact integer case
      do
        local result = RegionMath.cubeHexRoundedFromFractionalHexAxial({ q = 0, r = 0 })
        assertIntegers(result)
        assertCube(result, 0, 0, 0, "origin should round to origin")
      end
      
      -- 2) Exact integers in (checks your q/r -> z/x convention)
      do
        local result = RegionMath.cubeHexRoundedFromFractionalHexAxial({ q = -1, r = 1 })
        -- x=r=1, z=q=-1, y=-x-z=0
        assertIntegers(result)
        assertCube(result, 1, 0, -1, "(-1,1) should map to cube (1,0,-1)")
      end
      
      -- 3) Stage-1-like fractional from (x,z)=(0,10) with s=10: q=-1/3, r=2/3
      do
        local result = RegionMath.cubeHexRoundedFromFractionalHexAxial({ q = -0.34, r = 0.67 })
        -- x=2/3->1, z=-1/3->0, y=-1/3->0, enforce constraint on y -> -1
        assertIntegers(result)
        assertCube(result, 1, 0, -1, "(q=-0.34,r=0.67) should round to cube (1,0,-1)")
      end
      
      -- 4) Your earlier computed fractional example: q≈-0.7952, r≈0.6667
      do
        local result = RegionMath.cubeHexRoundedFromFractionalHexAxial({ q = -0.7952, r = 0.6667 })
        -- x=0.6667->1, z=-0.7952->-1, y=0.1285->0 (already sums to 0)
        assertIntegers(result)
        assertCube(result, 1, 0, -1, "(q=-0.7952,r=0.6667) should round to cube (1,0,-1)")
      end
      
      -- 5) Force constraint branch: max_error == error_x (adjust x)
      do
        -- Choose values so x rounding error is the largest.
        local result = RegionMath.cubeHexRoundedFromFractionalHexAxial({ q = 0.20, r = 0.49 })
        -- x=0.49->0 (err 0.49), z=0.20->0 (err 0.20), y=-0.69->-1 (err 0.31)
        -- max is error_x => x = -ry - rz = -(-1) - 0 = 1
        assertIntegers(result)
        assertCube(result, 1, -1, 0, "should adjust x when error_x is max")
      end
      
      -- 6) Force constraint branch: max_error == error_y (adjust y)
      do
        -- Choose values so y rounding error is the largest.
        local result = RegionMath.cubeHexRoundedFromFractionalHexAxial({ q = 0.20, r = 0.31 })
        -- x=0.31->0 (err 0.31), z=0.20->0 (err 0.20), y=-0.51->-1 (err 0.49)
        -- max is error_y => y = -rx - rz = -0 - 0 = 0
        assertIntegers(result)
        assertCube(result, 0, 0, 0, "should adjust y when error_y is max")
      end
      
      -- 7) Force constraint branch: max_error == error_z (else branch, adjust z)
      do
        -- Choose values so z rounding error is the largest.
        local result = RegionMath.cubeHexRoundedFromFractionalHexAxial({ q = 0.49, r = 0.20 })
        -- x=0.20->0 (err 0.20), z=0.49->0 (err 0.49), y=-0.69->-1 (err 0.31)
        -- max is error_z => z = -rx - ry = -0 - (-1) = 1
        assertIntegers(result)
        assertCube(result, 0, -1, 1, "should adjust z when error_z is max")
      end
      
      -- 8) Invariant test: any input must return integer cube with sum 0
      do
        local result = RegionMath.cubeHexRoundedFromFractionalHexAxial({ q = 12.345, r = -98.76 })
        assertIntegers(result)
        Assert.equal(result.x + result.y + result.z, 0, "sum must always be 0 for arbitrary input")
      end
    end
  }
}
