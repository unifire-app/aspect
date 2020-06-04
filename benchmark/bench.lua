package.path = "./src/?.lua;./benchmark/?.lua;" .. package.path

local bench01 = require("bench-01")

bench01(1000)