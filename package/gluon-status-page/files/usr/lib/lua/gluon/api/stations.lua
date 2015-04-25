#!/usr/bin/lua

util = require 'luci.util'
json = require 'luci.json'
fs = require 'luci.fs'
nixio = require 'nixio'
iwinfo = require 'iwinfo'

function badrequest()
  uhttpd.send("Status: 400 Bad Request\n\n")
end

function get_stations(iw, ifname)
  local stations = {}

  for k, v in pairs(iw.assoclist(ifname)) do
    stations[k:lower()] = v
  end

  return stations
end

return function(env)
  local ifname = env.QUERY_STRING

  if ifname == nil then 
    badrequest()
    return
  end

  local list = util.exec('batctl if')
  local found = false
  for _, line in ipairs(util.split(list)) do
    if ifname == line:match('^(.-):') then
      found = true
    end
  end

  if found == false then
    badrequest()
    return
  end

  local wifitype = iwinfo.type(ifname)

  if wifitype == nil then
    badrequest()
    return
  end

  local iw = iwinfo[wifitype]

  uhttpd.send("Content-type: text/event-stream\n\n")

  while true do
    local stations = json.encode(get_stations(iw, ifname))
    uhttpd.send("data: " .. stations .. "\n\n")
    nixio.nanosleep(0, 20e6)
  end
end
