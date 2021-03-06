local uci = luci.model.uci.cursor()
local fs = require 'nixio.fs'


local function find_phy_by_path(path)
  for phy in fs.glob("/sys/devices/" .. path .. "/ieee80211/phy*") do
    return phy:match("([^/]+)$")
  end
end

local function find_phy_by_macaddr(macaddr)
  local addr = macaddr:lower()
  for file in fs.glob("/sys/class/ieee80211/*/macaddress") do
    if luci.util.trim(fs.readfile(file)) == addr then
      return file:match("([^/]+)/macaddress$")
    end
  end
end

local function txpower_list(iw)
  local list = iw.txpwrlist or { }
  local off  = tonumber(iw.txpower_offset) or 0
  local new  = { }
  local prev = -1
  local _, val
  for _, val in ipairs(list) do
    local dbm = val.dbm + off
    local mw  = math.floor(10 ^ (dbm / 10))
    if mw ~= prev then
      prev = mw
      table.insert(new, {
                     display_dbm = dbm,
                     display_mw  = mw,
                     driver_dbm  = val.dbm,
      })
    end
  end
  return new
end


local f = SimpleForm("wifi", translate("WLAN"))
f.template = "admin/expertmode"

local s = f:section(SimpleSection, nil, translate(
                "You can enable or disable your node's client and mesh network "
                  .. "SSIDs here. Please don't disable the mesh network without "
                  .. "a good reason, so other nodes can mesh with yours.<br /><br />"
                  .. "It is also possible to configure the WLAN adapters transmission power "
                  .. "here. Please note that the transmission power values include the antenna gain "
                  .. "where available, but there are many devices for which the gain is unavailable or inaccurate."
))

local radios = {}

-- look for wifi interfaces and add them to the array
uci:foreach('wireless', 'wifi-device',
  function(s)
    table.insert(radios, s['.name'])
  end
)

-- add a client and mesh checkbox for each interface
for _, radio in ipairs(radios) do
  local config = uci:get_all('wireless', radio)
  local p

  if config.hwmode == '11g' or config.hwmode == '11ng' then
    p = f:section(SimpleSection, translate("2.4GHz WLAN"))
  elseif config.hwmode == '11a' or config.hwmode == '11na' then
    p = f:section(SimpleSection, translate("5GHz WLAN"))
  end

  if p then
    local o

    --box for the client network
    o = p:option(Flag, radio .. '_client_enabled', translate("Enable client network"))
    o.default = uci:get_bool('wireless', 'client_' .. radio, "disabled") and o.disabled or o.enabled
    o.rmempty = false

    --box for the mesh network
    o = p:option(Flag, radio .. '_mesh_enabled', translate("Enable mesh network"))
    o.default = uci:get_bool('wireless', 'mesh_' .. radio, "disabled") and o.disabled or o.enabled
    o.rmempty = false

    local phy

    if config.path then
      phy = find_phy_by_path(config.path)
    elseif config.macaddr then
      phy = find_phy_by_path(config.macaddr)
    end

    if phy then
      local iw = luci.sys.wifi.getiwinfo(phy)
      if iw then
        local txpowers = txpower_list(iw)

        if #txpowers > 1 then
          local tp = p:option(ListValue, radio .. '_txpower', translate("Transmission power"))
          tp.rmempty = true
          tp.default = uci:get('wireless', radio, 'txpower') or 'default'

          tp:value('default', translate("(default)"))

          table.sort(txpowers, function(a, b) return a.driver_dbm > b.driver_dbm end)

          for _, entry in ipairs(txpowers) do
            tp:value(entry.driver_dbm, "%i dBm (%i mW)" % {entry.display_dbm, entry.display_mw})
          end
        end
      end
    end
  end

end

--when the save-button is pushed
function f.handle(self, state, data)
  if state == FORM_VALID then

    for _, radio in ipairs(radios) do

      local clientdisabled = 0
      if data[radio .. '_client_enabled'] == '0' then
        clientdisabled = 1
      end
      uci:set('wireless', 'client_' .. radio, "disabled", clientdisabled)

      local meshdisabled = 0
      if data[radio .. '_client_enabled'] == '0' then
        meshdisabled = 1
      end
      uci:set('wireless', 'mesh_' .. radio, "disabled", meshdisabled)

      if data[radio .. '_txpower'] then
        if data[radio .. '_txpower'] == 'default' then
          uci:delete('wireless', radio, 'txpower')
        else
          uci:set('wireless', radio, 'txpower', data[radio .. '_txpower'])
        end
      end

    end

    uci:save('wireless')
    uci:commit('wireless')
  end
end

return f
