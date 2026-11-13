extends RefCounted
const PROTOCOL:=40
const MAX_PLAYERS:=4
const GUEST_LIMIT:=MAX_PLAYERS-1
const CONNECT_TIMEOUT_MS:=15000
const REGISTER_TIMEOUT_MS:=10000
static var DEFAULT_PORT: int=clampi(int(OS.get_environment("MYSTICAL_GARDEN_TEST_PORT")),1024,65535) if not OS.get_environment("MYSTICAL_GARDEN_TEST_PORT").is_empty() else 24576

static func address(value: String) -> String:
 var result:=value.strip_edges()
 if result.to_lower()=="localhost": return "127.0.0.1"
 if result.begins_with("[") and result.ends_with("]"): result=result.substr(1,result.length()-2)
 return result
static func error(value: String,port: int) -> String:
 if port<1024 or port>65535: return "Choose a port between 1024 and 65535."
 if not address(value).is_valid_ip_address(): return "Enter an IPv4 or IPv6 address, or localhost. Put the port in its own field."
 return ""
static func format_endpoint(host: String, port: int) -> String:
 return "[%s]:%d" % [host,port] if host.contains(":") else "%s:%d" % [host,port]

static func parse_endpoint(value: String, fallback_port: int) -> Dictionary:
 var host := value.strip_edges()
 var port := fallback_port
 var suffix := ""
 var explicit_port := false
 if host.begins_with("["):
  var end := host.find("]")
  if end >= 0 and end+1 < host.length() and host[end+1] == ":":
   suffix = host.substr(end+2)
   host = host.substr(0,end+1)
   explicit_port = true
 elif host.count(":") == 1:
  var parts := host.split(":",true,1)
  host = parts[0]
  suffix = parts[1]
  explicit_port = true
 if explicit_port:
  if not suffix.is_valid_int():
   return {"error":"Enter a numeric UDP port."}
  port = int(suffix)
 return {"address":address(host),"port":port,"error":error(host,port)}

static func load_settings(root: String) -> Dictionary:
 var file := ConfigFile.new()
 file.load(root.path_join("network.cfg"))
 var host := str(file.get_value("network","address","127.0.0.1"))
 var port := int(file.get_value("network","port",DEFAULT_PORT))
 if not error(host,port).is_empty():
  host = "127.0.0.1"
  port = DEFAULT_PORT
 var host_port := int(file.get_value("network","host_port",port))
 if not error("127.0.0.1",host_port).is_empty():
  host_port = DEFAULT_PORT
 return {"address":address(host),"port":port,"host_port":host_port}

static func save_settings(root: String, host: String, port: int, joining: bool = true) -> Error:
 if not error(host if joining else "127.0.0.1",port).is_empty():
  return ERR_INVALID_PARAMETER
 var current := load_settings(root)
 var file := ConfigFile.new()
 file.set_value("network","address",address(host) if joining else current.address)
 file.set_value("network","port",port if joining else current.port)
 file.set_value("network","host_port",current.host_port if joining else port)
 return preload("res://preference_file.gd").write(root.path_join("network.cfg"),file,true)

static func join_progress(phase: String, host: String, port: int) -> String:
 var endpoint := format_endpoint(host,port)
 match phase:
  "compatibility": return "2 of 4 · Checking game versions"
  "character": return "3 of 4 · Registering your character"
  "garden": return "4 of 4 · Loading the host’s Garden"
 return "1 of 4 · Connecting to " + endpoint

static func join_failure(phase: String, host: String, port: int, timed_out: bool) -> String:
 match phase:
  "compatibility": return "The compatibility check did not finish. Confirm everyone is using the same build, then try again."
  "character": return "The host did not finish registering your character. Check that the party is in the Garden and try again."
  "garden": return "The host’s Garden did not finish loading. Try joining again when the party is in the Garden."
 var reason := "Connection timed out." if timed_out else "Could not connect to the host."
 return "%s Check %s, the host’s firewall and UDP forwarding, and whether the Garden has room." % [reason,format_endpoint(host,port)]

static func lan_addresses() -> Array[String]:
 var result: Array[String]=[]
 for value in IP.get_local_addresses():
  if value.contains(":") or value.begins_with("127.") or value.begins_with("169.254.") or value=="0.0.0.0": continue
  result.append(value)
 return result
