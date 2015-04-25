json = require 'luci.json'
statistics = require 'gluon.api.statistics'
stations = require 'gluon.api.stations'

function handle_request(env)
  uhttpd.send("Status: HTTP/1.1 200 OK\r\n")
  uhttpd.send("Access-Control-Allow-Origin: *\n")
  uhttpd.send("Connection: Keep-Alive\r\n")
  uhttpd.send("Transfer-Encoding: chunked\r\n")
--  uhttpd.send("Content-Type: text/plain\r\n\r\n")
--  uhttpd.send(json.encode(env))
--  statistics()
  stations(env)
end

