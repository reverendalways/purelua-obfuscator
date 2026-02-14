-- Wrapper script to run obfuscator with proper path setup
package.path = debug.getinfo(1, "S").source:match("(.*[/%\\])") .. "?.lua;" .. package.path

local cli = require("cli")

-- Get arguments
local args = {...}
if #args < 1 then
    print("Usage: luajit run-obfuscate.lua <input-file> [preset] [output-file]")
    os.exit(1)
end

-- This won't work directly, let's try a different approach
-- Actually, let's just fix the path issue by setting it manually

local script_dir = debug.getinfo(1, "S").source:match("(.*[/%\\])")
package.path = script_dir .. "?.lua;" .. package.path

-- Now require and run cli
dofile(script_dir .. "cli.lua")

