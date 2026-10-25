local host_client, host_ui, host_require = client, ui, require
local runtime = {created_items = 0, callback_errors = {}, controls = {}}
local script_environment = setmetatable({}, {__index = _G})
local function decode_protected_text(bytes)
local chars = {}
for i = 1, #bytes do
    chars[i] = string.char((bytes[i] - 73 - (i - 1) * 7) % 256)
end
return table.concat(chars)
end

local discord_url = decode_protected_text({177, 196, 203, 206, 216, 166, 162, 169, 229, 241, 2, 249, 12, 22, 15, 224, 32, 39, 246, 35, 67, 62, 72, 33, 75, 98, 98, 121, 100})
local panorama_api = panorama.open()
script_environment._G = script_environment
setfenv(1, script_environment)
local function pack(...) return {n = select("#", ...), ...} end
local function log(message) host_client.log("[Wraith local] " .. tostring(message)) end
local client = setmetatable({}, {__index = host_client})
local registered_callbacks = {}
function client.set_event_callback(event, callback)
    registered_callbacks[event] = registered_callbacks[event] or {}
    if registered_callbacks[event][callback] then return end
    local function wrapped(...)
        if (event == "setup_command" or event == "predict_command" or event == "run_command" or event == "pre_render") and entity.get_local_player() == nil then return end
        local result = pack(pcall(callback, ...))
        if result[1] then return unpack(result, 2, result.n) end
        local message = event .. ": " .. tostring(result[2])
        if not runtime.callback_errors[message] then log(message) end
        runtime.callback_errors[message] = (runtime.callback_errors[message] or 0) + 1
    end
    registered_callbacks[event][callback] = wrapped
    return host_client.set_event_callback(event, wrapped)
end
function client.unset_event_callback(event, callback)
    local wrapped = registered_callbacks[event] and registered_callbacks[event][callback]
    if wrapped then
        registered_callbacks[event][callback] = nil
        return host_client.unset_event_callback(event, wrapped)
    end
end
local ui = setmetatable({}, {__index = host_ui})
local control_kinds = {}
local unavailable_references = {}
function ui.reference(tab, container, name)
    local result = pack(pcall(host_ui.reference, tab, container, name))
    if result[1] then return unpack(result, 2, result.n) end
    if name == "sv_maxusrcmdprocessticks2" then
        return host_ui.reference(tab, container, "sv_maxusrcmdprocessticks")
    end
    if name ~= "sv_maxusrcmdprocessticks_holdaim" and name ~= "sv_maxunlag2" then error(result[2], 2) end
    local item = host_ui.new_slider("LUA", "B", "Wraith unavailable: " .. name, 0, 64, 0)
    host_ui.set_visible(item, false)
    unavailable_references[item] = true
    runtime.unsupported_controls = runtime.unsupported_controls or {}
    runtime.unsupported_controls[name] = true
    log("GameSense setting unavailable: " .. name .. "; changing it is disabled")
    return item
end
for _, name in ipairs({"new_button", "new_checkbox", "new_color_picker", "new_combobox", "new_hotkey", "new_label", "new_listbox", "new_multiselect", "new_slider", "new_textbox"}) do
    local constructor = assert(host_ui[name], "Missing GameSense UI constructor: " .. name)
    ui[name] = function(...)
        local args = pack(...)
        while args.n > 0 and args[args.n] == nil do args.n = args.n - 1 end
        local result
        if name == "new_listbox" then
            local items = args[4]
            if type(items) ~= "table" then
                items = {}
                for index = 4, args.n do items[#items + 1] = args[index] end
            end
            result = constructor(args[1], args[2], args[3], items)
        else
            result = constructor(unpack(args, 1, args.n))
        end
        runtime.created_items = runtime.created_items + 1
        local kind = name:sub(5)
        control_kinds[result] = kind
        runtime.controls[result] = {kind = kind, name = args[3]}
        if not runtime.main_switch and kind == "checkbox" then runtime.main_switch = result end
        return result
    end
end
function ui.set(item, value, ...)
    if unavailable_references[item] then return end
    if control_kinds[item] == "slider" and type(value) == "string" then value = assert(tonumber(value), "Invalid slider value") end
    if control_kinds[item] == "multiselect" and type(value) == "table" then return host_ui.set(item, unpack(value)) end
    return host_ui.set(item, value, ...)
end
function ui.set_visible(item, visible)
    return host_ui.set_visible(item, not unavailable_references[item] and visible or false)
end
local function control_type(item)
    local kind = control_kinds[item]
    if kind then return kind end
    return "reference"
end
local function optional_blur(...)
    if type(renderer.blur) == "function" then return renderer.blur(...) end
end
local function current_threat()
    if type(host_client.current_threat) == "function" then return host_client.current_threat() end
end
local clipboard_provider
local function clipboard()
    if clipboard_provider then return clipboard_provider end
    local ok, module = pcall(host_require, "gamesense/clipboard")
    if ok and type(module) == "table" then clipboard_provider = module; return module end
    local ffi = host_require("ffi")
    local interface = assert(host_client.create_interface("vgui2.dll", "VGUI_System010"), "Clipboard interface unavailable")
    local vtable = ffi.cast("void***", interface)[0]
    local count = ffi.cast("int(__thiscall*)(void*)", vtable[7])
    local read = ffi.cast("int(__thiscall*)(void*, int, char*, int)", vtable[11])
    local write = ffi.cast("void(__thiscall*)(void*, const char*, int)", vtable[9])
    clipboard_provider = {
        get = function()
            local length = count(interface)
            if length <= 1 then return "" end
            assert(length <= 1048576, "Clipboard config is too large")
            local buffer = ffi.new("char[?]", length)
            read(interface, 0, buffer, length)
            return ffi.string(buffer, length - 1)
        end,
        set = function(text) write(interface, text, #text) end,
    }
    return clipboard_provider
end
local bundled_modules = {}
local loaded_modules = {}
local empty_avatar = {contents = string.rep("\0", 48 * 48 * 4), width = 48, height = 48}
local function require(name)
    if loaded_modules[name] then return loaded_modules[name] end
    if name == "gamesense/clipboard" then
        local module = {get = function() return clipboard().get() end, set = function(text) return clipboard().set(text) end}
        loaded_modules[name] = module
        return module
    end
    local ok, module
    if name == "vector" or name == "gamesense/base64" then
        ok, module = pcall(host_require, name)
        if not ok then ok, module = pcall(bundled_modules[name]) end
    elseif bundled_modules[name] then
        ok, module = pcall(bundled_modules[name])
    else
        ok, module = pcall(host_require, name)
    end
    if not ok and name == "gamesense/images" then
        module = {get_steam_avatar = function() return nil end}
        log("Steam avatars unavailable: gamesense/images is not installed")
        ok = true
    end
    assert(ok, "Cannot load " .. name .. ": " .. tostring(module))
    loaded_modules[name] = module
    return module
end
local function toticks(seconds) return math.floor(seconds / globals.tickinterval() + 0.5) end
runtime.environment = script_environment

script_environment.client = client
script_environment.ui = ui
script_environment.renderer = setmetatable({}, {__index = renderer})
script_environment.globals = setmetatable({}, {__index = globals})
script_environment.require = require
script_environment.toticks = toticks
local script_table = setmetatable({}, {__index = table})
function script_table.clear(values)
    for key in pairs(values) do values[key] = nil end
end
script_environment.table = script_table
local function totime(ticks) return ticks * globals.tickinterval() end
script_environment.totime = totime

bundled_modules["vector"] = function()
local raise_error = error
local value_type = type
local to_number = tonumber
local sin = math.sin
local cos = math.cos
local atan2 = math.atan2
local sqrt = math.sqrt
local radians = math.rad
local degrees = math.deg
local format_string = string.format
local ffi = require("ffi")
local ffi_sizeof = ffi.sizeof
local ffi_istype = ffi.istype

ffi.cdef("typedef struct {\n\tfloat x, y, z;\n} Vector;\n")

local vector_type = ffi.typeof("Vector")
local world_up
local infinity = 1 / 0
local float_epsilon = 1.1920929e-07

local function new_vector(x, y, z)
	return vector_type(to_number(x) or 0, to_number(y) or 0, to_number(z) or 0)
end

local function is_vector(value)
	return value ~= nil and ffi_istype(vector_type, value)
end

local function is_number(value)
	return value ~= nil and value_type(value) == "number"
end

local function argument_error(argument_index, expected_type)
	return raise_error(format_string("bad argument #%d (expected %s)", argument_index, expected_type), 4)
end

local function assert_vector(value, argument_index)
	return is_vector(value) or argument_error(argument_index, "Vector")
end

local function assert_number(value, argument_index)
	return is_number(value) or argument_error(argument_index, "number")
end

local function clone_vector(vec)
	return new_vector(vec.x, vec.y, vec.z)
end

local function unpack_vector(vec)
	return vec.x, vec.y, vec.z
end

local function initialize_vector(vec, x, y, z)
	vec.x = x or 0
	vec.y = y or 0
	vec.z = z or 0
end

local function vector_from_angles(vec, pitch, yaw)
	assert_number(pitch, 2)
	assert_number(yaw, 3)

	local localValueGroup10Index0 = radians(pitch)
	local localValueGroup10Index1 = radians(yaw)
	local localValueGroup10Index2 = sin(localValueGroup10Index0)
	local localValueGroup10Index3 = cos(localValueGroup10Index0)
	local localValueGroup10Index4 = sin(localValueGroup10Index1)

	vec.x = localValueGroup10Index3 * cos(localValueGroup10Index1)
	vec.y = localValueGroup10Index3 * localValueGroup10Index4
	vec.z = -localValueGroup10Index2

	return vec
end

local function square(value)
	return value * value
end

local function multiply_components(vec, other)
	assert_vector(other, 2)

	return new_vector(vec.x * other.x, vec.y * other.y, vec.z * other.z)
end

local function length2d_squared(vec)
	return square(vec.x) + square(vec.y)
end

local function length_squared(vec)
	return square(vec.x) + square(vec.y) + square(vec.z)
end

local function length2d(vec)
	return sqrt(length2d_squared(vec))
end

local function vector_length(vec)
	return sqrt(length_squared(vec))
end

local function dot_product(vec, other)
	assert_vector(other, 2)

	return vec.x * other.x + vec.y * other.y + vec.z * other.z
end

local function distance_squared(vec, other)
	assert_vector(other, 2)

	return square(vec.x - other.x) + square(vec.y - other.y) + square(vec.z - other.z)
end

local function distance_to(vec, other)
	assert_vector(other, 2)

	return sqrt(square(vec.x - other.x) + square(vec.y - other.y) + square(vec.z - other.z))
end

local function distance2d_squared(vec, other)
	assert_vector(other, 2)

	return square(vec.x - other.x) + square(vec.y - other.y)
end

local function distance2d(vec, other)
	assert_vector(other, 2)

	return sqrt(square(vec.x - other.x) + square(vec.y - other.y))
end

local function scale_in_place(vec, scale)
	assert_number(scale, 2)

	vec.x = vec.x * scale
	vec.y = vec.y * scale
	vec.z = vec.z * scale
end

local function scaled_vector(vec, scale)
	assert_number(scale, 2)

	return new_vector(vec.x * scale, vec.y * scale, vec.z * scale)
end

local function normalize_in_place(vec)
	local localValueGroup24Index0 = vector_length(vec) + float_epsilon

	scale_in_place(vec, 1 / localValueGroup24Index0)

	return localValueGroup24Index0
end

local function normalized_vector(vec)
	return scaled_vector(vec, 1 / (vector_length(vec) + float_epsilon))
end

local function lerp_vector(vec, other, fraction)
	return assert_vector(other, 2) and new_vector(vec.x + (other.x - vec.x) * fraction, vec.y + (other.y - vec.y) * fraction, vec.z + (other.z - vec.z) * fraction)
end

local function cross_product(vec, other)
	assert_vector(other, 2)

	return new_vector(vec.y * other.z - vec.z * other.y, vec.z * other.x - vec.x * other.z, vec.x * other.y - vec.y * other.x)
end

local function vector_angles(vec)
	if vec.x == 0 and vec.y == 0 then
		return vec.z > 0 and -90 or 90, 0, 0
	end

	return degrees(atan2(-vec.z, length2d(vec))), degrees(atan2(vec.y, vec.x)), 0
end

local function perpendicular_vectors(vec)
	local localValueGroup29Index0
	local localValueGroup29Index1

	if vec.x == 0 and vec.y == 0 then
		localValueGroup29Index0 = new_vector(0, -1, 0)
		localValueGroup29Index1 = new_vector(-vec.z, 0, 0)
	else
		localValueGroup29Index0 = cross_product(vec, world_up)

		normalize_in_place(localValueGroup29Index0)

		localValueGroup29Index1 = cross_product(localValueGroup29Index0, vec)

		normalize_in_place(localValueGroup29Index1)
	end

	return localValueGroup29Index0, localValueGroup29Index1
end

local function direction_to(vec, target)
	assert_vector(target, 2)

	local localValueGroup30Index0 = new_vector(target.x - vec.x, target.y - vec.y, target.z - vec.z)

	normalize_in_place(localValueGroup30Index0)

	return localValueGroup30Index0
end

local function vectors_equal(vec, other)
	return is_vector(other) and vec.x == other.x and vec.y == other.y and vec.z == other.z
end

local function negate_vector(vec)
	return new_vector(-vec.x, -vec.y, -vec.z)
end

local function add_vectors(vec, other)
	return assert_vector(other, 3) and new_vector(vec.x + other.x, vec.y + other.y, vec.z + other.z)
end

local function vector_add(left, right)
	return is_vector(left) and add_vectors(left, right) or add_vectors(right, left)
end

local function subtract_vectors(vec, other)
	return assert_vector(other, 2) and new_vector(vec.x - other.x, vec.y - other.y, vec.z - other.z)
end

local function vector_subtract(left, right)
	return is_vector(left) and subtract_vectors(left, right) or subtract_vectors(right, left)
end

local function multiply_vector(vec, factor)
	return is_vector(factor) and multiply_components(vec, factor) or scaled_vector(vec, factor)
end

local function vector_multiply(left, right)
	return is_vector(left) and multiply_vector(left, right) or multiply_vector(right, left)
end

local function divide_vector(vec, factor)
	return assert_number(factor) and scaled_vector(vec, 1 / factor)
end

local function vector_divide(left, right)
	return is_vector(left) and divide_vector(left, right) or divide_vector(right, left)
end

local function vector_to_string(vec)
	return format_string("%f %f %f", vec.x, vec.y, vec.z)
end

local vector_metatable = {
	__add = vector_add,
	__div = vector_divide,
	__eq = vectors_equal,
	__len = vector_length,
	__mul = vector_multiply,
	__sub = vector_subtract,
	__tostring = vector_to_string,
	__unm = negate_vector,
	__index = {
		clone = clone_vector,
		unpack = unpack_vector,
		init = initialize_vector,
		init_from_angles = vector_from_angles,
		scale = scale_in_place,
		scaled = scaled_vector,
		normalize = normalize_in_place,
		normalized = normalized_vector,
		length2d = length2d,
		length = vector_length,
		length2dsqr = length2d_squared,
		lengthsqr = length_squared,
		lerp = lerp_vector,
		dot = dot_product,
		dist = distance_to,
		distsqr = distance_squared,
		dist2d = distance2d,
		dist2dsqr = distance2d_squared,
		cross = cross_product,
		angles = vector_angles,
		vectors = perpendicular_vectors,
		to = direction_to
	}
}

vector_type = ffi.metatype(vector_type, vector_metatable)
world_up = vector_type(0, 0, 1)

return new_vector

end

bundled_modules["gamesense/base64"] = function()
local bit = require "bit"
local M = {}

local shl, shr, band = bit.lshift, bit.rshift, bit.band
local char, byte, gsub, sub, format, concat, tostring, error, pairs = string.char, string.byte, string.gsub, string.sub, string.format, table.concat, tostring, error, pairs

local extract = function(v, from, width)
	return band(shr(v, from), shl(1, width) - 1)
end

local function makeencoder(alphabet)
	local encoder, decoder = {}, {}
	for i=1, 65 do
		local chr = byte(sub(alphabet, i, i)) or 32 
		if decoder[chr] ~= nil then
			error("invalid alphabet: duplicate character " .. tostring(chr), 3)
		end
		encoder[i-1] = chr
		decoder[chr] = i-1
	end
	return encoder, decoder
end

local encoders, decoders = {}, {}

encoders["base64"], decoders["base64"] = makeencoder("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
encoders["base64url"], decoders["base64url"] = makeencoder("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

local alphabet_mt = {
	__index = function(tbl, key)
		if type(key) == "string" and key:len() == 64 or key:len() == 65 then
			
			encoders[key], decoders[key] = makeencoder(key)
			return tbl[key]
		end
	end
}

setmetatable(encoders, alphabet_mt)
setmetatable(decoders, alphabet_mt)

function M.encode(str, encoder)
	encoder = encoders[encoder or "base64"] or error("invalid alphabet specified", 2)

	str = tostring(str)

	local t, k, n = {}, 1, #str
	local lastn = n % 3
	local cache = {}

	for i = 1, n-lastn, 3 do
		local a, b, c = byte(str, i, i+2)
		local v = a*0x10000 + b*0x100 + c
		local s = cache[v]

		if not s then
			s = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
			cache[v] = s
		end

		t[k] = s
		k = k + 1
	end

	if lastn == 2 then
		local a, b = byte(str, n-1, n)
		local v = a*0x10000 + b*0x100
		t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[64])
	elseif lastn == 1 then
		local v = byte(str, n)*0x10000
		t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[64], encoder[64])
	end

	return concat(t)
end

function M.decode(b64, decoder)
	decoder = decoders[decoder or "base64"] or error("invalid alphabet specified", 2)

	local pattern = "[^%w%+%/%=]"
	if decoder then
		local s62, s63
		for charcode, b64code in pairs(decoder) do
			if b64code == 62 then s62 = charcode
			elseif b64code == 63 then s63 = charcode
			end
		end
		pattern = format("[^%%w%%%s%%%s%%=]", char(s62), char(s63))
	end

	b64 = gsub(tostring(b64), pattern, '')

	local cache = {}
	local t, k = {}, 1
	local n = #b64
	local padding = sub(b64, -2) == "==" and 2 or sub(b64, -1) == "=" and 1 or 0

	for i = 1, padding > 0 and n-4 or n, 4 do
		local a, b, c, d = byte(b64, i, i+3)

		local v0 = a*0x1000000 + b*0x10000 + c*0x100 + d
		local s = cache[v0]
		if not s then
			local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
			s = char(extract(v,16,8), extract(v,8,8), extract(v,0,8))
			cache[v0] = s
		end

		t[k] = s
		k = k + 1
	end

	if padding == 1 then
		local a, b, c = byte(b64, n-3, n-1)
		local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40
		t[k] = char(extract(v,16,8), extract(v,8,8))
	elseif padding == 2 then
		local a, b = byte(b64, n-3, n-2)
		local v = decoder[a]*0x40000 + decoder[b]*0x1000
		t[k] = char(extract(v,16,8))
	end
	return concat(t)
end

return M

end

bundled_modules["gamesense/csgo_weapons"] = function()
local localValueGroup0Index0 = require("ffi")
local localValueGroup0Index1 = "struct {\n\tchar\t\t __pad_0x0000[4];\t\t\t\t\t   // 0x0000\n\tchar*\t\tconsole_name;\t\t\t\t\t\t  // 0x0004\n\tchar\t\t __pad_0x0008[12];\t\t\t\t\t  // 0x0008\n\tint\t\t  primary_clip_size;\t\t\t\t\t // 0x0014\n\tint\t\t  secondary_clip_size;\t\t\t\t   // 0x0018\n\tint\t\t  primary_default_clip_size;\t\t\t // 0x001c\n\tint\t\t  secondary_default_clip_size;\t\t   // 0x0020\n\tint\t\t  primary_reserve_ammo_max;\t\t\t  // 0x0024\n\tint\t\t  secondary_reserve_ammo_max;\t\t\t// 0x0028\n\tchar*\t\tmodel_world;\t\t\t\t\t\t   // 0x002c\n\tchar*\t\tmodel_player;\t\t\t\t\t\t  // 0x0030\n\tchar*\t\tmodel_dropped;\t\t\t\t\t\t // 0x0034\n\tchar*\t\tsound_empty;\t\t\t\t\t\t   // 0x0038\n\tchar*\t\tsound_single_shot;\t\t\t\t\t // 0x003c\n\tchar*\t\tsound_single_shot_accurate;\t\t\t// 0x0040\n\tchar\t\t __pad_0x0044[12];\t\t\t\t\t  // 0x0044\n\tchar*\t\tsound_burst;\t\t\t\t\t\t   // 0x0050\n\tchar*\t\tsound_reload;\t\t\t\t\t\t  // 0x0054\n\tchar\t\t __pad_0x0058[16];\t\t\t\t\t  // 0x0058\n\tchar*\t\tsound_special1;\t\t\t\t\t\t// 0x0068\n\tchar*\t\tsound_special2;\t\t\t\t\t\t// 0x006c\n\tchar*\t\tsound_special3;\t\t\t\t\t\t// 0x0070\n\tchar\t\t __pad_0x0074[4];\t\t\t\t\t   // 0x0074\n\tchar*\t\tsound_nearlyempty;\t\t\t\t\t // 0x0078\n\tchar\t\t __pad_0x007c[4];\t\t\t\t\t   // 0x007c\n\tchar*\t\tprimary_ammo;\t\t\t\t\t\t  // 0x0080\n\tchar*\t\tsecondary_ammo;\t\t\t\t\t\t// 0x0084\n\tchar*\t\titem_name;\t\t\t\t\t\t\t // 0x0088\n\tchar*\t\titem_class;\t\t\t\t\t\t\t// 0x008c\n\tbool\t\t itemflag_exhaustible;\t\t\t\t  // 0x0090\n\tbool\t\t model_right_handed;\t\t\t\t\t// 0x0091\n\tbool\t\t is_melee_weapon;\t\t\t\t\t   // 0x0092\n\tchar\t\t __pad_0x0093[9];\t\t\t\t\t   // 0x0093\n\tint\t\t  weapon_weight;\t\t\t\t\t\t // 0x009c\n\tint\t\t  primary_ammo_type;\t\t\t\t\t // 0x00a0\n\tchar\t\t __pad_0x00a4[4];\t\t\t\t\t   // 0x00a4\n\tint\t\t  item_gear_slot_position;\t\t\t   // 0x00a8\n\tchar\t\t __pad_0x00ac[28];\t\t\t\t\t  // 0x00ac\n\tint\t\t  weapon_type_int;\t\t\t\t\t   // 0x00c8\n\tchar\t\t __pad_0x00cc[4];\t\t\t\t\t   // 0x00cc\n\tint\t\t  in_game_price;\t\t\t\t\t\t // 0x00d0\n\tint\t\t  kill_award;\t\t\t\t\t\t\t// 0x00d4\n\tchar*\t\tplayer_animation_extension;\t\t\t// 0x00d8\n\tfloat\t\tcycletime;\t\t\t\t\t\t\t // 0x00dc\n\tfloat\t\tcycletime_alt;\t\t\t\t\t\t // 0x00e0\n\tfloat\t\ttime_to_idle;\t\t\t\t\t\t  // 0x00e4\n\tfloat\t\tidle_interval;\t\t\t\t\t\t // 0x00e8\n\tbool\t\t is_full_auto;\t\t\t\t\t\t  // 0x00ec\n\tchar\t\t __pad_0x00ed[3];\t\t\t\t\t   // 0x00ed\n\tint\t\t  damage;\t\t\t\t\t\t\t\t// 0x00f0\n\tfloat\t\theadshot_multiplier;\t\t\t\t   // 0x00f4\n\tfloat\t\tarmor_ratio;\t\t\t\t\t\t   // 0x00f8\n\tint\t\t  bullets;\t\t\t\t\t\t\t   // 0x00fc\n\tfloat\t\tpenetration;\t\t\t\t\t\t   // 0x0100\n\tfloat\t\tflinch_velocity_modifier_large;\t\t// 0x0104\n\tfloat\t\tflinch_velocity_modifier_small;\t\t// 0x0108\n\tfloat\t\trange;\t\t\t\t\t\t\t\t // 0x010c\n\tfloat\t\trange_modifier;\t\t\t\t\t\t// 0x0110\n\tfloat\t\tthrow_velocity;\t\t\t\t\t\t// 0x0114\n\tchar\t\t __pad_0x0118[12];\t\t\t\t\t  // 0x0118\n\tint\t\t  has_silencer;\t\t\t\t\t\t  // 0x0124\n\tchar\t\t __pad_0x0128[4];\t\t\t\t\t   // 0x0128\n\tint\t\t  crosshair_min_distance;\t\t\t\t// 0x012c\n\tint\t\t  crosshair_delta_distance;\t\t\t  // 0x0130\n\tfloat\t\tmax_player_speed;\t\t\t\t\t  // 0x0134\n\tfloat\t\tmax_player_speed_alt;\t\t\t\t  // 0x0138\n\tfloat\t\tattack_movespeed_factor;\t\t\t   // 0x013c\n\tfloat\t\tspread;\t\t\t\t\t\t\t\t// 0x0140\n\tfloat\t\tspread_alt;\t\t\t\t\t\t\t// 0x0144\n\tfloat\t\tinaccuracy_crouch;\t\t\t\t\t // 0x0148\n\tfloat\t\tinaccuracy_crouch_alt;\t\t\t\t // 0x014c\n\tfloat\t\tinaccuracy_stand;\t\t\t\t\t  // 0x0150\n\tfloat\t\tinaccuracy_stand_alt;\t\t\t\t  // 0x0154\n\tfloat\t\tinaccuracy_jump_initial;\t\t\t   // 0x0158\n\tfloat\t\tinaccuracy_jump_apex;\t\t\t\t  // 0x015c\n\tfloat\t\tinaccuracy_jump;\t\t\t\t\t   // 0x0160\n\tfloat\t\tinaccuracy_jump_alt;\t\t\t\t   // 0x0164\n\tfloat\t\tinaccuracy_land;\t\t\t\t\t   // 0x0168\n\tfloat\t\tinaccuracy_land_alt;\t\t\t\t   // 0x016c\n\tfloat\t\tinaccuracy_ladder;\t\t\t\t\t // 0x0170\n\tfloat\t\tinaccuracy_ladder_alt;\t\t\t\t // 0x0174\n\tfloat\t\tinaccuracy_fire;\t\t\t\t\t   // 0x0178\n\tfloat\t\tinaccuracy_fire_alt;\t\t\t\t   // 0x017c\n\tfloat\t\tinaccuracy_move;\t\t\t\t\t   // 0x0180\n\tfloat\t\tinaccuracy_move_alt;\t\t\t\t   // 0x0184\n\tfloat\t\tinaccuracy_reload;\t\t\t\t\t // 0x0188\n\tint\t\t  recoil_seed;\t\t\t\t\t\t   // 0x018c\n\tfloat\t\trecoil_angle;\t\t\t\t\t\t  // 0x0190\n\tfloat\t\trecoil_angle_alt;\t\t\t\t\t  // 0x0194\n\tfloat\t\trecoil_angle_variance;\t\t\t\t // 0x0198\n\tfloat\t\trecoil_angle_variance_alt;\t\t\t // 0x019c\n\tfloat\t\trecoil_magnitude;\t\t\t\t\t  // 0x01a0\n\tfloat\t\trecoil_magnitude_alt;\t\t\t\t  // 0x01a4\n\tfloat\t\trecoil_magnitude_variance;\t\t\t // 0x01a8\n\tfloat\t\trecoil_magnitude_variance_alt;\t\t // 0x01ac\n\tint\t\t  spread_seed;\t\t\t\t\t\t   // 0x01b0\n\tfloat\t\trecovery_time_crouch;\t\t\t\t  // 0x01b4\n\tfloat\t\trecovery_time_stand;\t\t\t\t   // 0x01b8\n\tfloat\t\trecovery_time_crouch_final;\t\t\t// 0x01bc\n\tfloat\t\trecovery_time_stand_final;\t\t\t // 0x01c0\n\tint\t\t  recovery_transition_start_bullet;\t  // 0x01c4\n\tint\t\t  recovery_transition_end_bullet;\t\t// 0x01c8\n\tbool\t\t unzoom_after_shot;\t\t\t\t\t // 0x01cc\n\tbool\t\t hide_view_model_zoomed;\t\t\t\t// 0x01cd\n\tchar\t\t __pad_0x01ce[2];\t\t\t\t\t   // 0x01ce\n\tint\t\t  zoom_levels;\t\t\t\t\t\t   // 0x01d0\n\tint\t\t  zoom_fov_1;\t\t\t\t\t\t\t// 0x01d4\n\tint\t\t  zoom_fov_2;\t\t\t\t\t\t\t// 0x01d8\n\tint\t\t  zoom_time_0;\t\t\t\t\t\t   // 0x01dc\n\tint\t\t  zoom_time_1;\t\t\t\t\t\t   // 0x01e0\n\tint\t\t  zoom_time_2;\t\t\t\t\t\t   // 0x01e4\n\tchar*\t\taddon_location;\t\t\t\t\t\t// 0x01e8\n\tchar\t\t __pad_0x01ec[4];\t\t\t\t\t   // 0x01ec\n\tfloat\t\taddon_scale;\t\t\t\t\t\t   // 0x01f0\n\tchar*\t\teject_brass_effect;\t\t\t\t\t// 0x01f4\n\tchar*\t\ttracer_effect;\t\t\t\t\t\t // 0x01f8\n\tint\t\t  tracer_frequency;\t\t\t\t\t  // 0x01fc\n\tint\t\t  tracer_frequency_alt;\t\t\t\t  // 0x0200\n\tchar*\t\tmuzzle_flash_effect_1st_person;\t\t// 0x0204\n\tchar*\t\tmuzzle_flash_effect_1st_person_alt;\t// 0x0208\n\tchar*\t\tmuzzle_flash_effect_3rd_person;\t\t// 0x020c\n\tchar*\t\tmuzzle_flash_effect_3rd_person_alt;\t// 0x0210\n\tchar*\t\theat_effect;\t\t\t\t\t\t   // 0x0214\n\tfloat\t\theat_per_shot;\t\t\t\t\t\t // 0x0218\n\tchar*\t\tzoom_in_sound;\t\t\t\t\t\t // 0x021c\n\tchar*\t\tzoom_out_sound;\t\t\t\t\t\t// 0x0220\n\tchar\t\t __pad_0x0224[4];\t\t\t\t\t   // 0x0224\n\tfloat\t\tinaccuracy_alt_sound_threshold;\t\t// 0x0228\n\tfloat\t\tbot_audible_range;\t\t\t\t\t // 0x022c\n\tchar\t\t __pad_0x0230[12];\t\t\t\t\t  // 0x0230\n\tbool\t\t has_burst_mode;\t\t\t\t\t\t// 0x023c\n\tbool\t\t is_revolver;\t\t\t\t\t\t   // 0x023d\n}\n"
local localValueGroup0Index2 = {
	"console_name",
	"primary_clip_size",
	"secondary_clip_size",
	"primary_default_clip_size",
	"secondary_default_clip_size",
	"primary_reserve_ammo_max",
	"secondary_reserve_ammo_max",
	"model_world",
	"model_player",
	"model_dropped",
	"sound_empty",
	"sound_single_shot",
	"sound_single_shot_accurate",
	"sound_burst",
	"sound_reload",
	"sound_special1",
	"sound_special2",
	"sound_special3",
	"sound_nearlyempty",
	"primary_ammo",
	"secondary_ammo",
	"item_name",
	"item_class",
	"itemflag_exhaustible",
	"model_right_handed",
	"is_melee_weapon",
	"weapon_weight",
	"primary_ammo_type",
	"item_gear_slot_position",
	"weapon_type_int",
	"in_game_price",
	"kill_award",
	"player_animation_extension",
	"cycletime",
	"cycletime_alt",
	"time_to_idle",
	"idle_interval",
	"is_full_auto",
	"damage",
	"headshot_multiplier",
	"armor_ratio",
	"bullets",
	"penetration",
	"flinch_velocity_modifier_large",
	"flinch_velocity_modifier_small",
	"range",
	"range_modifier",
	"throw_velocity",
	"has_silencer",
	"crosshair_min_distance",
	"crosshair_delta_distance",
	"max_player_speed",
	"max_player_speed_alt",
	"attack_movespeed_factor",
	"spread",
	"spread_alt",
	"inaccuracy_crouch",
	"inaccuracy_crouch_alt",
	"inaccuracy_stand",
	"inaccuracy_stand_alt",
	"inaccuracy_jump_initial",
	"inaccuracy_jump_apex",
	"inaccuracy_jump",
	"inaccuracy_jump_alt",
	"inaccuracy_land",
	"inaccuracy_land_alt",
	"inaccuracy_ladder",
	"inaccuracy_ladder_alt",
	"inaccuracy_fire",
	"inaccuracy_fire_alt",
	"inaccuracy_move",
	"inaccuracy_move_alt",
	"inaccuracy_reload",
	"recoil_seed",
	"recoil_angle",
	"recoil_angle_alt",
	"recoil_angle_variance",
	"recoil_angle_variance_alt",
	"recoil_magnitude",
	"recoil_magnitude_alt",
	"recoil_magnitude_variance",
	"recoil_magnitude_variance_alt",
	"spread_seed",
	"recovery_time_crouch",
	"recovery_time_stand",
	"recovery_time_crouch_final",
	"recovery_time_stand_final",
	"recovery_transition_start_bullet",
	"recovery_transition_end_bullet",
	"unzoom_after_shot",
	"hide_view_model_zoomed",
	"zoom_levels",
	"zoom_fov_1",
	"zoom_fov_2",
	"zoom_time_0",
	"zoom_time_1",
	"zoom_time_2",
	"addon_location",
	"addon_scale",
	"eject_brass_effect",
	"tracer_effect",
	"tracer_frequency",
	"tracer_frequency_alt",
	"muzzle_flash_effect_1st_person",
	"muzzle_flash_effect_1st_person_alt",
	"muzzle_flash_effect_3rd_person",
	"muzzle_flash_effect_3rd_person_alt",
	"heat_effect",
	"heat_per_shot",
	"zoom_in_sound",
	"zoom_out_sound",
	"inaccuracy_alt_sound_threshold",
	"bot_audible_range",
	"has_burst_mode",
	"is_revolver"
}
local localValueGroup0Index3 = {
	[0] = "knife",
	"pistol",
	"smg",
	"rifle",
	"shotgun",
	"sniperrifle",
	"machinegun",
	"c4",
	nil,
	"grenade",
	nil,
	"stackableitem",
	"fists",
	"breachcharge",
	"bumpmine",
	"tablet",
	"melee",
	nil,
	nil,
	"equipment"
}
local localValueGroup0Index4 = {
	[31] = "taser"
}
local localValueGroup0Index5 = client.find_signature("client.dll", "\x8B5\xCC\xCC\xCC\xCC\xFF\x10\x0F\xB7\xC0") or error("IWeaponSystem signature invalid")
local localValueGroup0Index6 = localValueGroup0Index0.cast("void****", localValueGroup0Index0.cast("char*", localValueGroup0Index5) + 2)[0]
local localValueGroup0Index7 = vtable_thunk(2, localValueGroup0Index1 .. "*(__thiscall*)(void*, unsigned int)") or error("invalid GetCSWeaponInfo index")
local localValueGroup0Index8 = localValueGroup0Index0.typeof("char*")
local localValueGroup0Index9 = panorama.loadstring("return {\n\tget_weapon_info: (idx) => {\n\t\tlet itemid = InventoryAPI.GetFauxItemIDFromDefAndPaintIndex(idx)\n\n\t\tif(itemid && itemid > 0) {\n\t\t\tlet data = {\n\t\t\t\tschema: JSON.parse(InventoryAPI.BuildItemSchemaDefJSON(itemid)),\n\t\t\t\tslot: InventoryAPI.GetSlot(itemid),\n\t\t\t\timage_hud: `materials/panorama/images/icons/equipment/${InventoryAPI.GetHudIconFileName(idx)}.svg`,\n\t\t\t\timage_inventory: `resource/Flash/${InventoryAPI.GetItemInventoryImage(itemid)}.png`\n\t\t\t}\n\n\t\t\treturn JSON.stringify(data)\n\t\t} else {\n\t\t\treturn \"null\"\n\t\t}\n\t},\n\tlocalize: $.Localize\n}\n", "CSGOMainMenu")()
local localValueGroup0Index10 = {}
local localValueGroup0Index11 = {}

for iteratorGroup0Index0 = 1, 1000 do
	local localValueGroup0Index12 = localValueGroup0Index7(localValueGroup0Index6, iteratorGroup0Index0)

	if localValueGroup0Index12 ~= nil then
		local localValueGroup0Index13 = {}

		for iteratorGroup0Index1 = 1, #localValueGroup0Index2 do
			local localValueGroup0Index14 = localValueGroup0Index2[iteratorGroup0Index1]
			local localValueGroup0Index15 = localValueGroup0Index12[localValueGroup0Index14]
			local localValueGroup0Index16, localValueGroup0Index17 = pcall(localValueGroup0Index0.typeof, localValueGroup0Index15)

			if localValueGroup0Index16 and localValueGroup0Index17 == localValueGroup0Index8 then
				localValueGroup0Index13[localValueGroup0Index14] = localValueGroup0Index0.string(localValueGroup0Index15)
			else
				localValueGroup0Index13[localValueGroup0Index14] = localValueGroup0Index15
			end
		end

		localValueGroup0Index13.idx = iteratorGroup0Index0
		localValueGroup0Index13.type = localValueGroup0Index4[iteratorGroup0Index0] or localValueGroup0Index3[localValueGroup0Index12.weapon_type_int]
		localValueGroup0Index13.name = localValueGroup0Index9.localize(localValueGroup0Index13.item_name)
		localValueGroup0Index13.raw = localValueGroup0Index12
		localValueGroup0Index13.is_grenade = localValueGroup0Index13.type == "grenade"
		localValueGroup0Index13.is_taser = localValueGroup0Index13.type == "taser"
		localValueGroup0Index13.is_knife = localValueGroup0Index13.type == "knife"
		localValueGroup0Index13.is_gun = localValueGroup0Index13.type == "pistol" or localValueGroup0Index13.type == "smg" or localValueGroup0Index13.type == "rifle" or localValueGroup0Index13.type == "shotgun" or localValueGroup0Index13.type == "sniperrifle" or localValueGroup0Index13.type == "machinegun"

		local localValueGroup0Index18 = json.parse(localValueGroup0Index9.get_weapon_info(iteratorGroup0Index0))

		if localValueGroup0Index18 ~= nil then
			for iteratorGroup0Index2, iteratorGroup0Index3 in pairs(localValueGroup0Index18) do
				localValueGroup0Index13[iteratorGroup0Index2] = iteratorGroup0Index3
			end
		end

		localValueGroup0Index10[iteratorGroup0Index0] = localValueGroup0Index13
		localValueGroup0Index11[localValueGroup0Index13.console_name] = localValueGroup0Index13
	end
end

local function localValueGroup0Index19(argumentGroup1Index0, argumentGroup1Index1)
	if argumentGroup1Index0 ~= localValueGroup0Index10 or type(argumentGroup1Index1) ~= "number" or argumentGroup1Index1 < 0 or argumentGroup1Index1 > 8191 then
		return
	end

	local localValueGroup1Index0 = entity.get_prop(argumentGroup1Index1, "m_iItemDefinitionIndex")

	return localValueGroup0Index10[localValueGroup1Index0]
end

function localValueGroup0Index11.get_player_weapon(argumentGroup2Index0, argumentGroup2Index1)
	return localValueGroup0Index19(argumentGroup2Index0, entity.get_player_weapon(argumentGroup2Index1))
end

function localValueGroup0Index11.get_player_weapons(argumentGroup3Index0, argumentGroup3Index1)
	local localValueGroup3Index0 = {}

	for iteratorGroup3Index0 = 0, 63 do
		local localValueGroup3Index1 = entity.get_prop(argumentGroup3Index1, "m_hMyWeapons", iteratorGroup3Index0)

		if localValueGroup3Index1 ~= nil and localValueGroup3Index1 > 0 then
			table.insert(localValueGroup3Index0, localValueGroup0Index19(argumentGroup3Index0, localValueGroup3Index1))
		end
	end

	return localValueGroup3Index0
end

setmetatable(localValueGroup0Index10, {
	__metatable = false,
	__index = localValueGroup0Index11,
	__call = localValueGroup0Index19
})

return localValueGroup0Index10

end

bundled_modules["gamesense/entity"] = function()
local localValueGroup0Index0 = require("ffi")
local localValueGroup0Index1 = require("gamesense/csgo_weapons")
local localValueGroup0Index2 = entity.get_local_player
local localValueGroup0Index3 = entity.is_enemy
local localValueGroup0Index4 = entity.get_bounding_box
local localValueGroup0Index5 = entity.get_all
local localValueGroup0Index6 = entity.set_prop
local localValueGroup0Index7 = entity.is_alive
local localValueGroup0Index8 = entity.get_steam64
local localValueGroup0Index9 = entity.get_classname
local localValueGroup0Index10 = entity.get_player_resource
local localValueGroup0Index11 = entity.get_esp_data
local localValueGroup0Index12 = entity.is_dormant
local localValueGroup0Index13 = entity.get_player_name
local localValueGroup0Index14 = entity.get_game_rules
local localValueGroup0Index15 = entity.get_origin
local localValueGroup0Index16 = entity.hitbox_position
local localValueGroup0Index17 = entity.get_player_weapon
local localValueGroup0Index18 = entity.get_players
local localValueGroup0Index19 = entity.get_prop
local localValueGroup0Index20 = client.userid_to_entindex
local localValueGroup0Index21 = client.draw_hitboxes
local localValueGroup0Index22 = client.scale_damage
local localValueGroup0Index23 = client.trace_line
local localValueGroup0Index24 = client.trace_bullet
local localValueGroup0Index25 = materialsystem.get_model_materials
local localValueGroup0Index26 = plist.set
local localValueGroup0Index27 = plist.get
local localValueGroup0Index28 = string.format
local localValueGroup0Index29 = localValueGroup0Index0.cast
local localValueGroup0Index30 = localValueGroup0Index0.typeof("\tstruct {\n\t\tchar pad[0x64];\n\t\tint index;\n\t}\n")
local localValueGroup0Index31 = localValueGroup0Index0.typeof("\tstruct {\n\t\tchar\t\tpad0[0x18];\n\t\tuint32_t\tsequence;\n\t\tfloat\t\tprev_cycle;\n\t\tfloat\t\tweight;\n\t\tfloat\t\tweight_delta_rate;\n\t\tfloat\t\tplayback_rate;\n\t\tfloat\t\tcycle;\n\t\tvoid*\t\tentity;\n\t\tchar\t\tpad1[0x4];\n\t} **\n")
local localValueGroup0Index32 = localValueGroup0Index0.typeof("\tstruct {\n\t\tchar\tpad0[0x18];\n\t\tfloat\tanim_update_timer;\n\t\tchar\tpad1[0xC];\n\t\tfloat\tstarted_moving_time;\n\t\tfloat\tlast_move_time;\n\t\tchar\tpad2[0x10];\n\t\tfloat\tlast_lby_time;\n\t\tchar\tpad3[0x8];\n\t\tfloat\trun_amount;\n\t\tchar\tpad4[0x10];\n\t\tvoid*\tentity;\n\t\tvoid*\tactive_weapon;\n\t\tvoid*\tlast_active_weapon;\n\t\tfloat\tlast_client_side_animation_update_time;\n\t\tint\t\tlast_client_side_animation_update_framecount;\n\t\tfloat\teye_timer;\n\t\tfloat\teye_angles_y;\n\t\tfloat\teye_angles_x;\n\t\tfloat\tgoal_feet_yaw;\n\t\tfloat\tcurrent_feet_yaw;\n\t\tfloat\ttorso_yaw;\n\t\tfloat\tlast_move_yaw;\n\t\tfloat\tlean_amount;\n\t\tchar\tpad5[0x4];\n\t\tfloat\tfeet_cycle;\n\t\tfloat\tfeet_yaw_rate;\n\t\tchar\tpad6[0x4];\n\t\tfloat\tduck_amount;\n\t\tfloat\tlanding_duck_amount;\n\t\tchar\tpad7[0x4];\n\t\tfloat\tcurrent_origin[3];\n\t\tfloat\tlast_origin[3];\n\t\tfloat\tvelocity_x;\n\t\tfloat\tvelocity_y;\n\t\tchar\tpad8[0x4];\n\t\tfloat\tunknown_float1;\n\t\tchar\tpad9[0x8];\n\t\tfloat\tunknown_float2;\n\t\tfloat\tunknown_float3;\n\t\tfloat\tunknown;\n\t\tfloat\tm_velocity;\n\t\tfloat\tjump_fall_velocity;\n\t\tfloat\tclamped_velocity;\n\t\tfloat\tfeet_speed_forwards_or_sideways;\n\t\tfloat\tfeet_speed_unknown_forwards_or_sideways;\n\t\tfloat\tlast_time_started_moving;\n\t\tfloat\tlast_time_stopped_moving;\n\t\tbool\ton_ground;\n\t\tbool\thit_in_ground_animation;\n\t\tchar\tpad10[0x4];\n\t\tfloat\ttime_since_in_air;\n\t\tfloat\tlast_origin_z;\n\t\tfloat\thead_from_ground_distance_standing;\n\t\tfloat\tstop_to_full_running_fraction;\n\t\tchar\tpad11[0x4];\n\t\tfloat\tmagic_fraction;\n\t\tchar\tpad12[0x3C];\n\t\tfloat\tworld_force;\n\t\tchar\tpad13[0x1CA];\n\t\tfloat\tmin_yaw;\n\t\tfloat\tmax_yaw;\n\t} **\n")
local localValueGroup0Index33 = localValueGroup0Index0.typeof("$ *", localValueGroup0Index30)
local localValueGroup0Index34 = localValueGroup0Index0.typeof("char*")
local localValueGroup0Index35 = vtable_bind("client.dll", "VClientEntityList003", 0, "void*(__thiscall*)(void*, int)")
local localValueGroup0Index36 = vtable_bind("client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*, int)")
local localValueGroup0Index37 = vtable_thunk(0, "void*(__thiscall*)(void*)")
local localValueGroup0Index38 = client.find_signature("client.dll", "U\x8B\xECS\x8B]\bV\x8B\xF1\x83") or error("invalid GetSequenceActivity signature")
local localValueGroup0Index39 = localValueGroup0Index0.cast("int(__thiscall*)(void*, int)", localValueGroup0Index38)

local function localValueGroup0Index40(argumentGroup1Index0)
	if argumentGroup1Index0 == nil then
		return
	end

	local localValueGroup1Index0 = localValueGroup0Index36(argumentGroup1Index0)

	if localValueGroup1Index0 == nil then
		return
	end

	return localValueGroup0Index29(localValueGroup0Index33, localValueGroup1Index0)
end

local localValueGroup0Index41 = {
	new = localValueGroup0Index40
}

local function localValueGroup0Index42(argumentGroup2Index0, argumentGroup2Index1)
	localValueGroup0Index41[argumentGroup2Index1] = function(argumentGroup3Index0, ...)
		return argumentGroup2Index0(argumentGroup3Index0:get_entindex(), ...)
	end
end

function localValueGroup0Index41.new_from_userid(argumentGroup4Index0)
	return localValueGroup0Index40(localValueGroup0Index20(argumentGroup4Index0))
end

function localValueGroup0Index41.get_local_player()
	return localValueGroup0Index40(localValueGroup0Index2())
end

function localValueGroup0Index41.get_all(...)
	local localValueGroup6Index0 = localValueGroup0Index5(...)

	for iteratorGroup6Index0, iteratorGroup6Index1 in ipairs(localValueGroup6Index0) do
		localValueGroup6Index0[iteratorGroup6Index0] = localValueGroup0Index40(iteratorGroup6Index1)
	end

	return localValueGroup6Index0
end

function localValueGroup0Index41.get_player_resource()
	return localValueGroup0Index40(localValueGroup0Index10())
end

function localValueGroup0Index41.get_game_rules()
	return localValueGroup0Index40(localValueGroup0Index14())
end

function localValueGroup0Index41.get_players(...)
	local localValueGroup9Index0 = localValueGroup0Index18(...)

	for iteratorGroup9Index0, iteratorGroup9Index1 in ipairs(localValueGroup9Index0) do
		localValueGroup9Index0[iteratorGroup9Index0] = localValueGroup0Index40(iteratorGroup9Index1)
	end

	return localValueGroup9Index0
end

function localValueGroup0Index41.get_player_weapon(argumentGroup10Index0)
	return localValueGroup0Index40(localValueGroup0Index17(argumentGroup10Index0:get_entindex()))
end

function localValueGroup0Index41.get_entindex(argumentGroup11Index0)
	if argumentGroup11Index0 == nil then
		return
	end

	return argumentGroup11Index0.index
end

function localValueGroup0Index41.get_anim_overlay(argumentGroup12Index0, argumentGroup12Index1)
	return localValueGroup0Index29(localValueGroup0Index31, localValueGroup0Index29(localValueGroup0Index34, argumentGroup12Index0) + 10640)[0][argumentGroup12Index1 or 1]
end

function localValueGroup0Index41.get_anim_state(argumentGroup13Index0)
	return localValueGroup0Index29(localValueGroup0Index32, localValueGroup0Index29(localValueGroup0Index34, argumentGroup13Index0) + 39264)[0][0]
end

function localValueGroup0Index41.get_sequence_activity(argumentGroup14Index0, argumentGroup14Index1)
	if argumentGroup14Index0 == nil then
		return
	end

	return localValueGroup0Index39(argumentGroup14Index0, argumentGroup14Index1)
end

function localValueGroup0Index41.get_client_networkable(argumentGroup15Index0)
	local localValueGroup15Index0 = localValueGroup0Index35(argumentGroup15Index0:get_entindex())

	if localValueGroup15Index0 == nil then
		return
	end

	return localValueGroup15Index0
end

function localValueGroup0Index41.get_client_unknown(argumentGroup16Index0)
	local localValueGroup16Index0 = argumentGroup16Index0:get_client_networkable()

	if localValueGroup16Index0 == nil then
		return
	end

	local localValueGroup16Index1 = localValueGroup0Index37(localValueGroup16Index0)

	if localValueGroup16Index1 == nil then
		return
	end

	return localValueGroup16Index1
end

function localValueGroup0Index41.get_weapon_info(argumentGroup17Index0)
	local localValueGroup17Index0 = argumentGroup17Index0:get_prop("m_iItemDefinitionIndex")

	return localValueGroup0Index1[localValueGroup17Index0]
end

localValueGroup0Index42(localValueGroup0Index3, "is_enemy")
localValueGroup0Index42(localValueGroup0Index4, "get_bounding_box")
localValueGroup0Index42(localValueGroup0Index6, "set_prop")
localValueGroup0Index42(localValueGroup0Index7, "is_alive")
localValueGroup0Index42(localValueGroup0Index8, "get_steam64")
localValueGroup0Index42(localValueGroup0Index9, "get_classname")
localValueGroup0Index42(localValueGroup0Index11, "get_esp_data")
localValueGroup0Index42(localValueGroup0Index15, "get_origin")
localValueGroup0Index42(localValueGroup0Index12, "is_dormant")
localValueGroup0Index42(localValueGroup0Index13, "get_player_name")
localValueGroup0Index42(localValueGroup0Index16, "hitbox_position")
localValueGroup0Index42(localValueGroup0Index19, "get_prop")
localValueGroup0Index42(localValueGroup0Index21, "draw_hitboxes")
localValueGroup0Index42(localValueGroup0Index22, "scale_damage")
localValueGroup0Index42(localValueGroup0Index23, "trace_line")
localValueGroup0Index42(localValueGroup0Index24, "trace_bullet")
localValueGroup0Index42(localValueGroup0Index25, "get_model_materials")
localValueGroup0Index42(localValueGroup0Index26, "plist_set")
localValueGroup0Index42(localValueGroup0Index27, "plist_get")

local localValueGroup0Index43 = {
	__index = localValueGroup0Index41,
	__tostring = function(argumentGroup18Index0)
		return localValueGroup0Index28("%d", argumentGroup18Index0:get_entindex())
	end,
	__concat = function(argumentGroup19Index0, argumentGroup19Index1)
		return localValueGroup0Index28("%s%s", argumentGroup19Index0, argumentGroup19Index1)
	end
}

localValueGroup0Index0.metatype(localValueGroup0Index30, localValueGroup0Index43)

return setmetatable(localValueGroup0Index41, {
	__metatable = true,
	__call = function(argumentGroup20Index0, argumentGroup20Index1)
		return localValueGroup0Index40(argumentGroup20Index1)
	end
})

end

bundled_modules["gamesense/antiaim_funcs"] = function()

local assert, bit_band, globals_curtime, globals_tickcount, globals_tickinterval, math_abs, math_floor, math_fmod, math_max, math_min, math_pow, table_remove, unpack, setmetatable = assert, bit.band, globals.curtime, globals.tickcount, globals.tickinterval, math.abs, math.floor, math.fmod, math.max, math.min, math.pow, table.remove, unpack, setmetatable

local type = type

local ffi = require 'ffi'
local vector = require 'vector'
local entity = require 'gamesense/entity'

local jmp_edx = client.find_signature('engine.dll', '\xFF\xE2')

local function vmt_thunk(index, typestring)
	local t = ffi.typeof(typestring)
	return function(instance, ...)
		assert(instance ~= nil)
		if instance then
			return ffi.cast(t, jmp_edx)(instance, ffi.cast('void***', instance)[0][index], ...)
		end
	end
end

local native_GetMaxSpeed = vtable_thunk(441, 'float(__thiscall*)(void*)')

local function clamp(val, min_val, max_val)
	return math_max(min_val, math_min(max_val, val))
end

local function anglemod(a)
	return (360 / 65536) * bit_band(math_floor(a * (65536 / 360)), 65535)
end

local function approach_angle(target, value, speed)
	target = anglemod(target)
	value = anglemod(value)

	local delta = target - value

	if speed < 0 then
		speed = -speed
	end

	if delta < -180 then
		delta = delta + 360
	elseif delta > 180 then
		delta = delta - 360
	end

	if delta > speed then
		value = value + speed
	elseif delta < -speed then
		value = value - speed
	else
		value = target
	end

	return value
end

local function normalize_angle(angle)
	while angle > 180 do angle = angle - 360 end
	while angle < -180 do angle = angle + 360 end
	return angle
end

local function angle_diff(dest_angle, src_angle)
	local delta = math_fmod(dest_angle - src_angle, 360)
	if dest_angle > src_angle then
		if delta >= 180 then
			delta = delta - 360
		end
	else
		if delta <= -180 then
			delta = delta + 360
		end
	end
	return delta
end

local function get_smoothed_velocity(min_delta, a, b)
	local delta = a - b
	local delta_length = delta:length()

	if delta_length <= min_delta then
		if -min_delta <= delta_length then
			return a
		else
			local radius = 1 / (delta_length + 1.19209290E-07)
			return b - ((delta * radius) * min_delta)
		end
	else
		local radius = 1 / (delta_length + 1.19209290E-07)
		return b + ((delta * radius) * min_delta)
	end
end

local estimate_abs_velocity = vmt_thunk(144, 'void(__fastcall*)(void*, void*, float*)')

local data = {
	abs_yaw = 0,
	feet_yaw = 0,
	server_feet_yaw = 0,
	desync_exact = 0,
	desync = 0,

	tickbase = { 
		shifting = 0,

		last_tickbase = 0,
		phase_tickbase = 0,

		list = (function()
			
			local index, max = { }, 16
			for i=1, max do
				index[#index+1] = 0
				if i == max then
					return index
				end
			end
		end)()
	},

	balance_adjust = {
		updating = false,
		next_update = 0
	}
}

local abs_vel, original_data = ffi.new('float[3]'), data
local stop_to_full_running_fraction, duck_amount, speed = 0, 0, 0
local eye_angles_y, srv_goal_feet_yaw
local class_ptr = ffi.typeof('void***')

local function setup_velocity(c)
	local curtime = globals_curtime()
	local tickinterval = globals_tickinterval()

	local local_player = entity.get_local_player()

	if local_player == nil then
		return
	end

	local anim_state = local_player:get_anim_state()

	if anim_state.anim_update_timer <= 0.0 then
		stop_to_full_running_fraction, duck_amount, speed = 0, 0, 0
		eye_angles_y, srv_goal_feet_yaw = nil, nil
		data = original_data
		return
	end

	if eye_angles_y == nil or srv_goal_feet_yaw == nil then
		eye_angles_y = anim_state.eye_angles_y
		srv_goal_feet_yaw = anim_state.goal_feet_yaw
	end

	if c.chokedcommands == 0 then
		stop_to_full_running_fraction = anim_state.stop_to_full_running_fraction
		duck_amount = anim_state.duck_amount
		eye_angles_y = anim_state.eye_angles_y

		estimate_abs_velocity(local_player:get_client_entity(), abs_vel)

		local velocity_a = vector(abs_vel[0], abs_vel[1], abs_vel[2])
		local velocity_b = vector(local_player:get_prop('m_vecVelocity'))

		local spd = velocity_a:lengthsqr()

		if spd > math_pow(1.2 * 260, 2) then
			local velocity_normalized = velocity_a:normalized()
			velocity_a = velocity_normalized * (1.2 * 260)
		end

		velocity_a.z = 0
		velocity_b = get_smoothed_velocity(tickinterval * 2000, velocity_a, velocity_b)

		speed = math_min(velocity_b:length(), 260)
	end

	local lower_body = local_player:get_anim_overlay(3)

	local weapon = local_player:get_player_weapon()
	local max_movement_speed = weapon and math_max(native_GetMaxSpeed(ffi.cast(class_ptr, weapon:get_client_entity())), 0.001) or 260

	local running_speed = clamp(speed / (max_movement_speed * 0.520), 0, 1)
	local yaw_modifier = (((stop_to_full_running_fraction * -0.3) - 0.2) * running_speed) + 1

	if duck_amount > 0 then
		local ducking_speed = clamp(speed / (max_movement_speed * 0.340), 0, 1)
		yaw_modifier = yaw_modifier + ((duck_amount * ducking_speed) * (0.5 - yaw_modifier))
	end

	srv_goal_feet_yaw = clamp(srv_goal_feet_yaw, -360, 360)

	local eye_feet_delta = angle_diff(eye_angles_y, srv_goal_feet_yaw)
	local max_yaw_modifier, min_yaw_modifier = 
		yaw_modifier * 58,
		yaw_modifier * -58

	if eye_feet_delta <= max_yaw_modifier then
		if min_yaw_modifier > eye_feet_delta then
			srv_goal_feet_yaw = math_abs(min_yaw_modifier) + eye_angles_y
		end
	else
		srv_goal_feet_yaw = eye_angles_y - math_abs(max_yaw_modifier)
	end

	if speed > 0.1 then
		srv_goal_feet_yaw = approach_angle(
			eye_angles_y,
			normalize_angle(srv_goal_feet_yaw),
			((stop_to_full_running_fraction * 20) + 30) * tickinterval
		)
	else
		srv_goal_feet_yaw = approach_angle(
			local_player:get_prop('m_flLowerBodyYawTarget'),
			normalize_angle(srv_goal_feet_yaw), 
			tickinterval * 100
		)
	end

	if not data.balance_adjust.updating then
		data.balance_adjust.next_update = curtime + 0.22
	elseif local_player:get_sequence_activity(lower_body.sequence) == 979 then
		if data.balance_adjust.next_update < curtime and lower_body.weight > 0.000 then
			data.balance_adjust.next_update = curtime + 1.1
		end
	end

	if c.chokedcommands == 0 then
		local body_lean = math_abs(angle_diff(anim_state.eye_angles_y, anim_state.goal_feet_yaw))

		data.balance_adjust.updating = 
			anim_state.on_ground and anim_state.m_velocity < 0.1 and
			anim_state.anim_update_timer > 0.0

		data.abs_yaw = anim_state.eye_angles_y
		data.feet_yaw = anim_state.goal_feet_yaw
		data.server_feet_yaw = srv_goal_feet_yaw

		data.desync_exact = angle_diff(srv_goal_feet_yaw, anim_state.goal_feet_yaw)
		data.desync = clamp(data.desync_exact, -body_lean, body_lean)
	end
end

local function net_update()
	local local_player = entity.get_local_player()

	if local_player == nil or not local_player:is_alive() then
		return
	end

	local sim_time = local_player:get_prop('m_flSimulationTime')

	if sim_time == nil then
		return
	end

	local tick_count = globals_tickcount()
	local max_tbs_value = math_max(unpack(data.tickbase.list))
	local shifting = max_tbs_value < 0 and math_abs(max_tbs_value) or 0
	
    if shifting <= 0 then
		data.tickbase.shifting = 0
        data.tickbase.last_tickbase = 0
        data.tickbase.phase_tickbase = 0
    else
        if data.tickbase.phase_tickbase == 0 or data.tickbase.shifting < shifting then
            data.tickbase.shifting = shifting
        end

        if data.tickbase.last_tickbase > shifting then
            data.tickbase.shifting = data.tickbase.last_tickbase
            data.tickbase.phase_tickbase = 1
        end

        data.tickbase.last_tickbase = shifting
    end

	data.tickbase.list[#data.tickbase.list+1] = 
		sim_time/globals_tickinterval() - tick_count

	table_remove(data.tickbase.list, 1)
end

client.set_event_callback('setup_command', setup_velocity)
client.set_event_callback('net_update_start', net_update)

local this = { }

local ret_thing = function(n, ...)
	local type = { }
	local _arr = { ... }

	for i=1, #_arr do
		type[#type+1] = _arr[i]
	end

	if type[n] == nil then
		return unpack(_arr)
	end

	return type[n]
end

local get_curtime = function(nOffset)
	return globals_curtime() - (nOffset * globals_tickinterval())
end

local weapon_ready = function()
	local target = entity.get_local_player()

	if target == nil or not target:is_alive() then
		return
	end

	local weapon = target:get_player_weapon()

	if weapon == nil then
		return false
	end

	if get_curtime(16) < target:get_prop('m_flNextAttack') then 
		return false
	end

	if get_curtime(0) < weapon:get_prop('m_flNextPrimaryAttack') then
		return false
	end

	return true
end

return {
	approach_angle = function(target, value, speed) return approach_angle(target, value, speed) end,
	angle_diff = function(dest_angle, src_angle) return angle_diff(dest_angle, src_angle) end,
	normalize_angle = function(angle) return normalize_angle(angle) end,

	get_abs_yaw = function() return data.abs_yaw end,
	get_balance_adjust = function() return data.balance_adjust end,
	get_body_yaw = function(n) return ret_thing(n, data.feet_yaw, data.server_feet_yaw) end,
	get_desync = function(n) return ret_thing(n, data.desync, data.desync_exact) end,
	get_tickbase_shifting = function() return data.tickbase.shifting end,
	get_double_tap = function() return weapon_ready() and data.tickbase.shifting > 0 end,

	get_overlap = function(rotation)
		local client, server, lean =
			data.feet_yaw,
			data.server_feet_yaw,
			angle_diff(data.abs_yaw, data.feet_yaw)
	
		if type(rotation) == 'number' then
			local cLean = math_abs(lean)
	
			client = clamp(
				rotation, 
				data.abs_yaw-cLean, data.abs_yaw+cLean
			)
		end
	
		if rotation == true then
			client = data.abs_yaw + lean
		end
	
		local adiff = math_abs(angle_diff(client, server))
	
		return 1 - (adiff / 120 * 1), client
	end
}

end

bundled_modules["gamesense/surface"] = function()
local localValueGroup0Index0 = {}
local localValueGroup0Index1 = require("ffi")
local localValueGroup0Index2 = require("bit").bor
local localValueGroup0Index3 = localValueGroup0Index1.string
local localValueGroup0Index4 = localValueGroup0Index1.cast

local function localValueGroup0Index5(argumentGroup1Index0, argumentGroup1Index1, argumentGroup1Index2)
	return localValueGroup0Index1.cast(argumentGroup1Index2, localValueGroup0Index1.cast("void***", argumentGroup1Index0)[0][argumentGroup1Index1])
end

local function localValueGroup0Index6(argumentGroup2Index0, argumentGroup2Index1, argumentGroup2Index2, argumentGroup2Index3)
	local localValueGroup2Index0 = client.create_interface(argumentGroup2Index0, argumentGroup2Index1) or error("invalid interface")
	local localValueGroup2Index1, localValueGroup2Index2 = pcall(localValueGroup0Index1.typeof, argumentGroup2Index3)

	if not localValueGroup2Index1 then
		error(localValueGroup2Index2, 2)
	end

	local localValueGroup2Index3 = localValueGroup0Index5(localValueGroup2Index0, argumentGroup2Index2, localValueGroup2Index2) or error("invalid vtable")

	return function(...)
		return localValueGroup2Index3(localValueGroup2Index0, ...)
	end
end

local function localValueGroup0Index7(argumentGroup4Index0, argumentGroup4Index1)
	local localValueGroup4Index0 = localValueGroup0Index1.typeof(argumentGroup4Index1)

	return function(argumentGroup5Index0, ...)
		assert(argumentGroup5Index0 ~= nil)

		if argumentGroup5Index0 then
			return localValueGroup0Index5(argumentGroup5Index0, argumentGroup4Index0, localValueGroup4Index0)(argumentGroup5Index0, ...)
		end
	end
end

local localValueGroup0Index8 = localValueGroup0Index1.typeof("char[?]")
local localValueGroup0Index9 = localValueGroup0Index1.typeof("int[1]")
local localValueGroup0Index10 = localValueGroup0Index1.typeof("wchar_t[?]")
local localValueGroup0Index11 = localValueGroup0Index6("localize.dll", "Localize_001", 15, "int(__thiscall*)(void*, const char*, wchar_t*, int)")
local localValueGroup0Index12 = localValueGroup0Index6("localize.dll", "Localize_001", 16, "int(__thiscall*)(void*, wchar_t*, char*, int)")
local localValueGroup0Index13 = localValueGroup0Index6("localize.dll", "Localize_001", 12, "wchar_t*(__thiscall*)(void*, const char*)")
local localValueGroup0Index14 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 15, "void(__thiscall*)(void*, int, int, int, int)")
local localValueGroup0Index15 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 16, "void(__thiscall*)(void*, int, int, int, int)")
local localValueGroup0Index16 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 18, "void(__thiscall*)(void*, int, int, int, int)")
local localValueGroup0Index17 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 19, "void(__thiscall*)(void*, int, int, int, int)")
local localValueGroup0Index18 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 20, "void(__thiscall*)(void*, int*, int*, int)")
local localValueGroup0Index19 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 23, "void(__thiscall*)(void*, unsigned long)")
local localValueGroup0Index20 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 25, "void(__thiscall*)(void*, int, int, int, int)")
local localValueGroup0Index21 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 26, "void(__thiscall*)(void*, int, int)")
local localValueGroup0Index22 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 28, "void(__thiscall*)(void*, const wchar_t*, int, int)")
local localValueGroup0Index23 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 34, "int(__thiscall*)(void*, const char*)")
local localValueGroup0Index24 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 35, "bool(__thiscall*)(void*, int, char*, int)")
local localValueGroup0Index25 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 36, "void(__thiscall*)(void*, int, const char*, int, bool)")
local localValueGroup0Index26 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 37, "void(__thiscall*)(void*, int, const wchar_t*, int, int)")
local localValueGroup0Index27 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 38, "void(__thiscall*)(void*, int)")
local localValueGroup0Index28 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 39, "void(__thiscall*)(void*, int)")
local localValueGroup0Index29 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 40, "void(__thiscall*)(void*, int, int&, int&)")
local localValueGroup0Index30 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 41, "void(__thiscall*)(void*, int, int, int, int)")
local localValueGroup0Index31 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 42, "bool(__thiscall*)(void*, int)")
local localValueGroup0Index32 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 43, "int(__thiscall*)(void*, bool)")
local localValueGroup0Index33 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 66, "void(__thiscall*)(void*)")
local localValueGroup0Index34 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 67, "void(__thiscall*)(void*)")
local localValueGroup0Index35 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 71, "unsigned int(__thiscall*)(void*)")
local localValueGroup0Index36 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 72, "void(__thiscall*)(void*, unsigned long, const char*, int, int, int, int, unsigned long, int, int)")
local localValueGroup0Index37 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 79, "void(__thiscall*)(void*, unsigned long, const wchar_t*, int&, int&)")
local localValueGroup0Index38 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 100, "unsigned int(__thiscall*)(void*, int*, int*)")
local localValueGroup0Index39 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 101, "unsigned int(__thiscall*)(void*, int, int)")
local localValueGroup0Index40 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 103, "void(__thiscall*)(void*, int, int, int, int)")
local localValueGroup0Index41 = localValueGroup0Index6("vguimatsurface.dll", "VGUI_Surface031", 123, "void(__thiscall*)(void*, int, int, int, int, unsigned int, unsigned int, bool)")

local function localValueGroup0Index42(argumentGroup6Index0, argumentGroup6Index1)
	if argumentGroup6Index1 then
		local localValueGroup6Index0 = 1024
		local localValueGroup6Index1 = localValueGroup0Index8(localValueGroup6Index0)

		localValueGroup0Index12(argumentGroup6Index0, localValueGroup6Index1, localValueGroup6Index0)

		local localValueGroup6Index2 = localValueGroup0Index3(localValueGroup6Index1)

		return localValueGroup0Index22(argumentGroup6Index0, localValueGroup6Index2:len(), 0)
	else
		local localValueGroup6Index3 = 1024
		local localValueGroup6Index4 = localValueGroup0Index10(localValueGroup6Index3)

		localValueGroup0Index11(argumentGroup6Index0, localValueGroup6Index4, localValueGroup6Index3)

		return localValueGroup0Index22(localValueGroup6Index4, argumentGroup6Index0:len(), 0)
	end
end

local function localValueGroup0Index43(argumentGroup7Index0, argumentGroup7Index1)
	local localValueGroup7Index0 = localValueGroup0Index10(1024)
	local localValueGroup7Index1 = localValueGroup0Index9()
	local localValueGroup7Index2 = localValueGroup0Index9()

	localValueGroup0Index11(argumentGroup7Index1, localValueGroup7Index0, 1024)
	localValueGroup0Index37(argumentGroup7Index0, localValueGroup7Index0, localValueGroup7Index1, localValueGroup7Index2)

	local localValueGroup7Index3 = tonumber(localValueGroup7Index1[0])
	local localValueGroup7Index4 = tonumber(localValueGroup7Index2[0])

	return localValueGroup7Index3, localValueGroup7Index4
end

local localValueGroup0Index44 = {}

function localValueGroup0Index0.create_font(argumentGroup8Index0, argumentGroup8Index1, argumentGroup8Index2, argumentGroup8Index3)
	local localValueGroup8Index0 = 0
	local localValueGroup8Index1 = type(argumentGroup8Index3)

	if localValueGroup8Index1 == "number" then
		localValueGroup8Index0 = argumentGroup8Index3
	elseif localValueGroup8Index1 == "table" then
		for iteratorGroup8Index0 = 1, #argumentGroup8Index3 do
			localValueGroup8Index0 = localValueGroup8Index0 + argumentGroup8Index3[iteratorGroup8Index0]
		end
	else
		error("invalid flags type, has to be number or table")
	end

	local localValueGroup8Index2 = string.format("%s\x00%d\x00%d\x00%d", argumentGroup8Index0, argumentGroup8Index1, argumentGroup8Index2, localValueGroup8Index0)

	if localValueGroup0Index44[localValueGroup8Index2] == nil then
		localValueGroup0Index44[localValueGroup8Index2] = localValueGroup0Index35()

		localValueGroup0Index36(localValueGroup0Index44[localValueGroup8Index2], argumentGroup8Index0, argumentGroup8Index1, argumentGroup8Index2, 0, 0, localValueGroup0Index2(localValueGroup8Index0), 0, 0)
	end

	return localValueGroup0Index44[localValueGroup8Index2]
end

function localValueGroup0Index0.localize_string(argumentGroup9Index0, argumentGroup9Index1)
	local localValueGroup9Index0 = localValueGroup0Index13(argumentGroup9Index0)
	local localValueGroup9Index1 = localValueGroup0Index8(argumentGroup9Index1 or 1024)

	localValueGroup0Index12(localValueGroup9Index0, localValueGroup9Index1, argumentGroup9Index1 or 1024)

	return localValueGroup9Index1 and localValueGroup0Index3(localValueGroup9Index1) or nil
end

function localValueGroup0Index0.draw_text(argumentGroup10Index0, argumentGroup10Index1, argumentGroup10Index2, argumentGroup10Index3, argumentGroup10Index4, argumentGroup10Index5, argumentGroup10Index6, argumentGroup10Index7)
	localValueGroup0Index21(argumentGroup10Index0, argumentGroup10Index1)
	localValueGroup0Index19(argumentGroup10Index6)
	localValueGroup0Index20(argumentGroup10Index2, argumentGroup10Index3, argumentGroup10Index4, argumentGroup10Index5)

	return localValueGroup0Index42(argumentGroup10Index7, false)
end

function localValueGroup0Index0.draw_localized_text(argumentGroup11Index0, argumentGroup11Index1, argumentGroup11Index2, argumentGroup11Index3, argumentGroup11Index4, argumentGroup11Index5, argumentGroup11Index6, argumentGroup11Index7)
	localValueGroup0Index21(argumentGroup11Index0, argumentGroup11Index1)
	localValueGroup0Index19(argumentGroup11Index6)
	localValueGroup0Index20(argumentGroup11Index2, argumentGroup11Index3, argumentGroup11Index4, argumentGroup11Index5)

	local localValueGroup11Index0 = localValueGroup0Index13(argumentGroup11Index7)

	return localValueGroup0Index42(localValueGroup11Index0, true)
end

function localValueGroup0Index0.draw_line(argumentGroup12Index0, argumentGroup12Index1, argumentGroup12Index2, argumentGroup12Index3, argumentGroup12Index4, argumentGroup12Index5, argumentGroup12Index6, argumentGroup12Index7)
	localValueGroup0Index14(argumentGroup12Index4, argumentGroup12Index5, argumentGroup12Index6, argumentGroup12Index7)

	return localValueGroup0Index17(argumentGroup12Index0, argumentGroup12Index1, argumentGroup12Index2, argumentGroup12Index3)
end

function localValueGroup0Index0.draw_filled_rect(argumentGroup13Index0, argumentGroup13Index1, argumentGroup13Index2, argumentGroup13Index3, argumentGroup13Index4, argumentGroup13Index5, argumentGroup13Index6, argumentGroup13Index7)
	localValueGroup0Index14(argumentGroup13Index4, argumentGroup13Index5, argumentGroup13Index6, argumentGroup13Index7)

	return localValueGroup0Index15(argumentGroup13Index0, argumentGroup13Index1, argumentGroup13Index0 + argumentGroup13Index2, argumentGroup13Index1 + argumentGroup13Index3)
end

function localValueGroup0Index0.draw_outlined_rect(argumentGroup14Index0, argumentGroup14Index1, argumentGroup14Index2, argumentGroup14Index3, argumentGroup14Index4, argumentGroup14Index5, argumentGroup14Index6, argumentGroup14Index7)
	localValueGroup0Index14(argumentGroup14Index4, argumentGroup14Index5, argumentGroup14Index6, argumentGroup14Index7)

	return localValueGroup0Index16(argumentGroup14Index0, argumentGroup14Index1, argumentGroup14Index0 + argumentGroup14Index2, argumentGroup14Index1 + argumentGroup14Index3)
end

function localValueGroup0Index0.draw_filled_outlined_rect(argumentGroup15Index0, argumentGroup15Index1, argumentGroup15Index2, argumentGroup15Index3, argumentGroup15Index4, argumentGroup15Index5, argumentGroup15Index6, argumentGroup15Index7, argumentGroup15Index8, argumentGroup15Index9, argumentGroup15Index10, argumentGroup15Index11)
	localValueGroup0Index14(argumentGroup15Index4, argumentGroup15Index5, argumentGroup15Index6, argumentGroup15Index7)
	localValueGroup0Index15(argumentGroup15Index0, argumentGroup15Index1, argumentGroup15Index0 + argumentGroup15Index2, argumentGroup15Index1 + argumentGroup15Index3)
	localValueGroup0Index14(argumentGroup15Index8, argumentGroup15Index9, argumentGroup15Index10, argumentGroup15Index11)

	return localValueGroup0Index16(argumentGroup15Index0, argumentGroup15Index1, argumentGroup15Index0 + argumentGroup15Index2, argumentGroup15Index1 + argumentGroup15Index3)
end

function localValueGroup0Index0.draw_filled_gradient_rect(argumentGroup16Index0, argumentGroup16Index1, argumentGroup16Index2, argumentGroup16Index3, argumentGroup16Index4, argumentGroup16Index5, argumentGroup16Index6, argumentGroup16Index7, argumentGroup16Index8, argumentGroup16Index9, argumentGroup16Index10, argumentGroup16Index11, argumentGroup16Index12)
	localValueGroup0Index14(argumentGroup16Index4, argumentGroup16Index5, argumentGroup16Index6, argumentGroup16Index7)
	localValueGroup0Index41(argumentGroup16Index0, argumentGroup16Index1, argumentGroup16Index0 + argumentGroup16Index2, argumentGroup16Index1 + argumentGroup16Index3, 255, 255, argumentGroup16Index12)
	localValueGroup0Index14(argumentGroup16Index8, argumentGroup16Index9, argumentGroup16Index10, argumentGroup16Index11)

	return localValueGroup0Index41(argumentGroup16Index0, argumentGroup16Index1, argumentGroup16Index0 + argumentGroup16Index2, argumentGroup16Index1 + argumentGroup16Index3, 0, 255, argumentGroup16Index12)
end

function localValueGroup0Index0.draw_outlined_circle(argumentGroup17Index0, argumentGroup17Index1, argumentGroup17Index2, argumentGroup17Index3, argumentGroup17Index4, argumentGroup17Index5, argumentGroup17Index6, argumentGroup17Index7)
	localValueGroup0Index14(argumentGroup17Index2, argumentGroup17Index3, argumentGroup17Index4, argumentGroup17Index5)

	return localValueGroup0Index40(argumentGroup17Index0, argumentGroup17Index1, argumentGroup17Index6, argumentGroup17Index7)
end

function localValueGroup0Index0.draw_poly_line(argumentGroup18Index0, argumentGroup18Index1, argumentGroup18Index2, argumentGroup18Index3, argumentGroup18Index4, argumentGroup18Index5, argumentGroup18Index6)
	localValueGroup0Index14(argumentGroup18Index2, argumentGroup18Index3, argumentGroup18Index4, argumentGroup18Index5)

	return localValueGroup0Index18(localValueGroup0Index9(argumentGroup18Index0), localValueGroup0Index9(argumentGroup18Index1), argumentGroup18Index6)
end

function localValueGroup0Index0.test_font(argumentGroup19Index0, argumentGroup19Index1, argumentGroup19Index2, argumentGroup19Index3, argumentGroup19Index4, argumentGroup19Index5, argumentGroup19Index6)
	local localValueGroup19Index0, localValueGroup19Index1 = localValueGroup0Index43(argumentGroup19Index6, "a b c d e f g h i j k l m n o p q r s t u v w x y z")

	localValueGroup0Index0.draw_text(argumentGroup19Index0, argumentGroup19Index1, argumentGroup19Index2, argumentGroup19Index3, argumentGroup19Index4, argumentGroup19Index5, argumentGroup19Index6, "a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9 ß + # ä ö ü , . -")
	localValueGroup0Index0.draw_text(argumentGroup19Index0, argumentGroup19Index1 + localValueGroup19Index1, argumentGroup19Index2, argumentGroup19Index3, argumentGroup19Index4, argumentGroup19Index5, argumentGroup19Index6, "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z = ! \" § $ % & / ( ) = ? { [ ] } \\ * ' _ : ; ~ ")
end

function localValueGroup0Index0.get_text_size(argumentGroup20Index0, argumentGroup20Index1)
	return localValueGroup0Index43(argumentGroup20Index0, argumentGroup20Index1)
end

function localValueGroup0Index0.set_mouse_pos(argumentGroup21Index0, argumentGroup21Index1)
	return localValueGroup0Index39(argumentGroup21Index0, argumentGroup21Index1)
end

function localValueGroup0Index0.get_mouse_pos()
	local localValueGroup22Index0 = localValueGroup0Index9()
	local localValueGroup22Index1 = localValueGroup0Index9()

	localValueGroup0Index38(localValueGroup22Index0, localValueGroup22Index1)

	local localValueGroup22Index2 = tonumber(localValueGroup22Index0[0])
	local localValueGroup22Index3 = tonumber(localValueGroup22Index1[0])

	return localValueGroup22Index2, localValueGroup22Index3
end

function localValueGroup0Index0.unlock_cursor()
	return localValueGroup0Index33()
end

function localValueGroup0Index0.lock_cursor()
	return localValueGroup0Index34()
end

function localValueGroup0Index0.load_texture(argumentGroup25Index0)
	local localValueGroup25Index0 = localValueGroup0Index32(false)

	localValueGroup0Index25(localValueGroup25Index0, argumentGroup25Index0, true, true)

	local localValueGroup25Index1 = localValueGroup0Index9()
	local localValueGroup25Index2 = localValueGroup0Index9()

	localValueGroup0Index29(localValueGroup25Index0, localValueGroup25Index1, localValueGroup25Index2)

	local localValueGroup25Index3 = tonumber(localValueGroup25Index1[0])
	local localValueGroup25Index4 = tonumber(localValueGroup25Index2[0])

	return localValueGroup25Index0, localValueGroup25Index3, localValueGroup25Index4
end

setmetatable(localValueGroup0Index0, {
	__index = renderer
})

return localValueGroup0Index0

end

local initialize = (function()



local builtin_preset_payloads

local function initialize()
    local cvars = {}
    local helpers = {}
    local value, value2, vtableBind2, safe_call, ui_reference, vtableBind3, require_2, require_3, require_4, require_5, require_6, require_7, callback, safe_call_2, iterate_array, iterate_pairs, to_number, to_string, value3, value4, state, new, loadstring, get, export, flush, arshift, byte, abs, get_2, blur, absoluteframetime, get_all, color_log, interface, error_2, error_3, error_4, entries, entries2, require_8, entries3, vtableBind4, count, text, index2, entries4, text2, lshift, text3, value5, value6, value7, value8, value9, entries5, entries6, state2, to_number_2, entries7, math_pi_new_checkbox, entity_set_prop_find_signature, index3, entries8, entries9, entries10, text4, entries11, entries12, entries13, entries14, entries15, entries16, entries17, entries18, entries19, label, entries20, math_pi_new_combobox, formatted_text, entries21, text5, entries22, math_pi_reference, math_pi_reference_2, math_pi_reference_3, text6, text7, math_pi_set_callback, entity_set_prop_screen_size, screen_width, entries23, stored_configs, entries24, entries25, amount, amount2, amount3, pi_value, update_state, text8, require_tohex_sub, require_create_font, text9, entries26, entries27, text10, text11, text12, entries28, entries29, entries30, lshift_2, entries31, update_state_2, update_state_3, update_state_4, update_anti_aim, panorama_open, update_anti_aim_2, entity_set_prop_register_esp_flag, label_2, label_3, import_anti_aim, update_state_5, math_pi_new_button, enabled, on_paint_ui, create, load, save, delete, reset_2, import_from_clipboard, export_to_clipboard, on_shutdown, create_button, key, enabled_2, key2, math_tan, entries32, label_4, value10, index4, entry
    local state3 = {
        "set_event_callback",
        "new_slider",
        "get_local_player",
        "unset_event_callback",
        "is_menu_open",
        "measure_text",
        "chokedcommands",
        "unix_time",
        "screen_size"
    }
    function helpers.handle_value(index)
        return state3[index]
    end
    vtableBind2 = vtable_bind("vgui2.dll", "VGUI_System010", 22, "bool(__thiscall*)(void*, const char*)")
    safe_call = pcall
    ui_reference = ui.reference
    safe_call, ui_reference = safe_call(ui_reference, "MISC", "Miscellaneous", "Unlock hidden cvars")
    if (safe_call and (ui_reference ~= value)) then
        vtableBind3 = vtableBind2("-insecure")
        if vtableBind3 then
            pcall(ui.set, ui_reference, true)
        end
    end
    vtableBind3 = require("ffi")
    require_2 = require("bit")
    require_3 = require("vector")
    require_4 = require("gamesense/antiaim_funcs")
    if (not require_4) then
        require_4 = error("https://gamesense.pub/forums/viewtopic.php?id=29665")
    end
    require_5 = require("gamesense/surface")
    require_6 = require("gamesense/base64")
    if (not require_6) then
        require_6 = error("Base64 library required")
    end
    require_7 = require("gamesense/clipboard")
    if (not require_7) then
        require_7 = error("Clipboard library required")
    end
    callback = require
    safe_call_2 = pcall
    iterate_array = ipairs
    iterate_pairs = pairs
    to_number = tonumber
    to_string = tostring
    value3 = toticks
    value4 = totime
    state = {}
    new = vtableBind3.new
    state.new = new
    new = vtableBind3.typeof
    state.typeof = new
    new = vtableBind3.cast
    state.cast = new
    new = vtableBind3.cdef
    state.cdef = new
    new = vtableBind3.sizeof
    state.sizeof = new
    new = vtableBind3.string
    state.string = new
    new = {}
    loadstring = panorama.loadstring
    new.loadstring = loadstring
    loadstring = panorama.open
    new.open = loadstring
    loadstring = {}
    get = plist.get
    loadstring.get = get
    get = plist.set
    loadstring.set = get
    get = {}
    export = config.export
    get.export = export
    export = config.import
    get.import = export
    export = config.load
    get.load = export
    export = {}
    flush = database.flush
    export.flush = flush
    flush = database.read
    export.read = flush
    flush = database.write
    export.write = flush
    flush = {}
    arshift = require_2.arshift
    flush.arshift = arshift
    arshift = require_2.band
    flush.band = arshift
    arshift = require_2.bnot
    flush.bnot = arshift
    arshift = require_2.bor
    flush.bor = arshift
    arshift = require_2.bswap
    flush.bswap = arshift
    arshift = require_2.bxor
    flush.bxor = arshift
    arshift = require_2.lshift
    flush.lshift = arshift
    arshift = require_2.rol
    flush.rol = arshift
    arshift = require_2.ror
    flush.ror = arshift
    arshift = require_2.rshift
    flush.rshift = arshift
    arshift = require_2.tobit
    flush.tobit = arshift
    arshift = require_2.tohex
    flush.tohex = arshift
    arshift = {}
    byte = string.byte
    arshift.byte = byte
    byte = string.char
    arshift.char = byte
    byte = string.find
    arshift.find = byte
    byte = string.format
    arshift.format = byte
    byte = string.gmatch
    arshift.gmatch = byte
    byte = string.gsub
    arshift.gsub = byte
    byte = string.len
    arshift.len = byte
    byte = string.lower
    arshift.lower = byte
    byte = string.match
    arshift.match = byte
    byte = string.rep
    arshift.rep = byte
    byte = string.reverse
    arshift.reverse = byte
    byte = string.sub
    arshift.sub = byte
    byte = string.upper
    arshift.upper = byte
    byte = {}
    abs = math.abs
    byte.abs = abs
    abs = math.acos
    byte.acos = abs
    abs = math.asin
    byte.asin = abs
    abs = math.atan
    byte.atan = abs
    abs = math.atan2
    byte.atan2 = abs
    abs = math.ceil
    byte.ceil = abs
    abs = math.cos
    byte.cos = abs
    abs = math.cosh
    byte.cosh = abs
    abs = math.deg
    byte.deg = abs
    abs = math.exp
    byte.exp = abs
    abs = math.floor
    byte.floor = abs
    abs = math.fmod
    byte.fmod = abs
    abs = math.frexp
    byte.frexp = abs
    abs = math.ldexp
    byte.ldexp = abs
    abs = math.log
    byte.log = abs
    abs = math.log10
    byte.log10 = abs
    abs = math.max
    byte.max = abs
    abs = math.min
    byte.min = abs
    abs = math.modf
    byte.modf = abs
    abs = math.pow
    byte.pow = abs
    abs = math.rad
    byte.rad = abs
    abs = math.random
    byte.random = abs
    abs = math.randomseed
    byte.randomseed = abs
    abs = math.sin
    byte.sin = abs
    abs = math.sinh
    byte.sinh = abs
    abs = math.sqrt
    byte.sqrt = abs
    abs = math.tan
    key = byte
    key2 = "tan"
    math_tan = abs
    key[key2] = math_tan
    abs = math.tanh
    byte.tanh = abs
    abs = math.pi
    byte.pi = abs
    abs = {}
    get_2 = ui.get
    abs.get = get_2
    get_2 = ui.is_menu_open
    abs.is_menu_open = get_2
    get_2 = ui.menu_size
    abs.menu_size = get_2
    get_2 = ui.menu_position
    abs.menu_position = get_2
    get_2 = ui.mouse_position
    abs.mouse_position = get_2
    get_2 = ui.name
    abs.name = get_2
    get_2 = ui.new_button
    abs.new_button = get_2
    get_2 = ui.new_checkbox
    abs.new_checkbox = get_2
    get_2 = ui.new_color_picker
    abs.new_color_picker = get_2
    get_2 = ui.new_combobox
    abs.new_combobox = get_2
    get_2 = ui.new_hotkey
    abs.new_hotkey = get_2
    get_2 = ui.new_label
    abs.new_label = get_2
    get_2 = ui.new_listbox
    abs.new_listbox = get_2
    get_2 = ui.new_multiselect
    abs.new_multiselect = get_2
    get_2 = ui.new_slider
    abs.new_slider = get_2
    get_2 = ui.new_string
    abs.new_string = get_2
    get_2 = ui.new_textbox
    abs.new_textbox = get_2
    get_2 = ui.reference
    abs.reference = get_2
    get_2 = ui.set
    abs.set = get_2
    get_2 = ui.set_callback
    abs.set_callback = get_2
    get_2 = ui.set_visible
    abs.set_visible = get_2
    get_2 = ui.update
    abs.update = get_2
    get_2 = {}
    blur = renderer.blur
    get_2.blur = blur
    blur = renderer.circle
    get_2.circle = blur
    blur = renderer.circle_outline
    get_2.circle_outline = blur
    blur = renderer.gradient
    get_2.gradient = blur
    blur = renderer.indicator
    get_2.indicator = blur
    blur = renderer.line
    get_2.line = blur
    blur = renderer.load_jpg
    get_2.load_jpg = blur
    blur = renderer.load_png
    get_2.load_png = blur
    blur = renderer.load_rgba
    get_2.load_rgba = blur
    blur = renderer.load_svg
    get_2.load_svg = blur
    blur = renderer.measure_text
    get_2.measure_text = blur
    blur = renderer.rectangle
    get_2.rectangle = blur
    blur = renderer.text
    get_2.text = blur
    blur = renderer.texture
    get_2.texture = blur
    blur = renderer.triangle
    get_2.triangle = blur
    blur = renderer.world_to_screen
    get_2.world_to_screen = blur
    blur = {}
    absoluteframetime = globals.absoluteframetime
    blur.absoluteframetime = absoluteframetime
    absoluteframetime = globals.chokedcommands
    blur.chokedcommands = absoluteframetime
    absoluteframetime = globals.commandack
    blur.commandack = absoluteframetime
    absoluteframetime = globals.curtime
    blur.curtime = absoluteframetime
    absoluteframetime = globals.framecount
    blur.framecount = absoluteframetime
    absoluteframetime = globals.frametime
    blur.frametime = absoluteframetime
    absoluteframetime = globals.lastoutgoingcommand
    blur.lastoutgoingcommand = absoluteframetime
    absoluteframetime = globals.mapname
    blur.mapname = absoluteframetime
    absoluteframetime = globals.maxplayers
    blur.maxplayers = absoluteframetime
    absoluteframetime = globals.oldcommandack
    blur.oldcommandack = absoluteframetime
    absoluteframetime = globals.realtime
    blur.realtime = absoluteframetime
    absoluteframetime = globals.tickcount
    blur.tickcount = absoluteframetime
    absoluteframetime = globals.tickinterval
    blur.tickinterval = absoluteframetime
    absoluteframetime = {}
    get_all = entity.get_all
    absoluteframetime.get_all = get_all
    get_all = entity.get_bounding_box
    absoluteframetime.get_bounding_box = get_all
    get_all = entity.get_classname
    absoluteframetime.get_classname = get_all
    get_all = entity.get_esp_data
    absoluteframetime.get_esp_data = get_all
    get_all = entity.get_game_rules
    absoluteframetime.get_game_rules = get_all
    get_all = entity.get_local_player
    absoluteframetime.get_local_player = get_all
    get_all = entity.get_origin
    absoluteframetime.get_origin = get_all
    get_all = entity.get_player_name
    absoluteframetime.get_player_name = get_all
    get_all = entity.get_player_resource
    absoluteframetime.get_player_resource = get_all
    get_all = entity.get_player_weapon
    absoluteframetime.get_player_weapon = get_all
    get_all = entity.get_players
    absoluteframetime.get_players = get_all
    get_all = entity.get_prop
    absoluteframetime.get_prop = get_all
    get_all = entity.get_steam64
    absoluteframetime.get_steam64 = get_all
    get_all = entity.hitbox_position
    absoluteframetime.hitbox_position = get_all
    get_all = entity.is_alive
    absoluteframetime.is_alive = get_all
    get_all = entity.is_dormant
    absoluteframetime.is_dormant = get_all
    get_all = entity.is_enemy
    absoluteframetime.is_enemy = get_all
    get_all = entity.new_prop
    absoluteframetime.new_prop = get_all
    get_all = entity.set_prop
    absoluteframetime.set_prop = get_all
    get_all = {}
    color_log = _G.client.camera_angles
    key = get_all
    key2 = "camera_angles"
    math_tan = color_log
    key[key2] = math_tan
    color_log = _G.client.camera_position
    key = get_all
    key2 = "camera_position"
    math_tan = color_log
    key[key2] = math_tan
    color_log = _G.client.color_log
    get_all.color_log = color_log
    color_log = _G.client.create_interface
    get_all.create_interface = color_log
    color_log = _G.client.current_threat
    get_all.current_threat = color_log
    color_log = _G.client.delay_call
    get_all.delay_call = color_log
    color_log = _G.client.draw_debug_text
    get_all.draw_debug_text = color_log
    color_log = _G.client.draw_hitboxes
    get_all.draw_hitboxes = color_log
    color_log = _G.client.error_log
    get_all.error_log = color_log
    color_log = _G.client.exec
    get_all.exec = color_log
    color_log = _G.client.eye_position
    get_all.eye_position = color_log
    color_log = _G.client.find_signature
    get_all.find_signature = color_log
    color_log = _G.client.fire_event
    get_all.fire_event = color_log
    color_log = _G.client.get_cvar
    get_all.get_cvar = color_log
    color_log = _G.client.get_model_name
    get_all.get_model_name = color_log
    color_log = _G.client.key_state
    get_all.key_state = color_log
    color_log = _G.client.latency
    get_all.latency = color_log
    color_log = _G.client.log
    get_all.log = color_log
    color_log = _G.client.random_float
    get_all.random_float = color_log
    color_log = _G.client.random_int
    get_all.random_int = color_log
    color_log = _G.client.real_latency
    get_all.real_latency = color_log
    color_log = _G.client.register_esp_flag
    get_all.register_esp_flag = color_log
    color_log = _G.client.reload_active_scripts
    get_all.reload_active_scripts = color_log
    color_log = _G.client.request_full_update
    get_all.request_full_update = color_log
    color_log = _G.client.scale_damage
    get_all.scale_damage = color_log
    color_log = _G.client.screen_size
    get_all.screen_size = color_log
    color_log = _G.client.set_clan_tag
    get_all.set_clan_tag = color_log
    color_log = _G.client.set_event_callback
    get_all.set_event_callback = color_log
    color_log = _G.client.system_time
    get_all.system_time = color_log
    color_log = _G.client.timestamp
    get_all.timestamp = color_log
    color_log = _G.client.trace_bullet
    get_all.trace_bullet = color_log
    color_log = _G.client.trace_line
    get_all.trace_line = color_log
    color_log = _G.client.unix_time
    get_all.unix_time = color_log
    color_log = _G.client.unset_event_callback
    get_all.unset_event_callback = color_log
    color_log = _G.client.update_player_list
    get_all.update_player_list = color_log
    color_log = _G.client.userid_to_entindex
    get_all.userid_to_entindex = color_log
    color_log = _G.client.visible
    get_all.visible = color_log
    color_log = state.typeof("void***")
    interface = get_all.create_interface("client.dll", "VClientEntityList003")
    if (not interface) then
        interface = error("VClientEntityList003 wasnt found", 2)
    end
    error_2 = state.cast(color_log, interface)
    if (not error_2) then
        error_2 = error("rawientitylist is nil", 2)
    end
    error_3 = state.cast("void*(__thiscall*)(void*, int)", error_2[0][3])
    if (not error_3) then
        error_3 = error("get_client_entity is nil", 2)
    end
    error_4 = state.cast("void*(__thiscall*)(void*, int)", error_2[0][0])
    if (not error_4) then
        error_4 = error("get_client_networkable_t is nil", 2)
    end
    state.cdef([[
  struct animation_layer_t_cona {
      char  pad_0000[20];
      uint32_t m_nOrder; //0x0014
      uint32_t m_nSequence; //0x0018
      float m_flPrevCycle; //0x001C
      float m_flWeight; //0x0020
      float m_flWeightDeltaRate; //0x0024
      float m_flPlaybackRate; //0x0028
      float m_flCycle; //0x002C
      void *m_pOwner; //0x0030 // player's thisptr
      char  pad_0038[4]; //0x0034
  };

  struct animstate_t1 {
      char pad[ 3 ];
      char m_bForceWeaponUpdate; //0x4
      char pad1[ 91 ];
      void* m_pBaseEntity; //0x60
      void* m_pActiveWeapon; //0x64
      void* m_pLastActiveWeapon; //0x68
      float m_flLastClientSideAnimationUpdateTime; //0x6C
      int m_iLastClientSideAnimationUpdateFramecount; //0x70
      float m_flAnimUpdateDelta; //0x74
      float m_flEyeYaw; //0x78
      float m_flPitch; //0x7C
      float m_flGoalFeetYaw; //0x80
      float m_flCurrentFeetYaw; //0x84
      float m_flCurrentTorsoYaw; //0x88
      float m_flUnknownVelocityLean; //0x8C
      float m_flLeanAmount; //0x90
      char pad2[ 4 ];
      float m_flFeetCycle; //0x98
      float m_flFeetYawRate; //0x9C
      char pad3[ 4 ];
      float m_fDuckAmount; //0xA4
      float m_fLandingDuckAdditiveSomething; //0xA8
      char pad4[ 4 ];
      float m_vOriginX; //0xB0
      float m_vOriginY; //0xB4
      float m_vOriginZ; //0xB8
      float m_vLastOriginX; //0xBC
      float m_vLastOriginY; //0xC0
      float m_vLastOriginZ; //0xC4
      float m_vVelocityX; //0xC8
      float m_vVelocityY; //0xCC
      char pad5[ 4 ];
      float m_flUnknownFloat1; //0xD4
      char pad6[ 8 ];
      float m_flUnknownFloat2; //0xE0
      float m_flUnknownFloat3; //0xE4
      float m_flUnknown; //0xE8
      float m_flSpeed2D; //0xEC
      float m_flUpVelocity; //0xF0
      float m_flSpeedNormalized; //0xF4
      float m_flFeetSpeedForwardsOrSideWays; //0xF8
      float m_flFeetSpeedUnknownForwardOrSideways; //0xFC
      float m_flTimeSinceStartedMoving; //0x100
      float m_flTimeSinceStoppedMoving; //0x104
      bool m_bOnGround; //0x108
      bool m_bInHitGroundAnimation; //0x109
      char m_pad[2];
      float m_flJumpToFall;
      float m_flTimeSinceInAir; //0x10A
      float m_flLastOriginZ; //0x10E
      float m_flHeadHeightOrOffsetFromHittingGroundAnimation; //0x112
      float m_flStopToFullRunningFraction; //0x116
      char pad7[ 4 ]; //0x11A
      float m_flMagicFraction; //0x11E
      char pad8[ 60 ]; //0x122
      float m_flWorldForce; //0x15E
      char pad9[ 462 ]; //0x162
      float m_flMaxYaw; //0x334
  };

]])
    export.write("current_clip_board_to_save", "")
    entries = {}
    entries2 = {}
    require_8 = {}
    entries3 = "remove_search_path"
    vtableBind4 = "U\139\236\129\236\204\204\204\204\139U\bS\139\217"
    count = "void(__thiscall*)(void*, const char*, const char*)"
    require_8[1] = entries3
    require_8[2] = vtableBind4
    require_8[3] = count
    entries3 = {}
    vtableBind4 = "remove_file"
    count = "U\139\236\129\236\204\204\204\204\141\133\204\204\204\204VP\141E\f"
    text = "void(__thiscall*)(void*, const char*, const char*)"
    entries3[1] = vtableBind4
    entries3[2] = count
    entries3[3] = text
    vtableBind4 = {}
    count = "find_next"
    text = "U\139\236\131\236\fS\139\217\139\r\204\204\204\204"
    index2 = "const char*(__thiscall*)(void*, int)"
    vtableBind4[1] = count
    vtableBind4[2] = text
    vtableBind4[3] = index2
    count = {}
    text = "find_is_directory"
    index2 = "U\139\236\015\183E\b"
    entries4 = "bool(__thiscall*)(void*, int)"
    count[1] = text
    count[2] = index2
    count[3] = entries4
    text = {}
    index2 = "find_close"
    entries4 = "U\139\236S\139]\b\133"
    text2 = "void(__thiscall*)(void*, int)"
    text[1] = index2
    text[2] = entries4
    text[3] = text2
    index2 = {}
    entries4 = "find_first"
    text2 = "U\139\236j\000\255u\016\255u\f\255u\b\232\204\204\204\204]"
    lshift = "const char*(__thiscall*)(void*, const char*, const char*, int*)"
    index2[1] = entries4
    index2[2] = text2
    index2[3] = lshift
    entries4 = {}
    text2 = "get_current_directory"
    lshift = "U\139\236V\139u\bV\255u\f"
    text3 = "bool(__thiscall*)(void*, char*, int)"
    entries4[1] = text2
    entries4[2] = lshift
    entries4[3] = text3
    entries2[1] = require_8
    entries2[2] = entries3
    entries2[3] = vtableBind4
    entries2[4] = count
    entries2[5] = text
    entries2[6] = index2
    entries2[7] = entries4
    require_8 = callback("ffi")
    do
        local entity_set_prop, safe_call_3, require_9
        entity_set_prop = get_all
        safe_call_3 = safe_call_2
        require_9 = require_8
        entries3 = function(value142, value143, value144, value145)
            local find_signature, safe_call_4, value146, error_5, handle_value_51
            local interface_2 = entity_set_prop.create_interface(value142, value143)
            if (not interface_2) then
                interface_2 = error("invalid interface", 2)
            end
            find_signature = entity_set_prop.find_signature(value142, value144)
            if (not find_signature) then
                find_signature = error("invalid signature", 2)
            end
            safe_call_4 = safe_call_3
            value146 = require_9.typeof
            safe_call_4, value146 = safe_call_4(value146, value145)
            if (not safe_call_4) then
                error(value146, 2)
            end
            error_5 = require_9.cast(value146, find_signature)
            if (not error_5) then
                error_5 = error("invalid typecast", 2)
            end
            do
                local value147, interface_3
                value147 = error_5
                interface_3 = interface_2
                handle_value_51 = function(...)
                    return value147(interface_3, ...)
                end
            end
            return handle_value_51
        end
    end
    vtableBind4 = 1
    count = (#entries2)
    text = 1
    for index2 = vtableBind4, count, text do
        entries4 = entries2[index2]
        text2 = entries4[1]
        lshift = entries3("filesystem_stdio.dll", "VFileSystem017", entries4[2], entries4[3])
        entries[text2] = lshift
    end
    vtableBind4 = vtable_bind("filesystem_stdio.dll", "VFileSystem017", 11, "void(__thiscall*)(void*, const char*, const char*, int)")
    text = state.typeof("char[128]")
    text = text()
    entries["get_current_directory"](text, state.sizeof(text))
    index2 = arshift.format("%s", state.string(text))
    vtableBind4(index2, "WRAITH_CONFIGS", 0)
    do
        local state_4, state_5
        state_4 = state
        state_5 = entries
        entries4 = function()
            local state96, key3
            local value142 = nil
            local entries48 = {}
            local entries49 = state_4.typeof("int[1]")
            entries49 = entries49()
            local value143 = state_5.find_first("*", "WRAITH_CONFIGS", entries49)
            while (value143 ~= value142) do
                state96 = state_4.string(value143)
                key3 = state_5.find_is_directory(entries49[0])
                if (not key3) then
                    key3 = state96.find(state96, "2124089493w.cfg")
                    if key3 then
                        key3 = ((#entries48) + 1)
                        entries48[key3] = state96
                    end
                end
                key3 = state_5.find_next(entries49[0])
                value143 = key3
            end
            state_5.find_close(entries49[0])
            return entries48
        end
    end
    do
        local create_component
        do
            local value_11
            value_11 = entries4
            create_component = function()
                local index6, state96
                local entries48 = value_11()
                local entries49 = {}
                local amount4 = 1
                local count_2 = (#entries48)
                local amount5 = 1
                for index6 = amount4, count_2, amount5 do
                    state96 = entries48[index6]
                    state96 = state96.gsub(state96, "2124089493w.cfg", "")
                    entries49[index6] = state96
                end
                return entries49
            end
        end
        key = create_component
    end
    update_cfg = key
    text2 = {}
    lshift = flush.lshift(1, 0)
    key = "attack"
    text2[key] = lshift
    lshift = flush.lshift(1, 5)
    key = "use"
    text2[key] = lshift
    lshift = state.typeof("struct { float pitch; float yaw; float roll; }")
    text3 = state.typeof("struct { float x; float y; float z; }")
    value5 = state.typeof([[
      struct
      {
          uintptr_t vfptr;
          int command_number;
          int tick_count;
          $ viewangles;
          $ aimdirection;
          float forwardmove;
          float sidemove;
          float upmove;
          int buttons;
          uint8_t impulse;
          int weaponselect;
          int weaponsubtype;
          int random_seed;
          short mousedx;
          short mousedy;
          bool hasbeenpredicted;
          $ headangles;
          $ headoffset;
      }
      ]], lshift, text3, lshift, text3)
    value6 = state.typeof("$* (__thiscall*)(uintptr_t ecx, int nSlot, int sequence_number)", value5)
    value7 = state.typeof([[
      struct
      {
          uintptr_t padding[8];
          $ GetUserCmd;
      }
      ]], value6)
    value8 = state.typeof([[
      struct
      {
          $* vfptr;
      }*
      ]], value7)
    value9 = state.cast
    entries5 = value8
    entries6 = state.cast
    state2 = "uintptr_t**"
    to_number_2 = to_number
    entries7 = state.cast
    math_pi_new_checkbox = "uintptr_t"
    entity_set_prop_find_signature = get_all.find_signature
    index3 = "client.dll"
    entries8 = "\185\204\204\204\204\139@8\255\208\132\192\015\133"
    entity_set_prop_find_signature = entity_set_prop_find_signature(index3, entries8)
    if (not entity_set_prop_find_signature) then
        entity_set_prop_find_signature = error
        index3 = "client.dll!:input not found."
        entity_set_prop_find_signature = entity_set_prop_find_signature(index3)
    end
    to_number_2 = to_number_2(entries7(math_pi_new_checkbox, entity_set_prop_find_signature))
    to_number_2 = (to_number_2 + 1)
    entries6 = entries6(state2, to_number_2)
    entries6 = entries6[0]
    value9 = value9(entries5, entries6)
    entries5 = {}
    key = "reset_once"
    enabled_2 = false
    entries5[key] = enabled_2
    entries6 = {}
    enabled_2 = "body"
    entries6[0] = enabled_2
    state2 = "head"
    to_number_2 = "chest"
    entries7 = "stomach"
    math_pi_new_checkbox = "left arm"
    entity_set_prop_find_signature = "right arm"
    index3 = "left leg"
    entries8 = "right leg"
    entries9 = "neck"
    entries10 = "?"
    text4 = "gear"
    entries6[1] = state2
    entries6[2] = to_number_2
    entries6[3] = entries7
    entries6[4] = math_pi_new_checkbox
    entries6[5] = entity_set_prop_find_signature
    entries6[6] = index3
    entries6[7] = entries8
    entries6[8] = entries9
    entries6[9] = entries10
    key = 10
    entries6[key] = text4
    key = "hitgroup_names"
    entries5[key] = entries6
    key = "fire_total_hits"
    entries5[key] = 0
    key = "post_total_hits"
    entries5[key] = 0
    key = "current_condition"
    entries5[key] = ""
    key = "mode"
    enabled_2 = "back"
    entries5[key] = enabled_2
    key = "is_defensive_running"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "banana"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "old_tick_count"
    entries5[key] = 0
    key = "yaw_increment_spin"
    entries5[key] = 0
    entries6 = tickbase_max
    state2 = tickbase_diff
    to_number_2 = current_cmd
    entries5[1] = entries6
    entries5[2] = state2
    entries5[3] = to_number_2
    key = "bomb_defused"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "bomb_exploded"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "pulse"
    enabled_2 = 240
    entries5[key] = enabled_2
    key = "started"
    enabled_2 = 10
    entries5[key] = enabled_2
    key = "smooth_wraith"
    entries5[key] = 0
    key = "smooth_dt"
    entries5[key] = 0
    key = "smooth_os"
    entries5[key] = 0
    key = "smooth_pc"
    entries5[key] = 0
    key = "smooth_bo"
    entries5[key] = 0
    key = entries5
    key2 = "current_desync"
    math_tan = 0
    key[key2] = math_tan
    key = "fake_fakelag"
    entries5[key] = 0
    key = "cur"
    entries5[key] = 0
    key = "is_defusing"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "desync_rect_dist"
    entries5[key] = 0
    key = "dt_os_text_anim"
    entries5[key] = 0
    key = "current_cond_text_anim"
    entries5[key] = 0
    key = "smooth_wraith_recode"
    entries5[key] = 0
    key = "smooth_dt_2"
    entries5[key] = 0
    key = "smooth_stance"
    entries5[key] = 0
    key = "dt_vertical_dist"
    entries5[key] = 0
    key = "jumping"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "on_ground"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "rage_fired"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "last_jump_ducked"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "landing"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "waiting_scan_text"
    entries5[key] = 0
    key = "hittable"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "defensive_risk"
    entries5[key] = 0
    key = "smooth_defensive_bar"
    entries5[key] = 0
    key = "smooth_left_arrow"
    entries5[key] = 0
    key = "smooth_right_arrow"
    entries5[key] = 0
    key = "smooth_up_arrow"
    entries5[key] = 0
    key = "smooth_arrow_alpha"
    entries5[key] = 0
    key = "breaking_lc"
    enabled_2 = false
    entries5[key] = enabled_2
    entries6 = require_3
    entries6 = entries6(0, 0, 0)
    key = "last_origin"
    entries5[key] = entries6
    entries6 = require_3
    entries6 = entries6(0, 0, 0)
    key = "origin_delta"
    entries5[key] = entries6
    key = "is_defensive_forced"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "running_extended"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "air_time"
    entries5[key] = 0
    key = "wait_for_land_update"
    enabled_2 = false
    entries5[key] = enabled_2
    key = "time_on_ground"
    entries5[key] = 0
    entries6 = {}
    key = "active"
    enabled_2 = false
    entries6[key] = enabled_2
    key = "start_time"
    entries6[key] = 0
    key = "axis"
    entries6[key] = value
    key = "cs_state"
    entries5[key] = entries6
    entries6 = {}
    key = "cache_sun_loc"
    entries5[key] = entries6
    key = "force_sunset_once"
    enabled_2 = false
    entries5[key] = enabled_2
    entries6 = {}
    state2 = {}
    key = "cur"
    entries6[key] = state2
    state2 = {}
    key = "prev"
    entries6[key] = state2
    state2 = {}
    key = "pre_prev"
    entries6[key] = state2
    state2 = {}
    key = "pre_pre_prev"
    entries6[key] = state2
    state2 = {}
    to_number_2 = {}
    entries7 = 1
    math_pi_new_checkbox = 64
    entity_set_prop_find_signature = 1
    for index3 = entries7, math_pi_new_checkbox, entity_set_prop_find_signature do
        entries8 = {}
        entries9 = {}
        key = "stand"
        entries8[key] = entries9
        entries9 = {}
        key = "stand_type"
        entries8[key] = entries9
        entries9 = {}
        key = "run"
        entries8[key] = entries9
        entries9 = {}
        key = "run_type"
        entries8[key] = entries9
        entries9 = {}
        key = "air"
        entries8[key] = entries9
        entries9 = {}
        key = "air_type"
        entries8[key] = entries9
        entries9 = {}
        key = "duck"
        entries8[key] = entries9
        entries9 = {}
        key = "duck_type"
        entries8[key] = entries9
        to_number_2[index3] = entries8
    end
    entries7 = value2
    if entries7 then
        entries7 = value2()
    end
    if (not entries7) then
        entries7 = {}
        key = "user"
        enabled_2 = decode_protected_text({177, 177, 194, 201, 198, 213})
        entries7[key] = enabled_2
        key = "build"
        enabled_2 = "recode"
        entries7[key] = enabled_2
    end
    math_pi_new_checkbox = abs.new_checkbox
    entity_set_prop_find_signature = "AA"
    index3 = "Anti-aimbot angles"
    entries8 = arshift.lower
    entries9 = entries7["user"]
    entries8 = entries8(entries9)
    entries8 = ("wraith - " .. entries8)
    math_pi_new_checkbox = math_pi_new_checkbox(entity_set_prop_find_signature, index3, entries8)
    index3 = nil
    entries8 = nil
    entries9 = nil
    entries10 = {}
    text4 = "anti-aim"
    entries11 = "anti-aim 2"
    entries12 = "visuals"
    entries13 = "misc"
    entries14 = "config"
    entries15 = "debug"
    entries10[1] = text4
    entries10[2] = entries11
    entries10[3] = entries12
    entries10[4] = entries13
    entries10[5] = entries14
    entries10[6] = entries15
    text4 = {}
    entries11 = {}
    entries12 = {}
    entries13 = "global"
    entries14 = "standing"
    entries15 = "moving"
    entries16 = "slow motion"
    entries17 = "in air"
    entries18 = "in air duck"
    entries19 = "in duck"
    label = "in duck moving"
    helpers.handle_value_2 = "in fake duck"
    entries20 = "fakelag"
    math_pi_new_combobox = "manual"
    helpers.handle_value_3 = "freestanding"
    helpers.handle_value_4 = "backstab"
    formatted_text = "height"
    entries21 = "high distance"
    helpers.handleValue5 = "legit"
    entries12[1] = entries13
    entries12[2] = entries14
    entries12[3] = entries15
    entries12[4] = entries16
    entries12[5] = entries17
    entries12[6] = entries18
    entries12[7] = entries19
    entries12[8] = label
    entries12[9] = helpers.handle_value_2
    key = 10
    entries12[key] = entries20
    key = 11
    entries12[key] = math_pi_new_combobox
    key = 12
    entries12[key] = helpers.handle_value_3
    key = 13
    entries12[key] = helpers.handle_value_4
    key = 14
    entries12[key] = formatted_text
    key = 15
    entries12[key] = entries21
    key = 16
    entries12[key] = helpers.handleValue5
    entries13 = {}
    key = "lua"
    enabled_2 = "\238\138\140"
    entries13[key] = enabled_2
    key = "star"
    enabled_2 = "\238\130\130"
    entries13[key] = enabled_2
    key = "lock"
    enabled_2 = "\238\135\183"
    entries13[key] = enabled_2
    key = "arrows"
    enabled_2 = "\238\137\140"
    entries13[key] = enabled_2
    key = "pizza"
    enabled_2 = "\238\131\170"
    entries13[key] = enabled_2
    key = "up arrow"
    enabled_2 = "\238\131\164"
    entries13[key] = enabled_2
    key = "cpu"
    enabled_2 = "\238\139\172"
    entries13[key] = enabled_2
    key = "smilie"
    enabled_2 = "\238\136\180"
    entries13[key] = enabled_2
    key = "heart"
    enabled_2 = "\238\130\165"
    entries13[key] = enabled_2
    entries14 = {}
    key = "le_icon"
    enabled_2 = "a"
    entries14[key] = enabled_2
    entries15 = {}
    entries16 = "\238\135\160"
    entries17 = "\238\135\160\226\145\181"
    entries18 = "\238\138\132"
    entries19 = "\238\135\172"
    label = "\238\135\129"
    helpers.handle_value_2 = "F"
    entries15[1] = entries16
    entries15[2] = entries17
    entries15[3] = entries18
    entries15[4] = entries19
    entries15[5] = label
    entries15[6] = helpers.handle_value_2
    key = "tabs_names"
    entries14[key] = entries15
    entries15 = {}
    key = "tab"
    entries14[key] = entries15
    key = "selected_tab"
    entries14[key] = 0
    entries15 = {}
    entries16 = {}
    entries17 = 20
    entries18 = 20
    entries19 = 20
    label = 255
    entries16[1] = entries17
    entries16[2] = entries18
    entries16[3] = entries19
    entries16[4] = label
    entries17 = {}
    entries18 = 210
    entries19 = 210
    label = 210
    helpers.handle_value_2 = 255
    entries17[1] = entries18
    entries17[2] = entries19
    entries17[3] = label
    entries17[4] = helpers.handle_value_2
    entries15[1] = entries16
    entries15[2] = entries17
    key = "selected_color"
    entries14[key] = entries15
    key = "is_open"
    entries14[key] = true
    key = "menu_alpha"
    enabled_2 = 255
    entries14[key] = enabled_2
    key = "is_hovered"
    enabled_2 = false
    entries14[key] = enabled_2
    key = "height"
    enabled_2 = 68
    entries14[key] = enabled_2
    entries15 = {}
    entries16 = {}
    entries17 = 84
    entries18 = 149
    entries16[1] = entries17
    entries16[2] = entries18
    entries17 = {}
    entries18 = 100
    entries19 = 181
    entries17[1] = entries18
    entries17[2] = entries19
    entries18 = {}
    entries19 = 116
    label = 213
    entries18[1] = entries19
    entries18[2] = label
    entries19 = {}
    label = 132
    helpers.handle_value_2 = 245
    entries19[1] = label
    entries19[2] = helpers.handle_value_2
    label = {}
    helpers.handle_value_2 = 148
    entries20 = 277
    label[1] = helpers.handle_value_2
    label[2] = entries20
    entries15[1] = entries16
    entries15[2] = entries17
    entries15[3] = entries18
    entries15[4] = entries19
    entries15[5] = label
    key = "dpi_scaling_y"
    entries14[key] = entries15
    key = "selected_gs_tab"
    enabled_2 = false
    entries14[key] = enabled_2
    key = "mouse_press"
    enabled_2 = false
    entries14[key] = enabled_2
    entries15 = {}
    entries16 = 0
    entries17 = 0
    entries15[1] = entries16
    entries15[2] = entries17
    key = "old_mpos"
    entries14[key] = entries15
    entries15 = false
    entries16 = false
    entries17 = {}
    key = "100%"
    enabled_2 = 68
    entries17[key] = enabled_2
    key = "125%"
    enabled_2 = 75
    entries17[key] = enabled_2
    key = "150%"
    enabled_2 = 85
    entries17[key] = enabled_2
    key = "175%"
    enabled_2 = 95
    entries17[key] = enabled_2
    key = "200%"
    enabled_2 = 105
    entries17[key] = enabled_2
    entries18 = {}
    entries19 = abs.new_combobox("AA", "Anti-aimbot angles", "\n", entries10)
    key = "tab"
    entries18[key] = entries19
    entries19 = {}
    label = abs.new_combobox("AA", "Anti-aimbot angles", "type", "gamesense", "wraith (dont use)")
    entries19[0] = label
    label = abs.new_combobox("AA", "Anti-aimbot angles", "condition", entries12)
    entries19[1] = label
    key = "anti-aim"
    entries18[key] = entries19
    entries19 = {}
    label = abs.new_multiselect("AA", "Anti-aimbot angles", "add features", "other anti-aim binds", "manual anti-aim")
    entries19[0] = label
    label = abs.new_hotkey("AA", "Anti-aimbot angles", "edge-yaw")
    entries19[1] = label
    label = abs.new_hotkey("AA", "Anti-aimbot angles", "freestanding")
    entries19[2] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "manual anti-aim")
    entries19[3] = label
    label = abs.new_hotkey("AA", "Anti-aimbot angles", "left")
    entries19[4] = label
    label = abs.new_slider("AA", "Anti-aimbot angles", [[

 left angle]], 0, 145, 90, true, "\194\176", 1, {})
    entries19[8] = label
    label = abs.new_hotkey("AA", "Anti-aimbot angles", "right")
    entries19[5] = label
    label = abs.new_slider("AA", "Anti-aimbot angles", [[

 right angle]], 0, 145, 90, true, "\194\176", 1, {})
    entries19[9] = label
    label = abs.new_hotkey("AA", "Anti-aimbot angles", "forward")
    entries19[6] = label
    label = abs.new_hotkey("AA", "Anti-aimbot angles", "reset")
    entries19[7] = label
    key = "anti-aim 2"
    entries18[key] = entries19
    entries19 = {}
    label = abs.new_combobox("AA", "Anti-aimbot angles", "indicators", "off", "minimal (og)", "anti urine", "recode alpha")
    entries19[0] = label
    label = abs.new_color_picker("AA", "Anti-aimbot angles", "anti-aim indicators", 200, 200, 255, 255)
    entries19[1] = label
    label = abs.new_multiselect("AA", "Anti-aimbot angles", "indicator extras", "animations on scope", "lowercase", "min damage", "desync", "defensive", "lc indicator")
    entries19[6] = label
    label = abs.new_combobox("AA", "Anti-aimbot angles", "indicators size", "small", "thin", "bold", "blind")
    entries19[3] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "watermark")
    entries19[2] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "third person only")
    key = "sunset mode"
    entries19[key] = label
    label = abs.new_combobox("AA", "Anti-aimbot angles", "size", "small", "thin", "bold", "blind")
    entries19[4] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "notifications size")
    entries19[7] = label
    label = abs.new_combobox("AA", "Anti-aimbot angles", [[

 nigga]], "small", "thin", "bold", "blind")
    entries19[5] = label
    label = abs.new_combobox("AA", "Anti-aimbot angles", "extended teleport prediction", "off", "box", "circle")
    entries19[8] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "manual anti-aim")
    entries19[9] = label
    label = abs.new_color_picker("AA", "Anti-aimbot angles", "manual anti-aim", 200, 200, 200, 200)
    key = 10
    entries19[key] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "Onii presence")
    key = 11
    entries19[key] = label
    label = abs.new_multiselect("AA", "Anti-aimbot angles", "Onii visualize", "defensive", "break lc", "vulnerable")
    key = entries19
    key2 = 12
    math_tan = label
    key[key2] = math_tan
    label = abs.new_multiselect("AA", "Anti-aimbot angles", "Onii object", "skeleton", "box", "text")
    key = 13
    entries19[key] = label
    label = abs.new_label("AA", "Anti-aimbot angles", "defensive skeleton")
    key = 69
    entries19[key] = label
    label = abs.new_color_picker("AA", "Anti-aimbot angles", "skeleton defensive color", 200, 200, 255, 255)
    key = 14
    entries19[key] = label
    label = abs.new_label("AA", "Anti-aimbot angles", "defensive box")
    key = 72
    entries19[key] = label
    label = abs.new_color_picker("AA", "Anti-aimbot angles", "box defensive color", 200, 200, 255, 255)
    key = 17
    entries19[key] = label
    label = abs.new_label("AA", "Anti-aimbot angles", "lc skeleton")
    key = 70
    entries19[key] = label
    label = abs.new_color_picker("AA", "Anti-aimbot angles", "lc color", 200, 200, 255, 255)
    key = entries19
    key2 = 15
    math_tan = label
    key[key2] = math_tan
    label = abs.new_label("AA", "Anti-aimbot angles", "lc box box")
    key = 73
    entries19[key] = label
    label = abs.new_color_picker("AA", "Anti-aimbot angles", "lc box color", 200, 200, 255, 255)
    key = 18
    entries19[key] = label
    label = abs.new_label("AA", "Anti-aimbot angles", "vulnerable skeleton")
    key = 71
    entries19[key] = label
    label = abs.new_color_picker("AA", "Anti-aimbot angles", "vulnerable skeleton color", 200, 200, 255, 255)
    key = 16
    entries19[key] = label
    label = abs.new_label("AA", "Anti-aimbot angles", "vulnerable box")
    key = 74
    entries19[key] = label
    label = abs.new_color_picker("AA", "Anti-aimbot angles", "vulnerable box color", 200, 200, 255, 255)
    key = 19
    entries19[key] = label
    label = abs.new_slider("AA", "Anti-aimbot angles", "Maximum records", 20, 500, 200, true, "", 1)
    key = "maxrecords"
    entries19[key] = label
    label = abs.new_slider("AA", "Anti-aimbot angles", "Record lifetime (ms)", 200, 5000, 2000, true, "ms", 1)
    key = "maxlife"
    entries19[key] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "show last record")
    key = "show_last_record"
    entries19[key] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "third person only")
    key = "thirdpersonly"
    entries19[key] = label
    key = "visuals"
    entries18[key] = entries19
    entries19 = {}
    label = abs.new_hotkey("AA", "Anti-aimbot angles", "extended teleport")
    entries19[6] = label
    label = abs.new_hotkey("AA", "Anti-aimbot angles", "extended teleport on hit")
    entries19[7] = label
    label = abs.new_combobox("AA", "Anti-aimbot angles", "extended teleport hit risk", "high", "medium", "low", "safest")
    entries19[8] = label
    label = abs.new_multiselect("AA", "Anti-aimbot angles", "custom animations", "pitch on land", "fallen legs", "moonwalk", "air walk", "blind", "fake walk", "earthquake", "slide", "fake duck", "smoothing")
    entries19[1] = label
    label = abs.new_multiselect("AA", "Anti-aimbot angles", "notify", "fire", "damage", "miss", "hurt", "hurt self", "config changes")
    entries19[2] = label
    label = abs.new_multiselect("AA", "Anti-aimbot angles", [[
type 
 nots]], "default", "center", "console")
    entries19[3] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "trashtalk")
    entries19[4] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "bypass anti trashtalk")
    entries19[5] = label
    key = "misc"
    entries18[key] = entries19
    entries19 = {}
    label = abs.new_label("AA", "Anti-aimbot angles", "config")
    entries19[0] = label
    label = abs.new_listbox("AA", "Anti-aimbot angles", "config_board", "")
    entries19[1] = label
    label = abs.new_textbox("AA", "Anti-aimbot angles", "config names")
    entries19[2] = label
    entries19[8] = 0
    key = entries19
    key2 = 3
    math_tan = 0
    key[key2] = math_tan
    entries19[4] = 0
    entries19[5] = 0
    key = entries19
    key2 = 6
    math_tan = 0
    key[key2] = math_tan
    entries19[7] = 0
    entries18.config = entries19
    entries19 = {}
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "alternative ui")
    entries19[0] = label
    label = abs.new_combobox("AA", "Anti-aimbot angles", "debug tab icon", "lua", "star", "lock", "arrows", "pizza", "up arrow", "cpu", "smilie", "heart")
    entries19[4] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "fps optimizations")
    entries19[2] = label
    label = abs.new_multiselect("AA", "Anti-aimbot angles", [[
disable
 optiz]], "3d sky", "fog", "shadows", "blood", "decals", "bloom", "other")
    entries19[3] = label
    label = abs.new_combobox("AA", "Anti-aimbot angles", "anti-aim correction", "off", "desync")
    entries19[1] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "on shot only (ragebot)")
    entries19[5] = label
    label = abs.new_hotkey("AA", "Anti-aimbot angles", [[

 on shot bind]], true)
    entries19[6] = label
    label = abs.new_checkbox("AA", "Anti-aimbot angles", "defensive peek correction")
    entries19[7] = label
    key = "debug"
    entries18[key] = entries19
    abs.new_label("Players", "Adjustments", "wraith anti-aim stealer")
    entries19 = abs.new_checkbox("Players", "Adjustments", "scan anti-aim")
    steal_aa_toggle = entries19
    entries19 = abs.new_checkbox("Players", "Adjustments", "ignore missing stances")
    steal_aa_ignore = entries19
    entries19, label, helpers.handle_value_2 = iterate_pairs(entries12)
    entries32 = entries19
    label_4 = label
    value10 = helpers.handle_value_2
    for index4, entry in entries32, label_4, value10 do
        label = index4
        helpers.handle_value_2 = entry
        entries20 = {}
        math_pi_new_combobox = abs.new_checkbox("AA", "Anti-aimbot angles", arshift.format("[%s - gamesense]", helpers.handle_value_2))
        entries20[0] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_combobox
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[
pitch 
 %s]], helpers.handle_value_2)
        entries21 = {}
        helpers.handleValue5 = "off"
        text5 = "default"
        entries22 = "up"
        math_pi_reference = "down"
        math_pi_reference_2 = "minimal"
        math_pi_reference_3 = "random"
        text6 = "custom"
        entries21[1] = helpers.handleValue5
        entries21[2] = text5
        entries21[3] = entries22
        entries21[4] = math_pi_reference
        entries21[5] = math_pi_reference_2
        entries21[6] = math_pi_reference_3
        entries21[7] = text6
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, entries21)
        entries20[1] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_slider
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[

%s pitch slider]], helpers.handle_value_2)
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, (-89), 89, 0, true, "\194\176", 1, {})
        entries20[2] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_combobox
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[
yaw base 
%s]], helpers.handle_value_2)
        entries21 = {}
        helpers.handleValue5 = "local view"
        text5 = "at targets"
        entries21[1] = helpers.handleValue5
        entries21[2] = text5
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, entries21)
        entries20[3] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_combobox
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[
yaw
 %s]], helpers.handle_value_2)
        entries21 = {}
        helpers.handleValue5 = "off"
        text5 = "180"
        entries22 = "spin"
        math_pi_reference = "static"
        math_pi_reference_2 = "180 Z"
        math_pi_reference_3 = "crosshair"
        entries21[1] = helpers.handleValue5
        entries21[2] = text5
        entries21[3] = entries22
        entries21[4] = math_pi_reference
        entries21[5] = math_pi_reference_2
        entries21[6] = math_pi_reference_3
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, entries21)
        entries20[4] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_slider
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[

%s yaw add]], helpers.handle_value_2)
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, (-180), 180, 0, true, "\194\176", 1, {})
        entries20[5] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_combobox
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[
yaw jitter
%s]], helpers.handle_value_2)
        entries21 = {}
        helpers.handleValue5 = "off"
        text5 = "offset"
        entries22 = "center"
        math_pi_reference = "random"
        math_pi_reference_2 = "skitter"
        math_pi_reference_3 = "slow"
        entries21[1] = helpers.handleValue5
        entries21[2] = text5
        entries21[3] = entries22
        entries21[4] = math_pi_reference
        entries21[5] = math_pi_reference_2
        entries21[6] = math_pi_reference_3
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, entries21)
        entries20[6] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_slider
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[

 %s yaw jitter]], helpers.handle_value_2)
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, (-180), 180, 0, true, "\194\176", 1, {})
        entries20[7] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_combobox
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[
body yaw
 %s]], helpers.handle_value_2)
        entries21 = {}
        helpers.handleValue5 = "off"
        text5 = "opposite"
        entries22 = "jitter"
        math_pi_reference = "static"
        entries21[1] = helpers.handleValue5
        entries21[2] = text5
        entries21[3] = entries22
        entries21[4] = math_pi_reference
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, entries21)
        entries20[8] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_slider
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[

%s body yaw static side]], helpers.handle_value_2)
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, (-180), 180, 0, true, "\194\176", 1, {})
        entries20[9] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_checkbox("AA", "Anti-aimbot angles", arshift.format([[
freestanding body yaw
 %s]], helpers.handle_value_2))
        key = 10
        entries20[key] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_checkbox("AA", "Anti-aimbot angles", arshift.format([[
edge yaw
 %s]], helpers.handle_value_2))
        key = 11
        entries20[key] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_checkbox("AA", "Anti-aimbot angles", arshift.format([[
freestanding
 %s]], helpers.handle_value_2))
        key = 12
        entries20[key] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_slider
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[
roll
 %s]], helpers.handle_value_2)
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, (-45), 45, 0, true, "\194\176", 1, {})
        key = 13
        entries20[key] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_checkbox("AA", "Anti-aimbot angles", arshift.format([[
force defensive
 %s]], helpers.handle_value_2))
        key = 14
        entries20[key] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_combobox
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[
defensive pitch
 %s]], helpers.handle_value_2)
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, "off", "up", "random", "minimal", "zero")
        key = 15
        entries20[key] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_combobox
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[
defensive yaw
 %s]], helpers.handle_value_2)
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, "off", "forward", "spin", "jitter", "opposite")
        key = 16
        entries20[key] = math_pi_new_combobox
        text4[label] = entries20
        entries20 = {}
        math_pi_new_combobox = abs.new_checkbox("AA", "Anti-aimbot angles", arshift.format("[%s - wraith] (incomplete)", helpers.handle_value_2))
        entries20[0] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_combobox
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[
pitch
 %s w]], helpers.handle_value_2)
        entries21 = {}
        helpers.handleValue5 = "off"
        text5 = "emotion (89)"
        entries22 = "up (-89)"
        math_pi_reference = "fake up (180)"
        math_pi_reference_2 = "fake down (-180)"
        math_pi_reference_3 = "fake zero (1080)"
        text6 = "fake down (-540)"
        entries21[1] = helpers.handleValue5
        entries21[2] = text5
        entries21[3] = entries22
        entries21[4] = math_pi_reference
        entries21[5] = math_pi_reference_2
        entries21[6] = math_pi_reference_3
        entries21[7] = text6
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, entries21)
        entries20[1] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_combobox
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[
yaw jitter
 %s w]], helpers.handle_value_2)
        entries21 = {}
        helpers.handleValue5 = "off"
        text5 = "offset"
        entries22 = "center"
        math_pi_reference = "random"
        math_pi_reference_2 = "3 way"
        math_pi_reference_3 = "5 way"
        entries21[1] = helpers.handleValue5
        entries21[2] = text5
        entries21[3] = entries22
        entries21[4] = math_pi_reference
        entries21[5] = math_pi_reference_2
        entries21[6] = math_pi_reference_3
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, entries21)
        entries20[2] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_slider
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[

 %s yaw jitter w]], helpers.handle_value_2)
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, (-180), 180, 0, true, "\194\176", 1, {})
        entries20[3] = math_pi_new_combobox
        math_pi_new_combobox = abs.new_combobox
        helpers.handle_value_3 = "AA"
        helpers.handle_value_4 = "Anti-aimbot angles"
        formatted_text = arshift.format([[
body yaw
 %s w]], helpers.handle_value_2)
        entries21 = {}
        helpers.handleValue5 = "off"
        text5 = "opposite"
        entries22 = "jitter"
        math_pi_reference = "static"
        entries21[1] = helpers.handleValue5
        entries21[2] = text5
        entries21[3] = entries22
        entries21[4] = math_pi_reference
        math_pi_new_combobox = math_pi_new_combobox(helpers.handle_value_3, helpers.handle_value_4, formatted_text, entries21)
        entries20[4] = math_pi_new_combobox
        entries11[label] = entries20
    end
    do
        local iterate_pairs_2, to_string_2
        iterate_pairs_2 = iterate_pairs
        to_string_2 = to_string
        entries19 = function(value142)
            local value143, value144, amount4, value_type, index6, entry_2
            local text13 = [[

{]]
            value143, value144, amount4 = iterate_pairs_2(value142)
            local value145 = value143
            local value146 = value144
            local value147 = amount4
            for index6, entry_2 in value145, value146, value147 do
                value144 = index6
                amount4 = entry_2
                value_type = type(value144)
                if (value_type == "string") then
                    text13 = (text13 .. ("[\"" .. (value144 .. "\"]=")))
                end
                value_type = type(amount4)
                if (value_type == "table") then
                    value_type = table_to_string(amount4)
                    text13 = (text13 .. value_type)
                else
                    value_type = type(amount4)
                    if (value_type == "boolean") then
                        value_type = to_string_2(amount4)
                        text13 = (text13 .. value_type)
                    else
                        text13 = (text13 .. ("\"" .. (amount4 .. "\"")))
                    end
                end
                text13 = (text13 .. ",\n")
            end
            if (text13 ~= "") then
                value144 = text13
                value143 = text13.sub
                amount4 = 1
                value_type = text13.len(text13)
                value143 = value143(value144, amount4, (value_type - 1))
                text13 = value143
            end
            return (text13 .. "}\n")
        end
    end
    do
        local require_tohex
        require_tohex = arshift
        label = function(value142, value143)
            local replaced_text, index6, entry_2
            local entries48 = {}
            local require_tohex_gmatch = require_tohex.gmatch
            local gmatch = value142
            local gmatch_2 = ("([^" .. (value143 .. "]+)"))
            require_tohex_gmatch, gmatch, gmatch_2 = require_tohex_gmatch(gmatch, gmatch_2)
            local require_tohex_gmatch_2 = require_tohex_gmatch
            local gmatch_3 = gmatch
            local gmatch_4 = gmatch_2
            for index6, entry_2 in require_tohex_gmatch_2, gmatch_3, gmatch_4 do
                gmatch = index6
                gmatch_2 = ((#entries48) + 1)
                replaced_text = require_tohex.gsub(gmatch, "\n", "")
                entries48[gmatch_2] = replaced_text
            end
            return entries48
        end
    end
    function helpers.handle_value_2(value142)
        if ((value142 == "true") or (value142 == "false")) then
            return (value142 == "true")
        end
        return value142
    end
    do
        local string_upper
        string_upper = byte
        entries20 = function(value142)
            return string_upper.floor((value142 + 0.5))
        end
    end
    do
        local string_upper_2
        string_upper_2 = byte
        math_pi_new_combobox = function(value142, value143, value144)
            local string_upper_max = string_upper_2.max
            local min = string_upper_2.min(value142, value144)
            return string_upper_max(min, value143)
        end
    end
    function helpers.handle_value_3(value142, value143, value144, value145, value146)
        local value147
        if (value144 == value143) then
            return value145
        end
        value147 = ((value142 - value143) / (value144 - value143))
        return (value145 + ((value146 - value145) * value147))
    end
    do
        local require_tohex_2
        require_tohex_2 = arshift
        helpers.handle_value_4 = function(value142, value143, value144, value145)
            return require_tohex_2.format("%02x%02x%02x%02x", value142, value143, value144, value145)
        end
    end
    do
        local iterate_array_2
        iterate_array_2 = iterate_array
        formatted_text = function(value142)
            local value143, value144, key3, amount4, index6, entry_2
            local entries48 = {}
            value143, value144, key3 = iterate_array_2(value142)
            local value145 = value143
            local value146 = value144
            local value147 = key3
            for index6, entry_2 in value145, value146, value147 do
                key3 = entry_2
                amount4 = entries48[key3]
                if (not amount4) then
                    amount4 = 0
                end
                amount4 = (amount4 + 1)
                entries48[key3] = amount4
            end
            return entries48
        end
    end
    do
        local iterate_pairs_3
        iterate_pairs_3 = iterate_pairs
        entries21 = function(entries48)
            local value142, key3, value143, index6, entry_2
            local next_2 = next(entries48)
            value142, key3, value143 = iterate_pairs_3(entries48)
            local value144 = value142
            local value145 = key3
            local value146 = value143
            for index6, entry_2 in value144, value145, value146 do
                key3 = index6
                if (entries48[next_2] < entries48[key3]) then
                    next_2 = key3
                end
            end
            return next_2
        end
    end
    do
        local value_12, value_13
        value_12 = entries21
        value_13 = formatted_text
        helpers.handleValue5 = function(value142)
            return value_12(value_13(value142))
        end
    end
    text5 = {}
    entries22 = {}
    math_pi_reference = {}
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "RAGE"
    text6 = "Aimbot"
    text7 = "Double tap"
    math_pi_reference = {math_pi_reference_2(math_pi_reference_3, text6, text7)}
    key = "ref_doubletap"
    entries22[key] = math_pi_reference
    math_pi_reference = abs.reference
    math_pi_reference_2 = "RAGE"
    math_pi_reference_3 = "Aimbot"
    text6 = "Force safe point"
    math_pi_reference = math_pi_reference(math_pi_reference_2, math_pi_reference_3, text6)
    key = "ref_safepoint"
    entries22[key] = math_pi_reference
    math_pi_reference = {}
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "RAGE"
    text6 = "Aimbot"
    text7 = "Force body aim"
    math_pi_reference = {math_pi_reference_2(math_pi_reference_3, text6, text7)}
    key = "ref_baim"
    entries22[key] = math_pi_reference
    math_pi_reference = {}
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "RAGE"
    text6 = "Aimbot"
    text7 = "Minimum damage"
    math_pi_reference = {math_pi_reference_2(math_pi_reference_3, text6, text7)}
    key = "ref_min_damage"
    entries22[key] = math_pi_reference
    math_pi_reference = {}
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "RAGE"
    text6 = "Aimbot"
    text7 = "Minimum damage override"
    math_pi_reference = {math_pi_reference_2(math_pi_reference_3, text6, text7)}
    key = "ref_min_damage_override"
    entries22[key] = math_pi_reference
    math_pi_reference = {}
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "RAGE"
    text6 = "Other"
    text7 = "Duck peek assist"
    math_pi_reference_2 = math_pi_reference_2(math_pi_reference_3, text6, text7)
    key = "ref_fakeduck"
    math_pi_reference[key] = math_pi_reference_2
    key = "other"
    entries22[key] = math_pi_reference
    key = "rage"
    text5[key] = entries22
    entries22 = {}
    math_pi_reference = {}
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "AA"
    text6 = "Anti-aimbot angles"
    text7 = "Enabled"
    math_pi_reference_2 = math_pi_reference_2(math_pi_reference_3, text6, text7)
    key = "ref_aa_enabled"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = {}
    math_pi_reference_3 = abs.reference
    text6 = "AA"
    text7 = "Anti-aimbot angles"
    math_pi_reference_2 = {math_pi_reference_3(text6, text7, "Pitch")}
    key = "ref_pitch"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = {}
    math_pi_reference_3 = abs.reference
    text6 = "AA"
    text7 = "Anti-aimbot angles"
    math_pi_reference_2 = {math_pi_reference_3(text6, text7, "Yaw")}
    key = "ref_yaw"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "AA"
    text6 = "Anti-aimbot angles"
    text7 = "Yaw base"
    math_pi_reference_2 = math_pi_reference_2(math_pi_reference_3, text6, text7)
    key = "ref_yaw_base"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = {}
    math_pi_reference_3 = abs.reference
    text6 = "AA"
    text7 = "Anti-aimbot angles"
    math_pi_reference_2 = {math_pi_reference_3(text6, text7, "Body yaw")}
    key = "ref_body_yaw"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = {}
    math_pi_reference_3 = abs.reference
    text6 = "AA"
    text7 = "Anti-aimbot angles"
    math_pi_reference_2 = {math_pi_reference_3(text6, text7, "Yaw jitter")}
    key = "ref_yaw_jitter"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "AA"
    text6 = "Anti-aimbot angles"
    text7 = "Freestanding body yaw"
    math_pi_reference_2 = math_pi_reference_2(math_pi_reference_3, text6, text7)
    key = "ref_freestand_body"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "AA"
    text6 = "Anti-aimbot angles"
    text7 = "Edge yaw"
    math_pi_reference_2 = math_pi_reference_2(math_pi_reference_3, text6, text7)
    key = "ref_edge_yaw"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = {}
    math_pi_reference_3 = abs.reference
    text6 = "AA"
    text7 = "Anti-aimbot angles"
    math_pi_reference_2 = {math_pi_reference_3(text6, text7, "Freestanding")}
    key = "ref_freestand"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "AA"
    text6 = "Anti-aimbot angles"
    text7 = "Roll"
    math_pi_reference_2 = math_pi_reference_2(math_pi_reference_3, text6, text7)
    key = "ref_roll"
    math_pi_reference[key] = math_pi_reference_2
    key = entries22
    key2 = "anti_aimbot_angles"
    math_tan = math_pi_reference
    key[key2] = math_tan
    math_pi_reference = {}
    key = "fakelag"
    entries22[key] = math_pi_reference
    math_pi_reference = {}
    math_pi_reference_2 = {}
    math_pi_reference_3 = abs.reference
    text6 = "AA"
    text7 = "Other"
    math_pi_reference_2 = {math_pi_reference_3(text6, text7, "Slow motion")}
    key = "ref_slowmotion"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = {}
    math_pi_reference_3 = abs.reference
    text6 = "AA"
    text7 = "Other"
    math_pi_reference_2 = {math_pi_reference_3(text6, text7, "On shot anti-aim")}
    key = "ref_onshotantiaim"
    math_pi_reference[key] = math_pi_reference_2
    key = "other"
    entries22[key] = math_pi_reference
    key = "anti_aim"
    text5[key] = entries22
    entries22 = {}
    math_pi_reference = {}
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "MISC"
    text6 = "Settings"
    text7 = "DPI scale"
    math_pi_reference_2 = math_pi_reference_2(math_pi_reference_3, text6, text7)
    key = "ref_dpiscale"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "MISC"
    text6 = "Settings"
    text7 = "Menu key"
    math_pi_reference_2 = math_pi_reference_2(math_pi_reference_3, text6, text7)
    key = "ref_menukey"
    math_pi_reference[key] = math_pi_reference_2
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "MISC"
    text6 = "Settings"
    text7 = "Faster grenade toss"
    math_pi_reference_2 = math_pi_reference_2(math_pi_reference_3, text6, text7)
    key = "ref_nadetoss"
    math_pi_reference[key] = math_pi_reference_2
    key = "settings"
    entries22[key] = math_pi_reference
    math_pi_reference = {}
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "MISC"
    text6 = "Movement"
    text7 = "Bunny hop"
    math_pi_reference_2 = math_pi_reference_2(math_pi_reference_3, text6, text7)
    key = "ref_bhop"
    math_pi_reference[key] = math_pi_reference_2
    key = "movement"
    entries22[key] = math_pi_reference
    key = "misc"
    text5[key] = entries22
    entries22 = {}
    math_pi_reference = abs.reference
    math_pi_reference_2 = "Players"
    math_pi_reference_3 = "Players"
    text6 = "Player list"
    math_pi_reference = math_pi_reference(math_pi_reference_2, math_pi_reference_3, text6)
    key = "players"
    entries22[key] = math_pi_reference
    math_pi_reference = abs.reference
    math_pi_reference_2 = "Players"
    math_pi_reference_3 = "Adjustments"
    text6 = "Force body yaw"
    math_pi_reference = math_pi_reference(math_pi_reference_2, math_pi_reference_3, text6)
    key = entries22
    key2 = "force_yaw"
    math_tan = math_pi_reference
    key[key2] = math_tan
    math_pi_reference = abs.reference
    math_pi_reference_2 = "Players"
    math_pi_reference_3 = "Adjustments"
    text6 = "Force body yaw value"
    math_pi_reference = math_pi_reference(math_pi_reference_2, math_pi_reference_3, text6)
    key = "force_yaw_value"
    entries22[key] = math_pi_reference
    math_pi_reference = abs.reference
    math_pi_reference_2 = "Players"
    math_pi_reference_3 = "Adjustments"
    text6 = "Force body yaw"
    math_pi_reference = math_pi_reference(math_pi_reference_2, math_pi_reference_3, text6)
    key = "force_body"
    entries22[key] = math_pi_reference
    math_pi_reference = abs.reference
    math_pi_reference_2 = "Players"
    math_pi_reference_3 = "Adjustments"
    text6 = "Force body yaw value"
    math_pi_reference = math_pi_reference(math_pi_reference_2, math_pi_reference_3, text6)
    key = "force_body_value"
    entries22[key] = math_pi_reference
    math_pi_reference = abs.reference
    math_pi_reference_2 = "Players"
    math_pi_reference_3 = "Players"
    text6 = "Reset all"
    math_pi_reference = math_pi_reference(math_pi_reference_2, math_pi_reference_3, text6)
    key = "reset"
    entries22[key] = math_pi_reference
    text5.plist = entries22
    entries22 = {}
    math_pi_reference = {}
    math_pi_reference_2 = abs.reference
    math_pi_reference_3 = "Visuals"
    text6 = "Effects"
    text7 = "Force third person (alive)"
    math_pi_reference = {math_pi_reference_2(math_pi_reference_3, text6, text7)}
    key = "thirdperson"
    entries22[key] = math_pi_reference
    math_pi_reference = abs.reference
    math_pi_reference_2 = "Visuals"
    math_pi_reference_3 = "Effects"
    text6 = "Disable post processing"
    math_pi_reference = math_pi_reference(math_pi_reference_2, math_pi_reference_3, text6)
    key = "post_processing"
    entries22[key] = math_pi_reference
    key = "visuals"
    text5[key] = entries22
    function entries22(entries48, value142)
        local enabled_3, index6
        local amount4 = 1
        local count_2 = (#entries48)
        local amount5 = 1
        for index6 = amount4, count_2, amount5 do
            if (entries48[index6] == value142) then
                enabled_3 = true
                while true do
                    return enabled_3
                end
            end
        end
    end
    function math_pi_reference(value142, value143, value144)
        return (value142 + ((value143 - value142) * value144))
    end
    function math_pi_reference_2(value142)
        while (180 < value142) do
            value142 = (value142 - 360)
        end
        while (value142 < (-180)) do
            value142 = (value142 + 360)
        end
        return value142
    end
    do
        local create_component_2
        do
            local string_upper_3, math_pi_reference_4
            string_upper_3 = byte
            math_pi_reference_4 = math_pi_reference_2
            create_component_2 = function(value142, value143)
                local position_2 = (value143 - value142)
                local reference = string_upper_3.atan((position_2.y / position_2.x))
                local reference_2 = math_pi_reference_4(((reference * 180) / string_upper_3.pi))
                reference = reference_2
                if (0 <= position_2.x) then
                    reference_2 = math_pi_reference_4((reference + 180))
                    reference = reference_2
                end
                return reference
            end
        end
        calculate_angle = create_component_2
    end
    do
        local globals_tickinterval
        globals_tickinterval = absoluteframetime
        math_pi_reference_3 = function(entity_index)
            local is_scoped = globals_tickinterval.get_prop(entity_index, "m_bIsScoped")
            if (is_scoped == 1) then
                return true
            end
            return false
        end
    end
    text6 = {}
    text7 = {}
    math_pi_set_callback = abs.set_callback
    helpers.handleValue6 = steal_aa_ignore
    do
        local math_pi, state_6
        math_pi = abs
        state_6 = text5
        entity_set_prop_screen_size = function()
            local entries48
            local value142 = nil
            local piValue2 = math_pi.get(steal_aa_ignore)
            if piValue2 then
                piValue2 = math_pi.get(state_6.plist.players)
                entries48 = text6
                entries48[piValue2] = true
            else
                piValue2 = math_pi.get(state_6.plist.players)
                if text6[piValue2] then
                    piValue2 = math_pi.get(state_6.plist.players)
                    entries48 = text6
                    entries48[piValue2] = value142
                end
            end
            return
        end
    end
    math_pi_set_callback(helpers.handleValue6, entity_set_prop_screen_size)
    math_pi_set_callback = abs.set_callback
    helpers.handleValue6 = text5.plist["players"]
    do
        local math_pi_2, state_7
        math_pi_2 = abs
        state_7 = text5
        entity_set_prop_screen_size = function()
            local value142 = nil
            local math_pi_set = math_pi_2.set
            local value143 = steal_aa_ignore
            local piValue2 = math_pi_2.get(state_7.plist.players)
            math_pi_set(value143, (text6[piValue2] ~= value142))
            return
        end
    end
    math_pi_set_callback(helpers.handleValue6, entity_set_prop_screen_size)
    math_pi_set_callback = abs.set_callback
    helpers.handleValue6 = text5.plist["reset"]
    do
        local math_pi_3
        math_pi_3 = abs
        entity_set_prop_screen_size = function()
            text6 = {}
            math_pi_3.set(steal_aa_ignore, false)
            return
        end
    end
    math_pi_set_callback(helpers.handleValue6, entity_set_prop_screen_size)
    math_pi_set_callback = abs.set_callback
    helpers.handleValue6 = steal_aa_toggle
    do
        local math_pi_4, state_8
        math_pi_4 = abs
        state_8 = text5
        entity_set_prop_screen_size = function()
            local entries48
            local value142 = nil
            local piValue2 = math_pi_4.get(steal_aa_toggle)
            if piValue2 then
                piValue2 = math_pi_4.get(state_8.plist.players)
                entries48 = text7
                entries48[piValue2] = true
            else
                piValue2 = math_pi_4.get(state_8.plist.players)
                if text7[piValue2] then
                    piValue2 = math_pi_4.get(state_8.plist.players)
                    entries48 = text7
                    entries48[piValue2] = value142
                end
            end
            return
        end
    end
    math_pi_set_callback(helpers.handleValue6, entity_set_prop_screen_size)
    math_pi_set_callback = abs.set_callback
    helpers.handleValue6 = text5.plist["players"]
    do
        local math_pi_5, state_9
        math_pi_5 = abs
        state_9 = text5
        entity_set_prop_screen_size = function()
            local value142 = nil
            local math_pi_set = math_pi_5.set
            local value143 = steal_aa_toggle
            local piValue2 = math_pi_5.get(state_9.plist.players)
            math_pi_set(value143, (text7[piValue2] ~= value142))
            return
        end
    end
    math_pi_set_callback(helpers.handleValue6, entity_set_prop_screen_size)
    math_pi_set_callback = abs.set_callback
    helpers.handleValue6 = text5.plist["reset"]
    do
        local math_pi_6
        math_pi_6 = abs
        entity_set_prop_screen_size = function()
            text7 = {}
            math_pi_6.set(steal_aa_toggle, false)
            return
        end
    end
    math_pi_set_callback(helpers.handleValue6, entity_set_prop_screen_size)
    do
        local math_pi_7, state_10
        math_pi_7 = abs
        state_10 = text5
        math_pi_set_callback = function()
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_aa_enabled, false)
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_pitch[1], "Off")
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_pitch[2], 0)
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_yaw[1], "Off")
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_yaw[2], 0)
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_yaw_base, "Local view")
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_body_yaw[1], "Off")
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_body_yaw[2], 0)
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_yaw_jitter[1], "Off")
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_yaw_jitter[2], 0)
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_freestand_body, false)
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_edge_yaw, false)
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_freestand[1], false)
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_freestand[2], "Always on")
            math_pi_7.set(state_10.anti_aim.anti_aimbot_angles.ref_roll, 0)
            return
        end
    end
    do
        local iterate_pairs_4, state_11, math_pi_8, iterate_array_3
        iterate_pairs_4 = iterate_pairs
        state_11 = text5
        math_pi_8 = abs
        iterate_array_3 = iterate_array
        helpers.handleValue6 = function(value142)
            local entries48, value_type, value143, value144, piValue2, index6, entry_2, value_type_2,
                  value145, value146, index7, entry_3
            local iterate_pairs_16 = iterate_pairs_4
            local value147 = state_11.anti_aim.anti_aimbot_angles
            iterate_pairs_16, value147, entries48 = iterate_pairs_16(value147)
            local iterate_pairs_17 = iterate_pairs_16
            local value148 = value147
            local value149 = entries48
            for index6, entry_2 in iterate_pairs_17, value148, value149 do
                value147 = index6
                entries48 = entry_2
                value_type = type(entries48)
                if (value_type ~= "table") then
                    math_pi_8.set_visible(entries48, (not value142))
                    if (not value142) then
                        value_type = math_pi_8.get(state_11.anti_aim.anti_aimbot_angles.ref_body_yaw[1])
                        if (value_type == "Off") then
                            math_pi_8.set_visible(state_11.anti_aim.anti_aimbot_angles.ref_freestand_body, false)
                        end
                    end
                else
                    value_type, value143, value144 = iterate_array_3(entries48)
                    value_type_2 = value_type
                    value145 = value143
                    value146 = value144
                    for index7, entry_3 in value_type_2, value145, value146 do
                        math_pi_8.set_visible(entry_3, (not value142))
                        if (not value142) then
                            piValue2 = math_pi_8.get(state_11.anti_aim.anti_aimbot_angles.ref_body_yaw[1])
                            if (piValue2 == "Opposite") then
                                math_pi_8.set_visible(state_11.anti_aim.anti_aimbot_angles.ref_body_yaw[2], false)
                            end
                        end
                        if (not value142) then
                            piValue2 = math_pi_8.get(entries48[1])
                            if ((piValue2 == "Off") and (value147 ~= "ref_pitch")) then
                                math_pi_8.set_visible(entries48[2], false)
                                piValue2 = math_pi_8.get(state_11.anti_aim.anti_aimbot_angles.ref_yaw[1])
                                if (piValue2 == "Off") then
                                    math_pi_8.set_visible(state_11.anti_aim.anti_aimbot_angles.ref_yaw_jitter[1], false)
                                end
                            end
                        end
                        if (not value142) then
                            piValue2 = math_pi_8.get(state_11.anti_aim.anti_aimbot_angles.ref_pitch[1])
                            if (piValue2 ~= "Custom") then
                                math_pi_8.set_visible(state_11.anti_aim.anti_aimbot_angles.ref_pitch[2], false)
                            end
                        end
                    end
                end
            end
            return
        end
    end
    entity_set_prop_screen_size = get_all.screen_size
    entity_set_prop_screen_size, screen_width = entity_set_prop_screen_size()
    entries23 = {}
    stored_configs = export.read("x_82hdnujdsgfu")
    if (not stored_configs) then
        stored_configs = ((entity_set_prop_screen_size - entity_set_prop_screen_size) + 10)
    end
    key = "x"
    entries23[key] = stored_configs
    stored_configs = export.read("y_ajshdahjdjhn")
    if (not stored_configs) then
        stored_configs = ((screen_width - screen_width) + 550)
    end
    key = "y"
    entries23[key] = stored_configs
    stored_configs = export.read("w_akjdfsahsdff")
    if (not stored_configs) then
        stored_configs = 100
    end
    key = "w"
    entries23[key] = stored_configs
    stored_configs = export.read("h_pi2jpoaojkfs")
    if (not stored_configs) then
        stored_configs = 100
    end
    key = "h"
    entries23[key] = stored_configs
    key = "dragging"
    enabled_2 = false
    entries23[key] = enabled_2
    do
        local math_pi_9
        math_pi_9 = abs
        stored_configs = function(value142, value143, value144, value145)
            local mouse_x
            local math_pi_mouse_position = math_pi_9.mouse_position
            math_pi_mouse_position, mouse_x = math_pi_mouse_position()
            local value146 = (value142 <= math_pi_mouse_position)
            if value146 then
                value146 = (math_pi_mouse_position <= (value142 + value144))
            end
            value146 = (value146 and (value143 <= mouse_x))
            if value146 then
                value146 = (mouse_x <= (value143 + value145))
            end
            return value146
        end
    end
    do
        local create_component_3
        do
            local math_pi_10, state_12, require_tohex_3, state_13, string_upper_4, entity_set_prop_2,
                  ui_update, position, stored_configs_2, globals_tickinterval_2, state_14, require_10,
                  iterate_pairs_5
            math_pi_10 = abs
            state_12 = entries18
            require_tohex_3 = arshift
            state_13 = entries7
            string_upper_4 = byte
            entity_set_prop_2 = get_all
            ui_update = get_2
            position = entries23
            stored_configs_2 = stored_configs
            globals_tickinterval_2 = absoluteframetime
            state_14 = entries5
            require_10 = require_4
            iterate_pairs_5 = iterate_pairs
            create_component_3 = function(value142, entity_index)
                local upper, upper_2, string_upper_floor, entries48, latency, entries49, x, table_insert,
                      x_2, state96, text13, require_tohex_sub_2, player_name, value143, value144,
                      value145, value146, piValue2, amount4, lower, position_2, table_insert_2, x_3,
                      value147, index6, entry_2
                local value148 = entity_index
                entity_index = value142
                value142 = nil
                local piValue3 = math_pi_10.get(state_12.visuals[2])
                if (not piValue3) then
                    return
                end
                piValue3 = ""
                upper = require_tohex_3.upper(state_13.build)
                upper_2 = require_tohex_3.upper(state_13.user)
                string_upper_floor = string_upper_4.floor
                entries48 = entity_set_prop_2.latency()
                string_upper_floor = string_upper_floor((entries48 * 1000))
                upper = ("WRAITH [" .. (upper .. ("]" .. (" | " .. (upper_2 .. (" | " .. (string_upper_floor .. "MS")))))))
                if (value148 == "small") then
                    piValue3 = "-"
                    upper_2 = require_tohex_3.upper(state_13.build)
                    string_upper_floor = require_tohex_3.upper(state_13.user)
                    entries48 = string_upper_4.floor
                    latency = entity_set_prop_2.latency()
                    entries48 = entries48((latency * 1000))
                    upper = ("WRAITH   [" .. (upper_2 .. ("]" .. ("   |   " .. (string_upper_floor .. ("   |   " .. (entries48 .. "MS")))))))
                else
                    if (value148 == "thin") then
                        piValue3 = ""
                        upper_2 = require_tohex_3.lower(upper)
                        upper = upper_2
                    else
                        if (value148 == "bold") then
                            piValue3 = "b"
                        else
                            if (value148 == "blind") then
                                piValue3 = "+"
                            end
                        end
                    end
                end
                upper_2 = entity_set_prop_2.screen_size
                upper_2, string_upper_floor = upper_2()
                entries48 = {}
                entries48 = {math_pi_10.mouse_position()}
                latency = entity_set_prop_2.key_state(1)
                entries49 = {}
                entries49 = {ui_update.measure_text(piValue3, upper)}
                x = math_pi_10.is_menu_open()
                if x then
                    if (position.dragging and (not latency)) then
                        position_2 = position
                        position_2.dragging = false
                    end
                    if (position.dragging and latency) then
                        x = (entries48[1] - position.drag_x)
                        position_2 = position
                        position_2.x = x
                        x = (entries48[2] - position.drag_y)
                        position_2 = position
                        position_2.y = x
                    end
                    x = stored_configs_2(position.x, position.y, (position.w + entries49[1]), (position.h + entries49[2]))
                    if (x and latency) then
                        position_2 = position
                        position_2.dragging = true
                        x = (entries48[1] - position.x)
                        position_2 = position
                        position_2.drag_x = x
                        x = (entries48[2] - position.y)
                        position_2 = position
                        position_2.drag_y = x
                    end
                end
                if (upper_2 < (position.x + entries49[1])) then
                    x = (position.x - 5)
                    position_2 = position
                    position_2.x = x
                else
                    if ((position.x + 20) < 0) then
                        x = (position.x + 5)
                        position_2 = position
                        position_2.x = x
                    end
                end
                if (string_upper_floor < (position.y + entries49[2])) then
                    x = (position.y - 10)
                    position_2 = position
                    position_2.y = x
                else
                    if ((position.y + entries49[2]) < 0) then
                        x = (position.y + 10)
                        position_2 = position
                        position_2.y = x
                    end
                end
                x = {}
                ui_update.gradient(position.x, ((position.y + entries49[2]) + 8), (entries49[1] / 1.5), 1, 0, 0, 0, 0, 220, 220, 220, 220, 255, true)
                ui_update.gradient((position.x + (entries49[1] / 1.5)), ((position.y + entries49[2]) + 8), (entries49[1] / 1.5), 1, 220, 220, 220, 255, 0, 0, 0, 0, true)
                ui_update.gradient(position.x, position.y, (entries49[1] / 1.5), (entries49[2] + 7), 12, 12, 12, 0, 12, 12, 12, 75, true)
                ui_update.gradient((position.x + (entries49[1] / 1.5)), position.y, (entries49[1] / 1.5), (entries49[2] + 7), 12, 12, 12, 75, 12, 12, 12, 0, true)
                ui_update.text((position.x + 18), (position.y + 5), 255, 255, 255, 220, piValue3, 0, upper)
                table_insert = globals_tickinterval_2.is_alive(entity_index)
                if (not table_insert) then
                    return
                end
                table_insert = table.insert
                x_2 = x
                state96 = {}
                text13 = require_tohex_3.upper(state_14.current_condition)
                text13 = ("- CONDITION: " .. text13)
                state96.text = text13
                state96.r = 240
                state96.g = 240
                state96.b = 240
                state96.a = 220
                table_insert(x_2, state96)
                table_insert = table.insert
                x_2 = x
                state96 = {}
                text13 = require_tohex_3.upper
                require_tohex_sub_2 = entity_set_prop_2.current_threat()
                require_tohex_sub_2 = (require_tohex_sub_2 == value142)
                if require_tohex_sub_2 then
                    require_tohex_sub_2 = "?"
                end
                if (not require_tohex_sub_2) then
                    require_tohex_sub_2 = require_tohex_3.sub
                    player_name = globals_tickinterval_2.get_player_name(entity_set_prop_2.current_threat())
                    require_tohex_sub_2 = require_tohex_sub_2(player_name, 0, 12)
                end
                text13 = text13(require_tohex_sub_2)
                text13 = ("- TARGET: " .. text13)
                state96.text = text13
                state96.r = 240
                state96.g = 240
                state96.b = 240
                state96.a = 220
                table_insert(x_2, state96)
                table_insert = table.insert
                x_2 = x
                state96 = {}
                text13 = require_10.get_double_tap()
                if (not text13) then
                    text13 = (state_14.tickbase_diff ~= 1)
                end
                if text13 then
                    text13 = "1"
                end
                if (not text13) then
                    text13 = "0"
                end
                text13 = ("- EXPLOIT CHARGE: " .. text13)
                state96.text = text13
                state96.r = 240
                state96.g = 240
                state96.b = 240
                state96.a = 220
                table_insert(x_2, state96)
                table_insert = table.insert
                x_2 = x
                state96 = {}
                text13 = require_tohex_3.upper(string_upper_4.abs(state_14.current_desync))
                text13 = ("- DESYNC: " .. (text13 .. "*"))
                state96.text = text13
                state96.r = 240
                state96.g = 240
                state96.b = 240
                state96.a = 220
                table_insert(x_2, state96)
                table_insert, x_2, state96 = iterate_pairs_5(x)
                table_insert_2 = table_insert
                x_3 = x_2
                value147 = state96
                for index6, entry_2 in table_insert_2, x_3, value147 do
                    x_2 = index6
                    state96 = entry_2
                    text13 = {}
                    text13 = {ui_update.measure_text(piValue3, state96.text)}
                    text_size2 = text13
                    text13 = ui_update.text
                    require_tohex_sub_2 = (position.x + 18)
                    player_name = ((10 + position.y) + (text_size2[2] * x_2))
                    value143 = state96.r
                    value144 = state96.g
                    value145 = state96.b
                    value146 = state96.a
                    piValue2 = piValue3
                    amount4 = 0
                    lower = (value148 == "thin")
                    if lower then
                        lower = require_tohex_3.lower(state96.text)
                    end
                    if (not lower) then
                        lower = state96.text
                    end
                    text13(require_tohex_sub_2, player_name, value143, value144, value145, value146, piValue2, amount4, lower)
                end
                return
            end
        end
        watermark = create_component_3
    end
    do
        local create_component_4
        do
            local ui_update_2
            ui_update_2 = get_2
            create_component_4 = function(x, y, width, height, entries48, value142)
                local index6, value143, value144, value145, value146, value147
                ui_update_2.rectangle(x, y, width, height, entries48[1], entries48[2], entries48[3], entries48[4])
                local value148 = (entries48[1] * value142)
                local value149 = (entries48[2] * value142)
                local value150 = (entries48[3] * value142)
                local amount4 = 1
                local value151 = value142
                local amount5 = 1
                for index6 = amount4, value151, amount5 do
                    value143 = (entries48[4] * (index6 / value142))
                    value144 = (width + (index6 * 2))
                    value145 = (height + (index6 * 2))
                    value146 = (x - index6)
                    value147 = (y - index6)
                    ui_update_2.rectangle(value146, value147, value144, value145, value148, value149, value150, value143)
                end
                return
            end
        end
        draw_glow = create_component_4
    end
    do
        local value_14, math_pi_11, state_15, math_pi_reference_5, state_16, math_pi_reference_6,
              renderer_world_to_screen, ui_update_3, value_15, value_16, string_upper_5
        value_14 = entries22
        math_pi_11 = abs
        state_15 = entries18
        math_pi_reference_5 = math_pi_reference_3
        state_16 = entries5
        math_pi_reference_6 = math_pi_reference
        renderer_world_to_screen = blur
        ui_update_3 = get_2
        value_15 = entries20
        value_16 = math_pi_new_combobox
        string_upper_5 = byte
        helpers.handle_value_7 = function(value142, value143, value144, value145, value146)
            local amount4, frame_time, abs_2, state96
            local desync_rect_dist = value_14
            local piValue2 = math_pi_11.get(state_15.visuals[6])
            desync_rect_dist = desync_rect_dist(piValue2, "desync")
            if (not desync_rect_dist) then
                return
            end
            desync_rect_dist = {}
            piValue2 = 255
            amount4 = 255
            frame_time = 255
            abs_2 = 255
            desync_rect_dist[1] = piValue2
            desync_rect_dist[2] = amount4
            desync_rect_dist[3] = frame_time
            desync_rect_dist[4] = abs_2
            dsy_rect = desync_rect_dist
            value146 = (value146 + 5)
            desync_rect_dist = math_pi_reference_5(value142)
            if desync_rect_dist then
                desync_rect_dist = value_14
                piValue2 = math_pi_11.get(state_15.visuals[6])
                desync_rect_dist = desync_rect_dist(piValue2, "animations on scope")
                if desync_rect_dist then
                    desync_rect_dist = math_pi_reference_6
                    piValue2 = state_16.desync_rect_dist
                    amount4 = 23
                    frame_time = renderer_world_to_screen.frametime()
                    desync_rect_dist = desync_rect_dist(piValue2, amount4, (frame_time * 15))
                    state96 = state_16
                    state96.desync_rect_dist = desync_rect_dist
                end
            else
                desync_rect_dist = value_14
                piValue2 = math_pi_11.get(state_15.visuals[6])
                desync_rect_dist = desync_rect_dist(piValue2, "animations on scope")
                if (not desync_rect_dist) then
                    desync_rect_dist = math_pi_11.get(state_15.visuals[0])
                    if (desync_rect_dist == "recode alpha") then
                        state96 = state_16
                        state96.desync_rect_dist = 23
                    end
                else
                    desync_rect_dist = math_pi_reference_6
                    piValue2 = state_16.desync_rect_dist
                    amount4 = 0
                    frame_time = renderer_world_to_screen.frametime()
                    desync_rect_dist = desync_rect_dist(piValue2, amount4, (frame_time * 10))
                    state96 = state_16
                    state96.desync_rect_dist = desync_rect_dist
                end
            end
            desync_rect_dist = ui_update_3.rectangle
            piValue2 = (value143 - 21)
            amount4 = value_15(state_16.desync_rect_dist)
            desync_rect_dist((piValue2 + amount4), (value144 + value146), 42, 4, 15, 15, 15, 255)
            desync_rect_dist = ui_update_3.rectangle
            piValue2 = (value143 - 20)
            amount4 = value_15(state_16.desync_rect_dist)
            piValue2 = (piValue2 + amount4)
            amount4 = (value144 + (value146 + 1))
            frame_time = value_16
            abs_2 = string_upper_5.abs(state_16.current_desync)
            frame_time = frame_time(((abs_2 / 58) * 40), 0, 40)
            desync_rect_dist(piValue2, amount4, frame_time, 2, dsy_rect[1], dsy_rect[2], dsy_rect[3], dsy_rect[4])
            return
        end
    end
    do
        local math_pi_12, entries_33, state_17, math_pi_reference_7, math_pi_reference_8,
              renderer_world_to_screen_2, value_17, iterate_pairs_6, ui_update_4, string_upper_6
        math_pi_12 = abs
        entries_33 = entries18
        state_17 = entries5
        math_pi_reference_7 = math_pi_reference_3
        math_pi_reference_8 = math_pi_reference
        renderer_world_to_screen_2 = blur
        value_17 = math_pi_new_combobox
        iterate_pairs_6 = iterate_pairs
        ui_update_4 = get_2
        string_upper_6 = byte
        helpers.handle_value_8 = function(value142, value143, value144)
            local left, x_pos, frame_time, state96, frame_time_2, ceil, ceil_2, state_97, x_pos_2,
                  value145, value146, index6, entry_2
            local reference = math_pi_12.get(entries_33.visuals[9])
            if reference then
                reference = math_pi_12.get(entries_33["anti-aim 2"][3])
                if reference then
                    goto branch_1
                end
            end
            do
                return
            end
            ::branch_1::
            reference = math_pi_reference_7(value142)
            if reference then
                reference = math_pi_reference_8
                left = state_17.smooth_left_arrow
                x_pos = 80
                frame_time = renderer_world_to_screen_2.frametime()
                reference = reference(left, x_pos, (frame_time * 15))
            end
            if (not reference) then
                reference = math_pi_reference_8
                left = state_17.smooth_left_arrow
                x_pos = 60
                frame_time = renderer_world_to_screen_2.frametime()
                reference = reference(left, x_pos, (frame_time * 15))
            end
            state_97 = state_17
            state_97.smooth_left_arrow = reference
            reference = math_pi_reference_7(value142)
            if reference then
                reference = math_pi_reference_8
                left = state_17.smooth_right_arrow
                x_pos = 80
                frame_time = renderer_world_to_screen_2.frametime()
                reference = reference(left, x_pos, (frame_time * 15))
            end
            if (not reference) then
                reference = math_pi_reference_8
                left = state_17.smooth_right_arrow
                x_pos = 60
                frame_time = renderer_world_to_screen_2.frametime()
                reference = reference(left, x_pos, (frame_time * 15))
            end
            state_97 = state_17
            state_97.smooth_right_arrow = reference
            reference = math_pi_reference_7(value142)
            if reference then
                reference = math_pi_reference_8
                left = state_17.smooth_up_arrow
                x_pos = 80
                frame_time = renderer_world_to_screen_2.frametime()
                reference = reference(left, x_pos, (frame_time * 15))
            end
            if (not reference) then
                reference = math_pi_reference_8
                left = state_17.smooth_up_arrow
                x_pos = 60
                frame_time = renderer_world_to_screen_2.frametime()
                reference = reference(left, x_pos, (frame_time * 15))
            end
            state_97 = state_17
            state_97.smooth_up_arrow = reference
            reference = {}
            left = {}
            left.indicator = "\238\130\158"
            x_pos = (-state_17.smooth_left_arrow)
            left.x_pos = x_pos
            left.y_pos = (-5)
            reference.left = left
            left = {}
            left.indicator = "\238\130\159"
            x_pos = state_17.smooth_left_arrow
            left.x_pos = x_pos
            left.y_pos = (-5)
            reference.right = left
            left = {}
            left.indicator = "\238\130\160"
            left.x_pos = 0
            x_pos = (-state_17.smooth_up_arrow)
            left.y_pos = x_pos
            reference.forward = left
            left = {}
            left = {math_pi_12.get(entries_33.visuals[10])}
            x_pos = math_pi_reference_7(value142)
            if x_pos then
                x_pos = math_pi_reference_8
                frame_time = state_17.smooth_arrow_alpha
                state96 = value_17((left[4] - 100), 0, 235)
                frame_time_2 = renderer_world_to_screen_2.frametime()
                x_pos = x_pos(frame_time, state96, (frame_time_2 * 15))
            end
            if (not x_pos) then
                x_pos = math_pi_reference_8
                frame_time = state_17.smooth_arrow_alpha
                state96 = left[4]
                frame_time_2 = renderer_world_to_screen_2.frametime()
                x_pos = x_pos(frame_time, state96, (frame_time_2 * 15))
            end
            state_97 = state_17
            state_97.smooth_arrow_alpha = x_pos
            x_pos, frame_time, state96 = iterate_pairs_6(reference)
            x_pos_2 = x_pos
            value145 = frame_time
            value146 = state96
            for index6, entry_2 in x_pos_2, value145, value146 do
                frame_time = index6
                state96 = entry_2
                if (frame_time == state_17.mode) then
                    frame_time_2 = ui_update_4.text
                    ceil = string_upper_6.ceil(state96.x_pos)
                    ceil = (value143 + ceil)
                    ceil_2 = string_upper_6.ceil(state96.y_pos)
                    frame_time_2(ceil, (value144 + ceil_2), left[1], left[2], left[3], state_17.smooth_arrow_alpha, "c+", 0, state96.indicator)
                end
            end
            return
        end
    end
    do
        local value_18, math_pi_13, state_18, state_19, ui_update_5, string_upper_7, math_pi_reference_9,
              renderer_world_to_screen_3, value_19
        value_18 = entries22
        math_pi_13 = abs
        state_18 = entries18
        state_19 = entries5
        ui_update_5 = get_2
        string_upper_7 = byte
        math_pi_reference_9 = math_pi_reference
        renderer_world_to_screen_3 = blur
        value_19 = math_pi_new_combobox
        helpers.handle_value_9 = function(value142, value143, value144)
            local piValue2, smooth_defensive_bar, ui_update_rectangle, piValue3, frame_time, value145,
                  state96
            local value146 = value144
            value144 = value143
            value142 = nil
            local ui_update_measure_text = value_18
            local piValue4 = math_pi_13.get(state_18.visuals[6])
            ui_update_measure_text = ui_update_measure_text(piValue4, "defensive")
            if (not ui_update_measure_text) then
                return
            end
            if (state_19.tickbase_diff ~= value142) then
                if (state_19.tickbase_diff <= (-1)) then
                    piValue2 = state_19.tickbase_diff
                    if ((-14) <= piValue2) then
                        ui_update_measure_text = ui_update_5.measure_text
                        ui_update_measure_text, piValue4 = ui_update_measure_text("c", "- defensive -")
                        defensive_size_y = piValue4
                        defensive_size_x = ui_update_measure_text
                        defensive_size_x = (defensive_size_x + 15)
                        ui_update_5.rectangle((value144 - (defensive_size_x / 2)), (((value146 / 3) + defensive_size_y) - 3), defensive_size_x, 4, 15, 15, 15, 150)
                        ui_update_measure_text = state_19.tickbase_diff
                        piValue4 = string_upper_7.abs(((-ui_update_measure_text) - 15))
                        piValue2 = piValue4
                        if ((piValue4 == piValue2) and (1 < piValue4)) then
                            piValue2 = (piValue2 - 1)
                        end
                        smooth_defensive_bar = math_pi_reference_9
                        ui_update_rectangle = state_19.smooth_defensive_bar
                        piValue3 = piValue2
                        frame_time = renderer_world_to_screen_3.frametime()
                        smooth_defensive_bar = smooth_defensive_bar(ui_update_rectangle, piValue3, (frame_time * 50))
                        state96 = state_19
                        state96.smooth_defensive_bar = smooth_defensive_bar
                        smooth_defensive_bar = math_pi_reference_9(75, 200, ((state_19.smooth_defensive_bar - 1) / 12))
                        ui_update_5.text(value144, (value146 / 3), 255, 255, 255, smooth_defensive_bar, "c", 0, "- defensive -")
                        ui_update_rectangle = ui_update_5.rectangle
                        piValue3 = ((value144 + 1) - (defensive_size_x / 2))
                        frame_time = ((value146 / 3) + 10)
                        value145 = value_19(((state_19.smooth_defensive_bar / 12) * defensive_size_x), 0, defensive_size_x)
                        ui_update_rectangle(piValue3, frame_time, (value145 - 2), 2, 200, 200, 200, smooth_defensive_bar)
                    end
                end
            else
                state96 = state_19
                state96.smooth_defensive_bar = 0.5
            end
            return
        end
    end
    function helpers.handle_value_10(entries48, entries49)
        local entries50 = {}
        local value142 = (entries48[1] + entries49[1])
        local value143 = (entries48[2] + entries49[2])
        local value144 = (entries48[3] + entries49[3])
        entries50[1] = value142
        entries50[2] = value143
        entries50[3] = value144
        return entries50
    end
    do
        local renderer_world_to_screen_4, globals_tickinterval_3
        renderer_world_to_screen_4 = blur
        globals_tickinterval_3 = absoluteframetime
        helpers.handle_value_11 = function(entity_index, value142)
            local amount4, value143, amount5, index6, entries48, value144, value145, value146
            local tick_interval = renderer_world_to_screen_4.tickinterval()
            local cvar_sv_gravity = cvar.sv_gravity
            cvar_sv_gravity = cvar_sv_gravity.get_float(cvar_sv_gravity)
            cvar_sv_gravity = (cvar_sv_gravity * tick_interval)
            local cvar_sv_jump_impulse = cvar.sv_jump_impulse
            cvar_sv_jump_impulse = cvar_sv_jump_impulse.get_float(cvar_sv_jump_impulse)
            cvar_sv_jump_impulse = (cvar_sv_jump_impulse * tick_interval)
            local entries49 = {}
            entries49 = {globals_tickinterval_3.get_origin(entity_index)}
            local state96 = {}
            state96 = {globals_tickinterval_3.get_origin(entity_index)}
            local entries50 = {}
            entries50 = {globals_tickinterval_3.get_prop(entity_index, "m_vecVelocity")}
            local value147 = (0 < entries50[3])
            if value147 then
                value147 = (-cvar_sv_gravity)
            end
            if (not value147) then
                value147 = cvar_sv_jump_impulse
            end
            amount4 = 1
            value143 = value142
            amount5 = 1
            for index6 = amount4, value143, amount5 do
                entries48 = {}
                value144 = (entries49[1] + (entries50[1] * tick_interval))
                value145 = (entries49[2] + (entries50[2] * tick_interval))
                value146 = (entries49[3] + ((entries50[3] + value147) * tick_interval))
                entries48[1] = value144
                entries48[2] = value145
                entries48[3] = value146
                entries49 = entries48
            end
            return entries49
        end
    end
    do
        local value_20, globals_tickinterval_4, ui_update_6
        value_20 = helpers.handle_value_10
        globals_tickinterval_4 = absoluteframetime
        ui_update_6 = get_2
        helpers.handle_value_12 = function(value142, entity_index, value143, value144, entries48)
            local entries49, entries50, entries51, entries52, entries53, entries_54, key3, entries_55,
                  entries_56, entries_57, amount4, amount5, amount6, amount7, amount_8, amount_9,
                  amount_10, amount_11, amount_12, amount_13
            local amount_14 = entries48
            entries48 = value144
            value144 = value143
            value143 = entity_index
            entity_index = value142
            value142 = nil
            local entries_58 = value144
            if (not entries_58) then
                entries_58 = nil
            end
            value144 = entries_58
            if (not entries48) then
                entries_58 = {}
                entries49 = 255
                entries50 = 255
                entries51 = 255
                entries52 = 255
                entries_58[1] = entries49
                entries_58[2] = entries50
                entries_58[3] = entries51
                entries_58[4] = entries52
                entries48 = entries_58
            end
            if (not amount_14) then
                amount_14 = 255
            end
            if (not value144) then
                entries50 = value_20
                entries51 = {}
                entries51 = {globals_tickinterval_4.get_prop(entity_index, "m_vecMins")}
                entries50 = entries50(entries51, value143)
                entries_58 = entries50
                entries50 = value_20
                entries51 = {}
                entries51 = {globals_tickinterval_4.get_prop(entity_index, "m_vecMaxs")}
                entries50 = entries50(entries51, value143)
                entries49 = entries50
            else
                entries50 = value_20(value144.min, value143)
                entries_58 = entries50
                entries50 = value_20(value144.max, value143)
                entries49 = entries50
            end
            entries50 = {}
            entries51 = {}
            entries52 = entries_58[1]
            entries53 = entries_58[2]
            entries_54 = entries_58[3]
            entries51[1] = entries52
            entries51[2] = entries53
            entries51[3] = entries_54
            entries52 = {}
            entries53 = entries_58[1]
            entries_54 = entries49[2]
            key3 = entries_58[3]
            entries52[1] = entries53
            entries52[2] = entries_54
            entries52[3] = key3
            entries53 = {}
            entries_54 = entries49[1]
            key3 = entries49[2]
            entries_55 = entries_58[3]
            entries53[1] = entries_54
            entries53[2] = key3
            entries53[3] = entries_55
            entries_54 = {}
            key3 = entries49[1]
            entries_55 = entries_58[2]
            entries_56 = entries_58[3]
            entries_54[1] = key3
            entries_54[2] = entries_55
            entries_54[3] = entries_56
            key3 = {}
            entries_55 = entries_58[1]
            entries_56 = entries_58[2]
            entries_57 = entries49[3]
            key3[1] = entries_55
            key3[2] = entries_56
            key3[3] = entries_57
            entries_55 = {}
            entries_56 = entries_58[1]
            entries_57 = entries49[2]
            amount4 = entries49[3]
            entries_55[1] = entries_56
            entries_55[2] = entries_57
            entries_55[3] = amount4
            entries_56 = {}
            entries_57 = entries49[1]
            amount4 = entries49[2]
            amount5 = entries49[3]
            entries_56[1] = entries_57
            entries_56[2] = amount4
            entries_56[3] = amount5
            entries_57 = {}
            amount4 = entries49[1]
            amount5 = entries_58[2]
            amount6 = entries49[3]
            entries_57[1] = amount4
            entries_57[2] = amount5
            entries_57[3] = amount6
            entries50[1] = entries51
            entries50[2] = entries52
            entries50[3] = entries53
            entries50[4] = entries_54
            entries50[5] = key3
            entries50[6] = entries_55
            entries50[7] = entries_56
            entries50[8] = entries_57
            entries51 = {}
            entries52 = {}
            entries53 = 0
            entries_54 = 1
            entries52[1] = entries53
            entries52[2] = entries_54
            entries53 = {}
            entries_54 = 1
            key3 = 2
            entries53[1] = entries_54
            entries53[2] = key3
            entries_54 = {}
            key3 = 2
            entries_55 = 3
            entries_54[1] = key3
            entries_54[2] = entries_55
            key3 = {}
            entries_55 = 3
            entries_56 = 0
            key3[1] = entries_55
            key3[2] = entries_56
            entries_55 = {}
            entries_56 = 5
            entries_57 = 6
            entries_55[1] = entries_56
            entries_55[2] = entries_57
            entries_56 = {}
            entries_57 = 6
            amount4 = 7
            entries_56[1] = entries_57
            entries_56[2] = amount4
            entries_57 = {}
            amount4 = 1
            amount5 = 4
            entries_57[1] = amount4
            entries_57[2] = amount5
            amount4 = {}
            amount5 = 4
            amount6 = 8
            amount4[1] = amount5
            amount4[2] = amount6
            amount5 = {}
            amount6 = 0
            amount7 = 4
            amount5[1] = amount6
            amount5[2] = amount7
            amount6 = {}
            amount7 = 1
            amount_8 = 5
            amount6[1] = amount7
            amount6[2] = amount_8
            amount7 = {}
            amount_8 = 2
            amount_9 = 6
            amount7[1] = amount_8
            amount7[2] = amount_9
            amount_8 = {}
            amount_9 = 3
            amount_10 = 7
            amount_8[1] = amount_9
            amount_8[2] = amount_10
            amount_9 = {}
            amount_10 = 5
            amount_11 = 8
            amount_9[1] = amount_10
            amount_9[2] = amount_11
            amount_10 = {}
            amount_11 = 7
            amount_12 = 8
            amount_10[1] = amount_11
            amount_10[2] = amount_12
            amount_11 = {}
            amount_12 = 3
            amount_13 = 4
            amount_11[1] = amount_12
            amount_11[2] = amount_13
            entries51[1] = entries52
            entries51[2] = entries53
            entries51[3] = entries_54
            entries51[4] = key3
            entries51[5] = entries_55
            entries51[6] = entries_56
            entries51[7] = entries_57
            entries51[8] = amount4
            entries51[9] = amount5
            entries51[10] = amount6
            entries51[11] = amount7
            entries51[12] = amount_8
            entries51[13] = amount_9
            entries51[14] = amount_10
            entries51[15] = amount_11
            entries52 = 1
            entries53 = (#entries51)
            entries_54 = 1
            for key3 = entries52, entries53, entries_54 do
                if (entries50[entries51[key3][1]] ~= value142) then
                    if (entries50[entries51[key3][2]] ~= value142) then
                        entries_55 = {}
                        entries_55 = {
                            ui_update_6.world_to_screen(entries50[entries51[key3][1]][1], entries50[entries51[key3][1]][2], entries50[entries51[key3][1]][3])
                        }
                        entries_56 = {}
                        entries_56 = {
                            ui_update_6.world_to_screen(entries50[entries51[key3][2]][1], entries50[entries51[key3][2]][2], entries50[entries51[key3][2]][3])
                        }
                        ui_update_6.line(entries_55[1], entries_55[2], entries_56[1], entries_56[2], entries48[1], entries48[2], entries48[3], amount_14)
                    end
                end
            end
            return
        end
    end
    do
        local string_upper_8, ui_update_7
        string_upper_8 = byte
        ui_update_7 = get_2
        helpers.handle_value_13 = function(value142, value143, value144, value145, value146, red, green, blue, alpha)
            local ui_update_world_to_screen, screen_x, amount4, amount5, value147, index6, radians,
                  cosine, sine, value148, ui_update_world_to_screen_2, screen_x_2
            local value149 = alpha
            alpha = blue
            blue = green
            green = red
            red = value146
            value146 = value145
            value145 = value144
            value144 = value143
            value143 = value142
            value142 = nil
            local amount6 = value149
            if (not amount6) then
                amount6 = 3
            end
            ui_update_world_to_screen = nil
            screen_x = nil
            amount4 = 0
            amount5 = 360
            value147 = amount6
            for index6 = amount4, amount5, value147 do
                radians = string_upper_8.rad(index6)
                cosine = string_upper_8.cos(radians)
                cosine = ((value146 * cosine) + value143)
                sine = string_upper_8.sin(radians)
                sine = ((value146 * sine) + value144)
                value148 = value145
                ui_update_world_to_screen_2 = ui_update_7.world_to_screen
                ui_update_world_to_screen_2, screen_x_2 = ui_update_world_to_screen_2(cosine, sine, value148)
                if ((ui_update_world_to_screen_2 ~= value142) and (ui_update_world_to_screen ~= value142)) then
                    ui_update_7.line(ui_update_world_to_screen_2, screen_x_2, ui_update_world_to_screen, screen_x, red, green, blue, alpha)
                end
                screen_x = screen_x_2
                ui_update_world_to_screen = ui_update_world_to_screen_2
            end
            return
        end
    end
    do
        local string_upper_9, ui_update_8
        string_upper_9 = byte
        ui_update_8 = get_2
        helpers.handle_value_14 = function(value142, value143, value144, value145, value146, value147, value148, value149, value150)
            local entries48, amount4, amount5, amount6, index6, entries49, entries50, entries51,
                  ui_update_world_to_screen, table_insert, ui_update_world_to_screen_2, entries52,
                  ui_update_world_to_screen_3, screen_x, value151, value152
            local amount7 = value150
            if (not amount7) then
                amount7 = 3
            end
            entries48 = {}
            amount4 = 0
            amount5 = 360
            amount6 = amount7
            for index6 = amount4, amount5, amount6 do
                entries49 = string_upper_9.rad(index6)
                entries50 = string_upper_9.cos(entries49)
                entries50 = ((value145 * entries50) + value142)
                entries51 = string_upper_9.sin(entries49)
                entries51 = ((value145 * entries51) + value143)
                ui_update_world_to_screen = value144
                table_insert = table.insert
                ui_update_world_to_screen_2 = entries48
                entries52 = {}
                ui_update_world_to_screen_3 = entries50
                screen_x = entries51
                value151 = ui_update_world_to_screen
                entries52[1] = ui_update_world_to_screen_3
                entries52[2] = screen_x
                entries52[3] = value151
                table_insert(ui_update_world_to_screen_2, entries52)
            end
            amount4 = 1
            amount5 = ((#entries48) - 2)
            amount6 = 1
            for index6 = amount4, amount5, amount6 do
                entries49 = entries48[1]
                entries50 = entries48[(index6 + 1)]
                entries51 = entries48[(index6 + 2)]
                ui_update_world_to_screen = ui_update_8.world_to_screen
                table_insert = entries49[1]
                ui_update_world_to_screen_2 = entries49[2]
                entries52 = entries49[3]
                ui_update_world_to_screen, table_insert = ui_update_world_to_screen(table_insert, ui_update_world_to_screen_2, entries52)
                ui_update_world_to_screen_2 = ui_update_8.world_to_screen
                entries52 = entries50[1]
                ui_update_world_to_screen_3 = entries50[2]
                screen_x = entries50[3]
                ui_update_world_to_screen_2, entries52 = ui_update_world_to_screen_2(entries52, ui_update_world_to_screen_3, screen_x)
                ui_update_world_to_screen_3 = ui_update_8.world_to_screen
                screen_x = entries51[1]
                value151 = entries51[2]
                value152 = entries51[3]
                ui_update_world_to_screen_3, screen_x = ui_update_world_to_screen_3(screen_x, value151, value152)
                if ((ui_update_world_to_screen and ui_update_world_to_screen_2) and ui_update_world_to_screen_3) then
                    ui_update_8.triangle(ui_update_world_to_screen, table_insert, ui_update_world_to_screen_2, entries52, ui_update_world_to_screen_3, screen_x, value146, value147, value148, value149)
                end
            end
            return
        end
    end
    do
        local value_21
        value_21 = helpers.handle_value_13
        helpers.handle_value_15 = function(value142, value143, value144, value145, value146, value147, value148, value149, value150, value151)
            local amount4, value152, value153, amount5, value154, amount6, index6
            local amount7 = value150
            if (not amount7) then
                amount7 = 3
            end
            amount4 = value151
            if (not amount4) then
                amount4 = 5
            end
            value152 = (value149 / amount4)
            value153 = value149
            amount5 = 1
            value154 = amount4
            amount6 = 1
            for index6 = amount5, value154, amount6 do
                value_21(value142, value143, value144, (value145 + index6), value146, value147, value148, value153, amount7)
                value153 = (value153 - value152)
            end
            return
        end
    end
    do
        local math_pi_14, state_20, state_21, state_22, value_22, value_23, value_24, value_25
        math_pi_14 = abs
        state_20 = text5
        state_21 = entries18
        state_22 = entries5
        value_22 = helpers.handle_value_11
        value_23 = helpers.handle_value_15
        value_24 = helpers.handle_value_14
        value_25 = helpers.handle_value_12
        helpers.handle_value_16 = function(value142)
            local value143 = value142
            value142 = nil
            local piValue2 = math_pi_14.get(state_20.anti_aim.other.ref_onshotantiaim[1])
            if piValue2 then
                piValue2 = math_pi_14.get(state_20.anti_aim.other.ref_onshotantiaim[2])
                if piValue2 then
                    goto branch_1
                end
            end
            piValue2 = math_pi_14.get(state_21.misc[6])
            if (not piValue2) then
                piValue2 = math_pi_14.get(state_21.misc[7])
                if (not piValue2) then
                    goto branch_1
                end
                if (not state_22.hittable) then
                    goto branch_1
                end
            end
            if (state_22.tickbase_diff ~= value142) then
                if (not (0 < state_22.tickbase_diff)) then
                    goto branch_2
                end
            end
            ::branch_1::
            do
                return
            end
            ::branch_2::
            piValue2 = math_pi_14.get(state_20.rage.ref_doubletap[1])
            if (not piValue2) then
                piValue2 = math_pi_14.get(state_20.rage.ref_doubletap[2])
                if (not piValue2) then
                    return
                end
            end
            piValue2 = value_22(value143, 14)
            predicted_pos = piValue2
            piValue2 = math_pi_14.get(state_21.visuals[8])
            if (piValue2 == "circle") then
                value_23(predicted_pos[1], predicted_pos[2], predicted_pos[3], 6, 255, 255, 255, 255, 3, 10)
                value_24(predicted_pos[1], predicted_pos[2], predicted_pos[3], 7, 255, 255, 255, 150, 3)
            else
                piValue2 = math_pi_14.get(state_21.visuals[8])
                if (piValue2 == "box") then
                    value_25(value143, predicted_pos, nil, nil, nil)
                end
            end
            return
        end
    end
    entries24 = {}
    entries25 = {}
    helpers.handle_value_17 = 0
    amount = 1
    amount2 = 6
    amount3 = 5
    pi_value = 4
    helpers.handle_value_18 = 3
    helpers.handle_value_19 = 2
    entries25[1] = helpers.handle_value_17
    entries25[2] = amount
    entries25[3] = amount2
    entries25[4] = amount3
    entries25[5] = pi_value
    entries25[6] = helpers.handle_value_18
    entries25[7] = helpers.handle_value_19
    key = "main"
    entries24[key] = entries25
    entries25 = {}
    helpers.handle_value_17 = 14
    amount = 18
    amount2 = 17
    amount3 = 1
    entries25[1] = helpers.handle_value_17
    entries25[2] = amount
    entries25[3] = amount2
    entries25[4] = amount3
    key = "left_arm"
    entries24[key] = entries25
    entries25 = {}
    helpers.handle_value_17 = 13
    amount = 16
    amount2 = 15
    amount3 = 1
    entries25[1] = helpers.handle_value_17
    entries25[2] = amount
    entries25[3] = amount2
    entries25[4] = amount3
    key = "right_arm"
    entries24[key] = entries25
    entries25 = {}
    helpers.handle_value_17 = 12
    amount = 10
    amount2 = 8
    amount3 = 2
    entries25[1] = helpers.handle_value_17
    entries25[2] = amount
    entries25[3] = amount2
    entries25[4] = amount3
    key = "left_leg"
    entries24[key] = entries25
    entries25 = {}
    helpers.handle_value_17 = 11
    amount = 9
    amount2 = 7
    amount3 = 2
    entries25[1] = helpers.handle_value_17
    entries25[2] = amount
    entries25[3] = amount2
    entries25[4] = amount3
    key = "right_leg"
    entries24[key] = entries25
    do
        local renderer_world_to_screen_5, globals_tickinterval_5, entity_set_prop_3
        renderer_world_to_screen_5 = blur
        globals_tickinterval_5 = absoluteframetime
        entity_set_prop_3 = get_all
        entries25 = function(entity_index, value142, value143)
            local entries48, amount4, value144, amount5, index6, entries49, value145, value146,
                  value147
            local tick_interval = renderer_world_to_screen_5.tickinterval()
            local cvar_sv_gravity = cvar.sv_gravity
            cvar_sv_gravity = cvar_sv_gravity.get_float(cvar_sv_gravity)
            cvar_sv_gravity = (cvar_sv_gravity * tick_interval)
            local cvar_sv_jump_impulse = cvar.sv_jump_impulse
            cvar_sv_jump_impulse = cvar_sv_jump_impulse.get_float(cvar_sv_jump_impulse)
            cvar_sv_jump_impulse = (cvar_sv_jump_impulse * tick_interval)
            local entries50 = value142
            local entries51 = {}
            entries51 = {globals_tickinterval_5.get_prop(entity_index, "m_vecVelocity")}
            local value148 = (0 < entries51[3])
            if value148 then
                value148 = (-cvar_sv_gravity)
            end
            if (not value148) then
                value148 = cvar_sv_jump_impulse
            end
            amount4 = 1
            value144 = value143
            amount5 = 1
            for index6 = amount4, value144, amount5 do
                entries48 = entries50
                entries49 = {}
                value145 = (entries50[1] + (entries51[1] * tick_interval))
                value146 = (entries50[2] + (entries51[2] * tick_interval))
                value147 = (entries50[3] + ((entries51[3] + value148) * tick_interval))
                entries49[1] = value145
                entries49[2] = value146
                entries49[3] = value147
                entries50 = entries49
                entries49 = entity_set_prop_3.trace_line((-1), entries48[1], entries48[2], entries48[3], entries50[1], entries50[2], entries50[3])
            end
            return entries50
        end
    end
    do
        local iterate_pairs_7, value_26, globals_tickinterval_6, ui_update_9
        iterate_pairs_7 = iterate_pairs
        value_26 = entries24
        globals_tickinterval_6 = absoluteframetime
        ui_update_9 = get_2
        helpers.handle_value_17 = function(value142)
            local value143, value144, entries48, value145, key3, value146, entries49, amount4,
                  amount5, amount6, index6, screen_x, entries50, position_2, x,
                  ui_update_world_to_screen, screen_x_2, index7, entry_2, value147, value148, value149,
                  index8, entry_3
            value143, value144, entries48 = iterate_pairs_7(value_26)
            local value150 = value143
            local value151 = value144
            local value152 = entries48
            for index7, entry_2 in value150, value151, value152 do
                entries48 = entry_2
                value145, key3, value146 = iterate_pairs_7(entries48)
                value147 = value145
                value148 = key3
                value149 = value146
                for index8, entry_3 in value147, value148, value149 do
                    key3 = index8
                    if (key3 ~= (#entries48)) then
                        entries49 = {}
                        amount4 = 0
                        amount5 = 18
                        amount6 = 1
                        for index6 = amount4, amount5, amount6 do
                            screen_x = {}
                            screen_x = {globals_tickinterval_6.hitbox_position(value142, index6)}
                            entries50 = screen_x
                            position_2 = {}
                            x = entries50[1]
                            position_2.x = x
                            x = entries50[2]
                            position_2.y = x
                            x = entries50[3]
                            position_2.z = x
                            entries49[index6] = position_2
                        end
                        amount4 = entries49[entries48[key3]].x
                        amount5 = entries49[entries48[key3]].y
                        amount6 = entries49[entries48[key3]].z
                        index6 = ui_update_9.world_to_screen
                        index6, screen_x = index6(amount4, amount5, amount6)
                        entries50 = entries49[entries48[(key3 + 1)]].x
                        position_2 = entries49[entries48[(key3 + 1)]].y
                        x = entries49[entries48[(key3 + 1)]].z
                        ui_update_world_to_screen = ui_update_9.world_to_screen
                        ui_update_world_to_screen, screen_x_2 = ui_update_world_to_screen(entries50, position_2, x)
                        ui_update_9.line(index6, screen_x, ui_update_world_to_screen, screen_x_2, 255, 255, 255, 255)
                    end
                end
            end
            return
        end
    end
    amount = 200
    amount2 = 2000
    amount3 = {}
    pi_value = nil
    do
        local ui_update_10
        ui_update_10 = get_2
        helpers.handle_value_18 = function(vector, value142, entries48)
            local ui_update_world_to_screen = ui_update_10.world_to_screen
            local screen_x = vector.x
            local value143 = vector.y
            local value144 = vector.z
            ui_update_world_to_screen, screen_x = ui_update_world_to_screen(screen_x, value143, value144)
            if (ui_update_world_to_screen and screen_x) then
                ui_update_10.text(ui_update_world_to_screen, screen_x, entries48[1], entries48[2], entries48[3], entries48[4], "+c", 0, value142)
            end
            return
        end
    end
    do
        local renderer_world_to_screen_6, string_upper_10
        renderer_world_to_screen_6 = blur
        string_upper_10 = byte
        helpers.handle_value_19 = function(value142)
            local value143, string_upper_min, string_upper_min_2, max
            local current_time = renderer_world_to_screen_6.curtime()
            local value144 = ((current_time - value142) * 1000)
            local value145 = (amount2 / 2)
            if (value144 <= value145) then
                value143 = (0 + (255 * ((value144 / value145) ^ 1.5)))
                string_upper_min = string_upper_10.min
                string_upper_min_2 = string_upper_10.max(value143, 0)
                return string_upper_min(string_upper_min_2, 255)
            end
            string_upper_min = (255 - (255 * ((value144 - value145) / value145)))
            string_upper_min_2 = string_upper_10.min
            max = string_upper_10.max(string_upper_min, 0)
            return string_upper_min_2(max, 255)
        end
    end
    do
        local globals_tickinterval_7, math_pi_15, state_23, state_24, value_27, entries_34,
              renderer_world_to_screen_7, state_25, string_upper_11
        globals_tickinterval_7 = absoluteframetime
        math_pi_15 = abs
        state_23 = entries18
        state_24 = text5
        value_27 = entries22
        entries_34 = amount3
        renderer_world_to_screen_7 = blur
        state_25 = entries5
        string_upper_11 = byte
        helpers.handleValue20 = function(value142)
            local piValue2, origin, hitbox_positions, min, max, amount4, cur_time, entries48,
                  position_2, x, entries49, key3, piValue3
            local value143 = value142
            value142 = nil
            local piValue4 = globals_tickinterval_7.is_alive(value143)
            if piValue4 then
                piValue4 = globals_tickinterval_7.get_prop
                piValue2 = globals_tickinterval_7.get_game_rules()
                piValue4 = piValue4(piValue2, "m_bFreezePeriod")
                if (piValue4 ~= 1) then
                    goto branch_1
                end
            end
            do
                return
            end
            ::branch_1::
            piValue4 = math_pi_15.get(state_23.visuals.thirdpersonly)
            if piValue4 then
                piValue4 = math_pi_15.get(state_24.visuals.thirdperson[2])
                if (not piValue4) then
                    return
                end
            end
            piValue4 = math_pi_15.get(state_23.visuals[11])
            if piValue4 then
                piValue4 = value_27
                piValue2 = math_pi_15.get(state_23.visuals[12])
                piValue4 = piValue4(piValue2, "defensive")
                if (not piValue4) then
                    piValue4 = value_27
                    piValue2 = math_pi_15.get(state_23.visuals[12])
                    piValue4 = piValue4(piValue2, "break lc")
                    if (not piValue4) then
                        piValue4 = value_27
                        piValue2 = math_pi_15.get(state_23.visuals[12])
                        piValue4 = piValue4(piValue2, "vulnerable")
                        if (not piValue4) then
                            goto branch_2
                        end
                    end
                end
                piValue4 = value_27
                piValue2 = math_pi_15.get(state_23.visuals[13])
                piValue4 = piValue4(piValue2, "skeleton")
                if piValue4 then
                    goto branch_3
                end
                piValue4 = value_27
                piValue2 = math_pi_15.get(state_23.visuals[13])
                piValue4 = piValue4(piValue2, "box")
                if piValue4 then
                    goto branch_3
                end
                piValue4 = value_27
                piValue2 = math_pi_15.get(state_23.visuals[13])
                piValue4 = piValue4(piValue2, "text")
                if piValue4 then
                    goto branch_3
                end
            end
            ::branch_2::
            table.clear(entries_34)
            do
                return
            end
            ::branch_3::
            piValue4 = globals_tickinterval_7.get_prop(value143, "m_flSimulationTime")
            if (pi_value ~= piValue4) then
                piValue2 = renderer_world_to_screen_7.chokedcommands()
                piValue2 = (piValue2 < 13)
                if piValue2 then
                    piValue2 = (state_25.tickbase_diff ~= value142)
                end
                if piValue2 then
                    piValue2 = (state_25.tickbase_diff ~= 1)
                end
                if piValue2 then
                    piValue2 = (state_25.tickbase_diff < (-2))
                end
                origin = {}
                origin = {globals_tickinterval_7.get_origin(value143)}
                hitbox_positions = {}
                min = 0
                max = 18
                amount4 = 1
                for cur_time = min, max, amount4 do
                    entries48 = {}
                    entries48 = {globals_tickinterval_7.hitbox_position(value143, cur_time)}
                    if entries48 then
                        position_2 = {}
                        x = entries48[1]
                        position_2.x = x
                        x = entries48[2]
                        position_2.y = x
                        x = entries48[3]
                        position_2.z = x
                        hitbox_positions[cur_time] = position_2
                    end
                end
                min = {}
                min = {globals_tickinterval_7.get_prop(value143, "m_vecMins")}
                max = {}
                max = {globals_tickinterval_7.get_prop(value143, "m_vecMaxs")}
                amount4 = {}
                amount4.origin = origin
                entries49 = amount4
                key3 = "simulation_time"
                piValue3 = piValue4
                entries49[key3] = piValue3
                cur_time = renderer_world_to_screen_7.curtime()
                amount4.cur_time = cur_time
                amount4.hitbox_positions = hitbox_positions
                amount4.defensive = piValue2
                cur_time = state_25.breaking_lc
                amount4.breaking_lc = cur_time
                cur_time = state_25.is_defensive_forced
                amount4.is_defensive_forced = cur_time
                amount4.min = min
                amount4.max = max
                if (0 < (#entries_34)) then
                    cur_time = (#entries_34)
                    entries48 = entries_34[cur_time].origin
                    position_2 = string_upper_11.sqrt(((((origin[1] - entries48[1]) ^ 2) + ((origin[2] - entries48[2]) ^ 2)) + ((origin[3] - entries48[3]) ^ 2)))
                    if (position_2 < 0.5) then
                        return
                    end
                end
                table.insert(entries_34, amount4)
                if ((#entries_34) > amount) then
                    table.remove(entries_34, 1)
                end
                pi_value = piValue4
            end
            return
        end
    end
    do
        local renderer_world_to_screen_8, entries_35
        renderer_world_to_screen_8 = blur
        entries_35 = amount3
        update_state = function()
            local index6
            local current_time = renderer_world_to_screen_8.curtime()
            local count_2 = (#entries_35)
            local amount4 = 1
            local value142 = (-1)
            for index6 = count_2, amount4, value142 do
                if (((current_time - entries_35[index6].cur_time) * 1000) > amount2) then
                    table.remove(entries_35, index6)
                end
            end
            return
        end
    end
    do
        local value_28, iterate_pairs_8, value_29, ui_update_11
        value_28 = helpers.handle_value_19
        iterate_pairs_8 = iterate_pairs
        value_29 = entries24
        ui_update_11 = get_2
        helpers.handle_value_21 = function(value142, entries48, alpha)
            local value143, value144, entries49, value145, key3, value146, value147, value148,
                  value149, ui_update_world_to_screen, screen_x, value150, value151, value152,
                  ui_update_world_to_screen_2, screen_x_2, value153, value154, value155, index6,
                  entry_2, value156, value157, value158, index7, entry_3
            if (alpha == 175) then

            else
                value143 = value_28(value142.cur_time)
                alpha = value143
            end
            if value142 then
                if value142.hitbox_positions then
                    goto branch_1
                end
            end
            print("Error: Invalid record or hitbox positions missing.")
            do
                return
            end
            ::branch_1::
            value143, value144, entries49 = iterate_pairs_8(value_29)
            value153 = value143
            value154 = value144
            value155 = entries49
            for index6, entry_2 in value153, value154, value155 do
                entries49 = entry_2
                value145, key3, value146 = iterate_pairs_8(entries49)
                value156 = value145
                value157 = key3
                value158 = value146
                for index7, entry_3 in value156, value157, value158 do
                    key3 = index7
                    if (key3 ~= (#entries49)) then
                        if value142.hitbox_positions[entries49[key3]] then
                            if (not value142.hitbox_positions[entries49[(key3 + 1)]]) then

                            else
                                value147 = value142.hitbox_positions[entries49[key3]].x
                                value148 = value142.hitbox_positions[entries49[key3]].y
                                value149 = value142.hitbox_positions[entries49[key3]].z
                                ui_update_world_to_screen = ui_update_11.world_to_screen
                                ui_update_world_to_screen, screen_x = ui_update_world_to_screen(value147, value148, value149)
                                value150 = value142.hitbox_positions[entries49[(key3 + 1)]].x
                                value151 = value142.hitbox_positions[entries49[(key3 + 1)]].y
                                value152 = value142.hitbox_positions[entries49[(key3 + 1)]].z
                                ui_update_world_to_screen_2 = ui_update_11.world_to_screen
                                ui_update_world_to_screen_2, screen_x_2 = ui_update_world_to_screen_2(value150, value151, value152)
                                if (((ui_update_world_to_screen and screen_x) and ui_update_world_to_screen_2) and screen_x_2) then
                                    ui_update_11.line(ui_update_world_to_screen, screen_x, ui_update_world_to_screen_2, screen_x_2, entries48[1], entries48[2], entries48[3], alpha)
                                end
                                goto branch_2
                            end
                        end
                        ::branch_2::
                        while true do
                            do
                                break
                            end
                        end
                    end
                end
            end
            return
        end
    end
    do
        local require_tohex_4, renderer_world_to_screen_9, string_upper_12
        require_tohex_4 = arshift
        renderer_world_to_screen_9 = blur
        string_upper_12 = byte
        helpers.handle_value_22 = function(length, value142, value143)
            local frame_time, substring
            local length_2 = require_tohex_4.len(value142)
            if (length < length_2) then
                frame_time = renderer_world_to_screen_9.frametime()
                length = (length + ((1 * frame_time) * value143))
            else
                length = length_2
            end
            frame_time = string_upper_12.floor(length)
            substring = require_tohex_4.sub(value142, 1, frame_time)
            return length, substring
        end
    end
    text8 = ""
    do
        local globals_tickinterval_8, value_30, math_pi_16, state_26, value_31, value_32, state_27,
              require_tohex_5, value_33, ui_update_12, callback_2, math_pi_reference_10,
              renderer_world_to_screen_10, string_upper_13, state_28, require_11, callback_3, value_34,
              value_35
        globals_tickinterval_8 = absoluteframetime
        value_30 = helpers.handle_value_16
        math_pi_16 = abs
        state_26 = entries18
        value_31 = helpers.handle_value_9
        value_32 = helpers.handle_value_8
        state_27 = entries5
        require_tohex_5 = arshift
        value_33 = entries22
        ui_update_12 = get_2
        callback_2 = math_pi_reference_3
        math_pi_reference_10 = math_pi_reference
        renderer_world_to_screen_10 = blur
        string_upper_13 = byte
        state_28 = text5
        require_11 = require_4
        callback_3 = iterate_pairs
        value_34 = helpers.handle_value_7
        value_35 = helpers.handle_value_22
        helpers.handle_value_23 = function(value142, value143, entity_index, entries48, value144)
            local alive, math_pi_get, get_3, get_4, get_5, value145, value146, text13, piValue2,
                  table_insert, lower, a, text14, lower_2, piValue3, piValue4, lower_3, table_insert_2,
                  table_insert_3, text_width, frame_time, a_2, piValue5, require_tohex_format,
                  require_tohex_format_2, get_6, get_7, get_8, piValue6, piValue7, entries49, key3,
                  amount4, table_insert_4, value147, value148, index6, entry_2, table_insert_5,
                  value149, value150, index7, entry_3, table_insert_6, value151, value152, index8,
                  entry_4
            if value143 then
                alive = globals_tickinterval_8.is_alive(entity_index)
                if alive then
                    goto branch_1
                end
            end
            do
                return
            end
            ::branch_1::
            value_30(entity_index)
            alive = {}
            math_pi_get = math_pi_16.get
            get_3 = state_26.visuals[1]
            math_pi_get, get_3, get_4, get_5 = math_pi_get(get_3)
            value145 = (entries48[1] / 2)
            value146 = (entries48[2] / 2)
            text13 = ""
            value_31(entity_index, value145, value146)
            value_32(entity_index, value145, value146)
            if (value144 == "small") then
                text13 = "-"
            else
                if (value144 == "thin") then
                    text13 = ""
                else
                    if (value144 == "bold") then
                        text13 = "b"
                    else
                        if (value144 == "blind") then
                            text13 = "+"
                        end
                    end
                end
            end
            piValue2 = math_pi_16.get(state_26.visuals[0])
            if (piValue2 ~= "recode alpha") then
                entries49 = state_27
                entries49.smooth_wraith_recode = 0
                entries49 = state_27
                entries49.smooth_dt_2 = 0
                entries49 = state_27
                entries49.smooth_stance = 0
                entries49 = state_27
                entries49.dt_os_text_anim = 0
                entries49 = state_27
                entries49.current_cond_text_anim = 0
            end
            piValue2 = math_pi_16.get(value143)
            if (piValue2 == "minimal (og)") then
                piValue2 = "SP BAIM FS"
                table_insert = "SP"
                lower = " BAIM"
                a = " FS"
                text14 = "WRAITH"
                lower_2 = "DT"
                piValue3 = "OS"
                piValue4 = require_tohex_5.upper(state_27.current_condition)
                if (text13 == "-") then
                    table_insert = "SP"
                    lower = "  BAIM"
                    a = "  FS"
                    piValue2 = "SP  BAIM  FS"
                end
                lower_3 = value_33
                table_insert_2 = math_pi_16.get(state_26.visuals[6])
                lower_3 = lower_3(table_insert_2, "lowercase")
                if lower_3 then
                    lower_3 = require_tohex_5.lower(text14)
                    text14 = lower_3
                    lower_3 = require_tohex_5.lower(lower_2)
                    lower_2 = lower_3
                    lower_3 = require_tohex_5.lower(piValue3)
                    piValue3 = lower_3
                    lower_3 = require_tohex_5.lower(piValue2)
                    piValue2 = lower_3
                    lower_3 = require_tohex_5.lower(table_insert)
                    table_insert = lower_3
                    lower_3 = require_tohex_5.lower(lower)
                    lower = lower_3
                    lower_3 = require_tohex_5.lower(a)
                    a = lower_3
                    lower_3 = require_tohex_5.lower(piValue4)
                end
                lower_3 = {}
                lower_3 = {ui_update_12.measure_text(text13, text14)}
                table_insert_2 = callback_2(entity_index)
                if table_insert_2 then
                    table_insert_2 = math_pi_reference_10
                    table_insert_3 = state_27.smooth_wraith
                    text_width = (-2)
                    frame_time = renderer_world_to_screen_10.frametime()
                    table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                end
                if (not table_insert_2) then
                    table_insert_2 = math_pi_reference_10
                    table_insert_3 = state_27.smooth_wraith
                    text_width = ui_update_12.measure_text(text13, text14)
                    text_width = (text_width / 2)
                    frame_time = renderer_world_to_screen_10.frametime()
                    table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                end
                entries49 = state_27
                entries49.smooth_wraith = table_insert_2
                table_insert_2 = table.insert
                table_insert_3 = alive
                text_width = {}
                text_width.text = text14
                text_width.r = 210
                text_width.g = 210
                text_width.b = 210
                text_width.a = 255
                frame_time = string_upper_13.ceil(state_27.smooth_wraith)
                text_width.size = frame_time
                table_insert_2(table_insert_3, text_width)
                table_insert_2 = callback_2(entity_index)
                if table_insert_2 then
                    table_insert_2 = math_pi_reference_10
                    table_insert_3 = state_27.smooth_pc
                    text_width = (-2)
                    frame_time = renderer_world_to_screen_10.frametime()
                    table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                end
                if (not table_insert_2) then
                    table_insert_2 = math_pi_reference_10
                    table_insert_3 = state_27.smooth_pc
                    text_width = ui_update_12.measure_text
                    frame_time = text13
                    a_2 = string_upper_13.abs(state_27.current_desync)
                    text_width = text_width(frame_time, (a_2 .. "%"))
                    text_width = (text_width / 2)
                    frame_time = renderer_world_to_screen_10.frametime()
                    table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                end
                entries49 = state_27
                entries49.smooth_pc = table_insert_2
                table_insert_2 = table.insert
                table_insert_3 = alive
                text_width = {}
                frame_time = string_upper_13.abs(state_27.current_desync)
                frame_time = (frame_time .. "%")
                text_width.text = frame_time
                text_width.r = 210
                text_width.g = 210
                text_width.b = 210
                text_width.a = 255
                frame_time = string_upper_13.ceil(state_27.smooth_pc)
                text_width.size = frame_time
                table_insert_2(table_insert_3, text_width)
                table_insert_2 = callback_2(entity_index)
                if table_insert_2 then
                    table_insert_2 = math_pi_reference_10
                    table_insert_3 = state_27.smooth_dt
                    text_width = (-2)
                    frame_time = renderer_world_to_screen_10.frametime()
                    table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                end
                if (not table_insert_2) then
                    table_insert_2 = math_pi_reference_10
                    table_insert_3 = state_27.smooth_dt
                    text_width = ui_update_12.measure_text(text13, piValue3)
                    text_width = (text_width / 2)
                    frame_time = renderer_world_to_screen_10.frametime()
                    table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                end
                entries49 = state_27
                entries49.smooth_dt = table_insert_2
                table_insert_2 = math_pi_16.get(state_28.rage.ref_doubletap[1])
                if table_insert_2 then
                    table_insert_2 = math_pi_16.get(state_28.rage.ref_doubletap[2])
                    if table_insert_2 then
                        table_insert_2 = require_11.get_double_tap()
                        if (not table_insert_2) then
                            table_insert_2 = (state_27.tickbase_diff ~= 1)
                        end
                        table_insert_3 = table.insert
                        text_width = alive
                        frame_time = {}
                        frame_time.text = lower_2
                        frame_time.r = 210
                        frame_time.g = 210
                        frame_time.b = 210
                        a_2 = table_insert_2
                        if a_2 then
                            a_2 = 255
                        end
                        if (not a_2) then
                            a_2 = 100
                        end
                        frame_time.a = a_2
                        a_2 = string_upper_13.ceil(state_27.smooth_dt)
                        frame_time.size = a_2
                        table_insert_3(text_width, frame_time)
                        table_insert_3 = math_pi_reference_10
                        text_width = state_27.dt_vertical_dist
                        frame_time = 10
                        a_2 = renderer_world_to_screen_10.frametime()
                        table_insert_3 = table_insert_3(text_width, frame_time, (a_2 * 20))
                        entries49 = state_27
                        entries49.dt_vertical_dist = table_insert_3
                    end
                else
                    table_insert_2 = math_pi_reference_10
                    table_insert_3 = state_27.dt_vertical_dist
                    text_width = 0
                    frame_time = renderer_world_to_screen_10.frametime()
                    table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 20))
                    entries49 = state_27
                    entries49.dt_vertical_dist = table_insert_2
                end
                table_insert_2 = callback_2(entity_index)
                if table_insert_2 then
                    table_insert_2 = math_pi_reference_10
                    table_insert_3 = state_27.smooth_os
                    text_width = (-2)
                    frame_time = renderer_world_to_screen_10.frametime()
                    table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                end
                if (not table_insert_2) then
                    table_insert_2 = math_pi_reference_10
                    table_insert_3 = state_27.smooth_os
                    text_width = ui_update_12.measure_text(text13, piValue3)
                    text_width = (text_width / 2)
                    frame_time = renderer_world_to_screen_10.frametime()
                    table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                end
                entries49 = state_27
                entries49.smooth_os = table_insert_2
                table_insert_2 = math_pi_16.get(state_28.anti_aim.other.ref_onshotantiaim[1])
                if table_insert_2 then
                    table_insert_2 = math_pi_16.get(state_28.anti_aim.other.ref_onshotantiaim[2])
                    if table_insert_2 then
                        table_insert_2 = math_pi_16.get(state_28.rage.ref_doubletap[1])
                        if table_insert_2 then
                            table_insert_2 = math_pi_16.get(state_28.rage.ref_doubletap[2])
                        end
                        table_insert_3 = table.insert
                        text_width = alive
                        frame_time = {}
                        frame_time.text = piValue3
                        frame_time.r = 210
                        frame_time.g = 210
                        frame_time.b = 210
                        a_2 = (not table_insert_2)
                        if a_2 then
                            a_2 = 255
                        end
                        if (not a_2) then
                            a_2 = string_upper_13.max(state_27.pulse, 100)
                        end
                        frame_time.a = a_2
                        a_2 = string_upper_13.ceil(state_27.smooth_os)
                        frame_time.size = a_2
                        table_insert_3(text_width, frame_time)
                    end
                end
                table_insert_2 = callback_2(entity_index)
                if table_insert_2 then
                    table_insert_2 = math_pi_reference_10
                    table_insert_3 = state_27.smooth_bo
                    text_width = (-2)
                    frame_time = renderer_world_to_screen_10.frametime()
                    table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                end
                if (not table_insert_2) then
                    table_insert_2 = math_pi_reference_10
                    table_insert_3 = state_27.smooth_bo
                    text_width = ui_update_12.measure_text(text13, piValue2)
                    text_width = (text_width / 2)
                    frame_time = renderer_world_to_screen_10.frametime()
                    table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                end
                entries49 = state_27
                entries49.smooth_bo = table_insert_2
                table_insert_2 = table.insert
                table_insert_3 = alive
                text_width = {}
                frame_time = ("\a%s" .. (table_insert .. ("\a%s" .. (lower .. ("\a%s" .. a)))))
                a_2 = frame_time
                frame_time = frame_time.format
                piValue5 = require_tohex_5.format
                require_tohex_format = "%02X%02X%02X%02X"
                require_tohex_format_2 = math_pi_get
                get_6 = get_3
                get_7 = get_4
                get_8 = math_pi_16.get(state_28.rage.ref_safepoint)
                if get_8 then
                    get_8 = 210
                end
                if (not get_8) then
                    get_8 = 100
                end
                piValue5 = piValue5(require_tohex_format, require_tohex_format_2, get_6, get_7, get_8)
                require_tohex_format = require_tohex_5.format
                require_tohex_format_2 = "%02X%02X%02X%02X"
                get_6 = math_pi_get
                get_7 = get_3
                get_8 = get_4
                piValue6 = math_pi_16.get(state_28.rage.ref_baim[1])
                if piValue6 then
                    piValue6 = 210
                end
                if (not piValue6) then
                    piValue6 = 100
                end
                require_tohex_format = require_tohex_format(require_tohex_format_2, get_6, get_7, get_8, piValue6)
                require_tohex_format_2 = require_tohex_5.format
                get_6 = "%02X%02X%02X%02X"
                get_7 = math_pi_get
                get_8 = get_3
                piValue6 = get_4
                piValue7 = math_pi_16.get(state_28.anti_aim.anti_aimbot_angles.ref_freestand[1])
                if piValue7 then
                    piValue7 = math_pi_16.get(state_28.anti_aim.anti_aimbot_angles.ref_freestand[2])
                end
                if piValue7 then
                    piValue7 = 210
                end
                if (not piValue7) then
                    piValue7 = 100
                end
                frame_time = frame_time(a_2, piValue5, require_tohex_format, require_tohex_format_2(get_6, get_7, get_8, piValue6, piValue7))
                text_width.text = frame_time
                text_width.r = 210
                text_width.g = 210
                text_width.b = 210
                text_width.a = 255
                frame_time = string_upper_13.ceil(state_27.smooth_bo)
                text_width.size = frame_time
                table_insert_2(table_insert_3, text_width)
                table_insert_2, table_insert_3, text_width = callback_3(alive)
                table_insert_4 = table_insert_2
                value147 = table_insert_3
                value148 = text_width
                for index6, entry_2 in table_insert_4, value147, value148 do
                    table_insert_3 = index6
                    text_width = entry_2
                    frame_time = ui_update_12.text
                    a_2 = value_33
                    piValue5 = math_pi_16.get(state_26.visuals[6])
                    a_2 = a_2(piValue5, "animations on scope")
                    a_2 = (a_2 == true)
                    if a_2 then
                        a_2 = (-text_width.size)
                    end
                    if (not a_2) then
                        a_2 = ui_update_12.measure_text(text13, text_width.text)
                        a_2 = (-(a_2 / 2))
                    end
                    frame_time((value145 + a_2), ((10 + value146) + (lower_3[2] * table_insert_3)), text_width.r, text_width.g, text_width.b, text_width.a, text13, 0, text_width.text)
                end
                table_insert_2 = {}
                table_insert_2 = {ui_update_12.measure_text(text13, text14)}
                value_34(entity_index, value145, value146, table_insert_2[1], table_insert_2[2])
            else
                entries49 = state_27
                entries49.smooth_wraith = 0
                entries49 = state_27
                entries49.smooth_dt = 0
                entries49 = state_27
                entries49.smooth_os = 0
                entries49 = state_27
                entries49.smooth_pc = 0
                entries49 = state_27
                entries49.smooth_bo = 0
                piValue2 = math_pi_16.get(value143)
                if (piValue2 == "anti urine") then
                    piValue2 = table.insert
                    table_insert = alive
                    lower = {}
                    lower.text = "ANTI URINE"
                    lower.r = 255
                    lower.g = 165
                    lower.b = 0
                    a = state_27.pulse
                    lower.a = a
                    a = ui_update_12.measure_text("b", "ANTI URINE")
                    a = (a / 2)
                    lower.size = a
                    piValue2(table_insert, lower)
                    piValue2 = table.insert
                    table_insert = alive
                    lower = {}
                    lower.text = "MIN DAMAGE"
                    lower.r = 191
                    lower.g = 159
                    lower.b = 255
                    a = math_pi_16.get(state_28.rage.ref_min_damage_override[2])
                    if a then
                        a = 255
                    end
                    if (not a) then
                        a = 100
                    end
                    lower.a = a
                    a = ui_update_12.measure_text("b", "MIN DAMAGE")
                    a = (a / 2)
                    lower.size = a
                    piValue2(table_insert, lower)
                    piValue2 = table.insert
                    table_insert = alive
                    lower = {}
                    lower.text = "ON SHOT"
                    lower.r = 128
                    lower.g = 230
                    lower.b = 150
                    a = math_pi_16.get(state_28.anti_aim.other.ref_onshotantiaim[1])
                    if a then
                        a = math_pi_16.get(state_28.anti_aim.other.ref_onshotantiaim[2])
                    end
                    if a then
                        a = 255
                    end
                    if (not a) then
                        a = 100
                    end
                    lower.a = a
                    a = ui_update_12.measure_text("b", "ON SHOT")
                    a = (a / 2)
                    entries49 = lower
                    key3 = "size"
                    amount4 = a
                    entries49[key3] = amount4
                    piValue2(table_insert, lower)
                    piValue2 = math_pi_16.get(state_28.rage.ref_doubletap[1])
                    if piValue2 then
                        piValue2 = math_pi_16.get(state_28.rage.ref_doubletap[2])
                    end
                    table_insert = table.insert
                    lower = alive
                    a = {}
                    a.text = "DT"
                    text14 = piValue2
                    if text14 then
                        text14 = 210
                    end
                    if (not text14) then
                        text14 = 255
                    end
                    a.r = text14
                    text14 = piValue2
                    if text14 then
                        text14 = 210
                    end
                    if (not text14) then
                        text14 = 0
                    end
                    a.g = text14
                    text14 = piValue2
                    if text14 then
                        text14 = 210
                    end
                    if (not text14) then
                        text14 = 0
                    end
                    a.b = text14
                    text14 = piValue2
                    if text14 then
                        text14 = 255
                    end
                    if (not text14) then
                        text14 = 100
                    end
                    a.a = text14
                    text14 = ui_update_12.measure_text("b", "DT")
                    text14 = (text14 / 2)
                    a.size = text14
                    table_insert(lower, a)
                    table_insert, lower, a = callback_3(alive)
                    table_insert_5 = table_insert
                    value149 = lower
                    value150 = a
                    for index7, entry_3 in table_insert_5, value149, value150 do
                        lower = index7
                        a = entry_3
                        ui_update_12.text((value145 - a.size), ((45 + value146) + (12 * lower)), a.r, a.g, a.b, a.a, "b", 0, a.text)
                    end
                else
                    piValue2 = math_pi_16.get(value143)
                    if (piValue2 == "recode alpha") then
                        piValue2 = "WRAITH\a%s RECODE"
                        piValue2 = piValue2.format(piValue2, require_tohex_5.format("%02X%02X%02X%02X", math_pi_get, get_3, get_4, string_upper_13.max(get_5, 100)))
                        table_insert = "DT"
                        lower = "ON SHOT"
                        a = {}
                        a = {ui_update_12.measure_text(text13, piValue2)}
                        text14 = require_tohex_5.upper(state_27.current_condition)
                        if (state_27.mode == "left") then
                            text14 = "MANUAL LEFT"
                        else
                            if (state_27.mode == "right") then
                                text14 = "MANUAL RIGHT"
                            else
                                if (state_27.mode == "forward") then
                                    text14 = "MANUAL FORWARD"
                                end
                            end
                        end
                        lower_2 = value_33
                        piValue3 = math_pi_16.get(state_26.visuals[6])
                        lower_2 = lower_2(piValue3, "lowercase")
                        if lower_2 then
                            lower_2 = require_tohex_5.lower(piValue2)
                            piValue2 = lower_2
                            lower_2 = require_tohex_5.lower(table_insert)
                            table_insert = lower_2
                            lower_2 = require_tohex_5.lower(lower)
                            lower = lower_2
                            lower_2 = require_tohex_5.lower(text14)
                            text14 = lower_2
                        end
                        lower_2 = require_11.get_double_tap()
                        if (not lower_2) then
                            lower_2 = (state_27.tickbase_diff ~= 1)
                        end
                        piValue3 = math_pi_16.get(state_28.anti_aim.other.ref_onshotantiaim[1])
                        if piValue3 then
                            piValue3 = math_pi_16.get(state_28.anti_aim.other.ref_onshotantiaim[2])
                        end
                        piValue4 = math_pi_16.get(state_28.rage.ref_doubletap[1])
                        if piValue4 then
                            piValue4 = math_pi_16.get(state_28.rage.ref_doubletap[2])
                        end
                        lower_3 = ""
                        if piValue4 then
                            lower_3 = table_insert
                        else
                            if piValue3 then
                                lower_3 = lower
                            end
                        end
                        table_insert_2 = value_35
                        table_insert_3 = state_27.dt_os_text_anim
                        table_insert_2, table_insert_3 = table_insert_2(table_insert_3, lower_3, 50)
                        ayo = table_insert_3
                        entries49 = state_27
                        entries49.dt_os_text_anim = table_insert_2
                        table_insert_2 = value_35
                        table_insert_3 = state_27.current_cond_text_anim
                        table_insert_2, table_insert_3 = table_insert_2(table_insert_3, text14, 25)
                        ayo2 = table_insert_3
                        entries49 = state_27
                        entries49.current_cond_text_anim = table_insert_2
                        if (text8 ~= text14) then
                            if ((#text8) <= (#text14)) then
                                table_insert_2 = (#text8)
                                entries49 = state_27
                                entries49.current_cond_text_anim = table_insert_2
                            end
                            text8 = text14
                        end
                        table_insert_2 = {}
                        table_insert_2 = {ui_update_12.measure_text(text13, piValue2)}
                        wraith_recode_text_size = table_insert_2
                        table_insert_2 = callback_2(entity_index)
                        if table_insert_2 then
                            table_insert_2 = math_pi_reference_10
                            table_insert_3 = state_27.smooth_wraith_recode
                            text_width = (-2)
                            frame_time = renderer_world_to_screen_10.frametime()
                            table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                        end
                        if (not table_insert_2) then
                            table_insert_2 = math_pi_reference_10
                            table_insert_3 = state_27.smooth_wraith_recode
                            text_width = (wraith_recode_text_size[1] / 2)
                            frame_time = renderer_world_to_screen_10.frametime()
                            table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                        end
                        entries49 = state_27
                        entries49.smooth_wraith_recode = table_insert_2
                        table_insert_2 = table.insert
                        table_insert_3 = alive
                        text_width = {}
                        text_width.text = piValue2
                        text_width.r = 240
                        text_width.g = 240
                        entries49 = text_width
                        key3 = "b"
                        amount4 = 240
                        entries49[key3] = amount4
                        text_width.a = 255
                        frame_time = string_upper_13.floor(state_27.smooth_wraith_recode)
                        text_width.size = frame_time
                        frame_time = {}
                        frame_time = {ui_update_12.measure_text(text13, piValue2)}
                        text_width.txt_measure = frame_time
                        table_insert_2(table_insert_3, text_width)
                        table_insert_2 = callback_2(entity_index)
                        if table_insert_2 then
                            table_insert_2 = math_pi_reference_10
                            table_insert_3 = state_27.smooth_dt_2
                            text_width = (-2)
                            frame_time = renderer_world_to_screen_10.frametime()
                            table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                        end
                        if (not table_insert_2) then
                            table_insert_2 = math_pi_reference_10
                            table_insert_3 = state_27.smooth_dt_2
                            text_width = ui_update_12.measure_text(text13, lower_3)
                            text_width = (text_width / 2)
                            frame_time = renderer_world_to_screen_10.frametime()
                            table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                        end
                        entries49 = state_27
                        entries49.smooth_dt_2 = table_insert_2
                        if (piValue4 or piValue3) then
                            table_insert_2 = table.insert
                            table_insert_3 = alive
                            text_width = {}
                            frame_time = ayo
                            text_width.text = frame_time
                            frame_time = piValue4
                            if frame_time then
                                frame_time = lower_2
                                if frame_time then
                                    frame_time = 0
                                end
                                if (not frame_time) then
                                    frame_time = 255
                                end
                            end
                            if (not frame_time) then
                                frame_time = 135
                            end
                            text_width.r = frame_time
                            frame_time = piValue4
                            if frame_time then
                                frame_time = lower_2
                                if frame_time then
                                    frame_time = 255
                                end
                                if (not frame_time) then
                                    frame_time = 0
                                end
                            end
                            if (not frame_time) then
                                frame_time = 206
                            end
                            text_width.g = frame_time
                            frame_time = piValue4
                            if frame_time then
                                frame_time = 0
                            end
                            if (not frame_time) then
                                frame_time = 250
                            end
                            text_width.b = frame_time
                            text_width.a = 255
                            frame_time = string_upper_13.floor(state_27.smooth_dt_2)
                            text_width.size = frame_time
                            frame_time = {}
                            frame_time = {ui_update_12.measure_text(text13, ayo)}
                            text_width.txt_measure = frame_time
                            table_insert_2(table_insert_3, text_width)
                        else
                            entries49 = state_27
                            entries49.dt_os_text_anim = 0
                        end
                        ayo2 = ("'  " .. (ayo2 .. "  '"))
                        table_insert_2 = callback_2(entity_index)
                        if table_insert_2 then
                            table_insert_2 = math_pi_reference_10
                            table_insert_3 = state_27.smooth_stance
                            text_width = (-2)
                            frame_time = renderer_world_to_screen_10.frametime()
                            table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                        end
                        if (not table_insert_2) then
                            table_insert_2 = math_pi_reference_10
                            table_insert_3 = state_27.smooth_stance
                            text_width = ui_update_12.measure_text(text13, ayo2)
                            text_width = (text_width / 2)
                            frame_time = renderer_world_to_screen_10.frametime()
                            table_insert_2 = table_insert_2(table_insert_3, text_width, (frame_time * 15))
                        end
                        entries49 = state_27
                        entries49.smooth_stance = table_insert_2
                        table_insert_2 = table.insert
                        table_insert_3 = alive
                        text_width = {}
                        frame_time = ayo2
                        text_width.text = frame_time
                        text_width.r = 240
                        text_width.g = 240
                        text_width.b = 240
                        text_width.a = 255
                        frame_time = string_upper_13.floor(state_27.smooth_stance)
                        text_width.size = frame_time
                        frame_time = {}
                        frame_time = {ui_update_12.measure_text(text13, ayo2)}
                        text_width.txt_measure = frame_time
                        table_insert_2(table_insert_3, text_width)
                        table_insert_2, table_insert_3, text_width = callback_3(alive)
                        table_insert_6 = table_insert_2
                        value151 = table_insert_3
                        value152 = text_width
                        for index8, entry_4 in table_insert_6, value151, value152 do
                            table_insert_3 = index8
                            text_width = entry_4
                            frame_time = ui_update_12.text
                            a_2 = value_33
                            piValue5 = math_pi_16.get(state_26.visuals[6])
                            a_2 = a_2(piValue5, "animations on scope")
                            a_2 = (a_2 == true)
                            if a_2 then
                                a_2 = (-text_width.size)
                            end
                            if (not a_2) then
                                a_2 = 0
                            end
                            frame_time((value145 + a_2), ((10 + value146) + (a[2] * table_insert_3)), text_width.r, text_width.g, text_width.b, text_width.a, text13, 0, text_width.text)
                        end
                        table_insert_2 = {}
                        table_insert_2 = {ui_update_12.measure_text(text13, piValue2)}
                        value_34(entity_index, value145, value146, table_insert_2[1], table_insert_2[2])
                    end
                end
            end
            return
        end
    end
    do
        local create_component_5
        do
            local ui_update_13
            ui_update_13 = get_2
            create_component_5 = function(x, value142, width, value143, alpha, value144)
                local enabled_3 = value144
                if (not enabled_3) then
                    enabled_3 = false
                end
                if (not enabled_3) then
                    ui_update_13.rectangle(x, (value142 - (value143 + 3)), width, 1, 12, 12, 12, alpha)
                    ui_update_13.rectangle((x + 2), (value142 - (value143 + 2)), (width - 4), 5, 60, 60, 60, alpha)
                    ui_update_13.rectangle((x + 2), (value142 - (value143 + 1)), (width - 4), 3, 40, 40, 40, alpha)
                    ui_update_13.rectangle(x, (value142 - (value143 + 3)), 1, (value143 + 3), 12, 12, 12, alpha)
                    ui_update_13.rectangle((x + 1), (value142 - (value143 + 2)), 4, (value143 + 2), 60, 60, 60, alpha)
                    ui_update_13.rectangle((x + 2), (value142 - (value143 + 1)), 3, (value143 + 1), 40, 40, 40, alpha)
                    ui_update_13.rectangle((x + 5), (value142 - (value143 - 2)), 1, (value143 - 2), 60, 60, 60, alpha)
                    ui_update_13.rectangle(((x + width) - 1), (value142 - (value143 + 3)), 1, (value143 + 3), 12, 12, 12, alpha)
                    ui_update_13.rectangle(((x + width) - 3), (value142 - (value143 + 2)), 2, (value143 + 2), 60, 60, 60, alpha)
                    ui_update_13.rectangle(((x + width) - 5), (value142 - (value143 + 1)), 3, (value143 + 1), 40, 40, 40, alpha)
                    ui_update_13.rectangle(((x + width) - 6), (value142 - (value143 - 2)), 1, (value143 - 2), 60, 60, 60, alpha)
                else
                    ui_update_13.rectangle(((x - (value143 / 2)) - 4), (value142 - 47), (value143 + 9), (width + 9), 12, 12, 12, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 10), (value142 - 53), (value143 + 20), 1, 12, 12, 12, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 9), (value142 - 52), (value143 + 18), 1, 60, 60, 60, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 8), (value142 - 51), (value143 + 17), 3, 40, 40, 40, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 5), (value142 - 48), (value143 + 10), 1, 60, 60, 60, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 10), (value142 - 53), 1, (width + 19), 12, 12, 12, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 9), (value142 - 51), 1, (width + 18), 60, 60, 60, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 8), (value142 - 48), 3, (width + 10), 40, 40, 40, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 5), (value142 - 48), 1, (width + 9), 60, 60, 60, alpha)
                    ui_update_13.rectangle(((x + (value143 / 2)) + 10), (value142 - 53), 1, (width + 20), 12, 12, 12, alpha)
                    ui_update_13.rectangle(((x + (value143 / 2)) + 9), (value142 - 52), 1, (width + 18), 60, 60, 60, alpha)
                    ui_update_13.rectangle(((x + (value143 / 2)) + 6), (value142 - 48), 3, (width + 10), 40, 40, 40, alpha)
                    ui_update_13.rectangle(((x + (value143 / 2)) + 5), (value142 - 48), 1, (width + 10), 60, 60, 60, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 10), (((value142 - 48) + width) + 14), (value143 + 20), 1, 12, 12, 12, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 5), (((value142 - 51) + width) + 12), (value143 + 10), 1, 60, 60, 60, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 8), (((value142 - 52) + width) + 14), (value143 + 17), 3, 40, 40, 40, alpha)
                    ui_update_13.rectangle(((x - (value143 / 2)) - 8), (((value142 - 49) + width) + 14), (value143 + 17), 1, 60, 60, 60, alpha)
                end
                return
            end
        end
        gamesense_outer = create_component_5
    end
    require_tohex_sub = arshift.sub
    require_create_font = abs.get(text5["misc"]["settings"]["ref_dpiscale"])
    require_tohex_sub = require_tohex_sub(require_create_font, 1, (-2))
    require_tohex_sub = (10 + ((require_tohex_sub - 100) / 25))
    require_create_font = require_5["create_font"]
    text9 = "Lucida Console"
    entries26 = require_tohex_sub
    entries27 = 400
    helpers.handleValue24 = {}
    helpers.handle_value_25 = 128
    helpers.handleValue24[1] = helpers.handle_value_25
    require_create_font = require_create_font(text9, entries26, entries27, helpers.handleValue24)
    text9 = {}
    entries26 = "new"
    do
        local require_12, entity_set_prop_4
        require_12 = require_3
        entity_set_prop_4 = get_all
        entries27 = function(index6, value142, m_color, m_time)
            local state96 = {}
            local entries48 = state96
            local text13 = "m_text"
            local value143 = value142
            entries48[text13] = value143
            state96.m_color = m_color
            state96.m_time = m_time
            local lerped_pos = require_12(entity_set_prop_4.screen_size()).y
            state96.lerped_pos = lerped_pos
            setmetatable(state96, index6)
            index6.__index = index6
            return state96
        end
    end
    text9[entries26] = entries27
    entries26 = {}
    entries27 = "new"
    do
        local function handle_value_50(index6)
            local state96 = {}
            local m_notify_text = {}
            state96.m_notify_text = m_notify_text
            setmetatable(state96, index6)
            index6.__index = index6
            return state96
        end
        entries26[entries27] = handle_value_50
    end
    entries27 = "add"
    do
        local value_36, math_pi_17, state_29, value_37, entity_set_prop_5
        value_36 = entries22
        math_pi_17 = abs
        state_29 = entries18
        value_37 = text9
        entity_set_prop_5 = get_all
        helpers.handleValue24 = function(value142, value143, value144, value145, value146, value147)
            local piValue2, amount4, amount5, amount6
            local entries48 = value144
            if (not entries48) then
                entries48 = {}
                piValue2 = 255
                amount4 = 255
                amount5 = 255
                amount6 = 255
                entries48[1] = piValue2
                entries48[2] = amount4
                entries48[3] = amount5
                entries48[4] = amount6
            end
            value144 = entries48
            entries48 = value145
            if (not entries48) then
                entries48 = 8
            end
            value145 = entries48
            entries48 = value_36
            piValue2 = math_pi_17.get(state_29.misc[3])
            entries48 = entries48(piValue2, "console")
            if (not entries48) then
                entries48 = false
            end
            value146 = entries48
            entries48 = value147
            if (not entries48) then
                entries48 = ""
            end
            value147 = entries48
            entries48 = table.insert
            piValue2 = value142.m_notify_text
            amount4 = value_37
            entries48(piValue2, amount4.new(amount4, value143, value144, value145))
            if value146 then
                if (value147 == "fire") then
                    entity_set_prop_5.color_log(182, 231, 23, "[gamesense] \000")
                    entity_set_prop_5.color_log(210, 210, 255, value143)
                else
                    print(value143)
                end
            end
            return
        end
    end
    entries26[entries27] = helpers.handleValue24
    entries27 = "think"
    do
        local renderer_world_to_screen_11, iterate_array_4, require_tohex_6, ui_update_14,
              math_pi_reference_11, string_upper_14, require_create_font_2, value_38, math_pi_18, state_30,
              require_13
        renderer_world_to_screen_11 = blur
        iterate_array_4 = iterate_array
        require_tohex_6 = arshift
        ui_update_14 = get_2
        math_pi_reference_11 = math_pi_reference
        string_upper_14 = byte
        require_create_font_2 = require_create_font
        value_38 = entries22
        math_pi_18 = abs
        state_30 = entries18
        require_13 = require_5
        helpers.handleValue24 = function(value142, entries48, value143)
            local entries49, value144, entries50, iterate_array_18, amount4, state96, entries51,
                  ui_update_gradient, m_time, frame_time, ceil, amount5, amount6, amount7, amount_8, max,
                  amount_9, amount_10, amount_11, max_2, iterate_array_19, value145, value146, index6,
                  entry_2
            local amount_12 = 5
            local value147 = (entries48[1] / 2)
            local value148 = (entries48[2] / 2)
            local text13 = "c"
            local amount_13 = 1
            if (value143 == "small") then
                text13 = "-c"
            else
                if (value143 == "thin") then
                    text13 = "c"
                else
                    if (value143 == "bold") then
                        text13 = "bc"
                    else
                        if (value143 == "blind") then
                            text13 = "+c"
                            amount_13 = 10
                        end
                    end
                end
            end
            if (6 < (#value142.m_notify_text)) then
                table.remove(value142.m_notify_text, 1)
            end
            iterate_array_18 = (#value142.m_notify_text)
            amount4 = 1
            state96 = (-1)
            for entries51 = iterate_array_18, amount4, state96 do
                ui_update_gradient = value142.m_notify_text[entries51]
                m_time = ui_update_gradient.m_time
                frame_time = renderer_world_to_screen_11.frametime()
                m_time = (m_time - frame_time)
                ui_update_gradient.m_time = m_time
                if (ui_update_gradient.m_time <= 0) then
                    table.remove(value142.m_notify_text, entries51)
                end
            end
            if ((#value142.m_notify_text) == 0) then
                return
            end
            iterate_array_18 = iterate_array_4
            amount4 = value142.m_notify_text
            iterate_array_18, amount4, state96 = iterate_array_18(amount4)
            iterate_array_19 = iterate_array_18
            value145 = amount4
            value146 = state96
            for index6, entry_2 in iterate_array_19, value145, value146 do
                amount4 = index6
                state96 = entry_2
                entries50 = state96.m_text
                if (value143 == "small") then
                    entries51 = require_tohex_6.upper(state96.m_text)
                    entries50 = entries51
                end
                entries51 = {}
                entries51 = {ui_update_14.measure_text(text13, entries50)}
                ui_update_gradient = math_pi_reference_11
                m_time = state96.lerped_pos
                frame_time = (((entries48[2] / 2) + 300) + (amount4 * (23 + entries51[2])))
                ceil = renderer_world_to_screen_11.frametime()
                ui_update_gradient = ui_update_gradient(m_time, frame_time, (ceil * 10))
                state96.lerped_pos = ui_update_gradient
                smooth_center_y = state96.lerped_pos
                value144 = state96.m_time
                entries49 = state96.m_color
                if (value144 < 0.5) then
                    ui_update_gradient = value144
                    m_time = string_upper_14.min
                    frame_time = string_upper_14.max(ui_update_gradient, 0)
                    m_time = m_time(frame_time, 0.5)
                    ui_update_gradient = (m_time / 0.5)
                    m_time = string_upper_14.floor((ui_update_gradient * 255))
                    entries49[4] = m_time
                    if ((amount4 == 1) and (ui_update_gradient < 0.2)) then
                        amount_12 = (amount_12 - (13 * (1 - (ui_update_gradient / 0.2))))
                    end
                else
                    entries49[4] = 255
                end
                if require_create_font_2 then
                    ui_update_gradient = value_38
                    m_time = math_pi_18.get(state_30.misc[3])
                    ui_update_gradient = ui_update_gradient(m_time, "default")
                    if ui_update_gradient then
                        require_13.draw_text(8, amount_12, entries49[1], entries49[2], entries49[3], entries49[4], require_create_font_2, state96.m_text)
                    end
                end
                ui_update_gradient = value_38
                m_time = math_pi_18.get(state_30.misc[3])
                ui_update_gradient = ui_update_gradient(m_time, "center")
                if ui_update_gradient then
                    gamesense_outer(value147, smooth_center_y, entries51[2], entries51[1], entries49[4], true)
                    smooth_center_y = (smooth_center_y - 46)
                    ui_update_gradient = ui_update_14.gradient
                    m_time = string_upper_14.ceil(((entries51[1] / 2) + 3))
                    m_time = (value147 - m_time)
                    frame_time = smooth_center_y
                    ceil = string_upper_14.ceil(entries51[1])
                    ui_update_gradient(m_time, frame_time, (ceil / 2), 1, 59, 175, 222, entries49[4], 202, 70, 205, entries49[4], true)
                    ui_update_gradient = ui_update_14.gradient
                    m_time = (value147 - 4)
                    frame_time = smooth_center_y
                    ceil = string_upper_14.ceil(((entries51[1] / 2) + 7.5))
                    ui_update_gradient(m_time, frame_time, ceil, 1, 202, 70, 205, entries49[4], 204, 227, 53, entries49[4], true)
                    ui_update_gradient = ui_update_14.gradient
                    m_time = string_upper_14.ceil(((entries51[1] / 2) + 3))
                    m_time = (value147 - m_time)
                    frame_time = (smooth_center_y + 1)
                    ceil = string_upper_14.ceil(entries51[1])
                    ceil = (ceil / 2)
                    amount5 = 1
                    amount6 = 59
                    amount7 = 175
                    amount_8 = 222
                    max = string_upper_14.max(0, string_upper_14.min(255, entries49[4]))
                    ui_update_gradient(m_time, frame_time, ceil, amount5, amount6, amount7, amount_8, (max - 100), 202, 70, 205, entries49[4], true)
                    ui_update_gradient = ui_update_14.gradient
                    m_time = (value147 - 4)
                    frame_time = (smooth_center_y + 1)
                    ceil = string_upper_14.ceil(((entries51[1] / 2) + 7.5))
                    amount5 = 1
                    amount6 = 202
                    amount7 = 70
                    amount_8 = 205
                    max = entries49[4]
                    amount_9 = 204
                    amount_10 = 227
                    amount_11 = 53
                    max_2 = string_upper_14.max(0, string_upper_14.min(255, entries49[4]))
                    ui_update_gradient(m_time, frame_time, ceil, amount5, amount6, amount7, amount_8, max, amount_9, amount_10, amount_11, (max_2 - 100), true)
                    ui_update_14.text(value147, ((smooth_center_y + entries51[2]) - amount_13), 209, 209, 209, entries49[4], text13, 0, entries50)
                end
                amount_12 = (amount_12 + 13)
            end
            return
        end
    end
    entries26[entries27] = helpers.handleValue24
    entries27 = entries26.new(entries26)
    g_notify = entries27
    entries27 = {}
    helpers.handleValue24 = "\216\172\216\175\216\167 \216\167\217\132\216\173\217\133\216\175 \217\132\217\132\217\135 \216\167\217\148\216\168\217\138"
    helpers.handle_value_25 = "\226\130\169\226\177\164\226\130\179\197\130\226\130\174\226\177\167 \226\130\180\201\134\226\130\166\196\144 \226\130\178\226\177\164\201\134\201\134\226\130\174\197\130\226\130\166\226\130\178\226\130\180 \226\130\177\226\130\179\226\177\164\226\130\179 \226\130\179 \226\130\181\195\152\226\130\166\226\130\179 \196\144\226\130\179 \226\130\174\201\132\226\130\179 \226\130\165\226\130\179\204\131\201\134"
    helpers.handle_value_26 = "\224\174\131\225\133\148>.< \209\135\208\187\208\181\208\189 \208\178 \208\183\208\176\208\180\208\189\208\184\209\134\208\181 \209\131 \209\128\209\131\209\129\209\129\208\186\208\184\209\133 \239\188\183\239\188\178\239\188\161\239\188\169\239\188\180\239\188\168 \239\188\178\239\188\165\239\188\163\239\188\175\239\188\164\239\188\165\225\133\149\224\174\131"
    text10 = "\200\182\202\143 \202\132\214\133\202\128 \202\1412 \198\136\214\133\202\141\214\132\201\168\211\188\201\168\214\133\213\188 \213\161\201\168\200\182\201\166 \200\182\201\166\201\155 \214\132\214\133\214\132\214\134 \199\159\213\188\201\150 \200\182\201\166\201\155 \201\174\199\159\213\188\201\162\214\134 \202\132\200\182 \240\157\148\128\240\157\147\187\240\157\147\184\240\157\147\189\240\157\147\177 \240\157\147\181\240\157\147\184\240\157\147\170"
    text11 = "\231\153\190\232\144\172\229\175\140\231\191\129\232\178\183\233\172\188 \227\131\132"
    text12 = "skeet invite code in morse: ... .-- ..-. -.-- -... .-- ..-. -... .--- --.. -... .-.. -.- .... ..-. .-.. -.- --. .. .-. .--. --. .-.. --.- --.- - -.-- .---- -..- . .-- -.- -.-- --.- ---.. .-.. .... ... ...- --.. -..- -.. .--. -..- -- -... - -.--"
    helpers.handle_value_27 = "\240\157\159\157\240\157\159\153.\240\157\159\153\240\157\159\159\240\157\159\160.\240\157\159\153\240\157\159\160\240\157\159\157.\240\157\159\154\240\157\159\155\240\157\159\155/\240\157\149\161\240\157\149\157\240\157\149\146\240\157\149\170\240\157\149\150\240\157\149\163\240\157\149\164.\240\157\149\155\240\157\149\164\240\157\149\160\240\157\149\159 \240\157\147\172\240\157\147\189\240\157\147\187\240\157\147\181+f \"\240\157\150\142\240\157\150\152\240\157\150\152\240\157\150\148 \240\157\150\139\240\157\150\148\240\157\150\142 \240\157\150\137\240\157\150\148\240\157\150\149\240\157\150\138, \240\157\150\140\240\157\150\134\240\157\150\147\240\157\150\137\240\157\150\134 \240\157\150\153\240\157\150\148\240\157\150\150\240\157\150\154\240\157\150\138\""
    helpers.handle_value_28 = "\240\159\149\175\239\184\143\226\167\154\240\159\142\131\226\167\154\240\159\148\174 \198\153\196\133YR\224\189\158\198\161\197\139 \225\191\179\196\177\198\150\198\150 \198\136\198\161\198\161\226\132\152 \202\130\226\132\152\196\177\201\155\198\150\201\155\197\139 \240\159\148\174\226\167\154\240\159\142\131\226\167\154\240\159\149\175\239\184\143"
    helpers.handleValue29 = " \226\147\148\226\147\156\226\147\145\226\147\161\226\147\144\226\147\146\226\147\148 \226\147\161\226\147\144\226\147\146\226\147\152\226\147\162\226\147\156 "
    helpers.handle_value_30 = "yesterday i got smoked by (\227\129\163\226\151\148\226\151\161\226\151\148)\227\129\163 \206\185\208\178\206\185z\206\177 6\226\132\147 1.9 \209\130\226\136\130\206\185 160 \194\162\207\133\207\129\209\143\206\177 2004 160 \208\189\207\129 / 118 \208\186\207\137 1896 \194\162\208\1883 (115.7 \194\162\207\133-\206\185\208\184)"
    helpers.handle_value_31 = "\227\128\144\227\128\128\239\188\183\239\188\178\239\188\161\239\188\169\239\188\180\239\188\168\227\128\128\239\188\161\239\188\174\239\188\180\239\188\169\239\188\141\239\188\161\239\188\169\239\188\173\239\188\162\239\188\175\239\188\180\227\128\128\239\188\178\239\188\165\239\188\163\239\188\175\239\188\164\239\188\165\227\128\128\227\128\145"
    helpers.handle_value_32 = "\202\128\225\180\128\225\180\162 \225\180\128\225\180\133\225\180\133\225\180\135\225\180\133 \225\180\155\202\156\201\170s \225\180\155\225\180\143 \225\180\161\202\128\225\180\128\201\170\225\180\155\202\156 \202\128\225\180\135\225\180\132\225\180\143\225\180\133\225\180\135 \225\180\128\201\180\225\180\133 \201\170\225\180\155 \225\180\141\225\180\128\225\180\133\225\180\135 \201\170\225\180\155 s\225\180\143 \225\180\141\225\180\156\225\180\132\202\156 \202\153\225\180\135\225\180\155\225\180\155\225\180\135\202\128"
    entries27[1] = helpers.handleValue24
    entries27[2] = helpers.handle_value_25
    entries27[3] = helpers.handle_value_26
    entries27[4] = text10
    entries27[5] = text11
    entries27[6] = text12
    entries27[7] = helpers.handle_value_27
    entries27[8] = helpers.handle_value_28
    entries27[9] = helpers.handleValue29
    key = 10
    entries27[key] = helpers.handle_value_30
    key = 11
    entries27[key] = helpers.handle_value_31
    key = 12
    entries27[key] = helpers.handle_value_32
    last_random = 0
    new_random = 0
    textalhao = ""
    say_time = 0
    ran = false
    do
        local math_pi_19, state_31, entity_set_prop_6, globals_tickinterval_9, entries_36,
              renderer_world_to_screen_12
        math_pi_19 = abs
        state_31 = entries18
        entity_set_prop_6 = get_all
        globals_tickinterval_9 = absoluteframetime
        entries_36 = entries27
        renderer_world_to_screen_12 = blur
        helpers.handleValue24 = function(value142)
            local value143, userid_to_entindex, userid_to_entindex_2, local_player, enemy, random_int
            local state96 = value142
            value142 = nil
            local piValue2 = math_pi_19.get(state_31.misc[4])
            if (not piValue2) then
                piValue2 = math_pi_19.get(state_31.misc[5])
                if (not piValue2) then
                    return
                end
            end
            piValue2 = state96.userid
            value143 = state96.attacker
            if ((piValue2 == value142) or (value143 == value142)) then
                return
            end
            userid_to_entindex = entity_set_prop_6.userid_to_entindex(piValue2)
            userid_to_entindex_2 = entity_set_prop_6.userid_to_entindex(value143)
            local_player = globals_tickinterval_9.get_local_player()
            if (userid_to_entindex_2 == local_player) then
                enemy = globals_tickinterval_9.is_enemy(userid_to_entindex)
                if enemy then
                    local_player = entity_set_prop_6.random_int(1, (#entries_36))
                    new_random = local_player
                    while true do
                        if (new_random ~= last_random) then
                            break
                        end
                        random_int = entity_set_prop_6.random_int(1, (#entries_36))
                        new_random = random_int
                    end
                    local_player = new_random
                    textalhao = ("say " .. entries_36[local_player])
                    local_player = math_pi_19.get(state_31.misc[5])
                    if local_player then
                        local_player = renderer_world_to_screen_12.curtime()
                        say_time = local_player
                        ran = false
                    else
                        entity_set_prop_6.exec(textalhao)
                    end
                    last_random = new_random
                end
            end
            return
        end
    end
    do
        local renderer_world_to_screen_13, entity_set_prop_7
        renderer_world_to_screen_13 = blur
        entity_set_prop_7 = get_all
        helpers.handle_value_25 = function(value142)
            local current_time, current_time_2
            if (not value142) then
                ran = false
                return
            end
            current_time = renderer_world_to_screen_13.curtime()
            if (current_time >= (say_time + 1.6)) then
                current_time_2 = renderer_world_to_screen_13.curtime()
                if (current_time_2 <= (say_time + 1.7)) then
                    if (not ran) then
                        entity_set_prop_7.exec(textalhao)
                        ran = true
                    end
                end
            end
            return
        end
    end
    do
        local math_pi_20, state_32, ui_update_15
        math_pi_20 = abs
        state_32 = text5
        ui_update_15 = get_2
        helpers.handle_value_26 = function(value142, value143, value144)
            local cvar_cl_crosshairsize, piValue2
            if (not value142) then
                return
            end
            cvar_cl_crosshairsize = cvar.cl_crosshairsize
            cvar_cl_crosshairsize = cvar_cl_crosshairsize.get_int(cvar_cl_crosshairsize)
            piValue2 = math_pi_20.get(state_32.rage.ref_min_damage_override[2])
            if piValue2 then
                piValue2 = math_pi_20.get(state_32.rage.ref_min_damage_override[3])
            end
            if (not piValue2) then
                piValue2 = math_pi_20.get(state_32.rage.ref_min_damage[1])
            end
            final_dmg = piValue2
            piValue2 = ui_update_15.measure_text("", final_dmg)
            dmg_size = piValue2
            ui_update_15.text(((value143 / 2) + 10), ((value144 / 2) - 20), 255, 255, 255, 250, "", 0, final_dmg)
            return
        end
    end
    text10 = entries18["visuals"][11]
    text11 = entries18["visuals"][12]
    text12 = entries18["visuals"][13]
    do
        local math_pi_21, value_39, value_40, value_41, require_14, globals_tickinterval_10,
              iterate_array_5, value_42, value_43, state_33, value_44, value_45, value_46, value_47
        math_pi_21 = abs
        value_39 = text10
        value_40 = text11
        value_41 = text12
        require_14 = require_3
        globals_tickinterval_10 = absoluteframetime
        iterate_array_5 = iterate_array
        value_42 = amount3
        value_43 = entries22
        state_33 = entries18
        value_44 = helpers.handle_value_19
        value_45 = helpers.handle_value_12
        value_46 = helpers.handle_value_21
        value_47 = helpers.handle_value_18
        helpers.handle_value_27 = function(value142)
            local piValue2, value143, value144, value145, state96, state_97, piValue3, value146,
                  value147, entries48, piValue4, entries49, amount4, amount5, amount6, amount7,
                  value148, entries50, amount_8, amount_9, amount_10, value149, value150, value151,
                  value152, index6, entry_2, value153, value154, value155, index7, entry_3
            local piValue5 = math_pi_21.get(value_39)
            if (not piValue5) then
                return
            end
            piValue5 = math_pi_21.get(value_40)
            piValue2 = math_pi_21.get(value_41)
            value143 = require_14(globals_tickinterval_10.get_origin(value142))
            value144, value145, state96 = iterate_array_5(value_42)
            value150 = value144
            value151 = value145
            value152 = state96
            for index6, entry_2 in value150, value151, value152 do
                value145 = index6
                state96 = entry_2
                state_97 = require_14(state96.origin[1], state96.origin[2], state96.origin[3])
                state_97 = (value143 - state_97)
                state_97 = state_97.length(state_97)
                if (state_97 < 15) then

                else
                    piValue3, value146, value147 = iterate_array_5(piValue2)
                    value153 = piValue3
                    value154 = value146
                    value155 = value147
                    for index7, entry_3 in value153, value154, value155 do
                        value147 = entry_3
                        entries48 = nil
                        piValue4 = nil
                        if state96.breaking_lc then
                            entries49 = value_43(piValue5, "break lc")
                            if entries49 then
                                entries48 = "LC"
                                entries49 = (value147 == "box")
                                if entries49 then
                                    entries49 = 18
                                end
                                if (not entries49) then
                                    entries49 = 15
                                end
                                piValue4 = entries49
                            end
                        else
                            if state96.defensive then
                                entries49 = value_43(piValue5, "defensive")
                                if entries49 then
                                    entries48 = "EXP"
                                    entries49 = (value147 == "box")
                                    if entries49 then
                                        entries49 = 17
                                    end
                                    if (not entries49) then
                                        entries49 = 14
                                    end
                                    piValue4 = entries49
                                end
                            else
                                if (not state96.defensive) then
                                    if state96.is_defensive_forced then
                                        entries49 = value_43(piValue5, "vulnerable")
                                        if entries49 then
                                            entries48 = "HIT"
                                            entries49 = (value147 == "box")
                                            if entries49 then
                                                entries49 = 19
                                            end
                                            if (not entries49) then
                                                entries49 = 16
                                            end
                                            piValue4 = entries49
                                        end
                                    end
                                end
                            end
                        end
                        if (entries48 and piValue4) then
                            entries49 = {}
                            entries49 = {math_pi_21.get(state_33.visuals[piValue4])}
                            amount4 = value_44(state96.cur_time)
                            if (value147 == "box") then
                                value_45(value142, state96.origin, state96, entries49, amount4)
                            else
                                if (value147 == "skeleton") then
                                    value_46(state96, entries49, amount4)
                                else
                                    if (value147 == "text") then
                                        amount5 = require_14(state96.origin[1], state96.origin[2], (state96.origin[3] + 77))
                                        amount6 = value_47
                                        amount7 = amount5
                                        value148 = entries48
                                        entries50 = {}
                                        amount_8 = 255
                                        amount_9 = 255
                                        amount_10 = 255
                                        value149 = amount4
                                        entries50[1] = amount_8
                                        entries50[2] = amount_9
                                        entries50[3] = amount_10
                                        entries50[4] = value149
                                        amount6(amount7, value148, entries50)
                                    end
                                end
                            end
                        end
                    end
                    if (value145 == 1) then
                        piValue3 = math_pi_21.get(state_33.visuals.show_last_record)
                        if piValue3 then
                            piValue3 = ""
                            if state96.breaking_lc then
                                piValue3 = "LC"
                            else
                                if state96.defensive then
                                    piValue3 = "EXP"
                                else
                                    if (not state96.defensive) then
                                        if state96.is_defensive_forced then
                                            piValue3 = "HIT"
                                        end
                                    else
                                        piValue3 = "\226\157\151"
                                    end
                                end
                            end
                            value146 = value_46
                            value147 = state96
                            entries48 = {}
                            piValue4 = 200
                            entries49 = 200
                            amount4 = 200
                            amount5 = 200
                            entries48[1] = piValue4
                            entries48[2] = entries49
                            entries48[3] = amount4
                            entries48[4] = amount5
                            value146(value147, entries48, 175)
                            value146 = require_14(state96.origin[1], state96.origin[2], (state96.origin[3] + 77))
                            value147 = value_47
                            entries48 = value146
                            piValue4 = piValue3
                            entries49 = {}
                            amount4 = 255
                            amount5 = 255
                            amount6 = 255
                            amount7 = 150
                            entries49[1] = amount4
                            entries49[2] = amount5
                            entries49[3] = amount6
                            entries49[4] = amount7
                            value147(entries48, piValue4, entries49)
                        end
                    end
                end
            end
            return
        end
    end
    do
        local value_48, math_pi_22, state_34, require_15, globals_tickinterval_11, state_35, ui_update_16
        value_48 = entries22
        math_pi_22 = abs
        state_34 = entries18
        require_15 = require_3
        globals_tickinterval_11 = absoluteframetime
        state_35 = entries5
        ui_update_16 = get_2
        helpers.handle_value_28 = function(entity_index)
            local amount4, amount5, amount6, amount7
            local entries48 = value_48
            local entries49 = math_pi_22.get(state_34.visuals[6])
            entries48 = entries48(entries49, "lc indicator")
            if (not entries48) then
                return
            end
            entries48 = {}
            entries49 = require_15(globals_tickinterval_11.get_prop(entity_index, "m_vecVelocity"))
            entries49 = entries49.length2d(entries49)
            if (265 < entries49) then
                if (not state_35.breaking_lc) then
                    entries49 = {}
                    amount4 = 255
                    amount5 = 0
                    amount6 = 0
                    amount7 = 255
                    entries49[1] = amount4
                    entries49[2] = amount5
                    entries49[3] = amount6
                    entries49[4] = amount7
                    entries48 = entries49
                end
            else
                if state_35.breaking_lc then
                    entries49 = {}
                    amount4 = 132
                    amount5 = 195
                    amount6 = 16
                    amount7 = 255
                    entries49[1] = amount4
                    entries49[2] = amount5
                    entries49[3] = amount6
                    entries49[4] = amount7
                    entries48 = entries49
                end
            end
            entries49 = require_15(globals_tickinterval_11.get_prop(entity_index, "m_vecVelocity"))
            entries49 = entries49.length2d(entries49)
            if entries49 then
                ui_update_16.indicator(entries48[1], entries48[2], entries48[3], entries48[4], "LC")
            end
            return
        end
    end
    do
        local globals_tickinterval_12, entity_set_prop_8, math_pi_23, state_36, value_49, value_50,
              value_51, value_52, value_53, value_54
        globals_tickinterval_12 = absoluteframetime
        entity_set_prop_8 = get_all
        math_pi_23 = abs
        state_36 = entries18
        value_49 = helpers.handle_value_28
        value_50 = helpers.handle_value_25
        value_51 = helpers.handle_value_26
        value_52 = entries22
        value_53 = helpers.handle_value_23
        value_54 = helpers.handle_value_27
        helpers.handleValue29 = function(value142)
            local piValue2
            local local_player = globals_tickinterval_12.get_local_player()
            local state96 = {}
            state96 = {entity_set_prop_8.screen_size()}
            local piValue3 = math_pi_23.get(state_36.visuals[3])
            local piValue4 = math_pi_23.get(state_36.visuals[4])
            local piValue5 = math_pi_23.get(state_36.visuals[5])
            value_49(local_player)
            local state_97 = value_50
            local piValue6 = math_pi_23.get(state_36.misc[4])
            if piValue6 then
                piValue6 = math_pi_23.get(state_36.misc[5])
            end
            state_97(piValue6)
            state_97 = value_51
            piValue6 = value_52
            piValue2 = math_pi_23.get(state_36.visuals[6])
            piValue6 = piValue6(piValue2, "min damage")
            if piValue6 then
                piValue6 = globals_tickinterval_12.is_alive(local_player)
            end
            state_97(piValue6, state96[1], state96[2])
            watermark(local_player, piValue4)
            value_53(value142, state_36.visuals[0], local_player, state96, piValue3)
            state_97 = g_notify
            state_97.think(state_97, state96, piValue5)
            value_54(local_player)
            return
        end
    end
    do
        local state_37, client_visible
        state_37 = state
        client_visible = color_log
        helpers.handle_value_30 = function(value142, value143)
            local text13, value144
            local amount4 = value143
            if (not amount4) then
                amount4 = 1
            end
            value143 = amount4
            amount4 = state_37.cast(client_visible, value142)
            value142 = amount4
            amount4 = state_37.cast
            text13 = "struct animation_layer_t_cona**"
            value144 = state_37.cast("char*", value142)
            amount4 = amount4(text13, (value144 + 10640))
            return amount4[0][value143]
        end
    end
    do
        local string_upper_15
        string_upper_15 = byte
        helpers.handle_value_31 = function(value142)
            duckammount = value142.m_fDuckAmount
            local max = string_upper_15.max(0, string_upper_15.min(value142.m_flFeetSpeedForwardsOrSideWays, 1))
            speedfraction = max
            max = string_upper_15.max(0, string_upper_15.min(1, value142.m_flFeetSpeedUnknownForwardOrSideways))
            speedfactor = max
            unk1 = (((value142.m_flStopToFullRunningFraction * (-0.30000001)) - 0.19999999) * speedfraction)
            unk2 = (unk1 + 1)
            unk3 = 0
            if (0 < duckammount) then
                unk2 = (unk2 + ((duckammount * speedfactor) * (0.5 - unk2)))
            end
            unk3 = (value142.m_flMaxYaw * unk2)
            return unk3
        end
    end
    do
        local value_55, value_56, value_57, state_38, client_visible_2
        value_55 = error_3
        value_56 = error_2
        value_57 = error_4
        state_38 = state
        client_visible_2 = color_log
        helpers.handle_value_32 = function(value142)
            local state96 = value142
            value142 = nil
            local value143 = value_55(value_56, state96)
            local value144 = value_57(value_56, state96)
            local value145 = state_38.cast(client_visible_2, value143)
            local value146 = state_38.cast("char*", value145)
            value146 = (value146 + 39264)
            local value147 = state_38.cast("struct animstate_t1**", value146)[0]
            if ((value143 ~= value142) and (value144 ~= value142)) then
                if (local_animstate ~= value142) then
                    goto branch_1
                end
            end
            do
                return
            end
            ::branch_1::
            state96.set_prop(state96, "m_flPoseParameter", 1, 6)
            return
        end
    end
    do
        local value_58, value_59, value_60, state_39, client_visible_3, renderer_world_to_screen_14,
              state_40, value_61, string_upper_16, globals_tickinterval_13, value_62, math_pi_24, state_41,
              require_16, value_63, entity_set_prop_9, value_64, value_65
        value_58 = error_3
        value_59 = error_2
        value_60 = error_4
        state_39 = state
        client_visible_3 = color_log
        renderer_world_to_screen_14 = blur
        state_40 = entries5
        value_61 = helpers.handle_value_31
        string_upper_16 = byte
        globals_tickinterval_13 = absoluteframetime
        value_62 = entries22
        math_pi_24 = abs
        state_41 = entries18
        require_16 = require_3
        value_63 = helpers.handle_value_30
        entity_set_prop_9 = get_all
        value_64 = helpers.handle_value_3
        value_65 = math_pi_new_combobox
        helpers.handle_value_33 = function(value142)
            local current_desync, piValue2, pose_parameter, value143, value144, state96
            local value145 = value142
            value142 = nil
            local value146 = value_58(value_59, value145)
            local value147 = value_60(value_59, value145)
            local value148 = state_39.cast(client_visible_3, value146)
            local value149 = state_39.cast("char*", value148)
            value149 = (value149 + 39264)
            local state_97 = state_39.cast("struct animstate_t1**", value149)[0]
            if (((value146 == value142) or (value147 == value142)) or (state_97 == value142)) then
                return
            end
            current_desync = renderer_world_to_screen_14.chokedcommands()
            if (current_desync == 0) then
                current_desync = value_61(state_97)
                state96 = state_40
                state96.max_desync = current_desync
                current_desync = string_upper_16.min
                piValue2 = string_upper_16.max
                pose_parameter = globals_tickinterval_13.get_prop(value145, "m_flPoseParameter", 11)
                piValue2 = piValue2(((pose_parameter * 120) - 60), (-58))
                current_desync = current_desync(piValue2, 58)
                state96 = state_40
                state96.current_desync = current_desync
                current_desync = (0 < state_40.current_desync)
                if current_desync then
                    current_desync = string_upper_16.ceil(state_40.current_desync)
                end
                if (not current_desync) then
                    current_desync = string_upper_16.floor(state_40.current_desync)
                end
                state96 = state_40
                state96.current_desync = current_desync
            end
            current_desync = value_62
            piValue2 = math_pi_24.get(state_41.misc[1])
            current_desync = current_desync(piValue2, "air walk")
            if current_desync then
                current_desync = require_16(globals_tickinterval_13.get_prop(value145, "m_vecVelocity"))
                current_desync = current_desync.length2d(current_desync)
                if (1.5 < current_desync) then
                    current_desync = value_63(value146, 6)
                    ANIMATION_LAYER_MOVEMENT_MOVE = current_desync
                    current_desync = ANIMATION_LAYER_MOVEMENT_MOVE
                    current_desync.m_flWeight = 1
                end
            end
            current_desync = value_62
            piValue2 = math_pi_24.get(state_41.misc[1])
            current_desync = current_desync(piValue2, "earthquake")
            if current_desync then
                current_desync = value_63(value146, 12)
                ANIMATION_LAYER_LEAN = current_desync
                current_desync = ANIMATION_LAYER_LEAN
                piValue2 = entity_set_prop_9.random_float(0, 1)
                current_desync.m_flWeight = piValue2
            end
            current_desync = value_62
            piValue2 = math_pi_24.get(state_41.misc[1])
            current_desync = current_desync(piValue2, "fake walk")
            if current_desync then
                if state_40.in_speed then
                    current_desync = value_63(value146, 12)
                    ANIMATION_LAYER_LEAN = current_desync
                    current_desync = ANIMATION_LAYER_LEAN
                    current_desync.m_flWeight = 0
                    current_desync = value_63(value146, 6)
                    ANIMATION_LAYER_MOVEMENT_MOVE = current_desync
                    current_desync = ANIMATION_LAYER_MOVEMENT_MOVE
                    current_desync.m_flWeight = 0
                end
            end
            current_desync = value_62
            piValue2 = math_pi_24.get(state_41.misc[1])
            current_desync = current_desync(piValue2, "blind")
            if current_desync then
                current_desync = value_63(value146, 9)
                ANIMATION_LAYER_FLASHED = current_desync
                current_desync = ANIMATION_LAYER_FLASHED
                current_desync.m_nSequence = 224
                current_desync = ANIMATION_LAYER_FLASHED
                current_desync.m_flWeight = 1
            end
            current_desync = value_62
            piValue2 = math_pi_24.get(state_41.misc[1])
            current_desync = current_desync(piValue2, "moonwalk")
            if current_desync then
                globals_tickinterval_13.set_prop(value145, "m_flPoseParameter", 0, 7)
            end
            current_desync = value_62
            piValue2 = math_pi_24.get(state_41.misc[1])
            current_desync = current_desync(piValue2, "smoothing")
            if current_desync then
                globals_tickinterval_13.set_prop(value145, "m_flPoseParameter", 0, 2)
            end
            current_desync = value_62
            piValue2 = math_pi_24.get(state_41.misc[1])
            current_desync = current_desync(piValue2, "fallen legs")
            if current_desync then
                if state_40.jumping then
                    if state_40.on_ground then
                        if (not state_40.wait_for_land_update) then
                            state96 = state_40
                            state96.wait_for_land_update = true
                            current_desync = (state_40.time_on_ground + 1)
                            state96 = state_40
                            state96.time_on_ground = current_desync
                        end
                    end
                end
                if (not state_40.wait_for_land_update) then
                    if (not state_40.jumping) then
                        if state_40.on_ground then
                            goto branch_1
                        end
                    end
                    if state_40.on_ground then
                        current_desync = renderer_world_to_screen_14.chokedcommands()
                        if (current_desync == 0) then
                            goto branch_1
                        end
                    end
                    current_desync = globals_tickinterval_13.set_prop
                    piValue2 = value145
                    pose_parameter = "m_flPoseParameter"
                    value143 = value_64
                    value144 = value_65(state_40.air_time, 0.75, 1.5)
                    value143 = value143(value144, 0.7, 1.5, 0, 1)
                    current_desync(piValue2, pose_parameter, value143, 6)
                    goto branch_3
                end
                ::branch_1::
                if state_40.jumping then
                    current_desync = state_40.on_ground
                    if current_desync then
                        goto branch_2
                    end
                end
                current_desync = state_40.on_ground
                ::branch_2::
                if current_desync then
                    current_desync = renderer_world_to_screen_14.chokedcommands()
                    if (current_desync == 0) then
                        state96 = state_40
                        state96.air_time = 0
                        state96 = state_40
                        state96.time_on_ground = 0
                    end
                end
                globals_tickinterval_13.set_prop(value145, "m_flPoseParameter", 0, 6)
                if state_40.wait_for_land_update then
                    current_desync = renderer_world_to_screen_14.chokedcommands()
                    if (current_desync ~= 0) then
                        if (2 < state_40.time_on_ground) then
                            globals_tickinterval_13.set_prop(value145, "m_flPoseParameter", 0, 6)
                            current_desync = value_63(value146, 4)
                            ANIMATION_LAYER_FOUR = current_desync
                            current_desync = ANIMATION_LAYER_FOUR
                            current_desync.m_flWeight = 0
                            current_desync = ANIMATION_LAYER_FOUR
                            current_desync.m_flCycle = 0
                        end
                    end
                else
                    if state_40.wait_for_land_update then
                        current_desync = renderer_world_to_screen_14.chokedcommands()
                        if (current_desync == 0) then
                            state96 = state_40
                            state96.wait_for_land_update = false
                        end
                    end
                end
                ::branch_3::
            end
            current_desync = value_62
            piValue2 = math_pi_24.get(state_41.misc[1])
            current_desync = current_desync(piValue2, "slide")
            if current_desync then
                globals_tickinterval_13.set_prop(value145, "m_flPoseParameter", 1, 0)
            end
            current_desync = value_62
            piValue2 = math_pi_24.get(state_41.misc[1])
            current_desync = current_desync(piValue2, "pitch on land")
            if current_desync then
                state96 = state_40
                state96.landing = true
                if state_97.m_bInHitGroundAnimation then
                    if (0.101 < state_97.m_flHeadHeightOrOffsetFromHittingGroundAnimation) then
                        if state_97.m_bOnGround then
                            piValue2 = entity_set_prop_9.key_state(32)
                            if (not piValue2) then
                                piValue2 = globals_tickinterval_13.get_prop
                                pose_parameter = globals_tickinterval_13.get_game_rules()
                                piValue2 = piValue2(pose_parameter, "m_bFreezePeriod")
                                if (piValue2 ~= 1) then
                                    current_desync = value_62
                                    piValue2 = math_pi_24.get(state_41.misc[1])
                                    current_desync = current_desync(piValue2, "pitch on land")
                                    if current_desync then
                                        if state_40.landing then
                                            globals_tickinterval_13.set_prop(value145, "m_flPoseParameter", 0.5, 12)
                                        end
                                    end
                                end
                            end
                        end
                    end
                else
                    state96 = state_40
                    state96.landing = false
                end
            end
            return
        end
    end
    entries28 = {}
    entries29 = {}
    entries30 = cvar["r_3dsky"]
    key = "cvar"
    entries29[key] = entries30
    key = "value"
    entries29[key] = 1
    key = "3d sky"
    entries28[key] = entries29
    entries29 = {}
    entries30 = {}
    cvars.fog_enable = cvar["fog_enable"]
    cvars.fog_enable_water_fog = cvar["fog_enable_water_fog"]
    entries30[1] = cvars.fog_enable
    entries30[2] = cvars.fog_enable_water_fog
    key = "cvars"
    entries29[key] = entries30
    key = "value"
    entries29[key] = 1
    key = "fog"
    entries28[key] = entries29
    entries29 = {}
    entries30 = {}
    cvars.fog_enable = cvar["r_shadows"]
    cvars.fog_enable_water_fog = cvar["cl_csm_static_prop_shadows"]
    cvars.cl_csm_shadows = cvar["cl_csm_shadows"]
    cvars.cl_csm_world_shadows = cvar["cl_csm_world_shadows"]
    cvars.cl_foot_contact_shadows = cvar["cl_foot_contact_shadows"]
    cvars.cl_csm_viewmodel_shadows = cvar["cl_csm_viewmodel_shadows"]
    cvars.cl_csm_rope_shadows = cvar["cl_csm_rope_shadows"]
    cvars.cl_csm_sprite_shadows = cvar["cl_csm_sprite_shadows"]
    cvars.cl_csm_translucent_shadows = cvar["cl_csm_translucent_shadows"]
    cvars.cl_csm_entity_shadows = cvar["cl_csm_entity_shadows"]
    cvars.cl_csm_world_shadows_in_viewmodelcascade = cvar["cl_csm_world_shadows_in_viewmodelcascade"]
    entries30[1] = cvars.fog_enable
    entries30[2] = cvars.fog_enable_water_fog
    entries30[3] = cvars.cl_csm_shadows
    entries30[4] = cvars.cl_csm_world_shadows
    entries30[5] = cvars.cl_foot_contact_shadows
    entries30[6] = cvars.cl_csm_viewmodel_shadows
    entries30[7] = cvars.cl_csm_rope_shadows
    entries30[8] = cvars.cl_csm_sprite_shadows
    entries30[9] = cvars.cl_csm_translucent_shadows
    key = 10
    entries30[key] = cvars.cl_csm_entity_shadows
    key = 11
    entries30[key] = cvars.cl_csm_world_shadows_in_viewmodelcascade
    key = "cvars"
    entries29[key] = entries30
    key = "value"
    entries29[key] = 1
    key = "shadows"
    entries28[key] = entries29
    entries29 = {}
    entries30 = cvar["violence_hblood"]
    key = "cvar"
    entries29[key] = entries30
    key = "value"
    entries29[key] = 1
    key = "blood"
    entries28[key] = entries29
    entries29 = {}
    entries30 = {}
    cvars.fog_enable = cvar["r_drawdecals"]
    cvars.fog_enable_water_fog = cvar["r_drawropes"]
    cvars.cl_csm_shadows = cvar["r_drawsprites"]
    entries30[1] = cvars.fog_enable
    entries30[2] = cvars.fog_enable_water_fog
    entries30[3] = cvars.cl_csm_shadows
    key = "cvars"
    entries29[key] = entries30
    key = "value"
    entries29[key] = 1
    key = "decals"
    entries28[key] = entries29
    entries29 = {}
    entries30 = cvar["mat_disable_bloom"]
    key = "cvar"
    entries29[key] = entries30
    key = "value"
    entries29[key] = 0
    key = "bloom"
    entries28[key] = entries29
    entries29 = {}
    entries30 = {}
    cvars.fog_enable = cvar["r_dynamic"]
    cvars.fog_enable_water_fog = cvar["r_eyegloss"]
    cvars.cl_csm_shadows = cvar["r_eyes"]
    cvars.cl_csm_world_shadows = cvar["r_drawtracers_firstperson"]
    cvars.cl_foot_contact_shadows = cvar["r_dynamiclighting"]
    entries30[1] = cvars.fog_enable
    entries30[2] = cvars.fog_enable_water_fog
    entries30[3] = cvars.cl_csm_shadows
    entries30[4] = cvars.cl_csm_world_shadows
    entries30[5] = cvars.cl_foot_contact_shadows
    key = "cvars"
    entries29[key] = entries30
    key = "value"
    entries29[key] = 1
    key = "other"
    entries28[key] = entries29
    do
        local math_pi_25, state_42, iterate_pairs_9, value_66, iterate_array_6, value_67
        math_pi_25 = abs
        state_42 = entries18
        iterate_pairs_9 = iterate_pairs
        value_66 = entries28
        iterate_array_6 = iterate_array
        value_67 = entries22
        entries29 = function()
            local value142, state96, iterate_array_18, piValue2, amount4, value143, value144,
                  amount5, iterate_array_19, value145, value146, index6, entry_2, piValue3, value147,
                  value148, index7, entry_3, piValue4, value149, value150, index8, entry_4,
                  iterate_array_20, value151, value152, index9, entry_5, iterate_array_21, value153,
                  value154, index10, entry_6
            local piValue5 = math_pi_25.get(state_42.debug[2])
            if (not piValue5) then
                piValue5, value142, state96 = iterate_pairs_9(value_66)
                piValue4 = piValue5
                value149 = value142
                value150 = state96
                for index8, entry_4 in piValue4, value149, value150 do
                    state96 = entry_4
                    if state96.cvar then
                        iterate_array_18 = state96.cvar
                        iterate_array_18 = iterate_array_18.get_int(iterate_array_18)
                        if (iterate_array_18 ~= state96.value) then
                            iterate_array_18 = state96.cvar
                            iterate_array_18.set_int(iterate_array_18, state96.value)
                        end
                    else
                        iterate_array_18 = iterate_array_6
                        piValue2 = state96.cvars
                        iterate_array_18, piValue2, amount4 = iterate_array_18(piValue2)
                        iterate_array_21 = iterate_array_18
                        value153 = piValue2
                        value154 = amount4
                        for index10, entry_6 in iterate_array_21, value153, value154 do
                            amount4 = entry_6
                            value143 = amount4.get_int(amount4)
                            if (value143 ~= state96.value) then
                                amount4.set_int(amount4, state96.value)
                            end
                        end
                    end
                end
                return
            end
            piValue5, value142, state96 = iterate_pairs_9(value_66)
            piValue3 = piValue5
            value147 = value142
            value148 = state96
            for index7, entry_3 in piValue3, value147, value148 do
                value142 = index7
                state96 = entry_3
                iterate_array_18 = value_67
                piValue2 = math_pi_25.get(state_42.debug[3])
                iterate_array_18 = iterate_array_18(piValue2, value142)
                if iterate_array_18 then
                    if state96.cvar then
                        iterate_array_18 = state96.cvar
                        iterate_array_18 = iterate_array_18.get_int(iterate_array_18)
                        if (iterate_array_18 == state96.value) then
                            iterate_array_18 = state96.cvar
                            piValue2 = iterate_array_18
                            iterate_array_18 = iterate_array_18.set_int
                            amount4 = (state96.value == 0)
                            if amount4 then
                                amount4 = 1
                            end
                            if (not amount4) then
                                amount4 = (state96.value == 1)
                                if amount4 then
                                    amount4 = 0
                                end
                                if (not amount4) then
                                    amount4 = state96.value
                                end
                            end
                            iterate_array_18(piValue2, amount4)
                        end
                    else
                        iterate_array_18 = iterate_array_6
                        piValue2 = state96.cvars
                        iterate_array_18, piValue2, amount4 = iterate_array_18(piValue2)
                        iterate_array_19 = iterate_array_18
                        value145 = piValue2
                        value146 = amount4
                        for index6, entry_2 in iterate_array_19, value145, value146 do
                            amount4 = entry_2
                            value143 = amount4.get_int(amount4)
                            if (value143 == state96.value) then
                                value144 = amount4
                                value143 = amount4.set_int
                                amount5 = (state96.value == 0)
                                if amount5 then
                                    amount5 = 1
                                end
                                if (not amount5) then
                                    amount5 = (state96.value == 1)
                                    if amount5 then
                                        amount5 = 0
                                    end
                                    if (not amount5) then
                                        amount5 = state96.value
                                    end
                                end
                                value143(value144, amount5)
                            end
                        end
                    end
                else
                    if state96.cvar then
                        iterate_array_18 = state96.cvar
                        iterate_array_18 = iterate_array_18.get_int(iterate_array_18)
                        if (iterate_array_18 ~= state96.value) then
                            iterate_array_18 = state96.cvar
                            iterate_array_18.set_int(iterate_array_18, state96.value)
                        end
                    else
                        iterate_array_18 = iterate_array_6
                        piValue2 = state96.cvars
                        iterate_array_18, piValue2, amount4 = iterate_array_18(piValue2)
                        iterate_array_20 = iterate_array_18
                        value151 = piValue2
                        value152 = amount4
                        for index9, entry_5 in iterate_array_20, value151, value152 do
                            amount4 = entry_5
                            value143 = amount4.get_int(amount4)
                            if (value143 ~= state96.value) then
                                amount4.set_int(amount4, state96.value)
                            end
                        end
                    end
                end
            end
            return
        end
    end
    entries30 = abs.set_callback
    cvars.fog_enable = entries18["visuals"]["sunset mode"]
    do
        local globals_tickinterval_14, state_43, math_pi_26, state_44
        globals_tickinterval_14 = absoluteframetime
        state_43 = entries5
        math_pi_26 = abs
        state_44 = text5
        cvars.fog_enable_water_fog = function(value142)
            local m_env_light_shadow_direction, cvar_mat_postprocess_enable, entries48,
                  globals_tickinterval_get_prop, m_env_light_shadow_direction_2,
                  m_env_light_shadow_direction_3, state96
            local value143 = globals_tickinterval_14.get_all("CCascadeLight")[1]
            if (not value143) then
                return
            end
            m_env_light_shadow_direction = globals_tickinterval_14.get_prop(value143, "m_envLightShadowDirection")
            if (m_env_light_shadow_direction ~= 0) then
                m_env_light_shadow_direction = state_43.cache_sun_loc
                cvar_mat_postprocess_enable = state_43.cache_sun_loc
                entries48 = state_43.cache_sun_loc
                globals_tickinterval_get_prop = globals_tickinterval_14.get_prop
                globals_tickinterval_get_prop, m_env_light_shadow_direction_2, m_env_light_shadow_direction_3 = globals_tickinterval_get_prop(value143, "m_envLightShadowDirection")
                entries48[3] = m_env_light_shadow_direction_3
                cvar_mat_postprocess_enable[2] = m_env_light_shadow_direction_2
                m_env_light_shadow_direction[1] = globals_tickinterval_get_prop
            end
            m_env_light_shadow_direction = math_pi_26.get(value142)
            if m_env_light_shadow_direction then
                cvar_mat_postprocess_enable = globals_tickinterval_14.get_prop(value143, "m_envLightShadowDirection")
                if (cvar_mat_postprocess_enable ~= 0) then
                    globals_tickinterval_14.set_prop(value143, "m_envLightShadowDirection", 0, 0, 0)
                end
                math_pi_26.set(state_44.visuals.post_processing, false)
                state96 = state_43
                state96.force_sunset_once = true
                cvar_mat_postprocess_enable = cvar.mat_postprocess_enable
                cvar_mat_postprocess_enable.set_int(cvar_mat_postprocess_enable, 0)
            else
                if state_43.force_sunset_once then
                    globals_tickinterval_14.set_prop(value143, "m_envLightShadowDirection", state_43.cache_sun_loc[1], state_43.cache_sun_loc[2], state_43.cache_sun_loc[3])
                    math_pi_26.set(state_44.visuals.post_processing, true)
                    state96 = state_43
                    state96.force_sunset_once = false
                    cvar_mat_postprocess_enable = cvar.mat_postprocess_enable
                    cvar_mat_postprocess_enable.set_int(cvar_mat_postprocess_enable, 1)
                end
            end
            return
        end
    end
    entries30(cvars.fog_enable, cvars.fog_enable_water_fog)
    do
        local globals_tickinterval_15, value_68, value_69
        globals_tickinterval_15 = absoluteframetime
        value_68 = entries29
        value_69 = helpers.handle_value_33
        entries30 = function()
            local local_player = globals_tickinterval_15.get_local_player()
            value_68()
            local alive = globals_tickinterval_15.is_alive(local_player)
            if (not alive) then
                return
            end
            value_69(local_player)
            return
        end
    end
    do
        local create_component_6
        do
            local value_70, value_71
            value_70 = entries5
            value_71 = amount3
            create_component_6 = function()
                local tickbase_diff_2 = nil
                local state96 = value_70
                state96.tickbase_diff = tickbase_diff_2
                state96 = value_70
                state96.tickbase_max = tickbase_diff_2
                state96 = value_70
                state96.old_tick_count = 0
                state96 = value_70
                state96.cur = 0
                state96 = value_70
                state96.banana = false
                state96 = value_70
                state96.bomb_defused = false
                state96 = value_70
                state96.bomb_exploded = false
                local state_97 = {}
                local cur = {}
                state_97.cur = cur
                cur = {}
                state_97.prev = cur
                cur = {}
                local state_98 = {}
                table.clear(value_71)
                return
            end
        end
        reset = create_component_6
    end
    reset()
    do
        local value_72
        value_72 = entries5
        cvars.fog_enable = function(command)
            local current_cmd_2 = command.command_number
            local state96 = value_72
            state96.current_cmd = current_cmd_2
            return
        end
    end
    do
        local state_45, globals_tickinterval_16, string_upper_17
        state_45 = entries5
        globals_tickinterval_16 = absoluteframetime
        string_upper_17 = byte
        cvars.fog_enable_water_fog = function(current_cmd_2)
            local globals_tickinterval_get_prop, tickbase_diff_2, globals_tickinterval_get_prop_2, amount4,
                  state96
            local state_97 = current_cmd_2
            current_cmd_2 = nil
            if (state_97.command_number == state_45.current_cmd) then
                state96 = state_45
                state96.current_cmd = current_cmd_2
                globals_tickinterval_get_prop = globals_tickinterval_16.get_prop
                tickbase_diff_2 = globals_tickinterval_16.get_local_player()
                globals_tickinterval_get_prop = globals_tickinterval_get_prop(tickbase_diff_2, "m_nTickBase")
                if (state_45.tickbase_max ~= current_cmd_2) then
                    tickbase_diff_2 = (globals_tickinterval_get_prop - state_45.tickbase_max)
                    state96 = state_45
                    state96.tickbase_diff = tickbase_diff_2
                end
                tickbase_diff_2 = string_upper_17.max
                globals_tickinterval_get_prop_2 = globals_tickinterval_get_prop
                amount4 = state_45.tickbase_max
                if (not amount4) then
                    amount4 = 0
                end
                tickbase_diff_2 = tickbase_diff_2(globals_tickinterval_get_prop_2, amount4)
                state96 = state_45
                state96.tickbase_max = tickbase_diff_2
            end
            return
        end
    end
    do
        local string_upper_18, renderer_world_to_screen_15
        string_upper_18 = byte
        renderer_world_to_screen_15 = blur
        cvars.cl_csm_shadows = function(value142)
            local string_upper_floor = string_upper_18.floor
            local tick_interval = renderer_world_to_screen_15.tickinterval()
            return string_upper_floor((0.5 + (value142 / tick_interval)))
        end
    end
    do
        local renderer_world_to_screen_16
        renderer_world_to_screen_16 = blur
        cvars.cl_csm_world_shadows = function(value142)
            local tick_interval = renderer_world_to_screen_16.tickinterval()
            return (tick_interval * value142)
        end
    end
    do
        local value_73
        value_73 = entries5
        cvars.cl_foot_contact_shadows = function()
            local state96 = value_73
            state96.fire_total_hits = 0
            state96 = value_73
            state96.post_total_hits = 0
            state96 = value_73
            state96.mode = "back"
            state96 = value_73
            state96.landing = false
            reset()
            return
        end
    end
    do
        local value_74, math_pi_27, state_46, state_47, renderer_world_to_screen_17, string_upper_19,
              globals_tickinterval_17, require_tohex_7, value_75
        value_74 = entries22
        math_pi_27 = abs
        state_46 = entries18
        state_47 = entries5
        renderer_world_to_screen_17 = blur
        string_upper_19 = byte
        globals_tickinterval_17 = absoluteframetime
        require_tohex_7 = arshift
        value_75 = value4
        cvars.cl_csm_viewmodel_shadows = function(event)
            local fire_total_hits, piValue2, tick_count, string_upper_min, string_upper_max,
                  pose_parameter, require_tohex_format, entries48, player_name, amount4, amount5,
                  amount6, value142, value143, state96
            if (not event) then
                return
            end
            rage_fired = true
            fire_total_hits = value_74
            piValue2 = math_pi_27.get(state_46.misc[2])
            fire_total_hits = fire_total_hits(piValue2, "fire")
            if fire_total_hits then
                fire_total_hits = state_47.hitgroup_names[event.hitgroup]
                if (not fire_total_hits) then
                    fire_total_hits = "?"
                end
                piValue2 = event.target
                tick_count = renderer_world_to_screen_17.tickcount()
                tick_count = (tick_count - event.tick)
                string_upper_min = string_upper_19.min
                string_upper_max = string_upper_19.max
                pose_parameter = globals_tickinterval_17.get_prop(piValue2, "m_flPoseParameter", 11)
                string_upper_max = string_upper_max(((pose_parameter * 120) - 60), (-58))
                string_upper_min = string_upper_min(string_upper_max, 58)
                string_upper_max = g_notify
                pose_parameter = string_upper_max
                string_upper_max = string_upper_max.add
                require_tohex_format = require_tohex_7.format
                entries48 = "fired at %s's %s for %i damage (%d%%) bt=%i (%ims) body=%i\194\186"
                player_name = globals_tickinterval_17.get_player_name(event.target)
                amount4 = fire_total_hits
                amount5 = event.damage
                amount6 = event.hit_chance
                value142 = tick_count
                value143 = value_75((tick_count * 1000))
                require_tohex_format = require_tohex_format(entries48, player_name, amount4, amount5, amount6, value142, value143, string_upper_min)
                entries48 = {}
                player_name = 210
                amount4 = 210
                amount5 = 255
                amount6 = 255
                entries48[1] = player_name
                entries48[2] = amount4
                entries48[3] = amount5
                entries48[4] = amount6
                string_upper_max(pose_parameter, require_tohex_format, entries48, 5, nil, "fire")
            end
            fire_total_hits = globals_tickinterval_17.get_prop
            piValue2 = globals_tickinterval_17.get_local_player()
            fire_total_hits = fire_total_hits(piValue2, "m_totalHitsOnServer")
            state96 = state_47
            state96.fire_total_hits = fire_total_hits
            fire_total_hits = renderer_world_to_screen_17.realtime()
            state96 = state_47
            state96.handle_time = fire_total_hits
            return
        end
    end
    do
        local value_76, math_pi_28, state_48, globals_tickinterval_18, state_49, entity_set_prop_10,
              require_tohex_8
        value_76 = entries22
        math_pi_28 = abs
        state_48 = entries18
        globals_tickinterval_18 = absoluteframetime
        state_49 = entries5
        entity_set_prop_10 = get_all
        require_tohex_8 = arshift
        cvars.cl_csm_rope_shadows = function(event)
            local local_player, piValue2, userid_to_entindex, userid_to_entindex_2, g_notify_add,
                  piValue3, formatted_text_2, entries48, player_name, amount4, amount5, amount6
            if (not event) then
                local_player = value_76
                piValue2 = math_pi_28.get(state_48.misc[2])
                local_player = local_player(piValue2, "damage")
                if (not local_player) then
                    local_player = value_76
                    piValue2 = math_pi_28.get(state_48.misc[2])
                    local_player = local_player(piValue2, "hurt")
                    if (not local_player) then
                        local_player = value_76
                        piValue2 = math_pi_28.get(state_48.misc[2])
                        local_player = local_player(piValue2, "hurt self")
                        if (not local_player) then
                            goto branch_1
                        end
                    end
                end
                return
            end
            ::branch_1::
            local_player = globals_tickinterval_18.get_local_player()
            piValue2 = state_49.hitgroup_names[event.hitgroup]
            if (not piValue2) then
                piValue2 = "?"
            end
            userid_to_entindex = entity_set_prop_10.userid_to_entindex(event.userid)
            userid_to_entindex_2 = entity_set_prop_10.userid_to_entindex(event.attacker)
            if (userid_to_entindex_2 == local_player) then
                g_notify_add = value_76
                piValue3 = math_pi_28.get(state_48.misc[2])
                g_notify_add = g_notify_add(piValue3, "damage")
                if g_notify_add then
                    g_notify_add = g_notify
                    piValue3 = g_notify_add
                    g_notify_add = g_notify_add.add
                    formatted_text_2 = require_tohex_8.format
                    entries48 = "hit %s in the %s for %d damage (%d health remaining)"
                    player_name = globals_tickinterval_18.get_player_name(userid_to_entindex)
                    formatted_text_2 = formatted_text_2(entries48, player_name, piValue2, event.dmg_health, event.health)
                    entries48 = {}
                    player_name = 255
                    amount4 = 255
                    amount5 = 255
                    amount6 = 255
                    entries48[1] = player_name
                    entries48[2] = amount4
                    entries48[3] = amount5
                    entries48[4] = amount6
                    g_notify_add(piValue3, formatted_text_2, entries48, 5)
                end
            else
                if ((userid_to_entindex_2 == 0) and (userid_to_entindex == local_player)) then
                    g_notify_add = value_76
                    piValue3 = math_pi_28.get(state_48.misc[2])
                    g_notify_add = g_notify_add(piValue3, "hurt self")
                    if g_notify_add then
                        g_notify_add = g_notify
                        piValue3 = g_notify_add
                        g_notify_add = g_notify_add.add
                        formatted_text_2 = require_tohex_8.format("hurt yourself in the %s for %d damage (%d health remaining)", piValue2, event.dmg_health, event.health)
                        entries48 = {}
                        player_name = 255
                        amount4 = 255
                        amount5 = 255
                        amount6 = 255
                        entries48[1] = player_name
                        entries48[2] = amount4
                        entries48[3] = amount5
                        entries48[4] = amount6
                        g_notify_add(piValue3, formatted_text_2, entries48, 5)
                    end
                else
                    if ((userid_to_entindex_2 ~= 0) and (userid_to_entindex == local_player)) then
                        g_notify_add = value_76
                        piValue3 = math_pi_28.get(state_48.misc[2])
                        g_notify_add = g_notify_add(piValue3, "hurt")
                        if g_notify_add then
                            g_notify_add = g_notify
                            piValue3 = g_notify_add
                            g_notify_add = g_notify_add.add
                            formatted_text_2 = require_tohex_8.format
                            entries48 = "hurt by %s in the %s for %d damage (%d health remaining)"
                            player_name = globals_tickinterval_18.get_player_name(userid_to_entindex_2)
                            formatted_text_2 = formatted_text_2(entries48, player_name, piValue2, event.dmg_health, event.health)
                            entries48 = {}
                            player_name = 255
                            amount4 = 255
                            amount5 = 255
                            amount6 = 255
                            entries48[1] = player_name
                            entries48[2] = amount4
                            entries48[3] = amount5
                            entries48[4] = amount6
                            g_notify_add(piValue3, formatted_text_2, entries48, 5)
                        end
                    end
                end
            end
            return
        end
    end
    do
        local value_77, math_pi_29, state_50, state_51, globals_tickinterval_19,
              renderer_world_to_screen_18, require_tohex_9
        value_77 = entries22
        math_pi_29 = abs
        state_50 = entries18
        state_51 = entries5
        globals_tickinterval_19 = absoluteframetime
        renderer_world_to_screen_18 = blur
        require_tohex_9 = arshift
        cvars.cl_csm_sprite_shadows = function(event)
            local post_total_hits, piValue2, formatted_text_2, entries48, amount4, amount5, amount6,
                  amount7, state96
            if (not event) then
                post_total_hits = value_77
                piValue2 = math_pi_29.get(state_50.misc[2])
                post_total_hits = post_total_hits(piValue2, "miss")
                if post_total_hits then
                    return
                end
            end
            post_total_hits = globals_tickinterval_19.get_prop
            piValue2 = globals_tickinterval_19.get_local_player()
            post_total_hits = post_total_hits(piValue2, "m_totalHitsOnServer")
            state96 = state_51
            state96.post_total_hits = post_total_hits
            if (event.reason == "?") then
                if (state_51.post_total_hits == (state_51.fire_total_hits + 1)) then
                    if (state_51.post_total_hits < 255) then
                        if (state_51.fire_total_hits < 255) then
                            event.reason = "godmode"
                        end
                    end
                else
                    post_total_hits = renderer_world_to_screen_18.realtime()
                    if (0.5 <= (post_total_hits - state_51.handle_time)) then
                        event.reason = "delay"
                    end
                end
            end
            post_total_hits = g_notify
            piValue2 = post_total_hits
            post_total_hits = post_total_hits.add
            formatted_text_2 = require_tohex_9.format("missed shot due to %s", event.reason)
            entries48 = {}
            amount4 = 255
            amount5 = 255
            amount6 = 255
            amount7 = 255
            entries48[1] = amount4
            entries48[2] = amount5
            entries48[3] = amount6
            entries48[4] = amount7
            post_total_hits(piValue2, formatted_text_2, entries48, 5)
            return
        end
    end
    do
        local value_78, math_pi_30, state_52, require_tohex_10, globals_tickinterval_20
        value_78 = entries22
        math_pi_30 = abs
        state_52 = entries18
        require_tohex_10 = arshift
        globals_tickinterval_20 = absoluteframetime
        cvars.cl_csm_translucent_shadows = function(event)
            local require_tohex_format, entries48, player_name, lower, amount4, amount5
            local g_notify_add = value_78
            local piValue2 = math_pi_30.get(state_52.misc[2])
            g_notify_add = g_notify_add(piValue2, "fire")
            if (not g_notify_add) then
                return
            end
            g_notify_add = g_notify
            piValue2 = g_notify_add
            g_notify_add = g_notify_add.add
            require_tohex_format = require_tohex_10.format
            entries48 = "fired at %s's %s for %i damage (%d%%) bt=? (?ms) body=?\194\186 s=dormant"
            player_name = globals_tickinterval_20.get_player_name(event.userid)
            lower = require_tohex_10.lower(event.aim_hitbox)
            require_tohex_format = require_tohex_format(entries48, player_name, lower, event.dmg_health, (event.accuracy * 100))
            entries48 = {}
            player_name = 210
            lower = 210
            amount4 = 255
            amount5 = 255
            entries48[1] = player_name
            entries48[2] = lower
            entries48[3] = amount4
            entries48[4] = amount5
            g_notify_add(piValue2, require_tohex_format, entries48, 5, nil, "fire")
            return
        end
    end
    do
        local value_79, math_pi_31, state_53, require_tohex_11, globals_tickinterval_21, entity_set_prop_11
        value_79 = entries22
        math_pi_31 = abs
        state_53 = entries18
        require_tohex_11 = arshift
        globals_tickinterval_21 = absoluteframetime
        entity_set_prop_11 = get_all
        cvars.cl_csm_entity_shadows = function(event)
            local require_tohex_format, entries48, player_name, lower, amount4, amount5
            local g_notify_add = value_79
            local piValue2 = math_pi_31.get(state_53.misc[2])
            g_notify_add = g_notify_add(piValue2, "miss")
            if (not g_notify_add) then
                return
            end
            g_notify_add = g_notify
            piValue2 = g_notify_add
            g_notify_add = g_notify_add.add
            require_tohex_format = require_tohex_11.format
            entries48 = "fired at %s's %s for ? damage (%d%%) bt=? (?ms) body=?\194\186 s=dormant"
            player_name = globals_tickinterval_21.get_player_name(event.userid)
            lower = require_tohex_11.lower(event.aim_hitbox)
            require_tohex_format = require_tohex_format(entries48, player_name, lower, (event.accuracy * 100))
            entries48 = {}
            player_name = 210
            lower = 210
            amount4 = 255
            amount5 = 255
            entries48[1] = player_name
            entries48[2] = lower
            entries48[3] = amount4
            entries48[4] = amount5
            g_notify_add(piValue2, require_tohex_format, entries48, 5)
            g_notify_add = entity_set_prop_11.delay_call
            piValue2 = 0.5
            do
                local function update_state_6()
                    local state96 = g_notify
                    state96.add(state96, "missed shot due to dormant", nil, 5)
                    return
                end
                g_notify_add(piValue2, update_state_6)
            end
            return
        end
    end
    do
        local state_54
        state_54 = entries5
        cvars.cl_csm_world_shadows_in_viewmodelcascade = function(value142)
            if (not value142) then
                return false
            end
            return (state_54.mode ~= "back")
        end
    end
    do
        local require_17, globals_tickinterval_22, entity_set_prop_12, string_upper_20, state_55
        require_17 = require_3
        globals_tickinterval_22 = absoluteframetime
        entity_set_prop_12 = get_all
        string_upper_20 = byte
        state_55 = entries5
        helpers.handle_value_34 = function(value142, command)
            local class_name
            local value143 = command
            command = value142
            value142 = nil
            local entries48 = {}
            local entity_set_prop_eye_position = "CWorld"
            local eye_x = "CCSPlayer"
            local eye_x_2 = "CFuncBrush"
            local entity_set_prop_camera_angles = "CPhysicsPropMultiplayer"
            local pitch = "CBaseEntity"
            local sine = "CC4"
            entries48[1] = entity_set_prop_eye_position
            entries48[2] = eye_x
            entries48[3] = eye_x_2
            entries48[4] = entity_set_prop_camera_angles
            entries48[5] = pitch
            entries48[6] = sine
            entity_set_prop_eye_position = require_17(globals_tickinterval_22.get_origin(value143))
            local_origin = entity_set_prop_eye_position
            entity_set_prop_eye_position = entity_set_prop_12.eye_position
            entity_set_prop_eye_position, eye_x, eye_x_2 = entity_set_prop_eye_position()
            entity_set_prop_camera_angles = entity_set_prop_12.camera_angles
            entity_set_prop_camera_angles, pitch = entity_set_prop_camera_angles()
            sine = string_upper_20.sin(string_upper_20.rad(entity_set_prop_camera_angles))
            local cosine = string_upper_20.cos(string_upper_20.rad(entity_set_prop_camera_angles))
            local sine_2 = string_upper_20.sin(string_upper_20.rad(pitch))
            local cosine_2 = string_upper_20.cos(string_upper_20.rad(pitch))
            local entries49 = {}
            local entity_set_prop_trace_line = (cosine * cosine_2)
            local trace_fraction = (cosine * sine_2)
            local entity_set_prop_eye_position_2 = (-sine)
            entries49[1] = entity_set_prop_trace_line
            entries49[2] = trace_fraction
            entries49[3] = entity_set_prop_eye_position_2
            entity_set_prop_trace_line = entity_set_prop_12.trace_line
            trace_fraction = value143
            entity_set_prop_eye_position_2 = entity_set_prop_eye_position
            local string_upper_abs = eye_x
            local eye_x_3 = eye_x_2
            local count_2 = (entity_set_prop_eye_position + (entries49[1] * 8192))
            local amount4 = (eye_x + (entries49[2] * 8192))
            local index6 = (eye_x_2 + (entries49[3] * 8192))
            entity_set_prop_trace_line, trace_fraction = entity_set_prop_trace_line(trace_fraction, entity_set_prop_eye_position_2, string_upper_abs, eye_x_3, count_2, amount4, index6)
            entity_set_prop_eye_position_2 = true
            if (((trace_fraction == (-1)) or (trace_fraction == value142)) or (value143 == value142)) then
                return
            end
            string_upper_abs = require_17(globals_tickinterval_22.get_origin(trace_fraction))
            object_origin = string_upper_abs
            string_upper_abs = string_upper_20.abs
            eye_x_3 = local_origin
            string_upper_abs = string_upper_abs(eye_x_3.dist2d(eye_x_3, object_origin))
            string_upper_abs = (150 < string_upper_abs)
            if (trace_fraction ~= value142) then
                eye_x_3 = 0
                count_2 = (#entries48)
                amount4 = 1
                for index6 = eye_x_3, count_2, amount4 do
                    class_name = globals_tickinterval_22.get_classname(trace_fraction)
                    if (class_name == entries48[index6]) then
                        entity_set_prop_eye_position_2 = false
                    end
                end
            end
            if string_upper_abs then
                entity_set_prop_eye_position_2 = false
            end
            if (not entity_set_prop_eye_position_2) then
                if (not state_55.is_defusing) then
                    if command.in_use then
                        command.in_use = 0
                    end
                end
            end
            return
        end
    end
    do
        local globals_tickinterval_23, require_18
        globals_tickinterval_23 = absoluteframetime
        require_18 = require_3
        helpers.handle_value_35 = function(entity_index, value142)
            local dormant, state96, value143, state_97
            if value142 then
                dormant = globals_tickinterval_23.is_dormant(value142)
                if (not dormant) then
                    goto branch_1
                end
            end
            do
                return
            end
            ::branch_1::
            dormant = require_18(globals_tickinterval_23.get_origin(value142))
            state96 = require_18(globals_tickinterval_23.get_origin(entity_index))
            value143 = state96.dist2d(state96, dormant)
            if (1400 < value143) then
                state_97 = require_18(globals_tickinterval_23.get_prop(entity_index, "m_vecVelocity"))
                state_97 = state_97.length2d(state_97)
                if (state_97 <= 150) then
                    return true
                end
            end
            return false
        end
    end
    do
        local globals_tickinterval_24, require_19
        globals_tickinterval_24 = absoluteframetime
        require_19 = require_3
        helpers.handle_value_36 = function(player_index, value142, value143)
            local dormant, state96, weapon, state_97, globals_tickinterval_get_prop, value144, class_name
            if value142 then
                dormant = globals_tickinterval_24.is_dormant(value142)
                if (not dormant) then
                    goto branch_1
                end
            end
            do
                return
            end
            ::branch_1::
            dormant = {}
            dormant = {globals_tickinterval_24.get_origin(value142)}
            state96 = {}
            state96 = {globals_tickinterval_24.get_origin(player_index)}
            weapon = globals_tickinterval_24.get_player_weapon(player_index)
            if (state96[3] > (dormant[3] + 55)) then
                state_97 = require_19
                globals_tickinterval_get_prop = globals_tickinterval_24.get_prop
                value144 = player_index
                class_name = "m_vecVelocity"
                state_97 = state_97(globals_tickinterval_get_prop(value144, class_name))
                state_97 = state_97.length2d(state_97)
                if (state_97 <= 60) then
                    goto branch_2
                end
                if (value143.in_duck == 1) then
                    goto branch_2
                end
            end
            if (not (value143.in_duck == 1)) then
                goto branch_3
            end
            class_name = globals_tickinterval_24.get_classname(weapon)
            ::branch_2::
            if (class_name == "CKnife") then
                return true
            end
            ::branch_3::
            return false
        end
    end
    do
        local globals_tickinterval_25, entity_set_prop_13, string_upper_21, cvar_r_drawtracers_firstperson
        globals_tickinterval_25 = absoluteframetime
        entity_set_prop_13 = get_all
        string_upper_21 = byte
        cvar_r_drawtracers_firstperson = cvars.cl_csm_world_shadows
        helpers.handle_value_37 = function(entity_index, entity_index_2)
            local entries48, entries49, entries50, entries51, entries52, abs_2, abs_3,
                  string_upper_abs, abs_4, entries53, entries_54, entity_set_prop_trace_line, abs_5,
                  entity_set_prop_trace_line_2, abs_6, entity_set_prop_trace_line_3, abs_7,
                  entity_set_prop_trace_line_4, abs_8, abs_9, abs_10, abs_11, abs_12, abs_13, abs_14,
                  abs_15, abs_16, abs_17, abs_18, abs_19, abs_20, abs_21, abs_22, abs_23, abs_24, abs_25,
                  abs_26, abs_27, abs_28, abs_29, abs_30, abs_31, abs_32, abs_33, abs_34, abs_35, abs_36,
                  abs_37, abs_38, abs_39, abs_40, abs_41, abs_42, abs_43, abs_44, abs_45, abs_46, abs_47
            if entity_index_2 then
                entries48 = globals_tickinterval_25.is_dormant(entity_index_2)
                if (not entries48) then
                    goto branch_1
                end
            end
            do
                return
            end
            ::branch_1::
            entries48 = {}
            entries48 = {globals_tickinterval_25.get_origin(entity_index_2)}
            entries49 = {}
            entries49 = {globals_tickinterval_25.get_prop(entity_index_2, "m_vecViewOffset")}
            entries50 = {}
            entries50 = {entity_set_prop_13.eye_position()}
            entries51 = {}
            entries52 = (entries48[1] + entries49[1])
            abs_2 = (entries48[2] + entries49[2])
            abs_3 = (entries48[3] + entries49[3])
            entries51[1] = entries52
            entries51[2] = abs_2
            entries51[3] = abs_3
            entries52 = {}
            abs_2 = string_upper_21.abs((entries51[1] - entries50[1]))
            abs_3 = string_upper_21.abs((entries51[2] - entries50[2]))
            string_upper_abs = string_upper_21.abs
            abs_4 = (entries51[3] - entries50[3])
            string_upper_abs, abs_4, entries53, entries_54, entity_set_prop_trace_line, abs_5, entity_set_prop_trace_line_2, abs_6, entity_set_prop_trace_line_3, abs_7, entity_set_prop_trace_line_4, abs_8, abs_9, abs_10, abs_11, abs_12, abs_13, abs_14, abs_15, abs_16, abs_17, abs_18, abs_19, abs_20, abs_21, abs_22, abs_23, abs_24, abs_25, abs_26, abs_27, abs_28, abs_29, abs_30, abs_31, abs_32, abs_33, abs_34, abs_35, abs_36, abs_37, abs_38, abs_39, abs_40, abs_41, abs_42, abs_43, abs_44, abs_45, abs_46, abs_47 = string_upper_abs(abs_4)
            entries52[1] = abs_2
            entries52[2] = abs_3
            entries52[3] = string_upper_abs
            entries52[4] = abs_4
            entries52[5] = entries53
            entries52[6] = entries_54
            entries52[7] = entity_set_prop_trace_line
            entries52[8] = abs_5
            entries52[9] = entity_set_prop_trace_line_2
            entries52[10] = abs_6
            entries52[11] = entity_set_prop_trace_line_3
            entries52[12] = abs_7
            entries52[13] = entity_set_prop_trace_line_4
            entries52[14] = abs_8
            entries52[15] = abs_9
            entries52[16] = abs_10
            entries52[17] = abs_11
            entries52[18] = abs_12
            entries52[19] = abs_13
            entries52[20] = abs_14
            entries52[21] = abs_15
            entries52[22] = abs_16
            entries52[23] = abs_17
            entries52[24] = abs_18
            entries52[25] = abs_19
            entries52[26] = abs_20
            entries52[27] = abs_21
            entries52[28] = abs_22
            entries52[29] = abs_23
            entries52[30] = abs_24
            entries52[31] = abs_25
            entries52[32] = abs_26
            entries52[33] = abs_27
            entries52[34] = abs_28
            entries52[35] = abs_29
            entries52[36] = abs_30
            entries52[37] = abs_31
            entries52[38] = abs_32
            entries52[39] = abs_33
            entries52[40] = abs_34
            entries52[41] = abs_35
            entries52[42] = abs_36
            entries52[43] = abs_37
            entries52[44] = abs_38
            entries52[45] = abs_39
            entries52[46] = abs_40
            entries52[47] = abs_41
            entries52[48] = abs_42
            entries52[49] = abs_43
            entries52[50] = abs_44
            entries52[51] = abs_45
            entries52[52] = abs_46
            entries52[53] = abs_47
            abs_2 = string_upper_21.abs((entries52[1] + entries52[2]))
            if (425 < abs_2) then
                return
            end
            abs_3 = {}
            abs_3 = {globals_tickinterval_25.get_prop(entity_index, "m_vecVelocity")}
            string_upper_abs = {}
            string_upper_abs = {globals_tickinterval_25.get_prop(entity_index_2, "m_vecVelocity")}
            abs_4 = cvar_r_drawtracers_firstperson(16)
            entries53 = {}
            entries_54 = (entries50[1] + (abs_3[1] * abs_4))
            entity_set_prop_trace_line = (entries50[2] + (abs_3[2] * abs_4))
            abs_5 = (entries50[3] + (abs_3[3] * abs_4))
            entries53[1] = entries_54
            entries53[2] = entity_set_prop_trace_line
            entries53[3] = abs_5
            entries_54 = {}
            entity_set_prop_trace_line = (entries51[1] + (string_upper_abs[1] * abs_4))
            abs_5 = (entries51[2] + (string_upper_abs[2] * abs_4))
            entity_set_prop_trace_line_2 = (entries51[3] + (string_upper_abs[3] * abs_4))
            entries_54[1] = entity_set_prop_trace_line
            entries_54[2] = abs_5
            entries_54[3] = entity_set_prop_trace_line_2
            entity_set_prop_trace_line = entity_set_prop_13.trace_line
            abs_5 = entity_index
            entity_set_prop_trace_line_2 = entries53[1]
            abs_6 = entries53[2]
            entity_set_prop_trace_line_3 = entries53[3]
            abs_7 = entries_54[1]
            entity_set_prop_trace_line_4 = entries_54[2]
            abs_8 = entries_54[3]
            entity_set_prop_trace_line, abs_5 = entity_set_prop_trace_line(abs_5, entity_set_prop_trace_line_2, abs_6, entity_set_prop_trace_line_3, abs_7, entity_set_prop_trace_line_4, abs_8)
            entity_set_prop_trace_line_2 = entity_set_prop_13.trace_line
            abs_6 = entity_index
            entity_set_prop_trace_line_3 = entries_54[1]
            abs_7 = entries_54[2]
            entity_set_prop_trace_line_4 = entries_54[3]
            abs_8 = entries53[1]
            abs_9 = entries53[2]
            abs_10 = entries53[3]
            entity_set_prop_trace_line_2, abs_6 = entity_set_prop_trace_line_2(abs_6, entity_set_prop_trace_line_3, abs_7, entity_set_prop_trace_line_4, abs_8, abs_9, abs_10)
            entity_set_prop_trace_line_3 = entity_set_prop_13.trace_line
            abs_7 = entity_index
            entity_set_prop_trace_line_4 = entries50[1]
            abs_8 = entries50[2]
            abs_9 = entries50[3]
            abs_10 = entries51[1]
            abs_11 = entries51[2]
            abs_12 = entries51[3]
            entity_set_prop_trace_line_3, abs_7 = entity_set_prop_trace_line_3(abs_7, entity_set_prop_trace_line_4, abs_8, abs_9, abs_10, abs_11, abs_12)
            entity_set_prop_trace_line_4 = entity_set_prop_13.trace_line
            abs_8 = entity_index
            abs_9 = entries50[1]
            abs_10 = entries50[2]
            abs_11 = entries50[3]
            abs_12 = entries48[1]
            abs_13 = entries48[2]
            abs_14 = entries48[3]
            entity_set_prop_trace_line_4, abs_8 = entity_set_prop_trace_line_4(abs_8, abs_9, abs_10, abs_11, abs_12, abs_13, abs_14)
            abs_9 = ((abs_5 == entity_index_2) or (entity_set_prop_trace_line == 1))
            abs_10 = ((abs_6 == entity_index) or (entity_set_prop_trace_line_2 == 1))
            abs_11 = ((abs_7 == entity_index_2) or (entity_set_prop_trace_line_3 == 1))
            abs_12 = ((abs_8 == entity_index_2) or (entity_set_prop_trace_line_4 == 1))
            abs_13 = globals_tickinterval_25.get_player_weapon(entity_index_2)
            abs_14 = globals_tickinterval_25.get_classname(abs_13)
            if ((abs_14 == "CKnife") and (((abs_9 or abs_10) or abs_11) or abs_12)) then
                return true
            end
            return false
        end
    end
    local function open_discord()
    panorama_api.SteamOverlayAPI.OpenExternalBrowserURL(discord_url)
	end

	local discord_button = ui.new_button("AA", "Anti-aimbot angles", "more cracks - click on link", open_discord)
    lshift_2 = flush.lshift(1, 11)
    entries31 = entries5["hitflag_state"]
    if (not entries31) then
        entries31 = {}
        key = "any_prev"
        enabled_2 = false
        entries31[key] = enabled_2
        helpers.handle_value_38 = {}
        key = "per_ent_prev"
        entries31[key] = helpers.handle_value_38
        key = "first_until_tick"
        entries31[key] = 0
    end
    key = "hitflag_state"
    entries5[key] = entries31
    do
        local globals_tickinterval_26, state_56, renderer_world_to_screen_19, iterate_array_7,
              database_write, lshift_3
        globals_tickinterval_26 = absoluteframetime
        state_56 = entries5
        renderer_world_to_screen_19 = blur
        iterate_array_7 = iterate_array
        database_write = flush
        lshift_3 = lshift_2
        entries31 = function()
            local enabled_3, first_until_tick, tick_count, per_ent_prev, any_prev, new_with_existing,
                  new_first, enabled_4, value142, value143, key3, alive, esp_data_flags, band, value144,
                  value145, value146, index6, entry_2
            local players = globals_tickinterval_26.get_players(true)
            local state96 = state_56.hitflag_state
            local entries48 = state96.per_ent_prev
            if (not entries48) then
                entries48 = {}
            end
            enabled_3 = state96.any_prev
            if (not enabled_3) then
                enabled_3 = false
            end
            first_until_tick = state96.first_until_tick
            if (not first_until_tick) then
                first_until_tick = 0
            end
            tick_count = renderer_world_to_screen_19.tickcount()
            per_ent_prev = {}
            any_prev = false
            new_with_existing = false
            enabled_4 = false
            value142, value143, key3 = iterate_array_7(players)
            value144 = value142
            value145 = value143
            value146 = key3
            for index6, entry_2 in value144, value145, value146 do
                key3 = entry_2
                alive = globals_tickinterval_26.is_alive(key3)
                if alive then
                    alive = globals_tickinterval_26.is_dormant(key3)
                    if (not alive) then
                        alive = globals_tickinterval_26.get_esp_data(key3)
                        esp_data_flags = alive
                        if esp_data_flags then
                            esp_data_flags = alive.flags
                        end
                        if (not esp_data_flags) then
                            esp_data_flags = 0
                        end
                        band = database_write.band(esp_data_flags, lshift_3)
                        band = (band ~= 0)
                        per_ent_prev[key3] = band
                        if band then
                            any_prev = true
                            if (not entries48[key3]) then
                                if enabled_3 then
                                    new_with_existing = true
                                else
                                    enabled_4 = true
                                end
                            end
                        end
                    end
                end
            end
            if (not any_prev) then
                first_until_tick = 0
                new_first = false
            else
                if enabled_4 then
                    first_until_tick = (tick_count + 12)
                end
                if ((first_until_tick ~= 0) and (tick_count <= first_until_tick)) then
                    new_first = true
                else
                    new_first = false
                end
            end
            state96.per_ent_prev = per_ent_prev
            state96.any_prev = any_prev
            state96.any_now = any_prev
            state96.new_with_existing = new_with_existing
            state96.new_first = new_first
            state96.first_until_tick = first_until_tick
            return any_prev, new_with_existing, new_first
        end
    end
    do
        local math_pi_32, state_57, state_58, state_59
        math_pi_32 = abs
        state_57 = text5
        state_58 = entries5
        state_59 = entries18
        helpers.handle_value_38 = function(command)
            local state96
            local piValue2 = math_pi_32.get(state_57.anti_aim.other.ref_onshotantiaim[1])
            if piValue2 then
                piValue2 = math_pi_32.get(state_57.anti_aim.other.ref_onshotantiaim[2])
                if piValue2 then
                    state96 = state_58
                    state96.running_extended = false
                    return
                end
            end
            piValue2 = math_pi_32.get(state_57.rage.ref_doubletap[1])
            if (not piValue2) then
                piValue2 = math_pi_32.get(state_57.rage.ref_doubletap[2])
                if (not piValue2) then
                    state96 = state_58
                    state96.running_extended = false
                    return
                end
            end
            piValue2 = math_pi_32.get(state_59.misc[8])
            if (piValue2 == "safest") then
                state96 = state_58
                state96.defensive_risk = (-4)
            else
                piValue2 = math_pi_32.get(state_59.misc[8])
                if (piValue2 == "low") then
                    state96 = state_58
                    state96.defensive_risk = (-3)
                else
                    piValue2 = math_pi_32.get(state_59.misc[8])
                    if (piValue2 == "medium") then
                        state96 = state_58
                        state96.defensive_risk = (-2)
                    else
                        piValue2 = math_pi_32.get(state_59.misc[8])
                        if (piValue2 == "high") then
                            state96 = state_58
                            state96.defensive_risk = (-1)
                        end
                    end
                end
            end
            piValue2 = math_pi_32.get(state_59.misc[6])
            if (not piValue2) then
                piValue2 = math_pi_32.get(state_59.misc[7])
                if (not piValue2) then
                    goto branch_1
                end
                if (not state_58.hittable) then
                    goto branch_1
                end
            end
            state96 = state_58
            state96.running_extended = true
            command.force_defensive = 1
            if (not (state_58.tickbase_diff == state_58.defensive_risk)) then
                goto branch_2
            end
            math_pi_32.set(state_57.rage.ref_doubletap[1], false)
            command.force_defensive = 0
            goto branch_3
            ::branch_1::
            command.force_defensive = 0
            math_pi_32.set(state_57.rage.ref_doubletap[1], true)
            state96 = state_58
            state96.running_extended = false
            ::branch_2::
            ::branch_3::
            return
        end
    end
    do
        local state_60, require_20, math_pi_33, state_61
        state_60 = entries5
        require_20 = require_4
        math_pi_33 = abs
        state_61 = text5
        helpers.handle_value_39 = function(command)
            local piValue2
            print(state_60.tickbase_diff)
            local value142 = require_20.get_double_tap()
            if (not value142) then
                if (state_60.tickbase_diff == 1) then
                    goto branch_1
                end
                piValue2 = math_pi_33.get(state_61.rage.ref_doubletap[1])
                if (not piValue2) then
                    goto branch_1
                end
                piValue2 = math_pi_33.get(state_61.rage.ref_doubletap[2])
                if (not piValue2) then
                    goto branch_1
                end
            end
            command.force_defensive = 1
            if (not (state_60.tickbase_diff ~= 1)) then
                goto branch_2
            end
            math_pi_33.set(state_61.rage.ref_doubletap[1], false)
            goto branch_3
            ::branch_1::
            math_pi_33.set(state_61.rage.ref_doubletap[1], true)
            ::branch_2::
            ::branch_3::
            return
        end
    end
    do
        local value_80, database_write_2, state_62, value_81,
              cvar_cl_csm_world_shadows_in_viewmodelcascade_2, value_82, math_pi_34, entries_37, value_83,
              value_84, state_63, globals_tickinterval_27, require_21, iterate_array_8
        value_80 = helpers.handle_value_37
        database_write_2 = flush
        state_62 = entries5
        value_81 = helpers.handle_value_34
        cvar_cl_csm_world_shadows_in_viewmodelcascade_2 = cvars.cl_csm_world_shadows_in_viewmodelcascade
        value_82 = entries22
        math_pi_34 = abs
        entries_37 = entries18
        value_83 = helpers.handle_value_36
        value_84 = helpers.handle_value_35
        state_63 = text5
        globals_tickinterval_27 = absoluteframetime
        require_21 = require_3
        iterate_array_8 = iterate_array
        helpers.handle_value_40 = function(value142, value143, value144)
            local check, check_2, piValue2, check_3, check_4, state96, check_5, state_97, check_6,
                  check_7, check_8, check_9, check_10, state_98, check_11, entries48, text13, text14,
                  value145, value146, value147, index6, entry_2
            local value148 = value144
            value144 = value143
            value143 = value142
            value142 = nil
            local entries49 = {}
            local state_99 = {}
            state_99.index = 13
            state_99.condition = "backstab"
            do
                local value149, value150
                value149 = value144
                value150 = value148
                check = function()
                    return value_80(value149, value150)
                end
            end
            state_99.check = check
            check = {}
            check.index = 16
            check.condition = "legit"
            do
                local state_100, value151
                state_100 = value143
                value151 = value144
                check_2 = function()
                    if state_100.in_use == 1 or state_100.in_use == true then
                        if (not state_62.is_defusing) then
                            value_81(state_100, value151)
                            return true
                        end
                    end
                    return
                end
            end
            check.check = check_2
            check_2 = {}
            check_2.index = 11
            check_2.condition = "manual"
            do
                local function check_12()
                    local cvar_cl_csm_world_shadows_in_viewmodelcascade_3 = cvar_cl_csm_world_shadows_in_viewmodelcascade_2
                    local piValue3 = value_82
                    local piValue4 = math_pi_34.get(entries_37["anti-aim 2"][0])
                    piValue3 = piValue3(piValue4, "manual anti-aim")
                    if piValue3 then
                        piValue3 = math_pi_34.get(entries_37["anti-aim 2"][3])
                    end
                    cvar_cl_csm_world_shadows_in_viewmodelcascade_3 = cvar_cl_csm_world_shadows_in_viewmodelcascade_3(piValue3)
                    if cvar_cl_csm_world_shadows_in_viewmodelcascade_3 then
                        return true
                    end
                    return
                end
                check_2.check = check_12
            end
            piValue2 = {}
            piValue2.index = 14
            piValue2.condition = "height"
            do
                local value152, value153, value154
                value152 = value144
                value153 = value148
                value154 = value143
                check_3 = function()
                    return value_83(value152, value153, value154)
                end
            end
            piValue2.check = check_3
            check_3 = {}
            check_3.index = 15
            check_3.condition = "high distance"
            do
                local value155, value156
                value155 = value144
                value156 = value148
                check_4 = function()
                    return value_84(value155, value156)
                end
            end
            check_3.check = check_4
            check_4 = {}
            check_4.index = 12
            entries48 = check_4
            text13 = "condition"
            text14 = "freestanding"
            entries48[text13] = text14
            do
                local function check_13()
                    return false
                end
                check_4.check = check_13
            end
            state96 = {}
            state96.index = 9
            state96.condition = "in fake duck"
            do
                local value157
                value157 = value144
                check_5 = function()
                    local flags
                    local database_write_band = math_pi_34.get(state_63.rage.other.ref_fakeduck)
                    if database_write_band then
                        database_write_band = database_write_2.band
                        flags = globals_tickinterval_27.get_prop(value157, "m_fFlags")
                        database_write_band = database_write_band(flags, 1)
                        database_write_band = (database_write_band ~= 0)
                    end
                    return database_write_band
                end
            end
            state96.check = check_5
            check_5 = {}
            check_5.index = 10
            check_5.condition = "fakelag"
            do
                local function check_14()
                    local piValue3 = math_pi_34.get(state_63.rage.ref_doubletap[2])
                    piValue3 = (not piValue3)
                    if piValue3 then
                        piValue3 = math_pi_34.get(state_63.anti_aim.other.ref_onshotantiaim[2])
                        piValue3 = (not piValue3)
                    end
                    return piValue3
                end
                check_5.check = check_14
            end
            state_97 = {}
            state_97.index = 5
            state_97.condition = "in air"
            do
                local state_101
                state_101 = value143
                check_6 = function()
                    local value_161 = (state_62.jumping == true)
                    if (not value_161) then
                        value_161 = (state_62.on_ground == false)
                    end
                    if value_161 then
                        value_161 = (state_101.in_duck == 0)
                    end
                    return value_161
                end
            end
            state_97.check = check_6
            check_6 = {}
            check_6.index = 6
            check_6.condition = "in air duck"
            do
                local state_102
                state_102 = value143
                check_7 = function()
                    local value_161 = (state_62.jumping == true)
                    if (not value_161) then
                        value_161 = (state_62.on_ground == false)
                    end
                    if value_161 then
                        value_161 = (state_102.in_duck == 1)
                    end
                    return value_161
                end
            end
            check_6.check = check_7
            check_7 = {}
            check_7.index = 8
            check_7.condition = "in duck moving"
            do
                local state_103, value158
                state_103 = value143
                value158 = value144
                check_8 = function()
                    local state_105 = (state_103.in_duck == 1)
                    if state_105 then
                        state_105 = require_21(globals_tickinterval_27.get_prop(value158, "m_vecVelocity"))
                        state_105 = state_105.length2d(state_105)
                        state_105 = (1.1 < state_105)
                    end
                    return state_105
                end
            end
            check_7.check = check_8
            check_8 = {}
            check_8.index = 7
            check_8.condition = "in duck"
            do
                local state_104
                state_104 = value143
                check_9 = function()
                    return (state_104.in_duck == 1)
                end
            end
            check_8.check = check_9
            check_9 = {}
            check_9.index = 2
            check_9.condition = "standing"
            do
                local value159
                value159 = value144
                check_10 = function()
                    local state_105 = require_21(globals_tickinterval_27.get_prop(value159, "m_vecVelocity"))
                    state_105 = state_105.length2d(state_105)
                    return (state_105 < 1.1)
                end
            end
            check_9.check = check_10
            check_10 = {}
            check_10.index = 4
            check_10.condition = "slow motion"
            do
                local function check_15()
                    local piValue3 = math_pi_34.get(state_63.anti_aim.other.ref_slowmotion[1])
                    if piValue3 then
                        piValue3 = math_pi_34.get(state_63.anti_aim.other.ref_slowmotion[2])
                    end
                    return piValue3
                end
                check_10.check = check_15
            end
            state_98 = {}
            state_98.index = 3
            state_98.condition = "moving"
            do
                local value_160
                value_160 = value144
                check_11 = function()
                    local flags
                    local database_write_band = require_21(globals_tickinterval_27.get_prop(value_160, "m_vecVelocity"))
                    database_write_band = database_write_band.length2d(database_write_band)
                    database_write_band = (1.1 < database_write_band)
                    if database_write_band then
                        database_write_band = database_write_2.band
                        flags = globals_tickinterval_27.get_prop(value_160, "m_fFlags")
                        database_write_band = database_write_band(flags, 1)
                        database_write_band = (database_write_band == 1)
                    end
                    return database_write_band
                end
            end
            state_98.check = check_11
            entries49[1] = state_99
            entries49[2] = check
            entries49[3] = check_2
            entries49[4] = piValue2
            entries49[5] = check_3
            entries49[6] = check_4
            entries49[7] = state96
            entries49[8] = check_5
            entries49[9] = state_97
            entries49[10] = check_6
            entries49[11] = check_7
            entries49[12] = check_8
            entries49[13] = check_9
            entries49[14] = check_10
            entries49[15] = state_98
            state_99, check, check_2 = iterate_array_8(entries49)
            value145 = state_99
            value146 = check
            value147 = check_2
            for index6, entry_2 in value145, value146, value147 do
                check_2 = entry_2
                piValue2 = check_2.check()
                if piValue2 then
                    piValue2 = math_pi_34.get(entries_37["anti-aim"][0])
                    if (piValue2 == "gamesense") then
                        if (entries9 ~= value142) then
                            check_3 = math_pi_34.get
                            check_4 = check_2.index
                            check_3 = check_3(entries9[check_4][0])
                            if check_3 then
                                piValue2 = math_pi_34.get
                                check_3 = check_2.index
                                piValue2 = piValue2(entries9[check_3][12])
                                if piValue2 then
                                    piValue2 = math_pi_34.get(entries_37["anti-aim 2"][2])
                                    if piValue2 then
                                        piValue2 = math_pi_34.get(entries9[12][0])
                                        if piValue2 then
                                            return "freestanding", 12
                                        end
                                        return "freestanding", 1
                                    end
                                end
                                return check_2.condition, check_2.index
                            end
                        end
                    end
                end
            end
            if (entries9 ~= value142) then
                check = math_pi_34.get(entries9[1][0])
                if check then
                    return "global", 1
                end
            end
            return "invalid", (-1)
        end
    end
    do
        local state_64, value_85, math_pi_set_callback_2, math_pi_35, entries_38, state_65, string_upper_22,
              renderer_world_to_screen_20, value_86, callback_4
        state_64 = entries5
        value_85 = helpers.handle_value_40
        math_pi_set_callback_2 = math_pi_set_callback
        math_pi_35 = abs
        entries_38 = entries18
        state_65 = text5
        string_upper_22 = byte
        renderer_world_to_screen_20 = blur
        value_86 = math_pi_new_combobox
        callback_4 = math_pi_reference_2
        helpers.handle_value_41 = function(value142, command, value143, value144)
            local math_pi_set, math_pi_set_2, math_pi_get, math_pi_get_2, key3, value145, amount4,
                  reference, entries48, key4, amount5
            local value146 = value144
            value144 = value143
            value143 = command
            command = value142
            value142 = nil
            if (not value146) then
                return
            end
            math_pi_set, math_pi_set_2 = value_85(command, value143, value144)
            entries48 = state_64
            entries48.current_condition_index = math_pi_set_2
            entries48 = state_64
            entries48.current_condition = math_pi_set
            if (state_64.current_condition == "invalid") then
                math_pi_set_callback_2()
                return
            end
            math_pi_set = math_pi_35.get(entries_38["anti-aim"][0])
            if (math_pi_set == "gamesense") then
                math_pi_set = math_pi_35.set
                math_pi_set_2 = state_65.anti_aim.anti_aimbot_angles.ref_pitch[1]
                math_pi_get = math_pi_35.get
                math_pi_get_2 = state_64.current_condition_index
                math_pi_set(math_pi_set_2, math_pi_get(entries9[math_pi_get_2][1]))
                math_pi_set = math_pi_35.set
                math_pi_set_2 = state_65.anti_aim.anti_aimbot_angles.ref_pitch[2]
                math_pi_get = math_pi_35.get
                math_pi_get_2 = state_64.current_condition_index
                math_pi_set(math_pi_set_2, math_pi_get(entries9[math_pi_get_2][2]))
                math_pi_set = math_pi_35.set
                math_pi_set_2 = state_65.anti_aim.anti_aimbot_angles.ref_yaw_base
                math_pi_get = math_pi_35.get
                math_pi_get_2 = state_64.current_condition_index
                math_pi_set(math_pi_set_2, math_pi_get(entries9[math_pi_get_2][3]))
                math_pi_set = math_pi_35.set
                math_pi_set_2 = state_65.anti_aim.anti_aimbot_angles.ref_yaw[1]
                math_pi_get = math_pi_35.get
                math_pi_get_2 = state_64.current_condition_index
                math_pi_set(math_pi_set_2, math_pi_get(entries9[math_pi_get_2][4]))
                if (state_64.current_condition == "manual") then
                    math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_freestand[1], false)
                    if (state_64.mode == "left") then
                        math_pi_set = math_pi_35.set
                        math_pi_set_2 = state_65.anti_aim.anti_aimbot_angles.ref_yaw[2]
                        math_pi_get = math_pi_35.get(entries_38["anti-aim 2"][8])
                        math_pi_set(math_pi_set_2, (-math_pi_get))
                    else
                        if (state_64.mode == "right") then
                            math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_yaw[2], math_pi_35.get(entries_38["anti-aim 2"][9]))
                        else
                            if (state_64.mode == "forward") then
                                math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_yaw[2], 180)
                            end
                        end
                    end
                else
                    math_pi_set = math_pi_35.set
                    math_pi_set_2 = state_65.anti_aim.anti_aimbot_angles.ref_yaw[2]
                    math_pi_get = math_pi_35.get
                    math_pi_get_2 = state_64.current_condition_index
                    math_pi_set(math_pi_set_2, math_pi_get(entries9[math_pi_get_2][5]))
                end
                math_pi_set = string_upper_22.floor((state_64.fake_fakelag / 3))
                math_pi_set = ((math_pi_set % 2) == 1)
                math_pi_set_2 = math_pi_35.get
                math_pi_get = state_64.current_condition_index
                math_pi_set_2 = math_pi_set_2(entries9[math_pi_get][6])
                if (math_pi_set_2 ~= "slow") then
                    math_pi_set_2 = math_pi_35.set
                    math_pi_get = state_65.anti_aim.anti_aimbot_angles.ref_yaw_jitter[1]
                    math_pi_get_2 = math_pi_35.get
                    key3 = state_64.current_condition_index
                    math_pi_set_2(math_pi_get, math_pi_get_2(entries9[key3][6]))
                    math_pi_set_2 = math_pi_35.set
                    math_pi_get = state_65.anti_aim.anti_aimbot_angles.ref_yaw_jitter[2]
                    math_pi_get_2 = math_pi_35.get
                    key3 = state_64.current_condition_index
                    math_pi_set_2(math_pi_get, math_pi_get_2(entries9[key3][7]))
                    math_pi_set_2 = math_pi_35.set
                    math_pi_get = state_65.anti_aim.anti_aimbot_angles.ref_body_yaw[1]
                    math_pi_get_2 = math_pi_35.get
                    key3 = state_64.current_condition_index
                    math_pi_set_2(math_pi_get, math_pi_get_2(entries9[key3][8]))
                    math_pi_set_2 = math_pi_35.set
                    math_pi_get = state_65.anti_aim.anti_aimbot_angles.ref_body_yaw[2]
                    math_pi_get_2 = math_pi_35.get
                    key3 = state_64.current_condition_index
                    math_pi_set_2(math_pi_get, math_pi_get_2(entries9[key3][9]))
                else
                    math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_yaw_jitter[1], "Off")
                    math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_yaw_jitter[2], 0)
                    math_pi_set_2 = math_pi_35.set
                    math_pi_get = state_65.anti_aim.anti_aimbot_angles.ref_yaw[2]
                    math_pi_get_2 = math_pi_set
                    if math_pi_get_2 then
                        math_pi_get_2 = math_pi_35.get
                        key3 = state_64.current_condition_index
                        math_pi_get_2 = math_pi_get_2(entries9[key3][7])
                        math_pi_get_2 = ((-math_pi_get_2) / 2)
                    end
                    if (not math_pi_get_2) then
                        math_pi_get_2 = math_pi_35.get
                        key3 = state_64.current_condition_index
                        math_pi_get_2 = math_pi_get_2(entries9[key3][7])
                        math_pi_get_2 = (math_pi_get_2 / 2)
                    end
                    math_pi_set_2(math_pi_get, math_pi_get_2)
                    math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_body_yaw[1], "static")
                    math_pi_set_2 = math_pi_35.set
                    math_pi_get = state_65.anti_aim.anti_aimbot_angles.ref_body_yaw[2]
                    math_pi_get_2 = math_pi_set
                    if math_pi_get_2 then
                        math_pi_get_2 = (-60)
                    end
                    if (not math_pi_get_2) then
                        math_pi_get_2 = 60
                    end
                    math_pi_set_2(math_pi_get, math_pi_get_2)
                end
                math_pi_set_2 = math_pi_35.set
                math_pi_get = state_65.anti_aim.anti_aimbot_angles.ref_freestand_body
                math_pi_get_2 = math_pi_35.get
                key3 = state_64.current_condition_index
                math_pi_set_2(math_pi_get, math_pi_get_2(entries9[key3][10]))
                math_pi_set_2 = math_pi_35.set
                math_pi_get = state_65.anti_aim.anti_aimbot_angles.ref_edge_yaw
                math_pi_get_2 = math_pi_35.get
                key3 = state_64.current_condition_index
                math_pi_set_2(math_pi_get, math_pi_get_2(entries9[key3][11]))
                math_pi_set_2 = math_pi_35.set
                math_pi_get = state_65.anti_aim.anti_aimbot_angles.ref_roll
                math_pi_get_2 = math_pi_35.get
                key3 = state_64.current_condition_index
                math_pi_set_2(math_pi_get, math_pi_get_2(entries9[key3][13]))
                if (state_64.current_condition == "freestanding") then
                    math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_freestand[1], true)
                    math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_edge_yaw, false)
                else
                    math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_freestand[1], false)
                end
                math_pi_set_2 = math_pi_35.get
                math_pi_get = state_64.current_condition_index
                math_pi_set_2 = math_pi_set_2(entries9[math_pi_get][14])
                if math_pi_set_2 then
                    command.force_defensive = 1
                end
                math_pi_set_2 = renderer_world_to_screen_20.chokedcommands()
                if (math_pi_set_2 <= 1) then
                    if (state_64.tickbase_diff ~= value142) then
                        if (state_64.tickbase_diff < (-4)) then
                            math_pi_set_2 = state_64.current_condition_index
                            math_pi_set_2 = entries9[math_pi_set_2]
                            math_pi_get = math_pi_35.get(math_pi_set_2[15])
                            math_pi_get_2 = math_pi_35.get(math_pi_set_2[16])
                            if ((math_pi_get ~= "off") and (math_pi_get ~= "zero")) then
                                math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_pitch[1], math_pi_get)
                            else
                                if (math_pi_get == "zero") then
                                    math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_pitch[1], "custom")
                                    math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_pitch[2], 0)
                                end
                            end
                            if (math_pi_get_2 ~= "off") then
                                math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_yaw[1], "180")
                                math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_yaw_jitter[1], "off")
                                if (math_pi_get_2 == "forward") then
                                    math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_yaw[2], 180)
                                else
                                    if (math_pi_get_2 == "spin") then
                                        key3 = math_pi_35.set
                                        value145 = state_65.anti_aim.anti_aimbot_angles.ref_yaw[2]
                                        amount4 = value_86
                                        reference = callback_4(state_64.yaw_increment_spin)
                                        key3(value145, amount4(reference, (-180), 180))
                                    else
                                        if (math_pi_get_2 == "jitter") then
                                            key3 = math_pi_35.set
                                            value145 = state_65.anti_aim.anti_aimbot_angles.ref_yaw[2]
                                            amount4 = state_64.banana
                                            if amount4 then
                                                amount4 = 90
                                            end
                                            if (not amount4) then
                                                amount4 = (-90)
                                            end
                                            key3(value145, amount4)
                                        else
                                            if (math_pi_get_2 == "opposite") then
                                                key3 = {}
                                                entries48 = key3
                                                key4 = "forward"
                                                amount5 = 0
                                                entries48[key4] = amount5
                                                key3.left = 90
                                                key3.right = (-90)
                                                value145 = key3[state_64.mode]
                                                if (value145 ~= value142) then
                                                    math_pi_35.set(state_65.anti_aim.anti_aimbot_angles.ref_yaw[2], value145)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                math_pi_set_2 = math_pi_35.set
                math_pi_get = state_65.anti_aim.anti_aimbot_angles.ref_yaw[1]
                math_pi_get_2 = math_pi_35.get
                key3 = state_64.current_condition_index
                math_pi_set_2(math_pi_get, math_pi_get_2(entries9[key3][4]))
            else
                math_pi_set = math_pi_35.get(entries_38["anti-aim"][0])
                if (math_pi_set == "wraith (dont use)") then
                    math_pi_set_callback_2()
                end
            end
            return
        end
    end
    do
        local require_22, globals_tickinterval_28, state_66
        require_22 = require_3
        globals_tickinterval_28 = absoluteframetime
        state_66 = entries5
        helpers.handle_value_42 = function(value142)
            local state96
            local value143 = value142
            value142 = nil
            local globals_tickinterval_get_prop = require_22(globals_tickinterval_28.get_origin(value143))
            local_origin = globals_tickinterval_get_prop
            local state_97 = require_22
            local globals_tickinterval_get_prop_2 = globals_tickinterval_28.get_prop
            local is_defusing = globals_tickinterval_28.get_all("CPlantedC4")
            state_97 = state_97(globals_tickinterval_get_prop_2(is_defusing[1], "m_vecOrigin"))
            if (state_97.x ~= value142) then
                globals_tickinterval_get_prop_2 = local_origin
                globals_tickinterval_get_prop_2 = globals_tickinterval_get_prop_2.dist(globals_tickinterval_get_prop_2, state_97)
                globals_tickinterval_get_prop = globals_tickinterval_get_prop_2
            else
                globals_tickinterval_get_prop = value142
            end
            globals_tickinterval_get_prop_2 = globals_tickinterval_28.get_prop(value143, "m_iTeamNum")
            is_defusing = ((globals_tickinterval_get_prop_2 == 3) and (globals_tickinterval_get_prop < 60))
            if is_defusing then
                is_defusing = (not state_66.bomb_defused)
            end
            if is_defusing then
                is_defusing = (not state_66.bomb_exploded)
            end
            state96 = state_66
            state96.is_defusing = is_defusing
            return
        end
    end
    cvars.cl_forwardspeed = cvar["cl_forwardspeed"]
    cvars.cl_forwardspeed = cvars.cl_forwardspeed["get_float"](cvars.cl_forwardspeed)
    cl_fwd = cvars.cl_forwardspeed
    CS_MIN_PEAK_SPEED = 120
    CS_MIN_DROP_ABS = 5
    cvars.cl_forwardspeed = entries5["cs_state"]
    if (not cvars.cl_forwardspeed) then
        cvars.cl_forwardspeed = {}
        key = "last_speed"
        cvars.cl_forwardspeed[key] = 0
    end
    key = "cs_state"
    entries5[key] = cvars.cl_forwardspeed
    do
        local create_component_7
        do
            local state_67, string_upper_23
            state_67 = entries5
            string_upper_23 = byte
            create_component_7 = function(value142, vector, value143)
                local state96, value144, distance, distance_2, value145, enabled_3, entries48, text13,
                      distance_3
                if ((not vector) or (not value143)) then
                    state96 = state_67.cs_state
                    state96.last_speed = 0
                    return false, false
                end
                state96 = vector.x
                value144 = vector.y
                distance = string_upper_23.sqrt(((state96 * state96) + (value144 * value144)))
                distance_2 = state_67.cs_state.last_speed
                if (not distance_2) then
                    distance_2 = distance
                end
                value145 = (distance_2 - distance)
                enabled_3 = false
                if (distance_2 >= CS_MIN_PEAK_SPEED) then
                    if (value145 >= CS_MIN_DROP_ABS) then
                        enabled_3 = true
                    end
                end
                entries48 = state_67.cs_state
                text13 = "last_speed"
                distance_3 = distance
                entries48[text13] = distance_3
                return false, enabled_3
            end
        end
        update_counter_strafe = create_component_7
    end
    do
        local globals_tickinterval_29, entity_set_prop_14, math_pi_36, state_68, state_69, state_70,
              state_71, database_write_3, state_72, value_87, value_88, renderer_world_to_screen_21,
              string_upper_24, value_89, require_23, value_90
        globals_tickinterval_29 = absoluteframetime
        entity_set_prop_14 = get_all
        math_pi_36 = abs
        state_68 = entries18
        state_69 = entries14
        state_70 = entries23
        state_71 = entries5
        database_write_3 = flush
        state_72 = text5
        value_87 = helpers.handle_value_38
        value_88 = helpers.handle_value_42
        renderer_world_to_screen_21 = blur
        string_upper_24 = byte
        value_89 = helpers.handle_value_41
        require_23 = require_3
        value_90 = entries31
        cvars.cl_forwardspeed = function(command)
            local string_upper_max, pose_parameter, is_defensive_forced, value142, state96
            local local_player = globals_tickinterval_29.get_local_player()
            local threat = entity_set_prop_14.current_threat()
            local current_desync = math_pi_36.get(state_68.debug[0])
            if current_desync then
                current_desync = state_69.is_hovered
                if current_desync then
                    goto branch_1
                end
            end
            current_desync = state_70.dragging
            ::branch_1::
            if current_desync then
                command.in_attack = false
            end
            current_desync = database_write_3.band
            string_upper_max = globals_tickinterval_29.get_prop(local_player, "m_fFlags")
            current_desync = current_desync(string_upper_max, 1)
            current_desync = (current_desync == 1)
            state96 = state_71
            state96.on_ground = current_desync
            current_desync = math_pi_36.get(state_72.misc.movement.ref_bhop)
            if current_desync then
                current_desync = (command.in_jump == 1)
            end
            state96 = state_71
            state96.jumping = current_desync
            current_desync = command.in_speed == 1 or command.in_speed == true
            state96 = state_71
            state96.in_speed = current_desync
            value_87(command)
            value_88(local_player)
            current_desync = renderer_world_to_screen_21.chokedcommands()
            if (current_desync == 0) then
                current_desync = string_upper_24.min
                string_upper_max = string_upper_24.max
                pose_parameter = globals_tickinterval_29.get_prop(local_player, "m_flPoseParameter", 11)
                string_upper_max = string_upper_max(((pose_parameter * 120) - 60), (-58))
                current_desync = current_desync(string_upper_max, 58)
                state96 = state_71
                state96.current_desync = current_desync
                current_desync = (0 < state_71.current_desync)
                if current_desync then
                    current_desync = string_upper_24.ceil(state_71.current_desync)
                end
                if (not current_desync) then
                    current_desync = string_upper_24.floor(state_71.current_desync)
                end
                state96 = state_71
                state96.current_desync = current_desync
            end
            current_desync = renderer_world_to_screen_21.chokedcommands()
            if (current_desync == 0) then
                current_desync = (state_71.fake_fakelag + 1)
                state96 = state_71
                state96.fake_fakelag = current_desync
                if (6 <= state_71.fake_fakelag) then
                    state96 = state_71
                    state96.fake_fakelag = 0
                end
            end
            value_89(command, local_player, threat, true)
            current_desync = math_pi_36.get(state_68.debug[7])
            if current_desync then
                current_desync = require_23(globals_tickinterval_29.get_prop(local_player, "m_vecVelocity"))
                string_upper_max = update_counter_strafe
                pose_parameter = command
                is_defensive_forced = current_desync
                value142 = state_71.on_ground
                if value142 then
                    value142 = (not state_71.jumping)
                end
                string_upper_max, pose_parameter = string_upper_max(pose_parameter, is_defensive_forced, value142)
                if (not pose_parameter) then
                    if (not command.quick_stop) then
                        goto branch_2
                    end
                end
                command.force_defensive = 1
            end
            ::branch_2::
            current_desync, string_upper_max, pose_parameter = value_90()
            state96 = state_71
            state96.hittable = current_desync
            if pose_parameter then
                command.force_defensive = 0
            end
            if string_upper_max then
                command.force_defensive = 1
            end
            is_defensive_forced = command.force_defensive
            state96 = state_71
            state96.is_defensive_forced = is_defensive_forced
            return
        end
    end
    do
        local state_73, math_pi_37, state_74, entity_set_prop_15
        state_73 = entries14
        math_pi_37 = abs
        state_74 = text5
        entity_set_prop_15 = get_all
        update_state_2 = function()
            local piValue2, entries48, entries49, entries50, entries51, amount4, amount5, state96
            if (not state_73.is_open) then
                state96 = state_73
                state96.mouse_press = false
                return
            end
            piValue2 = math_pi_37.get(state_74.misc.settings.ref_dpiscale)
            entries48 = {}
            entries48 = {math_pi_37.menu_size()}
            entries49 = {}
            entries49 = {math_pi_37.menu_position()}
            entries50 = {}
            entries50 = {math_pi_37.mouse_position()}
            entries51 = {}
            amount4 = 0
            amount5 = 0
            entries51[1] = amount4
            entries51[2] = amount5
            scale = entries51
            scale_x = 0
            if (piValue2 == "100%") then
                entries51 = {}
                amount4 = state_73.dpi_scaling_y[1][1]
                amount5 = state_73.dpi_scaling_y[1][2]
                entries51[1] = amount4
                entries51[2] = amount5
                scale = entries51
                scale_x = 76
            else
                if (piValue2 == "125%") then
                    entries51 = {}
                    amount4 = state_73.dpi_scaling_y[2][1]
                    amount5 = state_73.dpi_scaling_y[2][2]
                    entries51[1] = amount4
                    entries51[2] = amount5
                    scale = entries51
                    scale_x = 95
                else
                    if (piValue2 == "150%") then
                        entries51 = {}
                        amount4 = state_73.dpi_scaling_y[3][1]
                        amount5 = state_73.dpi_scaling_y[3][2]
                        entries51[1] = amount4
                        entries51[2] = amount5
                        scale = entries51
                        scale_x = 113
                    else
                        if (piValue2 == "175%") then
                            entries51 = {}
                            amount4 = state_73.dpi_scaling_y[4][1]
                            amount5 = state_73.dpi_scaling_y[4][2]
                            entries51[1] = amount4
                            entries51[2] = amount5
                            scale = entries51
                            scale_x = 132
                        else
                            if (piValue2 == "200%") then
                                entries51 = {}
                                amount4 = state_73.dpi_scaling_y[5][1]
                                amount5 = state_73.dpi_scaling_y[5][2]
                                entries51[1] = amount4
                                entries51[2] = amount5
                                scale = entries51
                                scale_x = 151
                            end
                        end
                    end
                end
            end
            entries51 = entity_set_prop_15.key_state(1)
            if entries51 then
                if (not state_73.mouse_press) then
                    state96 = state_73
                    state96.mouse_press = true
                    if (entries50[1] > (entries49[1] + 5)) then
                        if (entries50[1] < ((entries49[1] + 5) + scale_x)) then
                            if (entries50[2] > (entries49[2] + scale[1])) then
                                if (entries50[2] < (entries49[2] + scale[2])) then
                                    state96 = state_73
                                    state96.selected_gs_tab = true
                                end
                            else
                                if (not (entries50[2] > (entries49[2] + 19))) then
                                    if (entries50[2] < (entries49[2] + entries48[2])) then
                                        if (entries50[2] < (entries49[2] + scale[1])) then
                                            if (entries50[2] > (entries49[2] + scale[2])) then
                                                if (entries50[2] < (entries49[2] + entries48[2])) then
                                                    if (state_73.selected_gs_tab == true) then
                                                        state96 = state_73
                                                        state96.selected_gs_tab = false
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            else
                state96 = state_73
                state96.mouse_press = false
            end
            return
        end
    end
    do
        local globals_tickinterval_30, entries_39, entries_40, iterate_pairs_10, math_pi_38
        globals_tickinterval_30 = absoluteframetime
        entries_39 = entries5
        entries_40 = entries18
        iterate_pairs_10 = iterate_pairs
        math_pi_38 = abs
        update_state_3 = function()
            local mode, value142, value143, key3, entries48, value144, value145, value146, index6,
                  entry_2
            local globals_tickinterval_get_prop = globals_tickinterval_30.get_prop
            local left = globals_tickinterval_30.get_local_player()
            globals_tickinterval_get_prop = globals_tickinterval_get_prop(left, "m_MoveType")
            if (globals_tickinterval_get_prop == 8) then
                entries48 = entries_39
                entries48.current_condition_index = 17
                entries48 = entries_39
                entries48.current_condition = "noclip"
            end
            globals_tickinterval_get_prop = {}
            left = entries_40["anti-aim 2"][4]
            globals_tickinterval_get_prop.left = left
            left = entries_40["anti-aim 2"][5]
            globals_tickinterval_get_prop.right = left
            left = entries_40["anti-aim 2"][6]
            globals_tickinterval_get_prop.forward = left
            left = entries_40["anti-aim 2"][7]
            globals_tickinterval_get_prop.back = left
            left = nil
            mode, value142, value143 = iterate_pairs_10(globals_tickinterval_get_prop)
            value144 = mode
            value145 = value142
            value146 = value143
            for index6, entry_2 in value144, value145, value146 do
                value142 = index6
                value143 = entry_2
                key3 = math_pi_38.get(value143)
                if key3 then
                    key3 = (value142 .. "_ready")
                    if entries_39[key3] then
                        key3 = (value142 == entries_39.mode)
                        if key3 then
                            key3 = "back"
                        end
                        if (not key3) then
                            key3 = value142
                        end
                        left = key3
                        key3 = (value142 .. "_ready")
                        entries48 = entries_39
                        entries48[key3] = false
                    end
                end
                key3 = math_pi_38.get(value143)
                if (not key3) then
                    key3 = (value142 .. "_ready")
                    entries48 = entries_39
                    entries48[key3] = true
                end
            end
            mode = left
            if (not mode) then
                mode = entries_39.mode
            end
            entries48 = entries_39
            entries48.mode = mode
            return
        end
    end
    do
        local state_75, renderer_world_to_screen_22
        state_75 = entries5
        renderer_world_to_screen_22 = blur
        update_state_4 = function()
            local pulse = renderer_world_to_screen_22.tickcount()
            local state96 = state_75
            state96.cur = pulse
            if (state_75.cur > state_75.old_tick_count) then
                pulse = (not state_75.banana)
                state96 = state_75
                state96.banana = pulse
                pulse = (state_75.cur + 1)
                state96 = state_75
                state96.old_tick_count = pulse
            end
            pulse = (state_75.yaw_increment_spin + 20)
            state96 = state_75
            state96.yaw_increment_spin = pulse
            if (1080 <= state_75.yaw_increment_spin) then
                state96 = state_75
                state96.yaw_increment_spin = 0
            end
            if (state_75.started == 10) then
                if (10 <= state_75.pulse) then
                    pulse = (state_75.pulse + 2.5)
                    state96 = state_75
                    state96.pulse = pulse
                end
                if (240 <= state_75.pulse) then
                    state96 = state_75
                    state96.started = 1
                end
            end
            if (state_75.started == 1) then
                pulse = (state_75.pulse - 2.5)
                state96 = state_75
                state96.pulse = pulse
                if (state_75.pulse <= 10) then
                    state96 = state_75
                    state96.started = 10
                end
            end
            return
        end
    end
    do
        local string_upper_25, math_pi_reference_12
        string_upper_25 = byte
        math_pi_reference_12 = math_pi_reference_2
        helpers.handle_value_43 = function(value142, value143, value144, value145, value146, value147, value148, value149, value150)
            local handle_value_51, entries48, abs_2, abs_3, abs_4, entries49, entries50, count_2,
                  amount4, entries51, key3, amount5, index6, index7, count_3, amount6, index8, abs_5
            local value151 = value150
            value150 = value149
            value149 = value148
            value148 = value147
            value147 = value146
            value146 = value145
            value145 = value144
            value144 = value143
            value143 = value142
            value142 = nil
            if ((not ((value144 and value145) and value146)) or (not value147)) then
                return "none", 0, 0, 0
            end
            handle_value_51 = string_upper_25.abs
            entries48 = value143
            if (not entries48) then
                entries48 = 0
            end
            handle_value_51 = handle_value_51(entries48)
            if (handle_value_51 <= 60) then
                return "none", 0, 0, 0
            end
            function handle_value_51(value152, value153)
                return math_pi_reference_12((value152 - value153))
            end
            entries48 = {}
            abs_2 = value144
            abs_3 = value145
            abs_4 = value146
            entries49 = value147
            entries48[1] = abs_2
            entries48[2] = abs_3
            entries48[3] = abs_4
            entries48[4] = entries49
            abs_2 = string_upper_25.abs(handle_value_51(value144, value145))
            if ((((value148 ~= value142) and (value149 ~= value142)) and (value150 ~= value142)) and (value151 ~= value142)) then
                abs_3 = (not value148)
                if (not abs_3) then
                    abs_3 = (not value149)
                end
                if (not abs_3) then
                    abs_3 = (not value150)
                end
                if (not abs_3) then
                    abs_3 = (not value151)
                end
                if abs_3 then
                    return "DR", abs_2, 0, 0
                end
            end
            abs_3 = handle_value_51(value144, value146)
            abs_4 = handle_value_51(value145, value147)
            if (30 < abs_2) then
                entries49 = string_upper_25.abs(abs_3)
                if (entries49 < 15) then
                    entries50 = string_upper_25.abs(abs_4)
                    if (entries50 < 15) then
                        return "CR", abs_2, 2, 3
                    end
                end
            end
            entries49 = {}
            entries50 = {}
            count_2 = 1
            amount4 = 4
            entries51 = 1
            for key3 = count_2, amount4, entries51 do
                amount5 = entries48[key3]
                index7 = 1
                count_3 = (#entries49)
                amount6 = 1
                for index8 = index7, count_3, amount6 do
                    abs_5 = string_upper_25.abs(handle_value_51(amount5, entries49[index8]))
                    if (abs_5 < 15) then
                        entries50[key3] = index8
                        index6 = true
                        while (not index6) do
                            index7 = ((#entries49) + 1)
                            entries49[index7] = amount5
                            index7 = (#entries49)
                            entries50[key3] = index7
                            goto branch_1
                        end
                    end
                end
                ::branch_1::
            end
            count_2 = (#entries49)
            amount4 = 0
            entries51 = 1
            key3 = 3
            amount5 = 1
            for index6 = entries51, key3, amount5 do
                if (entries50[index6] ~= entries50[(index6 + 1)]) then
                    amount4 = (amount4 + 1)
                end
            end
            if (count_2 == 2) then
                entries51 = string_upper_25.abs(handle_value_51(entries49[1], entries49[2]))
                if (((30 < entries51) and (entries51 <= 150)) and (1 <= amount4)) then
                    return "SCR", abs_2, count_2, amount4
                end
            end
            if (count_2 ~= 3) then
                return "none", abs_2, count_2, amount4
            end
            entries51 = 1
            key3 = 3
            amount5 = 1
            for index6 = entries51, key3, amount5 do
                if (entries50[index6] == entries50[(index6 + 1)]) then
                    return "none", abs_2, count_2, amount4
                end
            end
            entries51 = {}
            key3 = false
            amount5 = false
            index6 = false
            entries51[1] = key3
            entries51[2] = amount5
            entries51[3] = index6
            key3 = 1
            amount5 = 4
            index6 = 1
            for index7 = key3, amount5, index6 do
                count_3 = entries50[index7]
                entries51[count_3] = true
            end
            if entries51[1] then
                if entries51[2] then
                    if entries51[3] then
                        goto branch_2
                    end
                end
            end
            key3 = "none"
            amount5 = abs_2
            index6 = count_2
            index7 = amount4
            do
                return key3, amount5, index6, index7
            end
            ::branch_2::
            do
                local callback10, entries52
                callback10 = handle_value_51
                entries52 = entries49
                count_3 = function()
                    local index9, entries53, key4, key_5, amount7, index10, abs_6, abs_7, abs_8
                    local amount_8 = 1
                    local amount_9 = 3
                    local amount_10 = 1
                    for index9 = amount_8, amount_9, amount_10 do
                        entries53 = {}
                        key4 = 1
                        key_5 = 3
                        amount7 = 1
                        for index10 = key4, key_5, amount7 do
                            if (index10 ~= index9) then
                                abs_6 = ((#entries53) + 1)
                                entries53[abs_6] = index10
                            end
                        end
                        key4 = entries53[1]
                        key_5 = entries53[2]
                        amount7 = callback10(entries52[key4], entries52[index9])
                        index10 = callback10(entries52[key_5], entries52[index9])
                        if ((amount7 * index10) < 0) then
                            abs_6 = string_upper_25.abs(amount7)
                            abs_7 = string_upper_25.abs(index10)
                            if ((((10 <= abs_6) and (abs_6 <= 110)) and (10 <= abs_7)) and (abs_7 <= 110)) then
                                abs_8 = string_upper_25.abs((abs_6 - abs_7))
                                if (abs_8 <= 10) then
                                    return true
                                end
                            end
                        end
                    end
                    return false
                end
            end
            amount6 = count_3()
            if (amount6 and (2 <= amount4)) then
                return "SR", abs_2, count_2, amount4
            end
            return "none", abs_2, count_2, amount4
        end
    end
    do
        local globals_tickinterval_31, iterate_array_9, value_91, require_24, string_upper_26,
              math_pi_reference_13, database_write_4
        globals_tickinterval_31 = absoluteframetime
        iterate_array_9 = iterate_array
        value_91 = value3
        require_24 = require_3
        string_upper_26 = byte
        math_pi_reference_13 = math_pi_reference_2
        database_write_4 = flush
        update_anti_aim = function(value142)
            local state96, cur, key3, is_dormant, simtime, simulation_time, simtime_2, is_defensive,
                  value143, value144, position_2, value145, amount4, amount5, abs_2, abs_3, entries48,
                  yaw_backwards, duck_amount, database_write_band, flags, stance, weapon, last_shot_time,
                  esp_flags, value146, valid_yaw, invalid_yaw, yaw, value147, enabled_3, entries49,
                  state_97, origin, entries50, key4, value148, value149, value150, value151, index6,
                  entry_2
            local value152 = value142
            value142 = nil
            local players = globals_tickinterval_31.get_players(true)
            if ((#players) == 0) then
                state96 = {}
                cur = {}
                state96.cur = cur
                cur = {}
                state96.prev = cur
                cur = {}
                state96.pre_prev = cur
                cur = {}
                state96.pre_pre_prev = cur
                entries6 = state96
                return
            end
            state96, cur, key3 = iterate_array_9(players)
            value149 = state96
            value150 = cur
            value151 = key3
            for index6, entry_2 in value149, value150, value151 do
                key3 = entry_2
                is_dormant = globals_tickinterval_31.is_alive(key3)
                if is_dormant then
                    is_dormant = globals_tickinterval_31.is_dormant(key3)
                    if (not is_dormant) then
                        is_dormant = globals_tickinterval_31.is_dormant(key3)
                        simtime = is_dormant
                        if simtime then
                            simtime = (-1)
                        end
                        if (not simtime) then
                            simtime = value_91
                            simulation_time = globals_tickinterval_31.get_prop(key3, "m_flSimulationTime")
                            if (not simulation_time) then
                                simulation_time = 0
                            end
                            simtime = simtime(simulation_time)
                        end
                        simulation_time = entries6.cur[key3]
                        simtime_2 = simulation_time
                        if simtime_2 then
                            simtime_2 = simulation_time.simtime
                        end
                        if (not simtime_2) then
                            simtime_2 = simtime
                        end
                        is_defensive = simulation_time
                        if is_defensive then
                            is_defensive = simulation_time.is_defensive
                        end
                        if (not is_defensive) then
                            is_defensive = false
                        end
                        value143 = simulation_time
                        if value143 then
                            value143 = simulation_time.prev_valid_sim
                        end
                        if (not value143) then
                            value143 = nil
                        end
                        if (not is_dormant) then
                            if ((not is_defensive) and (simtime < simtime_2)) then
                                is_defensive = true
                                value143 = simtime_2
                            end
                            if ((is_defensive and value143) and (simtime >= value143)) then
                                is_defensive = false
                                value143 = value142
                            end
                        end
                        value144 = require_24(globals_tickinterval_31.get_prop(value152, "m_vecOrigin"))
                        position_2 = require_24(globals_tickinterval_31.get_prop(key3, "m_angEyeAngles"))
                        value145 = require_24(globals_tickinterval_31.get_prop(key3, "m_vecOrigin"))
                        amount4 = position_2.x
                        if (not amount4) then
                            amount4 = 0
                        end
                        amount5 = simulation_time
                        if amount5 then
                            amount5 = simulation_time.pitch
                            if (not amount5) then
                                amount5 = 0
                            end
                        end
                        if (not amount5) then
                            amount5 = 0
                        end
                        abs_2 = string_upper_26.abs(amount4)
                        abs_2 = (60 < abs_2)
                        abs_3 = string_upper_26.abs(amount5)
                        abs_3 = (60 < abs_3)
                        if ((not abs_2) and (not is_defensive)) then
                            entries48 = entries6.prev
                            entries48[key3] = value142
                            entries48 = entries6.pre_prev
                            entries48[key3] = value142
                            entries48 = entries6.pre_pre_prev
                            entries48[key3] = value142
                        end
                        entries48 = string_upper_26.floor
                        yaw_backwards = math_pi_reference_13
                        duck_amount = position_2.y
                        database_write_band = calculate_angle(value144, value145)
                        entries48 = entries48(yaw_backwards((duck_amount - database_write_band)))
                        yaw_backwards = string_upper_26.floor(math_pi_reference_13(calculate_angle(value144, value145)))
                        duck_amount = globals_tickinterval_31.get_prop(key3, "m_flDuckAmount")
                        if (not duck_amount) then
                            duck_amount = 0
                        end
                        database_write_band = database_write_4.band
                        flags = globals_tickinterval_31.get_prop(key3, "m_fFlags")
                        if (not flags) then
                            flags = 0
                        end
                        database_write_band = database_write_band(flags, 1)
                        database_write_band = (database_write_band == 1)
                        flags = require_24(globals_tickinterval_31.get_prop(key3, "m_vecVelocity"))
                        flags = flags.length2d(flags)
                        stance = database_write_band
                        if stance then
                            stance = (duck_amount == 1)
                            if stance then
                                stance = "duck"
                            end
                            if (not stance) then
                                stance = (1.2 < flags)
                                if stance then
                                    stance = "running"
                                end
                                if (not stance) then
                                    stance = "standing"
                                end
                            end
                        end
                        if (not stance) then
                            stance = "air"
                        end
                        weapon = globals_tickinterval_31.get_player_weapon(key3)
                        last_shot_time = 0
                        if (weapon ~= value142) then
                            esp_flags = globals_tickinterval_31.get_prop(weapon, "m_fLastShotTime")
                            if (not esp_flags) then
                                esp_flags = 0
                            end
                            last_shot_time = esp_flags
                        end
                        esp_flags = globals_tickinterval_31.get_esp_data(key3)
                        esp_flags = esp_flags.flags
                        if (not esp_flags) then
                            esp_flags = 0
                        end
                        value146 = simulation_time
                        if value146 then
                            value146 = simulation_time.valid_yaw
                            if (not value146) then
                                value146 = simulation_time.yaw
                            end
                        end
                        if (not value146) then

                        end
                        if is_defensive then
                            invalid_yaw = entries48
                            valid_yaw = value142
                            yaw = entries48
                        else
                            valid_yaw = entries48
                            invalid_yaw = value142
                            yaw = entries48
                        end
                        value147 = ((not is_dormant) and (simtime ~= simtime_2))
                        enabled_3 = false
                        if (((value147 and (simulation_time ~= value142)) and abs_2) and abs_3) then
                            enabled_3 = true
                        end
                        if enabled_3 then
                            entries49 = entries6.pre_pre_prev
                            state_97 = entries6.pre_prev[key3]
                            entries49[key3] = state_97
                            entries49 = entries6.pre_prev
                            state_97 = entries6.prev[key3]
                            entries49[key3] = state_97
                            entries49 = entries6.prev
                            entries49[key3] = simulation_time
                        end
                        entries49 = entries6.cur
                        state_97 = {}
                        state_97.id = key3
                        origin = require_24(globals_tickinterval_31.get_origin(key3))
                        state_97.origin = origin
                        origin = position_2.x
                        state_97.pitch = origin
                        state_97.yaw = yaw
                        state_97.yaw_backwards = yaw_backwards
                        state_97.valid_yaw = valid_yaw
                        state_97.invalid_yaw = invalid_yaw
                        state_97.simtime = simtime
                        state_97.stance = stance
                        state_97.esp_flags = esp_flags
                        state_97.last_shot_time = last_shot_time
                        state_97.is_defensive = is_defensive
                        entries50 = state_97
                        key4 = "prev_valid_sim"
                        value148 = value143
                        entries50[key4] = value148
                        state_97.is_dormant = is_dormant
                        entries49[key3] = state_97
                    end
                end
            end
            return
        end
    end
    panorama_open = false
    do
        local math_pi_reference_14
        math_pi_reference_14 = math_pi_reference_2
        helpers.handle_value_44 = function(value142, value143)
            return math_pi_reference_14((value142 - value143))
        end
    end
    do
        local value_92, string_upper_27
        value_92 = helpers.handle_value_44
        string_upper_27 = byte
        helpers.handle_value_45 = function(value142, value143, value144, value145)
            local value146
            local value147 = value142
            local value148 = value_92(value143, value147)
            local value149 = value_92(value144, value147)
            local value150 = value_92(value145, value147)
            local amount4 = 0
            local abs_2 = 0
            do
                local function handle_value_51(value151)
                    local abs_3 = string_upper_27.abs(value151)
                    if (abs_3 > abs_2) then
                        amount4 = value151
                        abs_2 = abs_3
                    end
                    return
                end
                handle_value_51(value148)
                handle_value_51(value149)
                handle_value_51(value150)
            end
            return amount4
        end
    end
    do
        local value_93, value_94
        value_93 = helpers.handle_value_44
        value_94 = helpers.handle_value_45
        helpers.handle_value_46 = function(value142, value143, value144, value145, value146)
            if (value142 == "CR") then
                return value_93(value143, value144)
            end
            if (value142 == "SCR") then
                return value_94(value143, value144, value145, value146)
            end
            return 0
        end
    end
    do
        local globals_tickinterval_32, math_pi_39, value95, iterate_array_10, string_upper_28,
              math_pi_reference_15, renderer_world_to_screen_23, value96, panorama_open_2, to_number_3,
              value97, value98, state_76
        globals_tickinterval_32 = absoluteframetime
        math_pi_39 = abs
        value95 = entries18
        iterate_array_10 = iterate_array
        string_upper_28 = byte
        math_pi_reference_15 = math_pi_reference_2
        renderer_world_to_screen_23 = blur
        value96 = helpers.handle_value_43
        panorama_open_2 = loadstring
        to_number_3 = to_number_2
        value97 = helpers.handle_value_46
        value98 = text5
        state_76 = state2
        update_anti_aim_2 = function(value142)
            local value143, value144, globals_tickinterval_is_alive, count_2, math_pi_get,
                  iterate_array_18, globals_tickinterval_is_alive_2, key3, globals_tickinterval_is_alive_3,
                  globals_tickinterval_is_dormant, entries48, entries49, entries50, entries51,
                  anti_aim_type, yaw_delta, panorama_open_set, value145, text13, enabled_3,
                  panorama_open_set_2, math_pi_reference_17, renderer_world_to_screen_curtime, table_insert,
                  panorama_open_set_3, panorama_open_set_4, enabled_4, math_pi_reference_18, unpack_values,
                  unpack_values_2, unpack_values_3, unpack_values_4, unpack_values_5, unpack_values_6,
                  unpack_values_7, unpack_values_8, unpack_values_9, unpack_values_10, unpack_values_11,
                  unpack_values_12, unpack_values_13, unpack_values_14, unpack_values_15, unpack_values_16,
                  unpack_values_17, unpack_values_18, unpack_values_19, unpack_values_20, unpack_values_21,
                  unpack_values_22, unpack_values_23, unpack_values_24, unpack_values_25, unpack_values_26,
                  unpack_values_27, unpack_values_28, unpack_values_29, unpack_values_30, unpack_values_31,
                  panorama_open_5, unpack_values_32, unpack_values_33, unpack_values_34, unpack_values_35,
                  unpack_values_36, unpack_values_37, unpack_values_38, unpack_values_39, unpack_values_40,
                  iterate_array_19, unpack_values_41, unpack_values_42, unpack_values_43, unpack_values_44,
                  result_values, result_count, register_top
            local function pack_results(...)
                return select("#", ...), {...}
            end
            value143 = value142
            ::branch_1::
            value144 = value143
            ::branch_2::
            value143 = nil
            ::branch_3::
            panorama_open_5 = globals_tickinterval_32
            ::branch_4::
            globals_tickinterval_is_alive = panorama_open_5["is_alive"]
            ::branch_5::
            count_2 = value144
            ::branch_6::
            globals_tickinterval_is_alive = globals_tickinterval_is_alive(count_2)
            ::branch_7::
            if (not globals_tickinterval_is_alive) then
                goto branch_9
            end
            ::branch_8::
            goto branch_10
            ::branch_9::
            goto branch_700
            ::branch_10::
            panorama_open_5 = globals_tickinterval_32
            ::branch_11::
            globals_tickinterval_is_alive = panorama_open_5["get_players"]
            ::branch_12::
            count_2 = true
            ::branch_13::
            globals_tickinterval_is_alive = globals_tickinterval_is_alive(count_2)
            ::branch_14::
            count_2 = (#globals_tickinterval_is_alive)
            ::branch_15::
            if (count_2 == 0) then
                goto branch_17
            end
            ::branch_16::
            goto branch_18
            ::branch_17::
            goto branch_699
            ::branch_18::
            count_2 = function(value146)
                local value147, entries52, value148
                local function pack_results(...)
                    return select("#", ...), {...}
                end
                value147 = value146
                ::branch_1::
                entries52 = value147
                ::branch_2::
                ::branch_3::
                if (not entries52) then
                    goto branch_5
                end
                ::branch_4::
                goto branch_7
                ::branch_5::
                value148 = nil
                ::branch_6::
                do
                    return value148
                end
                ::branch_7::
                value148 = entries52["valid_yaw"]
                ::branch_8::
                if (not value148) then
                    goto branch_10
                end
                ::branch_9::
                goto branch_11
                ::branch_10::
                value148 = entries52["yaw"]
                ::branch_11::
                do
                    return value148
                end
                ::branch_12::
                do
                    return
                end
                ::branch_13::
            end
            ::branch_19::
            panorama_open_5 = math_pi_39
            ::branch_20::
            math_pi_get = panorama_open_5["get"]
            ::branch_21::
            panorama_open_5 = value95
            ::branch_22::
            iterate_array_18 = panorama_open_5["debug"]
            ::branch_23::
            iterate_array_18 = iterate_array_18[1]
            ::branch_24::
            math_pi_get = math_pi_get(iterate_array_18)
            ::branch_25::
            iterate_array_18 = iterate_array_10
            ::branch_26::
            globals_tickinterval_is_alive_2 = globals_tickinterval_is_alive
            ::branch_27::
            iterate_array_18, globals_tickinterval_is_alive_2, key3 = iterate_array_18(globals_tickinterval_is_alive_2)
            ::branch_28::
            iterate_array_19 = iterate_array_18
            ::branch_29::
            unpack_values_41 = globals_tickinterval_is_alive_2
            ::branch_30::
            unpack_values_42 = key3
            ::branch_31::
            goto branch_696
            ::branch_32::
            ::branch_33::
            key3 = unpack_values_44
            ::branch_34::
            panorama_open_5 = globals_tickinterval_32
            ::branch_35::
            globals_tickinterval_is_alive_3 = panorama_open_5["is_alive"]
            ::branch_36::
            globals_tickinterval_is_dormant = key3
            ::branch_37::
            globals_tickinterval_is_alive_3 = globals_tickinterval_is_alive_3(globals_tickinterval_is_dormant)
            ::branch_38::
            panorama_open_5 = globals_tickinterval_32
            ::branch_39::
            globals_tickinterval_is_dormant = panorama_open_5["is_dormant"]
            ::branch_40::
            entries48 = key3
            ::branch_41::
            globals_tickinterval_is_dormant = globals_tickinterval_is_dormant(entries48)
            ::branch_42::
            if globals_tickinterval_is_alive_3 then
                goto branch_44
            end
            ::branch_43::
            goto branch_696
            ::branch_44::
            if (not globals_tickinterval_is_dormant) then
                goto branch_46
            end
            ::branch_45::
            goto branch_696
            ::branch_46::
            panorama_open_5 = entries6
            ::branch_47::
            entries48 = panorama_open_5["cur"]
            ::branch_48::
            entries48 = entries48[key3]
            ::branch_49::
            panorama_open_5 = entries6
            ::branch_50::
            entries49 = panorama_open_5["prev"]
            ::branch_51::
            entries49 = entries49[key3]
            ::branch_52::
            panorama_open_5 = entries6
            ::branch_53::
            entries50 = panorama_open_5["pre_prev"]
            ::branch_54::
            entries50 = entries50[key3]
            ::branch_55::
            panorama_open_5 = entries6
            ::branch_56::
            entries51 = panorama_open_5["pre_pre_prev"]
            ::branch_57::
            entries51 = entries51[key3]
            ::branch_58::
            anti_aim_type = nil
            ::branch_59::
            ::branch_60::
            if (not (entries48 == value143)) then
                goto branch_62
            end
            ::branch_61::
            goto branch_63
            ::branch_62::
            goto branch_83
            ::branch_63::
            anti_aim_type = value143
            ::branch_64::
            yaw_delta = 0
            ::branch_65::
            panorama_open_5 = panorama_open_2
            ::branch_66::
            panorama_open_set = panorama_open_5["set"]
            ::branch_67::
            value145 = key3
            ::branch_68::
            text13 = "Force body yaw"
            ::branch_69::
            enabled_3 = false
            ::branch_70::
            panorama_open_set(value145, text13, enabled_3)
            ::branch_71::
            panorama_open_5 = panorama_open_2
            ::branch_72::
            panorama_open_set = panorama_open_5["set"]
            ::branch_73::
            value145 = key3
            ::branch_74::
            text13 = "Force body yaw value"
            ::branch_75::
            enabled_3 = 0
            ::branch_76::
            panorama_open_set(value145, text13, enabled_3)
            ::branch_77::
            panorama_open_set = {}
            ::branch_78::
            panorama_open_set["anti_aim_type"] = anti_aim_type
            ::branch_79::
            panorama_open_set["yaw_delta"] = yaw_delta
            ::branch_80::
            panorama_open_5 = state_76
            ::branch_81::
            panorama_open_5[key3] = panorama_open_set
            ::branch_82::
            goto branch_696
            ::branch_83::
            if (not (entries49 == value143)) then
                goto branch_85
            end
            ::branch_84::
            goto branch_63
            ::branch_85::
            if (not (entries50 == value143)) then
                goto branch_87
            end
            ::branch_86::
            goto branch_63
            ::branch_87::
            if (not (entries51 == value143)) then
                goto branch_89
            end
            ::branch_88::
            goto branch_63
            ::branch_89::
            panorama_open_set = count_2
            ::branch_90::
            value145 = entries48
            ::branch_91::
            panorama_open_set = panorama_open_set(value145)
            ::branch_92::
            value145 = count_2
            ::branch_93::
            text13 = entries49
            ::branch_94::
            value145 = value145(text13)
            ::branch_95::
            text13 = count_2
            ::branch_96::
            enabled_3 = entries50
            ::branch_97::
            text13 = text13(enabled_3)
            ::branch_98::
            enabled_3 = count_2
            ::branch_99::
            panorama_open_set_2 = entries51
            ::branch_100::
            enabled_3 = enabled_3(panorama_open_set_2)
            ::branch_101::
            if panorama_open_set then
                goto branch_103
            end
            ::branch_102::
            goto branch_104
            ::branch_103::
            goto branch_119
            ::branch_104::
            anti_aim_type = value143
            ::branch_105::
            yaw_delta = 0
            ::branch_106::
            panorama_open_5 = panorama_open_2
            ::branch_107::
            panorama_open_set_2 = panorama_open_5["set"]
            ::branch_108::
            math_pi_reference_17 = key3
            ::branch_109::
            renderer_world_to_screen_curtime = "Force body yaw"
            ::branch_110::
            table_insert = false
            ::branch_111::
            panorama_open_set_2(math_pi_reference_17, renderer_world_to_screen_curtime, table_insert)
            ::branch_112::
            panorama_open_5 = panorama_open_2
            ::branch_113::
            panorama_open_set_2 = panorama_open_5["set"]
            ::branch_114::
            math_pi_reference_17 = key3
            ::branch_115::
            renderer_world_to_screen_curtime = "Force body yaw value"
            ::branch_116::
            table_insert = 0
            ::branch_117::
            panorama_open_set_2(math_pi_reference_17, renderer_world_to_screen_curtime, table_insert)
            ::branch_118::
            goto branch_77
            ::branch_119::
            if value145 then
                goto branch_121
            end
            ::branch_120::
            goto branch_104
            ::branch_121::
            if text13 then
                goto branch_123
            end
            ::branch_122::
            goto branch_104
            ::branch_123::
            if enabled_3 then
                goto branch_125
            end
            ::branch_124::
            goto branch_104
            ::branch_125::
            panorama_open_5 = string_upper_28
            ::branch_126::
            panorama_open_set_2 = panorama_open_5["abs"]
            ::branch_127::
            math_pi_reference_17 = math_pi_reference_15
            ::branch_128::
            renderer_world_to_screen_curtime = (panorama_open_set - value145)
            ::branch_129::
            result_count, result_values = pack_results(math_pi_reference_17(renderer_world_to_screen_curtime))
            register_top = ((21 + result_count) - 1)
            math_pi_reference_17, renderer_world_to_screen_curtime, table_insert, panorama_open_set_3, panorama_open_set_4, enabled_4, math_pi_reference_18, unpack_values, unpack_values_2, unpack_values_3, unpack_values_4, unpack_values_5, unpack_values_6, unpack_values_7, unpack_values_8, unpack_values_9, unpack_values_10, unpack_values_11, unpack_values_12, unpack_values_13, unpack_values_14, unpack_values_15, unpack_values_16, unpack_values_17, unpack_values_18, unpack_values_19, unpack_values_20, unpack_values_21, unpack_values_22, unpack_values_23, unpack_values_24, unpack_values_25, unpack_values_26, unpack_values_27, unpack_values_28, unpack_values_29, unpack_values_30, unpack_values_31, panorama_open_5, unpack_values_32, unpack_values_33, unpack_values_34, unpack_values_35, unpack_values_36, unpack_values_37, unpack_values_38, unpack_values_39, unpack_values_40, iterate_array_19, unpack_values_41, unpack_values_42, unpack_values_43, unpack_values_44 = unpack(result_values, 1, result_count)
            ::branch_130::
            panorama_open_set_2 = panorama_open_set_2(unpack({
                math_pi_reference_17,
                renderer_world_to_screen_curtime,
                table_insert,
                panorama_open_set_3,
                panorama_open_set_4,
                enabled_4,
                math_pi_reference_18,
                unpack_values,
                unpack_values_2,
                unpack_values_3,
                unpack_values_4,
                unpack_values_5,
                unpack_values_6,
                unpack_values_7,
                unpack_values_8,
                unpack_values_9,
                unpack_values_10,
                unpack_values_11,
                unpack_values_12,
                unpack_values_13,
                unpack_values_14,
                unpack_values_15,
                unpack_values_16,
                unpack_values_17,
                unpack_values_18,
                unpack_values_19,
                unpack_values_20,
                unpack_values_21,
                unpack_values_22,
                unpack_values_23,
                unpack_values_24,
                unpack_values_25,
                unpack_values_26,
                unpack_values_27,
                unpack_values_28,
                unpack_values_29,
                unpack_values_30,
                unpack_values_31,
                panorama_open_5,
                unpack_values_32,
                unpack_values_33,
                unpack_values_34,
                unpack_values_35,
                unpack_values_36,
                unpack_values_37,
                unpack_values_38,
                unpack_values_39,
                unpack_values_40,
                iterate_array_19,
                unpack_values_41,
                unpack_values_42,
                unpack_values_43,
                unpack_values_44
            }, 1, (register_top - 20)))
            ::branch_131::
            math_pi_reference_17 = math_pi_reference_15
            ::branch_132::
            renderer_world_to_screen_curtime = (panorama_open_set - value145)
            ::branch_133::
            math_pi_reference_17 = math_pi_reference_17(renderer_world_to_screen_curtime)
            ::branch_134::
            yaw_delta = math_pi_reference_17
            ::branch_135::
            math_pi_reference_17 = false
            ::branch_136::
            renderer_world_to_screen_curtime = entries48["last_shot_time"]
            ::branch_137::
            if (not (renderer_world_to_screen_curtime == value143)) then
                goto branch_139
            end
            ::branch_138::
            goto branch_160
            ::branch_139::
            panorama_open_5 = renderer_world_to_screen_23
            ::branch_140::
            renderer_world_to_screen_curtime = panorama_open_5["curtime"]
            ::branch_141::
            renderer_world_to_screen_curtime = renderer_world_to_screen_curtime()
            ::branch_142::
            table_insert = entries48["last_shot_time"]
            ::branch_143::
            renderer_world_to_screen_curtime = (renderer_world_to_screen_curtime - table_insert)
            ::branch_144::
            panorama_open_5 = renderer_world_to_screen_23
            ::branch_145::
            table_insert = panorama_open_5["tickinterval"]
            ::branch_146::
            table_insert = table_insert()
            ::branch_147::
            table_insert = (renderer_world_to_screen_curtime / table_insert)
            ::branch_148::
            panorama_open_5 = string_upper_28
            ::branch_149::
            panorama_open_set_3 = panorama_open_5["floor"]
            ::branch_150::
            panorama_open_5 = renderer_world_to_screen_23
            ::branch_151::
            panorama_open_set_4 = panorama_open_5["tickinterval"]
            ::branch_152::
            panorama_open_set_4 = panorama_open_set_4()
            ::branch_153::
            panorama_open_set_4 = (0.2 / panorama_open_set_4)
            ::branch_154::
            panorama_open_set_3 = panorama_open_set_3(panorama_open_set_4)
            ::branch_155::
            if (not (table_insert <= panorama_open_set_3)) then
                goto branch_157
            end
            ::branch_156::
            goto branch_158
            ::branch_157::
            panorama_open_set_3 = false
            goto branch_159
            ::branch_158::
            panorama_open_set_3 = true
            ::branch_159::
            math_pi_reference_17 = panorama_open_set_3
            ::branch_160::
            renderer_world_to_screen_curtime = entries48["is_defensive"]
            ::branch_161::
            renderer_world_to_screen_curtime = (not renderer_world_to_screen_curtime)
            ::branch_162::
            if (math_pi_get == "desync") then
                goto branch_164
            end
            ::branch_163::
            goto branch_165
            ::branch_164::
            goto branch_214
            ::branch_165::
            if (math_pi_get == "---") then
                goto branch_167
            end
            ::branch_166::
            goto branch_168
            ::branch_167::
            goto branch_197
            ::branch_168::
            if (math_pi_get == "off") then
                goto branch_170
            end
            ::branch_169::
            goto branch_77
            ::branch_170::
            table_insert = panorama_open
            ::branch_171::
            if table_insert then
                goto branch_173
            end
            ::branch_172::
            goto branch_77
            ::branch_173::
            anti_aim_type = value143
            ::branch_174::
            yaw_delta = 0
            ::branch_175::
            panorama_open_5 = math_pi_39
            ::branch_176::
            table_insert = panorama_open_5["set"]
            ::branch_177::
            panorama_open_5 = value98
            ::branch_178::
            panorama_open_set_3 = panorama_open_5["plist"]
            ::branch_179::
            panorama_open_set_3 = panorama_open_set_3["reset"]
            ::branch_180::
            panorama_open_set_4 = true
            ::branch_181::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_182::
            panorama_open_5 = panorama_open_2
            ::branch_183::
            table_insert = panorama_open_5["set"]
            ::branch_184::
            panorama_open_set_3 = key3
            ::branch_185::
            panorama_open_set_4 = "Force body yaw"
            ::branch_186::
            enabled_4 = false
            ::branch_187::
            table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4)
            ::branch_188::
            panorama_open_5 = panorama_open_2
            ::branch_189::
            table_insert = panorama_open_5["set"]
            ::branch_190::
            panorama_open_set_3 = key3
            ::branch_191::
            panorama_open_set_4 = "Force body yaw value"
            ::branch_192::
            enabled_4 = 0
            ::branch_193::
            table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4)
            ::branch_194::
            panorama_open_5 = false
            ::branch_195::
            panorama_open = panorama_open_5
            ::branch_196::
            goto branch_77
            ::branch_197::
            ::branch_198::
            ::branch_199::
            panorama_open_5 = true
            ::branch_200::
            panorama_open = panorama_open_5
            ::branch_201::
            panorama_open_5 = panorama_open_2
            ::branch_202::
            table_insert = panorama_open_5["set"]
            ::branch_203::
            panorama_open_set_3 = key3
            ::branch_204::
            panorama_open_set_4 = "Force body yaw"
            ::branch_205::
            enabled_4 = false
            ::branch_206::
            table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4)
            ::branch_207::
            panorama_open_5 = panorama_open_2
            ::branch_208::
            table_insert = panorama_open_5["set"]
            ::branch_209::
            panorama_open_set_3 = key3
            ::branch_210::
            panorama_open_set_4 = "Force body yaw value"
            ::branch_211::
            enabled_4 = 0
            ::branch_212::
            table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4)
            ::branch_213::
            goto branch_695
            ::branch_214::
            if renderer_world_to_screen_curtime then
                goto branch_216
            end
            ::branch_215::
            goto branch_165
            ::branch_216::
            panorama_open_5 = true
            ::branch_217::
            panorama_open = panorama_open_5
            ::branch_218::
            if math_pi_reference_17 then
                goto branch_220
            end
            ::branch_219::
            goto branch_221
            ::branch_220::
            goto branch_269
            ::branch_221::
            table_insert = entries48["valid_yaw"]
            ::branch_222::
            if (table_insert == value143) then
                goto branch_224
            end
            ::branch_223::
            goto branch_225
            ::branch_224::
            table_insert = false
            goto branch_226
            ::branch_225::
            table_insert = true
            ::branch_226::
            panorama_open_5 = entries49
            ::branch_227::
            panorama_open_5 = panorama_open_5["valid_yaw"]
            ::branch_228::
            panorama_open_set_3 = panorama_open_5
            ::branch_229::
            if (panorama_open_set_3 == value143) then
                goto branch_231
            end
            ::branch_230::
            goto branch_232
            ::branch_231::
            panorama_open_set_3 = false
            goto branch_233
            ::branch_232::
            panorama_open_set_3 = true
            ::branch_233::
            panorama_open_set_4 = entries50["valid_yaw"]
            ::branch_234::
            if (panorama_open_set_4 == value143) then
                goto branch_236
            end
            ::branch_235::
            goto branch_237
            ::branch_236::
            panorama_open_set_4 = false
            goto branch_238
            ::branch_237::
            panorama_open_set_4 = true
            ::branch_238::
            enabled_4 = entries51["valid_yaw"]
            ::branch_239::
            if (enabled_4 == value143) then
                goto branch_241
            end
            ::branch_240::
            goto branch_242
            ::branch_241::
            enabled_4 = false
            goto branch_243
            ::branch_242::
            enabled_4 = true
            ::branch_243::
            math_pi_reference_18 = value96
            ::branch_244::
            unpack_values = entries48["pitch"]
            ::branch_245::
            unpack_values_2 = panorama_open_set
            ::branch_246::
            unpack_values_3 = value145
            ::branch_247::
            unpack_values_4 = text13
            ::branch_248::
            unpack_values_5 = enabled_3
            ::branch_249::
            unpack_values_6 = table_insert
            ::branch_250::
            unpack_values_7 = panorama_open_set_3
            ::branch_251::
            unpack_values_8 = panorama_open_set_4
            ::branch_252::
            unpack_values_9 = enabled_4
            ::branch_253::
            math_pi_reference_18, unpack_values, unpack_values_2, unpack_values_3 = math_pi_reference_18(unpack_values, unpack_values_2, unpack_values_3, unpack_values_4, unpack_values_5, unpack_values_6, unpack_values_7, unpack_values_8, unpack_values_9)
            ::branch_254::
            if (not (math_pi_reference_18 == "CR")) then
                goto branch_256
            end
            ::branch_255::
            goto branch_257
            ::branch_256::
            goto branch_260
            ::branch_257::
            anti_aim_type = math_pi_reference_18
            ::branch_258::
            panorama_open_set_2 = unpack_values
            ::branch_259::
            goto branch_288
            ::branch_260::
            if (not (math_pi_reference_18 == "SCR")) then
                goto branch_262
            end
            ::branch_261::
            goto branch_257
            ::branch_262::
            if (not (math_pi_reference_18 == "SR")) then
                goto branch_264
            end
            ::branch_263::
            goto branch_257
            ::branch_264::
            if (math_pi_reference_18 == "DR") then
                goto branch_266
            end
            ::branch_265::
            goto branch_267
            ::branch_266::
            goto branch_257
            ::branch_267::
            anti_aim_type = value143
            ::branch_268::
            goto branch_288
            ::branch_269::
            panorama_open_5 = string_upper_28
            ::branch_270::
            table_insert = panorama_open_5["abs"]
            ::branch_271::
            panorama_open_5 = string_upper_28
            ::branch_272::
            panorama_open_set_3 = panorama_open_5["abs"]
            ::branch_273::
            panorama_open_set_4 = entries48["pitch"]
            ::branch_274::
            panorama_open_set_3 = panorama_open_set_3(panorama_open_set_4)
            ::branch_275::
            panorama_open_5 = string_upper_28
            ::branch_276::
            panorama_open_set_4 = panorama_open_5["abs"]
            ::branch_277::
            enabled_4 = entries49["pitch"]
            ::branch_278::
            panorama_open_set_4 = panorama_open_set_4(enabled_4)
            ::branch_279::
            panorama_open_set_3 = (panorama_open_set_3 - panorama_open_set_4)
            ::branch_280::
            table_insert = table_insert(panorama_open_set_3)
            ::branch_281::
            if (30 < table_insert) then
                goto branch_283
            end
            ::branch_282::
            goto branch_221
            ::branch_283::
            panorama_open_set_3 = entries48["pitch"]
            ::branch_284::
            panorama_open_set_4 = entries49["pitch"]
            ::branch_285::
            if (panorama_open_set_3 < panorama_open_set_4) then
                goto branch_287
            end
            ::branch_286::
            goto branch_221
            ::branch_287::
            anti_aim_type = "ON SHOT"
            ::branch_288::
            panorama_open_5 = math_pi_39
            ::branch_289::
            table_insert = panorama_open_5["get"]
            ::branch_290::
            panorama_open_5 = value95
            ::branch_291::
            panorama_open_set_3 = panorama_open_5["debug"]
            ::branch_292::
            panorama_open_set_3 = panorama_open_set_3[5]
            ::branch_293::
            table_insert = table_insert(panorama_open_set_3)
            ::branch_294::
            if table_insert then
                goto branch_296
            end
            ::branch_295::
            goto branch_297
            ::branch_296::
            goto branch_304
            ::branch_297::
            panorama_open_5 = panorama_open_2
            ::branch_298::
            table_insert = panorama_open_5["set"]
            ::branch_299::
            panorama_open_set_3 = key3
            ::branch_300::
            panorama_open_set_4 = "Add to whitelist"
            ::branch_301::
            enabled_4 = false
            ::branch_302::
            table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4)
            ::branch_303::
            goto branch_330
            ::branch_304::
            panorama_open_5 = math_pi_39
            ::branch_305::
            table_insert = panorama_open_5["get"]
            ::branch_306::
            panorama_open_5 = value95
            ::branch_307::
            panorama_open_set_3 = panorama_open_5["debug"]
            ::branch_308::
            panorama_open_set_3 = panorama_open_set_3[6]
            ::branch_309::
            table_insert = table_insert(panorama_open_set_3)
            ::branch_310::
            if table_insert then
                goto branch_312
            end
            ::branch_311::
            goto branch_297
            ::branch_312::
            if (not (anti_aim_type == "ON SHOT")) then
                goto branch_314
            end
            ::branch_313::
            goto branch_315
            ::branch_314::
            goto branch_322
            ::branch_315::
            panorama_open_5 = panorama_open_2
            ::branch_316::
            table_insert = panorama_open_5["set"]
            ::branch_317::
            panorama_open_set_3 = key3
            ::branch_318::
            panorama_open_set_4 = "Add to whitelist"
            ::branch_319::
            enabled_4 = false
            ::branch_320::
            table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4)
            ::branch_321::
            goto branch_330
            ::branch_322::
            if (not (anti_aim_type == value143)) then
                goto branch_324
            end
            ::branch_323::
            goto branch_315
            ::branch_324::
            panorama_open_5 = panorama_open_2
            ::branch_325::
            table_insert = panorama_open_5["set"]
            ::branch_326::
            panorama_open_set_3 = key3
            ::branch_327::
            panorama_open_set_4 = "Add to whitelist"
            ::branch_328::
            enabled_4 = true
            ::branch_329::
            table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4)
            ::branch_330::
            panorama_open_5 = text7
            ::branch_331::
            table_insert = panorama_open_5[key3]
            ::branch_332::
            if table_insert then
                goto branch_334
            end
            ::branch_333::
            goto branch_495
            ::branch_334::
            if (not (anti_aim_type == value143)) then
                goto branch_336
            end
            ::branch_335::
            goto branch_495
            ::branch_336::
            table_insert = entries48["stance"]
            ::branch_337::
            if (table_insert == "standing") then
                goto branch_339
            end
            ::branch_338::
            goto branch_340
            ::branch_339::
            goto branch_460
            ::branch_340::
            table_insert = entries48["stance"]
            ::branch_341::
            if (table_insert == "running") then
                goto branch_343
            end
            ::branch_342::
            goto branch_344
            ::branch_343::
            goto branch_424
            ::branch_344::
            table_insert = entries48["stance"]
            ::branch_345::
            if (table_insert == "air") then
                goto branch_347
            end
            ::branch_346::
            goto branch_348
            ::branch_347::
            goto branch_388
            ::branch_348::
            table_insert = entries48["stance"]
            ::branch_349::
            if (table_insert == "duck") then
                goto branch_351
            end
            ::branch_350::
            goto branch_495
            ::branch_351::
            panorama_open_5 = to_number_3
            ::branch_352::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_353::
            panorama_open_set_3 = panorama_open_set_3["duck"]
            ::branch_354::
            panorama_open_set_3 = (#panorama_open_set_3)
            ::branch_355::
            if (panorama_open_set_3 < 20) then
                goto branch_357
            end
            ::branch_356::
            goto branch_495
            ::branch_357::
            table_insert = _G["table"]
            ::branch_358::
            table_insert = table_insert["insert"]
            ::branch_359::
            panorama_open_5 = to_number_3
            ::branch_360::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_361::
            panorama_open_set_3 = panorama_open_set_3["duck_type"]
            ::branch_362::
            panorama_open_set_4 = anti_aim_type
            ::branch_363::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_364::
            if (anti_aim_type == "SR") then
                goto branch_366
            end
            ::branch_365::
            goto branch_367
            ::branch_366::
            goto branch_378
            ::branch_367::
            if (anti_aim_type == "CR") then
                goto branch_369
            end
            ::branch_368::
            goto branch_495
            ::branch_369::
            table_insert = _G["table"]
            ::branch_370::
            table_insert = table_insert["insert"]
            ::branch_371::
            panorama_open_5 = to_number_3
            ::branch_372::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_373::
            panorama_open_set_3 = panorama_open_set_3["duck"]
            ::branch_374::
            panorama_open_5 = panorama_open_set_2
            ::branch_375::
            panorama_open_set_4 = panorama_open_5
            ::branch_376::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_377::
            goto branch_495
            ::branch_378::
            if (5 < panorama_open_set_2) then
                goto branch_380
            end
            ::branch_379::
            goto branch_367
            ::branch_380::
            table_insert = _G["table"]
            ::branch_381::
            table_insert = table_insert["insert"]
            ::branch_382::
            panorama_open_5 = to_number_3
            ::branch_383::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_384::
            panorama_open_set_3 = panorama_open_set_3["duck"]
            ::branch_385::
            panorama_open_set_4 = panorama_open_set_2
            ::branch_386::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_387::
            goto branch_495
            ::branch_388::
            panorama_open_5 = to_number_3
            ::branch_389::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_390::
            panorama_open_set_3 = panorama_open_set_3["air"]
            ::branch_391::
            panorama_open_set_3 = (#panorama_open_set_3)
            ::branch_392::
            if (panorama_open_set_3 < 20) then
                goto branch_394
            end
            ::branch_393::
            goto branch_348
            ::branch_394::
            table_insert = _G["table"]
            ::branch_395::
            table_insert = table_insert["insert"]
            ::branch_396::
            panorama_open_5 = to_number_3
            ::branch_397::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_398::
            panorama_open_set_3 = panorama_open_set_3["air_type"]
            ::branch_399::
            panorama_open_set_4 = anti_aim_type
            ::branch_400::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_401::
            if (anti_aim_type == "SR") then
                goto branch_403
            end
            ::branch_402::
            goto branch_404
            ::branch_403::
            goto branch_414
            ::branch_404::
            if (anti_aim_type == "CR") then
                goto branch_406
            end
            ::branch_405::
            goto branch_495
            ::branch_406::
            table_insert = _G["table"]
            ::branch_407::
            table_insert = table_insert["insert"]
            ::branch_408::
            panorama_open_5 = to_number_3
            ::branch_409::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_410::
            panorama_open_set_3 = panorama_open_set_3["air"]
            ::branch_411::
            panorama_open_set_4 = panorama_open_set_2
            ::branch_412::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_413::
            goto branch_495
            ::branch_414::
            if (5 < panorama_open_set_2) then
                goto branch_416
            end
            ::branch_415::
            goto branch_404
            ::branch_416::
            table_insert = _G["table"]
            ::branch_417::
            table_insert = table_insert["insert"]
            ::branch_418::
            panorama_open_5 = to_number_3
            ::branch_419::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_420::
            panorama_open_set_3 = panorama_open_set_3["air"]
            ::branch_421::
            panorama_open_set_4 = panorama_open_set_2
            ::branch_422::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_423::
            goto branch_495
            ::branch_424::
            panorama_open_5 = to_number_3
            ::branch_425::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_426::
            panorama_open_set_3 = panorama_open_set_3["run"]
            ::branch_427::
            panorama_open_set_3 = (#panorama_open_set_3)
            ::branch_428::
            if (panorama_open_set_3 < 20) then
                goto branch_430
            end
            ::branch_429::
            goto branch_344
            ::branch_430::
            table_insert = _G["table"]
            ::branch_431::
            table_insert = table_insert["insert"]
            ::branch_432::
            panorama_open_5 = to_number_3
            ::branch_433::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_434::
            panorama_open_set_3 = panorama_open_set_3["run_type"]
            ::branch_435::
            panorama_open_set_4 = anti_aim_type
            ::branch_436::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_437::
            if (anti_aim_type == "SR") then
                goto branch_439
            end
            ::branch_438::
            goto branch_440
            ::branch_439::
            goto branch_450
            ::branch_440::
            if (anti_aim_type == "CR") then
                goto branch_442
            end
            ::branch_441::
            goto branch_495
            ::branch_442::
            table_insert = _G["table"]
            ::branch_443::
            table_insert = table_insert["insert"]
            ::branch_444::
            panorama_open_5 = to_number_3
            ::branch_445::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_446::
            panorama_open_set_3 = panorama_open_set_3["run"]
            ::branch_447::
            panorama_open_set_4 = panorama_open_set_2
            ::branch_448::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_449::
            goto branch_495
            ::branch_450::
            if (5 < panorama_open_set_2) then
                goto branch_452
            end
            ::branch_451::
            goto branch_440
            ::branch_452::
            table_insert = _G["table"]
            ::branch_453::
            table_insert = table_insert["insert"]
            ::branch_454::
            panorama_open_5 = to_number_3
            ::branch_455::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_456::
            panorama_open_set_3 = panorama_open_set_3["run"]
            ::branch_457::
            panorama_open_set_4 = panorama_open_set_2
            ::branch_458::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_459::
            goto branch_495
            ::branch_460::
            panorama_open_5 = to_number_3
            ::branch_461::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_462::
            panorama_open_set_3 = panorama_open_set_3["stand"]
            ::branch_463::
            panorama_open_set_3 = (#panorama_open_set_3)
            ::branch_464::
            if (panorama_open_set_3 < 20) then
                goto branch_466
            end
            ::branch_465::
            goto branch_340
            ::branch_466::
            table_insert = _G["table"]
            ::branch_467::
            table_insert = table_insert["insert"]
            ::branch_468::
            panorama_open_5 = to_number_3
            ::branch_469::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_470::
            panorama_open_set_3 = panorama_open_set_3["stand_type"]
            ::branch_471::
            panorama_open_set_4 = anti_aim_type
            ::branch_472::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_473::
            if (anti_aim_type == "SR") then
                goto branch_475
            end
            ::branch_474::
            goto branch_476
            ::branch_475::
            goto branch_486
            ::branch_476::
            if (anti_aim_type == "CR") then
                goto branch_478
            end
            ::branch_477::
            goto branch_495
            ::branch_478::
            table_insert = _G["table"]
            ::branch_479::
            table_insert = table_insert["insert"]
            ::branch_480::
            panorama_open_5 = to_number_3
            ::branch_481::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_482::
            panorama_open_set_3 = panorama_open_set_3["stand"]
            ::branch_483::
            panorama_open_set_4 = panorama_open_set_2
            ::branch_484::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_485::
            goto branch_495
            ::branch_486::
            if (5 < panorama_open_set_2) then
                goto branch_488
            end
            ::branch_487::
            goto branch_476
            ::branch_488::
            table_insert = _G["table"]
            ::branch_489::
            table_insert = table_insert["insert"]
            ::branch_490::
            panorama_open_5 = to_number_3
            ::branch_491::
            panorama_open_set_3 = panorama_open_5[key3]
            ::branch_492::
            panorama_open_set_3 = panorama_open_set_3["stand"]
            ::branch_493::
            panorama_open_set_4 = panorama_open_set_2
            ::branch_494::
            table_insert(panorama_open_set_3, panorama_open_set_4)
            ::branch_495::
            table_insert = entries48["pitch"]
            ::branch_496::
            if (78 <= table_insert) then
                goto branch_498
            end
            ::branch_497::
            goto branch_499
            ::branch_498::
            goto branch_512
            ::branch_499::
            panorama_open_5 = panorama_open_2
            ::branch_500::
            table_insert = panorama_open_5["set"]
            ::branch_501::
            panorama_open_set_3 = key3
            ::branch_502::
            panorama_open_set_4 = "Force body yaw"
            ::branch_503::
            enabled_4 = false
            ::branch_504::
            table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4)
            ::branch_505::
            panorama_open_5 = panorama_open_2
            ::branch_506::
            table_insert = panorama_open_5["set"]
            ::branch_507::
            panorama_open_set_3 = key3
            ::branch_508::
            panorama_open_set_4 = "Force body yaw value"
            ::branch_509::
            enabled_4 = 0
            ::branch_510::
            table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4)
            ::branch_511::
            goto branch_77
            ::branch_512::
            panorama_open_set_3 = entries49["pitch"]
            ::branch_513::
            if (78 < panorama_open_set_3) then
                goto branch_515
            end
            ::branch_514::
            goto branch_499
            ::branch_515::
            if (not (anti_aim_type == "SR")) then
                goto branch_517
            end
            ::branch_516::
            goto branch_518
            ::branch_517::
            goto branch_675
            ::branch_518::
            if (anti_aim_type == "DR") then
                goto branch_520
            end
            ::branch_519::
            goto branch_521
            ::branch_520::
            goto branch_641
            ::branch_521::
            if (not (anti_aim_type == "CR")) then
                goto branch_523
            end
            ::branch_522::
            goto branch_524
            ::branch_523::
            goto branch_575
            ::branch_524::
            table_insert = value97
            ::branch_525::
            panorama_open_5 = anti_aim_type
            ::branch_526::
            panorama_open_set_3 = panorama_open_5
            ::branch_527::
            panorama_open_set_4 = panorama_open_set
            ::branch_528::
            enabled_4 = value145
            ::branch_529::
            math_pi_reference_18 = text13
            ::branch_530::
            unpack_values = enabled_3
            ::branch_531::
            table_insert = table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4, math_pi_reference_18, unpack_values)
            ::branch_532::
            panorama_open_5 = panorama_open_2
            ::branch_533::
            panorama_open_set_3 = panorama_open_5["set"]
            ::branch_534::
            panorama_open_set_4 = key3
            ::branch_535::
            enabled_4 = "Force body yaw"
            ::branch_536::
            math_pi_reference_18 = true
            ::branch_537::
            panorama_open_set_3(panorama_open_set_4, enabled_4, math_pi_reference_18)
            ::branch_538::
            if (0 < table_insert) then
                goto branch_540
            end
            ::branch_539::
            goto branch_541
            ::branch_540::
            goto branch_559
            ::branch_541::
            if (table_insert < 0) then
                goto branch_543
            end
            ::branch_542::
            goto branch_77
            ::branch_543::
            panorama_open_5 = panorama_open_2
            ::branch_544::
            panorama_open_set_3 = panorama_open_5["set"]
            ::branch_545::
            panorama_open_set_4 = key3
            ::branch_546::
            enabled_4 = "Force body yaw value"
            ::branch_547::
            if (not (anti_aim_type == "SCR")) then
                goto branch_549
            end
            ::branch_548::
            goto branch_550
            ::branch_549::
            math_pi_reference_18 = false
            goto branch_551
            ::branch_550::
            math_pi_reference_18 = true
            ::branch_551::
            if math_pi_reference_18 then
                goto branch_553
            end
            ::branch_552::
            goto branch_554
            ::branch_553::
            math_pi_reference_18 = 60
            ::branch_554::
            if (not math_pi_reference_18) then
                goto branch_556
            end
            ::branch_555::
            goto branch_557
            ::branch_556::
            math_pi_reference_18 = (-60)
            ::branch_557::
            panorama_open_set_3(panorama_open_set_4, enabled_4, math_pi_reference_18)
            ::branch_558::
            goto branch_77
            ::branch_559::
            panorama_open_5 = panorama_open_2
            ::branch_560::
            panorama_open_set_3 = panorama_open_5["set"]
            ::branch_561::
            panorama_open_set_4 = key3
            ::branch_562::
            enabled_4 = "Force body yaw value"
            ::branch_563::
            if (not (anti_aim_type == "SCR")) then
                goto branch_565
            end
            ::branch_564::
            goto branch_566
            ::branch_565::
            math_pi_reference_18 = false
            goto branch_567
            ::branch_566::
            math_pi_reference_18 = true
            ::branch_567::
            if math_pi_reference_18 then
                goto branch_569
            end
            ::branch_568::
            goto branch_570
            ::branch_569::
            math_pi_reference_18 = (-60)
            ::branch_570::
            if (not math_pi_reference_18) then
                goto branch_572
            end
            ::branch_571::
            goto branch_573
            ::branch_572::
            math_pi_reference_18 = 60
            ::branch_573::
            panorama_open_set_3(panorama_open_set_4, enabled_4, math_pi_reference_18)
            ::branch_574::
            goto branch_77
            ::branch_575::
            if (anti_aim_type == "SCR") then
                goto branch_577
            end
            ::branch_576::
            goto branch_578
            ::branch_577::
            goto branch_524
            ::branch_578::
            if (anti_aim_type == "SR") then
                goto branch_580
            end
            ::branch_579::
            goto branch_77
            ::branch_580::
            table_insert = 0
            ::branch_581::
            panorama_open_set_4 = math_pi_reference_15
            ::branch_582::
            enabled_4 = (panorama_open_set - panorama_open_set_2)
            ::branch_583::
            panorama_open_set_4 = panorama_open_set_4(enabled_4)
            ::branch_584::
            if (not (value145 == panorama_open_set_4)) then
                goto branch_586
            end
            ::branch_585::
            goto branch_587
            ::branch_586::
            goto branch_635
            ::branch_587::
            math_pi_reference_18 = math_pi_reference_15
            ::branch_588::
            unpack_values = (panorama_open_set + panorama_open_set_2)
            ::branch_589::
            math_pi_reference_18 = math_pi_reference_18(unpack_values)
            ::branch_590::
            if (not (text13 == math_pi_reference_18)) then
                goto branch_592
            end
            ::branch_591::
            goto branch_593
            ::branch_592::
            goto branch_607
            ::branch_593::
            panorama_open_5 = panorama_open_2
            ::branch_594::
            panorama_open_set_4 = panorama_open_5["set"]
            ::branch_595::
            enabled_4 = key3
            ::branch_596::
            math_pi_reference_18 = "Force body yaw"
            ::branch_597::
            unpack_values = true
            ::branch_598::
            panorama_open_set_4(enabled_4, math_pi_reference_18, unpack_values)
            ::branch_599::
            panorama_open_5 = panorama_open_2
            ::branch_600::
            panorama_open_set_4 = panorama_open_5["set"]
            ::branch_601::
            enabled_4 = key3
            ::branch_602::
            math_pi_reference_18 = "Force body yaw value"
            ::branch_603::
            unpack_values = 0
            ::branch_604::
            panorama_open_set_4(enabled_4, math_pi_reference_18, unpack_values)
            ::branch_605::
            ::branch_606::
            goto branch_77
            ::branch_607::
            if (text13 == panorama_open_set) then
                goto branch_609
            end
            ::branch_608::
            goto branch_610
            ::branch_609::
            goto branch_593
            ::branch_610::
            if (not (panorama_open_set == table_insert)) then
                goto branch_612
            end
            ::branch_611::
            goto branch_77
            ::branch_612::
            panorama_open_5 = panorama_open_2
            ::branch_613::
            panorama_open_set_4 = panorama_open_5["set"]
            ::branch_614::
            enabled_4 = key3
            ::branch_615::
            math_pi_reference_18 = "Force body yaw"
            ::branch_616::
            unpack_values = true
            ::branch_617::
            panorama_open_set_4(enabled_4, math_pi_reference_18, unpack_values)
            ::branch_618::
            if (panorama_open_set < 0) then
                goto branch_620
            end
            ::branch_619::
            goto branch_621
            ::branch_620::
            goto branch_628
            ::branch_621::
            panorama_open_5 = panorama_open_2
            ::branch_622::
            panorama_open_set_4 = panorama_open_5["set"]
            ::branch_623::
            enabled_4 = key3
            ::branch_624::
            math_pi_reference_18 = "Force body yaw value"
            ::branch_625::
            unpack_values = (-60)
            ::branch_626::
            panorama_open_set_4(enabled_4, math_pi_reference_18, unpack_values)
            ::branch_627::
            goto branch_77
            ::branch_628::
            panorama_open_5 = panorama_open_2
            ::branch_629::
            panorama_open_set_4 = panorama_open_5["set"]
            ::branch_630::
            enabled_4 = key3
            ::branch_631::
            math_pi_reference_18 = "Force body yaw value"
            ::branch_632::
            unpack_values = 60
            ::branch_633::
            panorama_open_set_4(enabled_4, math_pi_reference_18, unpack_values)
            ::branch_634::
            goto branch_77
            ::branch_635::
            enabled_4 = math_pi_reference_15
            ::branch_636::
            math_pi_reference_18 = (panorama_open_set + panorama_open_set_2)
            ::branch_637::
            enabled_4 = enabled_4(math_pi_reference_18)
            ::branch_638::
            if (value145 == enabled_4) then
                goto branch_640
            end
            ::branch_639::
            goto branch_610
            ::branch_640::
            goto branch_587
            ::branch_641::
            table_insert = entries48["valid_yaw"]
            ::branch_642::
            if (not table_insert) then
                goto branch_644
            end
            ::branch_643::
            goto branch_645
            ::branch_644::
            table_insert = entries48["yaw"]
            ::branch_645::
            if (not table_insert) then
                goto branch_647
            end
            ::branch_646::
            goto branch_648
            ::branch_647::
            table_insert = 0
            ::branch_648::
            panorama_open_set_3 = math_pi_reference_15
            ::branch_649::
            panorama_open_set_4 = table_insert
            ::branch_650::
            panorama_open_set_3 = panorama_open_set_3(panorama_open_set_4)
            ::branch_651::
            table_insert = panorama_open_set_3
            ::branch_652::
            panorama_open_5 = panorama_open_2
            ::branch_653::
            panorama_open_set_3 = panorama_open_5["set"]
            ::branch_654::
            panorama_open_set_4 = key3
            ::branch_655::
            enabled_4 = "Force body yaw"
            ::branch_656::
            math_pi_reference_18 = true
            ::branch_657::
            panorama_open_set_3(panorama_open_set_4, enabled_4, math_pi_reference_18)
            ::branch_658::
            if (table_insert < 0) then
                goto branch_660
            end
            ::branch_659::
            goto branch_661
            ::branch_660::
            goto branch_668
            ::branch_661::
            panorama_open_5 = panorama_open_2
            ::branch_662::
            panorama_open_set_3 = panorama_open_5["set"]
            ::branch_663::
            panorama_open_set_4 = key3
            ::branch_664::
            enabled_4 = "Force body yaw value"
            ::branch_665::
            math_pi_reference_18 = (-60)
            ::branch_666::
            panorama_open_set_3(panorama_open_set_4, enabled_4, math_pi_reference_18)
            ::branch_667::
            goto branch_77
            ::branch_668::
            panorama_open_5 = panorama_open_2
            ::branch_669::
            panorama_open_set_3 = panorama_open_5["set"]
            ::branch_670::
            panorama_open_set_4 = key3
            ::branch_671::
            enabled_4 = "Force body yaw value"
            ::branch_672::
            math_pi_reference_18 = 60
            ::branch_673::
            panorama_open_set_3(panorama_open_set_4, enabled_4, math_pi_reference_18)
            ::branch_674::
            goto branch_77
            ::branch_675::
            if (not (anti_aim_type == "CR")) then
                goto branch_677
            end
            ::branch_676::
            goto branch_518
            ::branch_677::
            if (not (anti_aim_type == "SCR")) then
                goto branch_679
            end
            ::branch_678::
            goto branch_518
            ::branch_679::
            if (anti_aim_type == "DR") then
                goto branch_681
            end
            ::branch_680::
            goto branch_682
            ::branch_681::
            goto branch_518
            ::branch_682::
            panorama_open_5 = panorama_open_2
            ::branch_683::
            table_insert = panorama_open_5["set"]
            ::branch_684::
            panorama_open_set_3 = key3
            ::branch_685::
            panorama_open_set_4 = "Force body yaw"
            ::branch_686::
            enabled_4 = false
            ::branch_687::
            table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4)
            ::branch_688::
            panorama_open_5 = panorama_open_2
            ::branch_689::
            table_insert = panorama_open_5["set"]
            ::branch_690::
            panorama_open_set_3 = key3
            ::branch_691::
            panorama_open_set_4 = "Force body yaw value"
            ::branch_692::
            enabled_4 = 0
            ::branch_693::
            table_insert(panorama_open_set_3, panorama_open_set_4, enabled_4)
            ::branch_694::
            goto branch_77
            ::branch_695::
            do
                return
            end
            ::branch_696::
            unpack_values_43, unpack_values_44 = iterate_array_19(unpack_values_41, unpack_values_42)
            if (unpack_values_43 ~= nil) then
                unpack_values_42 = unpack_values_43
            else
                goto branch_698
            end
            ::branch_697::
            goto branch_32
            ::branch_698::
            goto branch_695
            ::branch_699::
            do
                return
            end
            ::branch_700::
            globals_tickinterval_is_alive = panorama_open
            ::branch_701::
            if globals_tickinterval_is_alive then
                goto branch_703
            end
            ::branch_702::
            goto branch_703
            ::branch_703::
            panorama_open_5 = false
            ::branch_704::
            panorama_open = panorama_open_5
            ::branch_705::
            do
                return
            end
            ::branch_706::
            do
                return
            end
            ::branch_707::
        end
    end
    do
        local require_tohex_12
        require_tohex_12 = arshift
        helpers.handleValue47 = function(value142, value143, value144)
            local formatted_text_2
            if value143 then
                formatted_text_2 = require_tohex_12.format([[
record %d:
origin: x=%.2f, y=%.2f, z=%.2f
simulation time: %.2f]], value144, value143.origin[1], value143.origin[2], value143.origin[3], value143.simulationTime)
                print(formatted_text_2)
            end
            return
        end
    end
    do
        local value99, value100
        value99 = helpers.handleValue20
        value100 = update_state
        helpers.handleValue48 = function(value142)
            value99(value142)
            value100(value142)
            return
        end
    end
    do
        local globals_tickinterval_33, math_pi_40, state77, value101, math_pi_new_checkbox_2, value102,
              value103, value104, value105, state78, renderer_world_to_screen_24, require_25
        globals_tickinterval_33 = absoluteframetime
        math_pi_40 = abs
        state77 = entries18
        value101 = helpers.handleValue48
        math_pi_new_checkbox_2 = math_pi_new_checkbox
        value102 = entries22
        value103 = update_state_4
        value104 = update_anti_aim
        value105 = update_anti_aim_2
        state78 = entries5
        renderer_world_to_screen_24 = blur
        require_25 = require_3
        helpers.handleValue49 = function(entity_index)
            local piValue2, state96
            local piValue3 = globals_tickinterval_33.get_local_player()
            entity_index = piValue3
            piValue3 = math_pi_40.get(state77.visuals.maxrecords)
            amount = piValue3
            piValue3 = math_pi_40.get(state77.visuals.maxlife)
            amount2 = piValue3
            value101(entity_index)
            piValue3 = math_pi_40.get(math_pi_new_checkbox_2)
            if (not piValue3) then
                return
            end
            piValue3 = value102
            piValue2 = math_pi_40.get(state77.misc[1])
            piValue3 = piValue3(piValue2, "fake duck")
            if piValue3 then
                globals_tickinterval_33.set_prop(entity_index, "m_flPoseParameter", 1, 1)
            end
            value103()
            value104(entity_index)
            value105(entity_index)
            if (not state78.wait_for_land_update) then
                if (not state78.jumping) then
                    if state78.on_ground then
                        goto branch_1
                    end
                end
                if state78.on_ground then
                    piValue3 = renderer_world_to_screen_24.chokedcommands()
                    if (piValue3 == 0) then
                        goto branch_1
                    end
                end
                if state78.air_time then
                    piValue3 = state78.air_time
                    piValue2 = renderer_world_to_screen_24.tickinterval()
                    piValue3 = (piValue3 + piValue2)
                    state96 = state78
                    state96.air_time = piValue3
                end
            end
            ::branch_1::
            piValue3 = require_25(globals_tickinterval_33.get_prop(entity_index, "m_vecOrigin"))
            if (piValue3 ~= state78.last_origin) then
                piValue3 = require_25(globals_tickinterval_33.get_prop(entity_index, "m_vecOrigin"))
                piValue3 = (piValue3 - state78.last_origin)
                state96 = state78
                state96.origin_delta = piValue3
                piValue3 = state78.origin_delta
                piValue3 = piValue3.lengthsqr(piValue3)
                piValue3 = (4096 < piValue3)
                state96 = state78
                state96.breaking_lc = piValue3
                piValue3 = require_25(globals_tickinterval_33.get_prop(entity_index, "m_vecOrigin"))
                state96 = state78
                state96.last_origin = piValue3
            end
            return
        end
    end
    entity_set_prop_register_esp_flag = get_all.register_esp_flag
    label_2 = ""
    label_3 = 255
    import_anti_aim = 255
    update_state_5 = 255
    do
        local globals_tickinterval_34, math_pi_41, state79, entries41, require_tohex_13
        globals_tickinterval_34 = absoluteframetime
        math_pi_41 = abs
        state79 = entries18
        entries41 = state2
        require_tohex_13 = arshift
        math_pi_new_button = function(value142)
            local upper
            local key3 = value142
            value142 = nil
            local alive = globals_tickinterval_34.is_alive(globals_tickinterval_34.get_local_player())
            if (not alive) then
                return
            end
            alive = math_pi_41.get(state79.debug[1])
            if alive then
                alive = globals_tickinterval_34.is_alive(key3)
                if alive then
                    alive = globals_tickinterval_34.is_dormant(key3)
                    if (not alive) then
                        if (entries41[key3] ~= value142) then
                            if (entries41[key3].anti_aim_type ~= value142) then
                                alive = true
                                upper = require_tohex_13.upper(entries41[key3].anti_aim_type)
                                return alive, ("\affffffc8" .. upper)
                            end
                        end
                    end
                end
            end
            return
        end
    end
    entity_set_prop_register_esp_flag(label_2, label_3, import_anti_aim, update_state_5, math_pi_new_button)
    do
        local math_pi_42, state80, math_pi_new_checkbox_3, state81, state82, entries42,
              renderer_world_to_screen_25, string_upper_29, math_pi_reference_16, iterate_array_11,
              ui_update_17, entries43, entity_set_prop_16, value106
        math_pi_42 = abs
        state80 = entries18
        math_pi_new_checkbox_3 = math_pi_new_checkbox
        state81 = entries14
        state82 = text5
        entries42 = entries17
        renderer_world_to_screen_25 = blur
        string_upper_29 = byte
        math_pi_reference_16 = math_pi_reference
        iterate_array_11 = iterate_array
        ui_update_17 = get_2
        entries43 = entries13
        entity_set_prop_16 = get_all
        value106 = entries10
        entity_set_prop_register_esp_flag = function()
            local height, real_time, min, menu_alpha, ceil, entries48, entries49, is_hovered,
                  selected_tab, value142, value143, value144, entries50, entries51, amount4, amount5,
                  amount6, value145, value146, text13, amount7, piValue2, entries52, key3,
                  value147, iterate_array_18, value148, value149, index6, entry_2, entries53,
                  value150, value151, index7, entry_3
            local piValue3 = math_pi_42.get(state80.debug[0])
            if piValue3 then
                piValue3 = math_pi_42.get(math_pi_new_checkbox_3)
                if piValue3 then
                    goto branch_1
                end
            end
            entries52 = state81
            entries52.menu_alpha = 0
            entries52 = state81
            entries52.is_hovered = false
            entries16 = false
            do
                return
            end
            ::branch_1::
            piValue3 = math_pi_42.get(state82.misc.settings.ref_dpiscale)
            height = entries42[piValue3]
            if (not height) then
                height = 68
            end
            entries52 = state81
            entries52.height = height
            height = math_pi_42.get(state82.misc.settings.ref_menukey)
            if height then
                if (not entries15) then
                    entries15 = true
                    height = (not state81.is_open)
                    entries52 = state81
                    entries52.is_open = height
                    entries16 = false
                end
            else
                entries15 = false
            end
            height = math_pi_42.is_menu_open()
            if (not height) then
                entries52 = state81
                entries52.is_open = false
            end
            if (not entries16) then
                height = state81.is_open
                if height then
                    height = renderer_world_to_screen_25.realtime()
                end
                if (not height) then
                    height = renderer_world_to_screen_25.realtime()
                end
                entries52 = state81
                entries52.fade_start_time = height
                entries16 = true
            end
            if (not state81.selected_gs_tab) then
                entries52 = state81
                entries52.menu_alpha = 0
            end
            height = state81.is_open
            if height then
                height = state81.selected_gs_tab
            end
            if height then
                height = 255
            end
            if (not height) then
                height = 0
            end
            real_time = renderer_world_to_screen_25.realtime()
            real_time = (real_time - state81.fade_start_time)
            min = string_upper_29.min(1, (real_time / 0.5))
            menu_alpha = math_pi_reference_16(state81.menu_alpha, height, min)
            entries52 = state81
            entries52.menu_alpha = menu_alpha
            if (state81.menu_alpha <= 0) then
                entries52 = state81
                entries52.is_hovered = false
                return
            end
            menu_alpha = {}
            menu_alpha = {math_pi_42.menu_size()}
            ceil = string_upper_29.ceil(((menu_alpha[1] - 12) / (#state81.tabs_names)))
            entries48 = {}
            entries48 = {math_pi_42.menu_position()}
            entries49 = {}
            entries49 = {math_pi_42.mouse_position()}
            is_hovered = (entries49[1] > entries48[1])
            if is_hovered then
                is_hovered = (entries49[1] < (entries48[1] + (ceil * (#state81.tabs_names))))
            end
            if is_hovered then
                is_hovered = (entries49[2] > (entries48[2] - state81.height))
            end
            if is_hovered then
                is_hovered = (entries49[2] < ((entries48[2] - state81.height) + state81.height))
            end
            entries52 = state81
            entries52.is_hovered = is_hovered
            is_hovered = iterate_array_11
            selected_tab = state81.tabs_names
            is_hovered, selected_tab, value142 = is_hovered(selected_tab)
            iterate_array_18 = is_hovered
            value148 = selected_tab
            value149 = value142
            for index6, entry_2 in iterate_array_18, value148, value149 do
                selected_tab = index6
                value142 = entry_2
                value143 = ((entries48[1] + 6) + (ceil * (selected_tab - 1)))
                value144 = (value143 < entries49[1])
                if value144 then
                    value144 = (entries49[1] < (value143 + ceil))
                end
                if value144 then
                    value144 = (entries49[2] > (entries48[2] - state81.height))
                end
                if value144 then
                    value144 = (entries49[2] < entries48[2])
                end
                if (state81.selected_tab == selected_tab) then
                    entries50 = state81.selected_color
                    entries51 = {}
                    amount4 = 20
                    amount5 = 20
                    amount6 = 20
                    entries51[1] = amount4
                    entries51[2] = amount5
                    entries51[3] = amount6
                    entries50[1] = entries51
                    entries50 = state81.selected_color
                    entries51 = {}
                    amount4 = 210
                    amount5 = 210
                    amount6 = 210
                    entries51[1] = amount4
                    entries51[2] = amount5
                    entries51[3] = amount6
                    entries52 = entries50
                    key3 = 2
                    value147 = entries51
                    entries52[key3] = value147
                else
                    entries50 = state81.selected_color
                    entries51 = {}
                    amount4 = 12
                    amount5 = 12
                    amount6 = 12
                    entries51[1] = amount4
                    entries51[2] = amount5
                    entries51[3] = amount6
                    entries50[1] = entries51
                    entries50 = state81.selected_color
                    entries51 = {}
                    amount4 = 90
                    amount5 = 90
                    amount6 = 90
                    entries51[1] = amount4
                    entries51[2] = amount5
                    entries51[3] = amount6
                    entries50[2] = entries51
                end
                if value144 then
                    if (state81.selected_tab ~= selected_tab) then
                        entries50 = state81.selected_color
                        entries51 = {}
                        amount4 = 12
                        amount5 = 12
                        amount6 = 12
                        entries51[1] = amount4
                        entries51[2] = amount5
                        entries51[3] = amount6
                        entries50[1] = entries51
                        entries50 = state81.selected_color
                        entries51 = {}
                        amount4 = 167
                        amount5 = 167
                        amount6 = 167
                        entries51[1] = amount4
                        entries51[2] = amount5
                        entries51[3] = amount6
                        entries50[2] = entries51
                    end
                end
                ui_update_17.rectangle(value143, (entries48[2] - state81.height), ceil, state81.height, state81.selected_color[1][1], state81.selected_color[1][2], state81.selected_color[1][3], state81.menu_alpha)
                entries50 = ui_update_17.text
                entries51 = (value143 + (ceil / 2))
                amount4 = (entries48[2] - (state81.height / 2))
                amount5 = state81.selected_color[2][1]
                amount6 = state81.selected_color[2][2]
                value145 = state81.selected_color[2][3]
                value146 = state81.menu_alpha
                text13 = "c+d"
                amount7 = 0
                piValue2 = (selected_tab == 6)
                if piValue2 then
                    piValue2 = math_pi_42.get(state80.debug[4])
                    piValue2 = entries43[piValue2]
                end
                if (not piValue2) then
                    piValue2 = value142
                end
                entries50(entries51, amount4, amount5, amount6, value145, value146, text13, amount7, piValue2)
                if value144 then
                    entries50 = entity_set_prop_16.key_state(1)
                    if entries50 then
                        entries52 = state81
                        entries52.selected_tab = selected_tab
                        entries50, entries51, amount4 = iterate_array_11(value106)
                        entries53 = entries50
                        value150 = entries51
                        value151 = amount4
                        for index7, entry_3 in entries53, value150, value151 do
                            entries51 = index7
                            amount4 = entry_3
                            if (state81.selected_tab == entries51) then
                                math_pi_42.set(state80.tab, amount4)
                            end
                        end
                    end
                end
            end
            gamesense_outer(entries48[1], entries48[2], menu_alpha[1], state81.height, state81.menu_alpha, false)
            return
        end
    end
    label_2 = abs.new_label("Players", "Adjustments", "-")
    label_3 = abs.new_label("Players", "Adjustments", "-")
    do
        local math_pi_43, state83, entries44, value107, globals_tickinterval_35
        math_pi_43 = abs
        state83 = text5
        entries44 = to_number_2
        value107 = helpers.handleValue5
        globals_tickinterval_35 = absoluteframetime
        import_anti_aim = function()
            local text13, text14, player_name
            local value142 = nil
            local key3 = math_pi_43.get(state83.plist.players)
            if (key3 == value142) then
                return
            end
            if (not text7[key3]) then
                text13 = g_notify
                text13.add(text13, "[STEALER] Please enable 'scan anti-aim'.", nil, 5)
                return
            end
            if text6[key3] then
                if (not (20 <= (#entries44[key3].stand))) then
                    if (not (20 <= (#entries44[key3].run))) then
                        if (not (20 <= (#entries44[key3].air))) then
                            if (not (20 <= (#entries44[key3].duck))) then
                                goto branch_1
                            end
                        end
                    end
                end
                if (20 <= (#entries44[key3].stand)) then
                    text13 = value107(entries44[key3].stand_type)
                    text14 = value107(entries44[key3].stand)
                    if (text13 == "CR") then
                        text13 = "Center"
                    else
                        if (text13 == "SR") then
                            text13 = "Skitter"
                        end
                    end
                    math_pi_43.set(entries9[2][6], text13)
                    math_pi_43.set(entries9[2][7], text14)
                end
                if (20 <= (#entries44[key3].run)) then
                    text13 = value107(entries44[key3].run_type)
                    text14 = value107(entries44[key3].run)
                    if (text13 == "CR") then
                        text13 = "Center"
                    else
                        if (text13 == "SR") then
                            text13 = "Skitter"
                        end
                    end
                    math_pi_43.set(entries9[3][6], text13)
                    math_pi_43.set(entries9[3][7], text14)
                end
                if (20 <= (#entries44[key3].air)) then
                    text13 = value107(entries44[key3].air_type)
                    text14 = value107(entries44[key3].air)
                    if (text13 == "CR") then
                        text13 = "Center"
                    else
                        if (text13 == "SR") then
                            text13 = "Skitter"
                        end
                    end
                    math_pi_43.set(entries9[5][6], text13)
                    math_pi_43.set(entries9[5][7], text14)
                end
                if (not (20 <= (#entries44[key3].duck))) then
                    goto branch_2
                end
                text13 = value107(entries44[key3].duck_type)
                text14 = value107(entries44[key3].duck)
                if (text13 == "CR") then
                    text13 = "Center"
                else
                    if (text13 == "SR") then
                        text13 = "Skitter"
                    end
                end
                math_pi_43.set(entries9[7][6], text13)
                math_pi_43.set(entries9[7][7], text14)
                goto branch_3
                ::branch_1::
                text13 = g_notify
                text13.add(text13, "[STEALER] At least one stance must be done", nil, 5)
                ::branch_2::
                ::branch_3::
                while true do
                    text13 = g_notify
                    text14 = text13
                    text13 = text13.add
                    player_name = globals_tickinterval_35.get_player_name(key3)
                    text13(text14, ("[STEALER] Imported anti-aim settings from: " .. player_name), nil, 5)
                    do
                        return
                    end
                    if ((#entries44[key3].stand) ~= 20) then
                        text13 = g_notify
                        text13.add(text13, "[STEALER] Still scanning standing anti-aim", nil, 5)
                        return
                    end
                    if ((#entries44[key3].run) ~= 20) then
                        text13 = g_notify
                        text13.add(text13, "[STEALER] Still scanning running anti-aim", nil, 5)
                        return
                    end
                    if ((#entries44[key3].air) ~= 20) then
                        text13 = g_notify
                        text13.add(text13, "[STEALER] Still scanning air anti-aim", nil, 5)
                        return
                    end
                    if ((#entries44[key3].duck) ~= 20) then
                        text13 = g_notify
                        text13.add(text13, "[STEALER] Still scanning duck anti-aim", nil, 5)
                        return
                    end
                    if (20 <= (#entries44[key3].stand)) then
                        text13 = value107(entries44[key3].stand_type)
                        text14 = value107(entries44[key3].stand)
                        if (text13 == "CR") then
                            text13 = "Center"
                        else
                            if (text13 == "SR") then
                                text13 = "Skitter"
                            end
                        end
                        math_pi_43.set(entries9[2][6], text13)
                        math_pi_43.set(entries9[2][7], text14)
                    end
                    if (20 <= (#entries44[key3].run)) then
                        text13 = value107(entries44[key3].run_type)
                        text14 = value107(entries44[key3].run)
                        if (text13 == "CR") then
                            text13 = "Center"
                        else
                            if (text13 == "SR") then
                                text13 = "Skitter"
                            end
                        end
                        math_pi_43.set(entries9[3][6], text13)
                        math_pi_43.set(entries9[3][7], text14)
                    end
                    if (20 <= (#entries44[key3].air)) then
                        text13 = value107(entries44[key3].air_type)
                        text14 = value107(entries44[key3].air)
                        if (text13 == "CR") then
                            text13 = "Center"
                        else
                            if (text13 == "SR") then
                                text13 = "Skitter"
                            end
                        end
                        math_pi_43.set(entries9[5][6], text13)
                        math_pi_43.set(entries9[5][7], text14)
                    end
                    if (20 <= (#entries44[key3].duck)) then
                        text13 = value107(entries44[key3].duck_type)
                        text14 = value107(entries44[key3].duck)
                        if (text13 == "CR") then
                            text13 = "Center"
                        else
                            if (text13 == "SR") then
                                text13 = "Skitter"
                            end
                        end
                        math_pi_43.set(entries9[7][6], text13)
                        math_pi_43.set(entries9[7][7], text14)
                    end
                end
            end
        end
    end
    do
        local math_pi_44, state84, entries45, label_5, require_tohex_14, label_6
        math_pi_44 = abs
        state84 = text5
        entries45 = to_number_2
        label_5 = label_2
        require_tohex_14 = arshift
        label_6 = label_3
        update_state_5 = function()
            local math_pi_set, stand_type, require_tohex_format, text13, entries48, key3, value142
            local key4 = math_pi_44.get(state84.plist.players)
            if key4 then
                if text7[key4] then
                    perc_stand = (((#entries45[key4].stand) / 20) * 100)
                    perc_run = (((#entries45[key4].run) / 20) * 100)
                    perc_air = (((#entries45[key4].air) / 20) * 100)
                    perc_duck = (((#entries45[key4].duck) / 20) * 100)
                    steal_string = (perc_stand .. ("% - " .. (perc_run .. ("% - " .. (perc_air .. ("% - " .. (perc_duck .. "%")))))))
                    math_pi_44.set(label_5, require_tohex_14.format("%s", steal_string))
                    math_pi_set = math_pi_44.set
                    stand_type = label_6
                    require_tohex_format = require_tohex_14.format
                    text13 = "%s"
                    math_pi_set(stand_type, require_tohex_format(text13, "stand - run - air - duck"))
                    if text6[key4] then
                        if (perc_stand ~= 100) then
                            if (perc_run ~= 100) then
                                if (perc_air ~= 100) then
                                    text13 = perc_duck
                                end
                            end
                        end
                        if (text13 == 100) then
                            math_pi_44.set(label_5, require_tohex_14.format("%s", "done!"))
                        end
                    else
                        if (perc_stand == 100) then
                            if (perc_run == 100) then
                                if (perc_air == 100) then
                                    if (perc_duck == 100) then
                                        math_pi_44.set(label_5, require_tohex_14.format("%s", "done!"))
                                    end
                                end
                            end
                        end
                    end
                else
                    math_pi_44.set(label_5, require_tohex_14.format("%s", "waiting for scan..."))
                    math_pi_set = entries45[key4]
                    stand_type = {}
                    entries48 = math_pi_set
                    key3 = "stand"
                    value142 = stand_type
                    entries48[key3] = value142
                    math_pi_set = entries45[key4]
                    stand_type = {}
                    math_pi_set.stand_type = stand_type
                    math_pi_set = entries45[key4]
                    stand_type = {}
                    entries48 = math_pi_set
                    key3 = "run"
                    value142 = stand_type
                    entries48[key3] = value142
                    math_pi_set = entries45[key4]
                    stand_type = {}
                    math_pi_set.run_type = stand_type
                    math_pi_set = entries45[key4]
                    stand_type = {}
                    math_pi_set.air = stand_type
                    math_pi_set = entries45[key4]
                    stand_type = {}
                    math_pi_set.air_type = stand_type
                    math_pi_set = entries45[key4]
                    stand_type = {}
                    math_pi_set.duck = stand_type
                    math_pi_set = entries45[key4]
                    stand_type = {}
                    entries48 = math_pi_set
                    key3 = "duck_type"
                    value142 = stand_type
                    entries48[key3] = value142
                end
            end
            return
        end
    end
    math_pi_new_button = abs.new_button
    enabled = "Players"
    math_pi_new_button = math_pi_new_button(enabled, "Adjustments", "import anti-aim", import_anti_aim)
    enabled = false
    do
        local math_pi_45, math_pi_new_checkbox_4, entries46, entity_set_prop_register_esp_flag_2,
              value108, value109, state85, math_pi_set_callback_3, state86, value110,
              globals_tickinterval_36, iterate_array_12, panorama_open_3, callback5, value111, value112,
              value113, entries47
        math_pi_45 = abs
        math_pi_new_checkbox_4 = math_pi_new_checkbox
        entries46 = entries18
        entity_set_prop_register_esp_flag_2 = entity_set_prop_register_esp_flag
        value108 = update_state_2
        value109 = helpers.handleValue6
        state85 = entries5
        math_pi_set_callback_3 = math_pi_set_callback
        state86 = text5
        value110 = update_state_5
        globals_tickinterval_36 = absoluteframetime
        iterate_array_12 = iterate_array
        panorama_open_3 = loadstring
        callback5 = iterate_pairs
        value111 = entries22
        value112 = text4
        value113 = entries11
        entries47 = entries12
        on_paint_ui = function()
            local value142, entries48, entries49, value143, key3, value144, math_pi_set_visible,
                  piValue2, piValue3, piValue4, math_pi_set_visible_2, value145, piValue5,
                  piValue6, state96, value146, value147, value148, index6, entry_2, value149,
                  entries50, value150, index7, entry_3, math_pi_set_visible_3, value151, entries51,
                  index8, entry_4, value152, value153, value154, index9, entry_5, iterate_array_18,
                  value155, value156, index10, entry_6, value157, value158, value159, index11,
                  entry_7
            local piValue7 = math_pi_45.get(math_pi_new_checkbox_4)
            local piValue8 = math_pi_45.get(entries46.tab)
            local piValue9 = math_pi_45.get(entries46["anti-aim"][0])
            local piValue10 = math_pi_45.get(entries46["anti-aim"][1])
            entity_set_prop_register_esp_flag_2()
            local math_pi_set_visible_4 = math_pi_45.is_menu_open()
            if (not math_pi_set_visible_4) then
                return
            end
            value108()
            value109(piValue7)
            if (not piValue7) then
                if (not state85.reset_once) then
                    math_pi_set_callback_3()
                    state96 = state85
                    state96.reset_once = true
                end
                state96 = state85
                state96.smooth_wraith = (-1080)
                state96 = state85
                state96.smooth_dt = (-1080)
                state96 = state85
                state96.smooth_os = (-1080)
                state96 = state85
                state96.smooth_pc = (-1080)
                state96 = state85
                state96.smooth_bo = (-1080)
                state96 = state85
                state96.smooth_wraith_recode = (-1080)
                state96 = state85
                state96.smooth_dt_2 = (-1080)
                state96 = state85
                state96.smooth_stance = (-1080)
                state96 = state85
                state96.dt_os_text_anim = 0
                state96 = state85
                state96.current_cond_text_anim = 0
            else
                math_pi_45.set(state86.anti_aim.anti_aimbot_angles.ref_aa_enabled, true)
                state96 = state85
                state96.reset_once = false
            end
            if (piValue8 == "config") then
                math_pi_45.update(entries46.config[1], update_cfg())
            end
            math_pi_set_visible_4 = math_pi_45.set_visible
            entries48 = entries46.tab
            entries49 = piValue7
            if entries49 then
                entries49 = math_pi_45.get(entries46.debug[0])
                entries49 = (entries49 == false)
            end
            math_pi_set_visible_4(entries48, entries49)
            value110()
            math_pi_set_visible_4 = math_pi_45.get(entries46.debug[1])
            if (math_pi_set_visible_4 ~= "off") then
                math_pi_45.set_visible(state86.plist.force_body, false)
                math_pi_45.set_visible(state86.plist.force_body_value, false)
                enabled = true
            else
                if enabled then
                    math_pi_45.set_visible(state86.plist.force_body, true)
                    math_pi_45.set_visible(state86.plist.force_body_value, true)
                    math_pi_set_visible_4 = globals_tickinterval_36.get_players(true)
                    if ((#math_pi_set_visible_4) ~= 0) then
                        entries48, entries49, value143 = iterate_array_12(math_pi_set_visible_4)
                        value149 = entries48
                        entries50 = entries49
                        value150 = value143
                        for index7, entry_3 in value149, entries50, value150 do
                            value143 = entry_3
                            panorama_open_3.set(value143, "Force body yaw", false)
                            panorama_open_3.set(value143, "Force body yaw value", 0)
                        end
                    end
                    enabled = false
                end
            end
            math_pi_set_visible_4, entries48, entries49 = callback5(entries46)
            math_pi_set_visible_3 = math_pi_set_visible_4
            value151 = entries48
            entries51 = entries49
            for index8, entry_4 in math_pi_set_visible_3, value151, entries51 do
                entries48 = index8
                entries49 = entry_4
                if (entries49 ~= entries46.tab) then
                    value143, key3, value144 = callback5(entries49)
                    value157 = value143
                    value158 = key3
                    value159 = value144
                    for index11, entry_7 in value157, value158, value159 do
                        math_pi_45.set_visible(entry_7, (piValue7 and (entries48 == piValue8)))
                        if (piValue8 == "anti-aim 2") then
                            math_pi_set_visible = 1
                            piValue2 = 9
                            piValue3 = 1
                            for piValue4 = math_pi_set_visible, piValue2, piValue3 do
                                if ((piValue4 == 1) or (piValue4 == 2)) then
                                    math_pi_set_visible_2 = math_pi_45.set_visible
                                    value145 = entries46["anti-aim 2"][piValue4]
                                    piValue5 = piValue7
                                    if piValue5 then
                                        piValue5 = value111
                                        piValue6 = math_pi_45.get(entries46["anti-aim 2"][0])
                                        piValue5 = piValue5(piValue6, "other anti-aim binds")
                                    end
                                    math_pi_set_visible_2(value145, piValue5)
                                else
                                    if ((2 < piValue4) and (piValue4 < 10)) then
                                        math_pi_set_visible_2 = math_pi_45.set_visible
                                        value145 = entries46["anti-aim 2"][piValue4]
                                        piValue5 = piValue7
                                        if piValue5 then
                                            piValue5 = value111
                                            piValue6 = math_pi_45.get(entries46["anti-aim 2"][0])
                                            piValue5 = piValue5(piValue6, "manual anti-aim")
                                        end
                                        math_pi_set_visible_2(value145, piValue5)
                                    end
                                end
                            end
                        end
                        if (piValue8 == "visuals") then
                            math_pi_set_visible = math_pi_45.set_visible
                            piValue2 = entries46.visuals[4]
                            piValue3 = piValue7
                            if piValue3 then
                                piValue3 = math_pi_45.get(entries46.visuals[2])
                            end
                            math_pi_set_visible(piValue2, piValue3)
                            math_pi_set_visible = math_pi_45.set_visible
                            piValue2 = entries46.visuals[5]
                            piValue3 = piValue7
                            if piValue3 then
                                piValue3 = math_pi_45.get(entries46.visuals[7])
                            end
                            math_pi_set_visible(piValue2, piValue3)
                            math_pi_set_visible = value111
                            piValue2 = math_pi_45.get(entries46.misc[3])
                            math_pi_set_visible = math_pi_set_visible(piValue2, "default")
                            if (not math_pi_set_visible) then
                                math_pi_set_visible = value111
                                piValue2 = math_pi_45.get(entries46.misc[3])
                                math_pi_set_visible = math_pi_set_visible(piValue2, "center")
                                if (not math_pi_set_visible) then
                                    math_pi_set_visible = math_pi_45.set_visible
                                    piValue2 = entries46.visuals[5]
                                    piValue3 = piValue7
                                    if piValue3 then
                                        piValue3 = false
                                    end
                                    math_pi_set_visible(piValue2, piValue3)
                                    math_pi_set_visible = math_pi_45.set_visible
                                    piValue2 = entries46.visuals[7]
                                    piValue3 = piValue7
                                    if piValue3 then
                                        piValue3 = false
                                    end
                                    math_pi_set_visible(piValue2, piValue3)
                                end
                            end
                            math_pi_set_visible = math_pi_45.get(entries46.visuals[11])
                            if (not math_pi_set_visible) then
                                math_pi_45.set_visible(entries46.visuals[12], false)
                                math_pi_45.set_visible(entries46.visuals[13], false)
                                math_pi_45.set_visible(entries46.visuals[14], false)
                                math_pi_45.set_visible(entries46.visuals[15], false)
                                math_pi_45.set_visible(entries46.visuals[16], false)
                                math_pi_45.set_visible(entries46.visuals[17], false)
                                math_pi_45.set_visible(entries46.visuals[18], false)
                                math_pi_45.set_visible(entries46.visuals[19], false)
                                math_pi_45.set_visible(entries46.visuals[69], false)
                                math_pi_45.set_visible(entries46.visuals[70], false)
                                math_pi_45.set_visible(entries46.visuals[71], false)
                                math_pi_45.set_visible(entries46.visuals[72], false)
                                math_pi_45.set_visible(entries46.visuals[73], false)
                                math_pi_45.set_visible(entries46.visuals[74], false)
                                math_pi_45.set_visible(entries46.visuals.maxrecords, false)
                                math_pi_45.set_visible(entries46.visuals.maxlife, false)
                                math_pi_45.set_visible(entries46.visuals.show_last_record, false)
                                math_pi_45.set_visible(entries46.visuals.thirdpersonly, false)
                            end
                        end
                        if (piValue8 == "misc") then
                            math_pi_set_visible = math_pi_45.set_visible
                            piValue2 = entries46.misc[5]
                            piValue3 = piValue7
                            if piValue3 then
                                piValue3 = math_pi_45.get(entries46.misc[4])
                            end
                            math_pi_set_visible(piValue2, piValue3)
                        end
                        if (piValue8 == "debug") then
                            math_pi_set_visible = math_pi_45.set_visible
                            piValue2 = entries46.debug[3]
                            piValue3 = piValue7
                            if piValue3 then
                                piValue3 = math_pi_45.get(entries46.debug[2])
                            end
                            math_pi_set_visible(piValue2, piValue3)
                        end
                    end
                end
            end
            math_pi_set_visible_4 = iterate_array_12
            entries48 = {}
            entries49 = value112
            value143 = value113
            entries48[1] = entries49
            entries48[2] = value143
            math_pi_set_visible_4, entries48, entries49 = math_pi_set_visible_4(entries48)
            iterate_array_18 = math_pi_set_visible_4
            value155 = entries48
            value156 = entries49
            for index10, entry_6 in iterate_array_18, value155, value156 do
                entries49 = entry_6
                index3 = entries49
                value143, key3, value144 = callback5(entries49)
                value152 = value143
                value153 = key3
                value154 = value144
                for index9, entry_5 in value152, value153, value154 do
                    key3 = index9
                    value144 = entry_5
                    if (piValue9 == "gamesense") then
                        if (entries49 == value112) then
                            entries9 = entries49
                        end
                    else
                        if (piValue9 == "wraith (dont use)") then
                            if (entries49 == value113) then
                                entries8 = entries49
                            end
                        end
                    end
                    math_pi_set_visible, piValue2, piValue3 = callback5(value144)
                    value146 = math_pi_set_visible
                    value147 = piValue2
                    value148 = piValue3
                    for index6, entry_2 in value146, value147, value148 do
                        piValue3 = entry_2
                        piValue4 = (piValue9 == "gamesense")
                        if piValue4 then
                            piValue4 = (entries49 == value112)
                        end
                        if (not piValue4) then
                            piValue4 = (piValue9 == "wraith (dont use)")
                            if piValue4 then
                                piValue4 = (entries49 == value113)
                            end
                        end
                        if piValue4 then
                            piValue4 = (entries47[key3] == piValue10)
                        end
                        piValue4 = (piValue4 and (piValue8 == "anti-aim"))
                        if piValue4 then
                            piValue4 = piValue7
                        end
                        if piValue4 then
                            piValue4 = (piValue3 == entries49[key3][0])
                            if (not piValue4) then
                                piValue4 = math_pi_45.get(entries49[key3][0])
                            end
                        end
                        value142 = piValue4
                        if (piValue9 == "gamesense") then
                            if (entries49 == value112) then
                                if ((((piValue10 == "freestanding") or (piValue10 == "manual")) or (piValue10 == "legit")) or (piValue10 == "backstab")) then
                                    piValue4 = value142
                                    if piValue4 then
                                        piValue4 = (piValue3 ~= entries49[key3][11])
                                        if piValue4 then
                                            piValue4 = (piValue3 ~= entries49[key3][12])
                                        end
                                    end
                                    value142 = piValue4
                                end
                                if (piValue10 == "manual") then
                                    piValue4 = value142
                                    if piValue4 then
                                        piValue4 = (piValue3 ~= entries49[key3][5])
                                    end
                                    value142 = piValue4
                                end
                                piValue4 = math_pi_45.get(entries49[key3][1])
                                if (piValue4 ~= "custom") then
                                    piValue4 = value142
                                    if piValue4 then
                                        piValue4 = (piValue3 ~= entries49[key3][2])
                                    end
                                    value142 = piValue4
                                end
                                piValue4 = math_pi_45.get(entries49[key3][4])
                                if (piValue4 == "off") then
                                    piValue4 = value142
                                    if piValue4 then
                                        piValue4 = (piValue3 ~= entries49[key3][5])
                                        if piValue4 then
                                            piValue4 = (piValue3 ~= entries49[key3][6])
                                        end
                                        if piValue4 then
                                            piValue4 = (piValue3 ~= entries49[key3][7])
                                        end
                                    end
                                    value142 = piValue4
                                end
                                piValue4 = math_pi_45.get(entries49[key3][6])
                                if (piValue4 == "off") then
                                    piValue4 = value142
                                    if piValue4 then
                                        piValue4 = (piValue3 ~= entries49[key3][7])
                                    end
                                    value142 = piValue4
                                end
                                piValue4 = math_pi_45.get(entries49[key3][8])
                                if piValue4 then
                                    piValue4 = math_pi_45.get(entries49[key3][8])
                                    if (piValue4 == "off") then
                                        piValue4 = value142
                                        if piValue4 then
                                            piValue4 = (piValue3 ~= entries49[key3][10])
                                        end
                                        value142 = piValue4
                                    end
                                    piValue4 = math_pi_45.get(entries49[key3][8])
                                    if (piValue4 ~= "off") then
                                        math_pi_set_visible_2 = math_pi_45.get(entries49[key3][8])
                                        if (math_pi_set_visible_2 ~= "opposite") then
                                            goto branch_1
                                        end
                                    end
                                    piValue4 = value142
                                    if piValue4 then
                                        piValue4 = (piValue3 ~= entries49[key3][9])
                                    end
                                    value142 = piValue4
                                end
                                ::branch_1::
                                piValue4 = math_pi_45.get(entries49[key3][6])
                                if (piValue4 == "slow") then
                                    piValue4 = value142
                                    if piValue4 then
                                        piValue4 = (piValue3 ~= entries49[key3][9])
                                        if piValue4 then
                                            piValue4 = (piValue3 ~= entries49[key3][8])
                                        end
                                    end
                                    value142 = piValue4
                                end
                            end
                        end
                        math_pi_45.set_visible(piValue3, value142)
                    end
                end
            end
            return
        end
    end
    create = writefile
    load = to_string("!default_preset2124089493w.cfg")
    create(load, builtin_preset_payloads[1])
    create = writefile
    load = to_string("!default_fs_preset2124089493w.cfg")
    create(load, builtin_preset_payloads[2])
    do
        local math_pi_46, state87, value114, value115, to_string_3, require_tohex_15
        math_pi_46 = abs
        state87 = entries18
        value114 = entries22
        value115 = entries4
        to_string_3 = to_string
        require_tohex_15 = arshift
        create = function()
            local piValue2, piValue3, entries48, piValue4
            local g_notify_add = math_pi_46.get(state87.config[2])
            if (g_notify_add == "") then
                g_notify_add = value114
                piValue2 = math_pi_46.get(state87.misc[2])
                g_notify_add = g_notify_add(piValue2, "config changes")
                if g_notify_add then
                    g_notify_add = g_notify
                    g_notify_add.add(g_notify_add, "(error) empty config name", nil, 5)
                end
                return
            end
            g_notify_add = value114
            piValue2 = value115()
            piValue3 = math_pi_46.get(state87.config[2])
            g_notify_add = g_notify_add(piValue2, (piValue3 .. "2124089493w.cfg"))
            if (not g_notify_add) then
                g_notify_add = value114
                piValue2 = math_pi_46.get(state87.misc[2])
                g_notify_add = g_notify_add(piValue2, "config changes")
                if g_notify_add then
                    g_notify_add = g_notify
                    piValue2 = g_notify_add
                    g_notify_add = g_notify_add.add
                    piValue3 = math_pi_46.get(state87.config[2])
                    g_notify_add(piValue2, ("'" .. (piValue3 .. "' anti-aim config created")), nil, 5)
                end
                g_notify_add = writefile
                piValue2 = to_string_3
                piValue3 = math_pi_46.get(state87.config[2])
                piValue2 = piValue2((piValue3 .. "2124089493w.cfg"))
                g_notify_add(piValue2, "blank")
            else
                g_notify_add = value114
                piValue2 = math_pi_46.get(state87.misc[2])
                g_notify_add = g_notify_add(piValue2, "config changes")
                if g_notify_add then
                    g_notify_add = g_notify
                    piValue2 = g_notify_add
                    g_notify_add = g_notify_add.add
                    piValue3 = require_tohex_15.sub
                    entries48 = value115()
                    piValue4 = math_pi_46.get(state87.config[1])
                    piValue3 = piValue3(entries48[(piValue4 + 1)], 1, (-16))
                    g_notify_add(piValue2, ("(error) '" .. (piValue3 .. "' anti-aim config already exists")), nil, 5)
                end
            end
            return
        end
    end
    do
        local math_pi_47, state88, value116, value117, require_tohex_16, label_7, require_26,
              iterate_array_13, value118, value119, iterate_pairs_11, callback6
        math_pi_47 = abs
        state88 = entries18
        value116 = entries4
        value117 = entries22
        require_tohex_16 = arshift
        label_7 = label
        require_26 = require_6
        iterate_array_13 = iterate_array
        value118 = text4
        value119 = entries11
        iterate_pairs_11 = iterate_pairs
        callback6 = to_string
        load = function()
            local key3, piValue2, piValue3, entries48, entries49, key4, value142, amount4,
                  amount5, amount6, index6, value143, value144, value145, index7, entry_2,
                  iterate_array_18, value146, value147, index8, entry_3
            local value148 = nil
            local entries50 = math_pi_47.get(state88.config[1])
            if (entries50 ~= value148) then
                key3 = value116()
                piValue2 = math_pi_47.get(state88.config[1])
                if (key3[(piValue2 + 1)] ~= value148) then
                    goto branch_1
                end
            end
            entries50 = value117
            key3 = math_pi_47.get(state88.misc[2])
            entries50 = entries50(key3, "config changes")
            if entries50 then
                entries50 = g_notify
                entries50.add(entries50, "(error) no config selected", nil, 5)
            end
            do
                return
            end
            ::branch_1::
            entries50 = readfile
            key3 = value116()
            piValue2 = math_pi_47.get(state88.config[1])
            entries50 = entries50(key3[(piValue2 + 1)])
            if (entries50 == "blank") then
                entries50 = value117
                key3 = math_pi_47.get(state88.misc[2])
                entries50 = entries50(key3, "config changes")
                if entries50 then
                    entries50 = g_notify
                    key3 = entries50
                    entries50 = entries50.add
                    piValue2 = require_tohex_16.sub
                    piValue3 = value116()
                    entries48 = math_pi_47.get(state88.config[1])
                    piValue2 = piValue2(piValue3[(entries48 + 1)], 1, (-16))
                    entries50(key3, ("(error) '" .. (piValue2 .. "' anti-aim config is blank")), nil, 5)
                end
                return
            end
            entries50 = label_7
            key3 = require_26.decode
            piValue2 = readfile
            piValue3 = value116()
            entries48 = math_pi_47.get(state88.config[1])
            piValue2 = piValue2(piValue3[(entries48 + 1)])
            key3 = key3(piValue2, "base64")
            entries50 = entries50(key3, "_")
            key3 = 1
            piValue2 = iterate_array_13
            piValue3 = {}
            entries48 = value118
            entries49 = value119
            piValue3[1] = entries48
            piValue3[2] = entries49
            piValue2, piValue3, entries48 = piValue2(piValue3)
            iterate_array_18 = piValue2
            value146 = piValue3
            value147 = entries48
            for index8, entry_3 in iterate_array_18, value146, value147 do
                entries48 = entry_3
                entries49, key4, value142 = iterate_pairs_11(entries48)
                value143 = entries49
                value144 = key4
                value145 = value142
                for index7, entry_2 in value143, value144, value145 do
                    key4 = index7
                    if (entries48 == value118) then
                        amount4 = 0
                        amount5 = 16
                        amount6 = 1
                        for index6 = amount4, amount5, amount6 do
                            if (entries50[key3] == "true") then
                                math_pi_47.set(entries48[key4][index6], true)
                            else
                                if (entries50[key3] == "false") then
                                    math_pi_47.set(entries48[key4][index6], false)
                                else
                                    math_pi_47.set(entries48[key4][index6], callback6(entries50[key3]))
                                end
                            end
                            key3 = (key3 + 1)
                        end
                    else
                        amount4 = 0
                        amount5 = 4
                        amount6 = 1
                        for index6 = amount4, amount5, amount6 do
                            if (entries50[key3] == "true") then
                                math_pi_47.set(entries48[key4][index6], true)
                            else
                                if (entries50[key3] == "false") then
                                    math_pi_47.set(entries48[key4][index6], false)
                                else
                                    math_pi_47.set(entries48[key4][index6], callback6(entries50[key3]))
                                end
                            end
                            key3 = (key3 + 1)
                        end
                    end
                end
            end
            piValue2 = value117
            piValue3 = math_pi_47.get(state88.misc[2])
            piValue2 = piValue2(piValue3, "config changes")
            if piValue2 then
                piValue2 = g_notify
                piValue3 = piValue2
                piValue2 = piValue2.add
                entries48 = require_tohex_16.sub
                entries49 = value116()
                key4 = math_pi_47.get(state88.config[1])
                entries48 = entries48(entries49[(key4 + 1)], 1, (-16))
                piValue2(piValue3, ("'" .. (entries48 .. "' anti-aim config loaded")), nil, 5)
            end
            return
        end
    end
    do
        local iterate_array_14, value120, value121, iterate_pairs_12, callback7, math_pi_48, config_load,
              require_27, value122, state89, value123, require_tohex_17
        iterate_array_14 = iterate_array
        value120 = text4
        value121 = entries11
        iterate_pairs_12 = iterate_pairs
        callback7 = to_string
        math_pi_48 = abs
        config_load = export
        require_27 = require_6
        value122 = entries4
        state89 = entries18
        value123 = entries22
        require_tohex_17 = arshift
        save = function()
            local key3, value142, amount4, amount5, amount6, index6, text13, index7, entry_2,
                  value143, value144, value145, index8, entry_3
            local text14 = ""
            local iterate_array_18 = iterate_array_14
            local piValue2 = {}
            local entries48 = value120
            local entries49 = value121
            piValue2[1] = entries48
            piValue2[2] = entries49
            iterate_array_18, piValue2, entries48 = iterate_array_18(piValue2)
            local iterate_array_19 = iterate_array_18
            local value146 = piValue2
            local value147 = entries48
            for index7, entry_2 in iterate_array_19, value146, value147 do
                entries48 = entry_2
                entries49, key3, value142 = iterate_pairs_12(entries48)
                value143 = entries49
                value144 = key3
                value145 = value142
                for index8, entry_3 in value143, value144, value145 do
                    key3 = index8
                    if (entries48 == value120) then
                        amount4 = 0
                        amount5 = 16
                        amount6 = 1
                        for index6 = amount4, amount5, amount6 do
                            text13 = callback7(math_pi_48.get(entries48[key3][index6]))
                            text14 = (text14 .. (text13 .. "_"))
                        end
                    else
                        if (entries48 == value121) then
                            amount4, amount5, amount6 = 0, 4, 1
                            for index6 = amount4, amount5, amount6 do
                                text13 = callback7(math_pi_48.get(entries48[key3][index6]))
                                text14 = (text14 .. (text13 .. "_"))
                            end
                        end
                    end
                end
            end
            config_load.write("current_clip_board_to_save", require_27.encode(text14, "base64"))
            iterate_array_18 = config_load.read("current_clip_board_to_save")
            read_data = iterate_array_18
            iterate_array_18 = writefile
            piValue2 = value122()
            entries48 = math_pi_48.get(state89.config[1])
            iterate_array_18(piValue2[(entries48 + 1)], read_data)
            iterate_array_18 = value123
            piValue2 = math_pi_48.get(state89.misc[2])
            iterate_array_18 = iterate_array_18(piValue2, "config changes")
            if iterate_array_18 then
                iterate_array_18 = g_notify
                piValue2 = iterate_array_18
                iterate_array_18 = iterate_array_18.add
                entries48 = require_tohex_17.sub
                entries49 = value122()
                key3 = math_pi_48.get(state89.config[1])
                entries48 = entries48(entries49[(key3 + 1)], 1, (-16))
                iterate_array_18(piValue2, ("'" .. (entries48 .. "' anti-aim config saved")), nil, 5)
            end
            return
        end
    end
    do
        local math_pi_49, state90, value124, value125, require_tohex_18, state91, index5
        math_pi_49 = abs
        state90 = entries18
        value124 = entries4
        value125 = entries22
        require_tohex_18 = arshift
        state91 = entries
        index5 = index2
        delete = function()
            local piValue2, require_tohex_sub_2, piValue3, piValue4
            local value142 = nil
            local g_notify_add = math_pi_49.get(state90.config[1])
            if (g_notify_add ~= value142) then
                piValue2 = value124()
                require_tohex_sub_2 = math_pi_49.get(state90.config[1])
                if (piValue2[(require_tohex_sub_2 + 1)] ~= value142) then
                    goto branch_1
                end
            end
            do
                return
            end
            ::branch_1::
            g_notify_add = value125
            piValue2 = math_pi_49.get(state90.misc[2])
            g_notify_add = g_notify_add(piValue2, "config changes")
            if g_notify_add then
                g_notify_add = g_notify
                piValue2 = g_notify_add
                g_notify_add = g_notify_add.add
                require_tohex_sub_2 = require_tohex_18.sub
                piValue3 = value124()
                piValue4 = math_pi_49.get(state90.config[1])
                require_tohex_sub_2 = require_tohex_sub_2(piValue3[(piValue4 + 1)], 1, (-16))
                g_notify_add(piValue2, ("'" .. (require_tohex_sub_2 .. "' anti-aim config deleted")), nil, 5)
            end
            g_notify_add = state91.remove_file
            piValue2 = index5
            require_tohex_sub_2 = value124()
            piValue3 = math_pi_49.get(state90.config[1])
            piValue2 = (piValue2 .. ("/" .. require_tohex_sub_2[(piValue3 + 1)]))
            require_tohex_sub_2 = value124()
            piValue3 = math_pi_49.get(state90.config[1])
            g_notify_add(piValue2, require_tohex_sub_2[(piValue3 + 1)])
            return
        end
    end
    do
        local iterate_pairs_13, value126, math_pi_50, value127, state92
        iterate_pairs_13 = iterate_pairs
        value126 = entries12
        math_pi_50 = abs
        value127 = entries22
        state92 = entries18
        reset_2 = function()
            local state96, key3, value142, value143, value144, value145, index6, entry_2
            if (entries9 == nil) then
                return
            end
            state96, key3, value142 = iterate_pairs_13(value126)
            value143 = state96
            value144 = key3
            value145 = value142
            for index6, entry_2 in value143, value144, value145 do
                key3 = index6
                math_pi_50.set(entries9[key3][0], false)
                math_pi_50.set(entries9[key3][1], "off")
                math_pi_50.set(entries9[key3][2], 0)
                math_pi_50.set(entries9[key3][3], "local view")
                math_pi_50.set(entries9[key3][4], "off")
                math_pi_50.set(entries9[key3][5], 0)
                math_pi_50.set(entries9[key3][6], "off")
                math_pi_50.set(entries9[key3][7], 0)
                math_pi_50.set(entries9[key3][8], "off")
                math_pi_50.set(entries9[key3][9], 0)
                math_pi_50.set(entries9[key3][10], false)
                math_pi_50.set(entries9[key3][11], false)
                math_pi_50.set(entries9[key3][12], false)
                math_pi_50.set(entries9[key3][13], 0)
                math_pi_50.set(entries9[key3][14], false)
                math_pi_50.set(entries9[key3][15], "off")
                math_pi_50.set(entries9[key3][16], "off")
            end
            state96 = value127
            key3 = math_pi_50.get(state92.misc[2])
            state96 = state96(key3, "config changes")
            if state96 then
                state96 = g_notify
                state96.add(state96, "anti-aim config reset", nil, 5)
            end
            return
        end
    end
    do
        local label_8, require_28, require_29, iterate_array_15, value128, value129, iterate_pairs_14,
              math_pi_51, callback8, value130, state93
        label_8 = label
        require_28 = require_6
        require_29 = require_7
        iterate_array_15 = iterate_array
        value128 = text4
        value129 = entries11
        iterate_pairs_14 = iterate_pairs
        math_pi_51 = abs
        callback8 = to_string
        value130 = entries22
        state93 = entries18
        import_from_clipboard = function()
            local key3, value142, amount4, amount5, amount6, index6, index7, entry_2, value143,
                  value144, value145, index8, entry_3
            local entries48 = label_8
            local key4 = require_28.decode
            local iterate_array_18 = require_29.get()
            key4 = key4(iterate_array_18, "base64")
            entries48 = entries48(key4, "_")
            key4 = 1
            iterate_array_18 = iterate_array_15
            local piValue2 = {}
            local entries49 = value128
            local value146 = value129
            piValue2[1] = entries49
            piValue2[2] = value146
            iterate_array_18, piValue2, entries49 = iterate_array_18(piValue2)
            local iterate_array_19 = iterate_array_18
            local value147 = piValue2
            local value148 = entries49
            for index7, entry_2 in iterate_array_19, value147, value148 do
                entries49 = entry_2
                value146, key3, value142 = iterate_pairs_14(entries49)
                value143 = value146
                value144 = key3
                value145 = value142
                for index8, entry_3 in value143, value144, value145 do
                    key3 = index8
                    if (entries49 == value128) then
                        amount4 = 0
                        amount5 = 16
                        amount6 = 1
                        for index6 = amount4, amount5, amount6 do
                            if (entries48[key4] == "true") then
                                math_pi_51.set(entries49[key3][index6], true)
                            else
                                if (entries48[key4] == "false") then
                                    math_pi_51.set(entries49[key3][index6], false)
                                else
                                    math_pi_51.set(entries49[key3][index6], callback8(entries48[key4]))
                                end
                            end
                            key4 = (key4 + 1)
                        end
                    else
                        amount4 = 0
                        amount5 = 4
                        amount6 = 1
                        for index6 = amount4, amount5, amount6 do
                            if (entries48[key4] == "true") then
                                math_pi_51.set(entries49[key3][index6], true)
                            else
                                if (entries48[key4] == "false") then
                                    math_pi_51.set(entries49[key3][index6], false)
                                else
                                    math_pi_51.set(entries49[key3][index6], callback8(entries48[key4]))
                                end
                            end
                            key4 = (key4 + 1)
                        end
                    end
                end
            end
            iterate_array_18 = value130
            piValue2 = math_pi_51.get(state93.misc[2])
            iterate_array_18 = iterate_array_18(piValue2, "config changes")
            if iterate_array_18 then
                iterate_array_18 = g_notify
                iterate_array_18.add(iterate_array_18, "imported wraith anti-aim", nil, 5)
            end
            return
        end
    end
    do
        local iterate_array_16, value131, value132, iterate_pairs_15, callback9, math_pi_52, require_30,
              require_31, value133, state94
        iterate_array_16 = iterate_array
        value131 = text4
        value132 = entries11
        iterate_pairs_15 = iterate_pairs
        callback9 = to_string
        math_pi_52 = abs
        require_30 = require_7
        require_31 = require_6
        value133 = entries22
        state94 = entries18
        export_to_clipboard = function()
            local key3, value142, amount4, amount5, amount6, index6, text13, index7, entry_2,
                  value143, value144, value145, index8, entry_3
            local text14 = ""
            local iterate_array_18 = iterate_array_16
            local piValue2 = {}
            local entries48 = value131
            local value146 = value132
            piValue2[1] = entries48
            piValue2[2] = value146
            iterate_array_18, piValue2, entries48 = iterate_array_18(piValue2)
            local iterate_array_19 = iterate_array_18
            local value147 = piValue2
            local value148 = entries48
            for index7, entry_2 in iterate_array_19, value147, value148 do
                entries48 = entry_2
                value146, key3, value142 = iterate_pairs_15(entries48)
                value143 = value146
                value144 = key3
                value145 = value142
                for index8, entry_3 in value143, value144, value145 do
                    key3 = index8
                    if (entries48 == value131) then
                        amount4 = 0
                        amount5 = 16
                        amount6 = 1
                        for index6 = amount4, amount5, amount6 do
                            text13 = callback9(math_pi_52.get(entries48[key3][index6]))
                            text14 = (text14 .. (text13 .. "_"))
                        end
                    else
                        if (entries48 == value132) then
                            amount4 = 0
                            amount5 = 4
                            amount6 = 1
                            for index6 = amount4, amount5, amount6 do
                                text13 = callback9(math_pi_52.get(entries48[key3][index6]))
                                text14 = (text14 .. (text13 .. "_"))
                            end
                        end
                    end
                end
            end
            iterate_array_18 = require_30.set
            piValue2 = require_31.encode(text14)
            iterate_array_18(piValue2, "base64")
            iterate_array_18 = value133
            piValue2 = math_pi_52.get(state94.misc[2])
            iterate_array_18 = iterate_array_18(piValue2, "config changes")
            if iterate_array_18 then
                iterate_array_18 = g_notify
                iterate_array_18.add(iterate_array_18, "exported wraith anti-aim", nil, 5)
            end
            return
        end
    end
    on_shutdown = entries18.config
    create_button = abs.new_button("AA", "Anti-aimbot angles", "create", create)
    on_shutdown[9] = create_button
    on_shutdown = entries18.config
    create_button = abs.new_button("AA", "Anti-aimbot angles", "load", load)
    on_shutdown[3] = create_button
    on_shutdown = entries18.config
    create_button = abs.new_button("AA", "Anti-aimbot angles", "save", save)
    on_shutdown[4] = create_button
    on_shutdown = entries18.config
    create_button = abs.new_button("AA", "Anti-aimbot angles", "delete", delete)
    on_shutdown[5] = create_button
    on_shutdown = entries18.config
    create_button = abs.new_button("AA", "Anti-aimbot angles", "reset", reset_2)
    on_shutdown[6] = create_button
    on_shutdown = entries18.config
    create_button = abs.new_button("AA", "Anti-aimbot angles", "import from clipboard", import_from_clipboard)
    on_shutdown[7] = create_button
    on_shutdown = entries18.config
    create_button = abs.new_button("AA", "Anti-aimbot angles", "export to clipboard", export_to_clipboard)
    on_shutdown[8] = create_button
    do
        local math_pi_set_callback_4, value134, math_pi_53, state95, globals_tickinterval_37,
              iterate_array_17, panorama_open_4
        math_pi_set_callback_4 = math_pi_set_callback
        value134 = helpers.handleValue6
        math_pi_53 = abs
        state95 = text5
        globals_tickinterval_37 = absoluteframetime
        iterate_array_17 = iterate_array
        panorama_open_4 = loadstring
        on_shutdown = function()
            local value142, value143, value144, value145, value146, value147, index6, entry_2
            math_pi_set_callback_4()
            value134(false)
            math_pi_53.set(state95.plist.reset, true)
            math_pi_53.set_visible(state95.plist.force_body, true)
            math_pi_53.set_visible(state95.plist.force_body_value, true)
            local players = globals_tickinterval_37.get_players(true)
            if ((#players) == 0) then
                return nil
            end
            value142, value143, value144 = iterate_array_17(players)
            value145 = value142
            value146 = value143
            value147 = value144
            for index6, entry_2 in value145, value146, value147 do
                value144 = entry_2
                panorama_open_4.set(value144, "Force body yaw", false)
                panorama_open_4.set(value144, "Force body yaw value", 0)
            end
            return
        end
    end
    do
        local math_pi_54, entity_set_prop_17, value135, math_pi_set_callback_5, value136, cvar_r_eyegloss,
              value137, value138, value139, cvar_cl_csm_translucent_shadows_2,
              cvar_cl_csm_entity_shadows_2, cvar_r_dynamiclighting, cvar_cl_csm_viewmodel_shadows_2,
              cvar_cl_csm_rope_shadows_2, cvar_cl_csm_sprite_shadows_2, value140, value141
        math_pi_54 = abs
        entity_set_prop_17 = get_all
        value135 = helpers.handleValue29
        math_pi_set_callback_5 = entries30
        value136 = cvars.fog_enable
        cvar_r_eyegloss = cvars.fog_enable_water_fog
        value137 = cvars.cl_forwardspeed
        value138 = update_state_3
        value139 = helpers.handleValue49
        cvar_cl_csm_translucent_shadows_2 = cvars.cl_csm_translucent_shadows
        cvar_cl_csm_entity_shadows_2 = cvars.cl_csm_entity_shadows
        cvar_r_dynamiclighting = cvars.cl_foot_contact_shadows
        cvar_cl_csm_viewmodel_shadows_2 = cvars.cl_csm_viewmodel_shadows
        cvar_cl_csm_rope_shadows_2 = cvars.cl_csm_rope_shadows
        cvar_cl_csm_sprite_shadows_2 = cvars.cl_csm_sprite_shadows
        value140 = helpers.handleValue24
        value141 = entries5
        create_button = function(value142)
            local callback10, text13, value143
            local piValue2 = math_pi_54.get(value142)
            local callback11 = piValue2
            if callback11 then
                callback11 = entity_set_prop_17.set_event_callback
            end
            if (not callback11) then
                callback11 = entity_set_prop_17.unset_event_callback
            end
            callback11("paint", value135)
            callback11("pre_render", math_pi_set_callback_5)
            callback11("run_command", value136)
            callback11("predict_command", cvar_r_eyegloss)
            callback11("setup_command", value137)
            callback11("net_update_start", value138)
            callback11("net_update_end", value139)
            callback11("dormant_hit", cvar_cl_csm_translucent_shadows_2)
            callback11("dormant_miss", cvar_cl_csm_entity_shadows_2)
            callback11("round_prestart", cvar_r_dynamiclighting)
            callback11("aim_fire", cvar_cl_csm_viewmodel_shadows_2)
            callback11("player_hurt", cvar_cl_csm_rope_shadows_2)
            callback11("aim_miss", cvar_cl_csm_sprite_shadows_2)
            callback11("player_death", value140)
            callback10 = callback11
            text13 = "bomb_defused"
            do
                local function update_state_6()
                    local state96 = value141
                    state96.bomb_defused = true
                    return
                end
                callback10(text13, update_state_6)
            end
            callback10 = callback11
            text13 = "bomb_exploded"
            do
                local function update_state_7()
                    local state96 = value141
                    state96.bomb_exploded = true
                    return
                end
                callback10(text13, update_state_7)
            end
            callback11("cs_match_end_restart", reset)
            callback11("cs_game_disconnected", reset)
            callback11("client_disconnect", reset)
            callback11("player_connect_full", reset)
            callback11("game_newmap", reset)
            return
        end
    end
    abs.set_callback(math_pi_new_checkbox, create_button)
    create_button(math_pi_new_checkbox)
    get_all.set_event_callback("paint_ui", on_paint_ui)
    get_all.set_event_callback("shutdown", on_shutdown)
    cvars.cl_use_opens_buy_menu = cvar["cl_use_opens_buy_menu"]
    cvars.cl_use_opens_buy_menu["set_int"](cvars.cl_use_opens_buy_menu, 0)
    cvars.cl_use_opens_buy_menu = cvar["cl_autowepswitch"]
    cvars.cl_use_opens_buy_menu["set_int"](cvars.cl_use_opens_buy_menu, 0)
    return
end


builtin_preset_payloads = {
    
    [1] = table.concat({
        "dHJ1ZV9taW5pbWFsXzBfYXQgdGFyZ2V0c18xODBfMF9za2l0dGVyXzIwX2ppdHRlcl8wX2ZhbHNlX2ZhbHNlX2ZhbHNlXzBfZmFsc2Vfb2ZmX29m",
        "Zl90cnVlX21pbmltYWxfMF9hdCB0YXJnZXRzXzE4MF8wX3NraXR0ZXJfMzBfaml0dGVyXzBfZmFsc2VfZmFsc2VfZmFsc2VfMF9mYWxzZV9vZmZf",
        "b2ZmX3RydWVfZGVmYXVsdF8wX2F0IHRhcmdldHNfMTgwXzBfc2xvd183MF9qaXR0ZXJfMF9mYWxzZV9mYWxzZV9mYWxzZV8wX2ZhbHNlX29mZl9v",
        "ZmZfdHJ1ZV9kZWZhdWx0XzBfYXQgdGFyZ2V0c18xODBfMF9za2l0dGVyXzUwX2ppdHRlcl8wX2ZhbHNlX2ZhbHNlX2ZhbHNlXzBfZmFsc2Vfb2Zm",
        "X29mZl90cnVlX2RlZmF1bHRfMF9hdCB0YXJnZXRzXzE4MF8wX3NraXR0ZXJfMzBfaml0dGVyXzBfZmFsc2VfZmFsc2VfZmFsc2VfMF9mYWxzZV9v",
        "ZmZfb2ZmX3RydWVfZGVmYXVsdF8wX2F0IHRhcmdldHNfMTgwXzBfc2xvd183M19qaXR0ZXJfMF9mYWxzZV9mYWxzZV9mYWxzZV8wX2ZhbHNlX29m",
        "Zl9vZmZfdHJ1ZV9taW5pbWFsXzBfYXQgdGFyZ2V0c18xODBfLTE1X29mZl81X3N0YXRpY18tNTRfZmFsc2VfZmFsc2VfZmFsc2VfMF9mYWxzZV9v",
        "ZmZfb2ZmX3RydWVfbWluaW1hbF8wX2F0IHRhcmdldHNfMTgwXzVfc2tpdHRlcl8zMF9qaXR0ZXJfMF9mYWxzZV9mYWxzZV9mYWxzZV8wX2ZhbHNl",
        "X29mZl9vZmZfZmFsc2Vfb2ZmXzBfbG9jYWwgdmlld19vZmZfMF9vZmZfMF9vZmZfMF9mYWxzZV9mYWxzZV9mYWxzZV8wX2ZhbHNlX29mZl9vZmZf",
        "dHJ1ZV9taW5pbWFsXzBfYXQgdGFyZ2V0c18xODBfM19vZmZzZXRfMTlfaml0dGVyXzE4MF9mYWxzZV9mYWxzZV9mYWxzZV8wX2ZhbHNlX29mZl9v",
        "ZmZfdHJ1ZV9taW5pbWFsXzBfbG9jYWwgdmlld18xODBfMF9vZmZfMF9zdGF0aWNfMTgwX2ZhbHNlX2ZhbHNlX2ZhbHNlXzBfZmFsc2Vfb2ZmX2pp",
        "dHRlcl9mYWxzZV91cF8wX2F0IHRhcmdldHNfc3Bpbl8xOV9vZmZfNDdfaml0dGVyXzBfZmFsc2VfZmFsc2VfZmFsc2VfMF9mYWxzZV91cF9vZmZf",
        "dHJ1ZV9yYW5kb21fMF9hdCB0YXJnZXRzXzE4MF8xODBfb2ZmXzBfb2ZmXzE4MF9mYWxzZV9mYWxzZV9mYWxzZV8wX2ZhbHNlX29mZl9vZmZfdHJ1",
        "ZV9taW5pbWFsXzBfYXQgdGFyZ2V0c18xODBfMF9vZmZfOF9zdGF0aWNfMF9mYWxzZV9mYWxzZV9mYWxzZV8wX2ZhbHNlX29mZl9vZmZfdHJ1ZV9k",
        "ZWZhdWx0XzBfYXQgdGFyZ2V0c18xODBfMF9vZmZfMF9zdGF0aWNfMF9mYWxzZV9mYWxzZV9mYWxzZV8wX2ZhbHNlX29mZl9vZmZfdHJ1ZV9vZmZf",
        "MF9sb2NhbCB2aWV3XzE4MF8xODBfb2ZmXzBfaml0dGVyXzBfZmFsc2VfZmFsc2VfZmFsc2VfMF9mYWxzZV9vZmZfb2ZmX2ZhbHNlX29mZl9vZmZf",
        "MF9vZmZfZmFsc2Vfb2ZmX29mZl8wX29mZl9mYWxzZV9vZmZfb2ZmXzBfb2ZmX2ZhbHNlX29mZl9vZmZfMF9vZmZfZmFsc2Vfb2ZmX29mZl8wX29m",
        "Zl9mYWxzZV9vZmZfb2ZmXzBfb2ZmX2ZhbHNlX29mZl9vZmZfMF9vZmZfZmFsc2Vfb2ZmX29mZl8wX29mZl9mYWxzZV9vZmZfb2ZmXzBfb2ZmX2Zh",
        "bHNlX29mZl9vZmZfMF9vZmZfZmFsc2Vfb2ZmX29mZl8wX29mZl9mYWxzZV9vZmZfb2ZmXzBfb2ZmX2ZhbHNlX29mZl9vZmZfMF9vZmZfZmFsc2Vf",
        "b2ZmX29mZl8wX29mZl9mYWxzZV9vZmZfb2ZmXzBfb2ZmX3RydWVfb2ZmX29mZl8wX29mZl8="
    }),
    
    [2] = table.concat({
        "ZmFsc2Vfb2ZmXzBfbG9jYWwgdmlld19vZmZfMF9vZmZfMF9vZmZfMF9mYWxzZV9mYWxzZV9mYWxzZV8wX2ZhbHNlX29mZl9vZmZfdHJ1ZV9kb3du",
        "XzBfYXQgdGFyZ2V0c18xODBfMF9za2l0dGVyXzQ1X2ppdHRlcl8wX2ZhbHNlX2ZhbHNlX3RydWVfMF9mYWxzZV9vZmZfb2ZmX3RydWVfZG93bl8w",
        "X2F0IHRhcmdldHNfMTgwXy0xX3Nsb3dfNDlfaml0dGVyXzBfZmFsc2VfZmFsc2VfdHJ1ZV8wX3RydWVfb2ZmX29wcG9zaXRlX3RydWVfZG93bl8w",
        "X2F0IHRhcmdldHNfMTgwXzFfc2xvd18xMTBfb3Bwb3NpdGVfMF9mYWxzZV9mYWxzZV9mYWxzZV8wX3RydWVfb2ZmX29wcG9zaXRlX3RydWVfZG93",
        "bl8wX2F0IHRhcmdldHNfMTgwXy01X2NlbnRlcl8yN19vcHBvc2l0ZV8wX2ZhbHNlX2ZhbHNlX2ZhbHNlXzBfdHJ1ZV96ZXJvX3NwaW5fdHJ1ZV9t",
        "aW5pbWFsXy00Nl9hdCB0YXJnZXRzXzE4MF8tNV9jZW50ZXJfMjdfc3RhdGljXzdfZmFsc2VfZmFsc2VfZmFsc2VfMF90cnVlX3JhbmRvbV9qaXR0",
        "ZXJfdHJ1ZV9kb3duXzBfYXQgdGFyZ2V0c18xODBfLTdfb2ZmXzMyX3N0YXRpY18tMTgwX2ZhbHNlX2ZhbHNlX2ZhbHNlXzBfZmFsc2Vfb2ZmX29m",
        "Zl90cnVlX21pbmltYWxfMF9hdCB0YXJnZXRzXzE4MF8tMV9zbG93XzQ1X29wcG9zaXRlXy0xODBfZmFsc2VfZmFsc2VfZmFsc2VfMF90cnVlX21p",
        "bmltYWxfb3Bwb3NpdGVfdHJ1ZV9kb3duXzBfYXQgdGFyZ2V0c18xODBfLTJfY2VudGVyXzMyX3N0YXRpY18tMTgwX2ZhbHNlX2ZhbHNlX2ZhbHNl",
        "XzBfdHJ1ZV9taW5pbWFsX29wcG9zaXRlX2ZhbHNlX29mZl8wX2xvY2FsIHZpZXdfb2ZmXzBfb2ZmXzBfb2ZmXzBfZmFsc2VfZmFsc2VfZmFsc2Vf",
        "MF9mYWxzZV9vZmZfb2ZmX2ZhbHNlX29mZl8wX2xvY2FsIHZpZXdfb2ZmXzBfb2ZmXzBfb2ZmXzBfZmFsc2VfZmFsc2VfZmFsc2VfMF9mYWxzZV9v",
        "ZmZfb2ZmX3RydWVfZG93bl8wX2F0IHRhcmdldHNfMTgwXzBfb2ZmXzE1X29wcG9zaXRlXzBfZmFsc2VfZmFsc2VfZmFsc2VfMF9mYWxzZV9vZmZf",
        "b2ZmX3RydWVfb2ZmXzBfYXQgdGFyZ2V0c18xODBfMTgwX29mZl8wX29wcG9zaXRlXzBfZmFsc2VfZmFsc2VfZmFsc2VfMF9mYWxzZV9vZmZfb2Zm",
        "X2ZhbHNlX21pbmltYWxfMF9hdCB0YXJnZXRzXzE4MF8tMV9vZmZfOF9vcHBvc2l0ZV8zX2ZhbHNlX2ZhbHNlX2ZhbHNlXzBfZmFsc2VfbWluaW1h",
        "bF9vZmZfZmFsc2Vfb2ZmXzBfbG9jYWwgdmlld19vZmZfMF9vZmZfMF9vZmZfMF9mYWxzZV9mYWxzZV9mYWxzZV8wX2ZhbHNlX29mZl9vZmZfdHJ1",
        "ZV9jdXN0b21fMF9hdCB0YXJnZXRzX29mZl8wX29mZl8wX29wcG9zaXRlXzE4MF9mYWxzZV9mYWxzZV9mYWxzZV8wX2ZhbHNlX29mZl9vZmZfZmFs",
        "c2Vfb2ZmX29mZl8wX29mZl9mYWxzZV9vZmZfb2ZmXzBfb2ZmX2ZhbHNlX29mZl9vZmZfMF9vZmZfZmFsc2Vfb2ZmX29mZl8wX29mZl9mYWxzZV9v",
        "ZmZfb2ZmXzBfb2ZmX2ZhbHNlX29mZl9vZmZfMF9vZmZfZmFsc2Vfb2ZmX29mZl8wX29mZl9mYWxzZV9vZmZfb2ZmXzBfb2ZmX2ZhbHNlX29mZl9v",
        "ZmZfMF9vZmZfZmFsc2Vfb2ZmX29mZl8wX29mZl9mYWxzZV9vZmZfb2ZmXzBfb2ZmX2ZhbHNlX2Zha2UgZG93biAoLTE4MClfY2VudGVyXzIzX2pp",
        "dHRlcl9mYWxzZV9vZmZfb2ZmXzBfb2ZmX2ZhbHNlX29mZl9vZmZfMF9vZmZfZmFsc2Vfb2ZmX29mZl8wX29mZl90cnVlX29mZl9vZmZfMF9vZmZf"
    }),
}

return initialize

end)()
initialize()
client.log("[Wraith local] Loaded; menu: AA > Anti-aimbot angles")
return runtime
