#!/usr/bin/lua

local util = require 'luci.util'
local nixio = require 'nixio'
local announce = require 'gluon.api.announce'

return function()
  uhttpd.send("Content-type: text/event-stream\n\n")

  while true do
    uhttpd.send("data: " .. announce("statistics") .. "\n\n")
    nixio.nanosleep(1, 0)
  end
end
