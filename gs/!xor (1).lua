--- @diagnostic disable
local ffi = require "ffi"
local antiaim_funcs = require "gamesense/antiaim_funcs"
local vector = require "vector"
local ent = require "gamesense/entity"
pBase64 = require("gamesense/base64")
pClipboard = require("gamesense/clipboard")
csgo_weapons = require("gamesense/csgo_weapons")

local client_scale_damage, client_trace_bullet, client_set_clan_tag, client_exec, client_eye_position, client_userid_to_entindex, client_latency, client_camera_angles, client_color_log, client_create_interface, client_current_threat, client_delay_call, client_find_signature, client_trace_line,
client_key_state, client_screen_size, client_set_event_callback, client_system_time, client_unset_event_callback, client_random_int, client_random_float, database_read, database_write, entity_get_classname,
entity_get_local_player, entity_get_origin, entity_get_player_name, entity_get_prop, entity_get_steam64,
entity_is_alive, globals_framecount, globals_realtime, globals_servertickcount, math_max, math_min,
panorama_loadstring, renderer_gradient, renderer_rectangle, table_insert, ui_get, ui_is_menu_open, ui_mouse_position, ui_new_checkbox, ui_new_color_picker, ui_new_combobox,
ui_new_slider, ui_set, ui_set_visible, ui_new_multiselect, setmetatable, pairs, error, globals_absoluteframetime, globals_curtime, 
globals_frametime, globals_maxplayers, globals_tickcount, globals_tickinterval, math_abs, type, pcall, renderer_load_svg, renderer_blur,
renderer_indicator, renderer_circle, renderer_circle_outline, renderer_load_rgba, renderer_measure_text, renderer_text, renderer_texture, renderer_triangle, renderer_world_to_screen, tostring, ui_new_button, ui_new_hotkey, ui_new_label, ui_new_listbox, ui_new_textbox, ui_reference, ui_set_callback, ui_type,
ui_update, entity_is_enemy, entity_set_prop, entity_is_dormant, entity_hitbox_position, entity_get_players, entity_get_player_weapon, entity_get_esp_data, unpack, tonumber, toticks, vtable_bind, plist_set, plist_get =
    client.scale_damage, client.trace_bullet, client.set_clan_tag, client.exec, client.eye_position, client.userid_to_entindex, client.latency, client.camera_angles, client.color_log, client.create_interface, client.current_threat, client.delay_call,
    client.find_signature, client.trace_line, client.key_state, client.screen_size,
    client.set_event_callback, client.system_time, client.unset_event_callback, client.random_int, client.random_float, database.read,
    database.write, entity.get_classname, entity.get_local_player, entity.get_origin, entity.get_player_name,
    entity.get_prop, entity.get_steam64, entity.is_alive, globals.framecount, globals.realtime, globals.servertickcount,
    math.max, math.min, panorama.loadstring, renderer.gradient, renderer.rectangle,
    table.insert, ui.get, ui.is_menu_open, ui.mouse_position, ui.new_checkbox,
    ui.new_color_picker, ui.new_combobox, ui.new_slider, ui.set, ui.set_visible, ui.new_multiselect, setmetatable, pairs, error,
    globals.absoluteframetime, globals.curtime, globals.frametime, globals.maxplayers, globals.tickcount,
    globals.tickinterval, math.abs, type, pcall, renderer.load_svg, renderer.blur, renderer.indicator, renderer.circle ,renderer.circle_outline, renderer.load_rgba, renderer.measure_text,
    renderer.text, renderer.texture, renderer.triangle, renderer.world_to_screen, tostring, ui.new_button, ui.new_hotkey, ui.new_label, ui.new_listbox,
    ui.new_textbox, ui.reference, ui.set_callback, ui.type, ui.update, entity.is_enemy, entity.set_prop,
    entity.is_dormant, entity.hitbox_position,
    entity.get_players, entity.get_player_weapon, entity.get_esp_data, unpack, tonumber, toticks, vtable_bind, plist.set, plist.get
local math_cos, math_sin, math_rad, math_floor, bit_band, json_stringify, json_parse = math.cos, math.sin, math.rad, math.floor, bit.band, json.stringify, json.parse
--- @diagnostic enable

--script info

local script = {
    name = "Xor Bytes",
    shortname = "Xor",
    build = _USER_NAME and "Release" or "Beta",
    user = _USER_NAME or "Dev1337",
    update = "2025-02-19 00:13:37"
}

--References
local ref = {
    antiaim_switch = ui_reference("AA", "Anti-aimbot angles", "Enabled"),
    pitch = { ui_reference("AA", "Anti-aimbot angles", "Pitch") },
    yaw = { ui_reference("AA", "Anti-aimbot angles", "Yaw") },
    bodyyaw = { ui_reference("AA", "Anti-aimbot angles", "Body yaw") },
    yaw_base = ui_reference("AA", "Anti-aimbot angles", "Yaw base"),
    yaw_jitter = { ui_reference("AA", "Anti-aimbot angles", "Yaw jitter") },
    freestanding_bodyyaw = ui_reference("AA", "Anti-aimbot angles", "Freestanding body yaw"),
    edgeyaw = ui_reference("AA", "Anti-aimbot angles", "Edge yaw"),
    freestanding = { ui_reference("AA", "Anti-aimbot angles", "Freestanding") },
    roll = ui_reference("AA", "Anti-aimbot angles", "Roll"),
    fakelag = ui_reference("AA", "Fake lag", "Enabled"),
    fakelag_mode = ui_reference("AA", "Fake lag", "Amount"),
    fakelag_variance = ui_reference("AA", "Fake lag", "Variance"),
    fakelag_limit = ui_reference("AA", "Fake lag", "Limit"),
    log_spread = ui_reference("RAGE", "Other", "Log misses due to spread"),
    fakeduck = ui_reference("RAGE", "Other", "Duck peek assist"),
    leg_movement = ui_reference("AA", "Other", "Leg movement"),
    slowwalk = { ui_reference("AA", "Other", "Slow motion") },
    fakepeek = { ui_reference("AA", "Other", "Fake peek") },

    --rage
    aimbot = ui_reference("RAGE", "Aimbot", "Enabled"),
    doubletap = { ui_reference("RAGE", "Aimbot", "Double Tap") },
    doubletap_hitchance = ui_reference("RAGE", "Aimbot", "Double tap hit chance"),
    doubletap_fakelag = ui_reference("RAGE", "Aimbot", "Double tap fake lag limit"),
    hideshot = { ui_reference("AA", "Other", "On shot anti-aim") },
    multipoint = ui_reference("RAGE", "Aimbot", "Multi-point scale"),
    mindmg = ui_reference("RAGE", "Aimbot", "Minimum damage"),
    mindmg_override = { ui_reference("Rage", "Aimbot", "Minimum damage override") },
    force_bodyaim = ui_reference("RAGE", "Aimbot", "Force body aim"),
    force_safepoint = ui_reference("RAGE", "Aimbot", "Force safe point"),
    correction = ui_reference("RAGE", "Other", "Anti-aim correction"),
    delayshot = ui_reference("RAGE", "Other", "Delay shot"),
    quick_peek = { ui_reference("Rage", "Other", "Quick peek assist") },
    accuracy_boost = ui_reference("RAGE", "Other", "Accuracy boost"),

    --visiual
    flags = ui_reference("Visuals", "Player ESP", "Flags"),
    thirdperson = {ui_reference("Visuals", "Effects", "Force Third Person (alive)")},

    -- misc
    airstrafe = ui_reference("MISC", "Movement", "Air strafe"),
    clantag = ui_reference("MISC", "Miscellaneous", "Clan tag spammer"),
    log_damage = ui_reference("MISC", "Miscellaneous", "Log damage dealt"),
    untrust = ui_reference("MISC", "Settings", "Anti-untrusted"),
    ping_spike = {ui.reference("Misc", "Miscellaneous", "Ping spike")},
    sv_maxusrcmdprocessticks = ui_reference("MISC", "Settings", "sv_maxusrcmdprocessticks2"),
    sv_maxusrcmdprocessticks_holdaim = ui_reference("Misc", "Settings", "sv_maxusrcmdprocessticks_holdaim"),
    sv_maxunlag = ui_reference("MISC", "Settings", "sv_maxunlag2"),
    autogrenade_enable = ui_reference("MISC", "Miscellaneous", "Automatic grenade release"),
    autogrenade_dmg = ui_reference("MISC", "Miscellaneous", "Minimum grenade damage"),

    --settings
    dpi_scale = ui_reference("MISC", "Settings", "DPI scale"),
    color = ui_reference("MISC", "Settings", "Menu color"),

    -- end of menu references and menu creation
}

sv_maxunlag = cvar.sv_maxunlag
sv_gravity = cvar.sv_gravity
cl_sidespeed = cvar.cl_sidespeed
weapon_accuracy_nospread  = cvar.weapon_accuracy_nospread
mp_teammates_are_enemies = cvar.mp_teammates_are_enemies
ui_set(ref.sv_maxusrcmdprocessticks,16)

local function vanila_skeet_element(state)
    ui_set_visible(ref.pitch[1], state)
    ui_set_visible(ref.pitch[2], state)
    ui_set_visible(ref.yaw_base, state)
    ui_set_visible(ref.yaw[1], state)
    ui_set_visible(ref.yaw[2], state)
    ui_set_visible(ref.yaw_jitter[1], state)
    ui_set_visible(ref.yaw_jitter[2], state)
    ui_set_visible(ref.bodyyaw[1], state)
    ui_set_visible(ref.bodyyaw[2], state)
    ui_set_visible(ref.freestanding_bodyyaw, state)
    ui_set_visible(ref.roll, state)
    ui_set_visible(ref.freestanding[1], state)
    ui_set_visible(ref.freestanding[2], state)
    ui_set_visible(ref.edgeyaw, state)
    ui_set_visible(ref.antiaim_switch, state)
    ui_set_visible(ref.fakelag, state)
    ui_set_visible(ref.fakelag_mode, state)
    ui_set_visible(ref.fakelag_variance, state)
    ui_set_visible(ref.fakelag_limit, state)
end

local function contains(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then
            return true
        end
    end
    return false
end


local flags = {
    ['H'] = { 0, 1 },
    ['K'] = { 1, 2 },
    ['HK'] = { 2, 4 },
    ['ZOOM'] = { 3, 8 },
    ['BLIND'] = { 4, 16 },
    ['RELOAD'] = { 5, 32 },
    ['C4'] = { 6, 64 },
    ['VIP'] = { 7, 128 },
    ['DEFUSE'] = { 8, 256 },
    ['FD'] = { 9, 512 },
    ['PIN'] = { 10, 1024 },
    ['HIT'] = { 11, 2048 },
    ['O'] = { 12, 4096 },
    ['X'] = { 13, 8192 },
    ['DEF'] = { 17, 131072 }
}


function say_phrases(phrases)
    local localplayer = entity_get_local_player()

    for i, phrase in pairs(phrases) do
        client_delay_call(
            2 * i,
            function()
                -- ?????????? ??????? ??????? ?????? ?????, ????? ???????? ??????
                --local sanitized_phrase = phrase:gsub('"', "")

                if localplayer then
                    client_exec('say ' .. phrase)
                end
            end
        )
    end
end

local rutrashtalk = {
    [1] = {"Xor.Bytes", "对不起 请你先别破防", "1,你怎么这么菜..."},
    [2] = {"用绿演参是打不中我的", "怎么退出训练营"},
    [3] = {"对不起没玩过cs2，不理解你的打法", "你选错cs2启动项了"},
    [4] = {"转人工", "小孩子不懂事e着玩的"},
    [5] = {"忘注入了，绿玩杀的", "这智商去玩cs2吧，那里适合你"},
    [6] = {"嘿，你是在试图击打我身边的空气来窒息我？", "1"},
    [7] = {"ez", "杀你只需要一根手指", "我没想到你参数这么垃圾..."},
    [8] = {"你在用otc么废物?", "你没注入吗？"},
    [9] = {"你被你爹1了,滚去买个好点的参数吧", "你也被脑控了吗"},
    [10] = {"别找借口 菜是原罪", "下去沉淀一下吧", "你不太够格挑战我"},
    [11] = {"别急 打不过我很正常", "你要来当我的坐骑吗"},
    [12] = {"别急 回家找妈妈安慰一下你吧 如果没有的话可以去转转租一个", "你没开ragebot吗 怎么打不中我", "农村人滚回去种地"},
    [13] = {"你的脑容量比你参群人数还少", "你在屏幕前红温的样子被我记录下来了"},
    [14] = {"这就死了吗...我都还没开始发力", "我没想到你参数这么垃圾..."},
    [15] = {"你的aa比薯片脆", "实在不行你去买个模型吧"},
    [16] = {"ez kill", "XOR.BYTES", "XOR.BYTES For Gamesense", "这也能被杀 买个脑白金补补脑子吧"},
    [17] = {"5oiR5pON5L2g5aaI56qd5ZuK5bqfMQ==", "ez1tap", "生气了吗？"},
    [18] = {"clown", "u mad? ", "stay mad", "hdf nn",},
    [19] = {"client.exec('say ez')", "ez", "owned bot"}
}

local function has_flag(entindex, flag_name)
    if not entindex or not flag_name then
        return false
    end

    local flag_data = flags[flag_name]

    if flag_data == nil then
        return false
    end

    local esp_data = entity_get_esp_data(entindex) or {}

    return bit_band(esp_data.flags or 0, bit.lshift(1, flag_data[1])) == flag_data[2]
end

function angle_to_forward(angle_x, angle_y)
    local sy = math_sin(math_rad(angle_y));
    local cy = math_cos(math_rad(angle_y));
    local sp = math_sin(math_rad(angle_x));
    local cp = math_cos(math_rad(angle_x));
    return cp * cy, cp * sy, -sp
end

math_clamp = function(val, min, max)
    return math.min(max, math_max(min, val))
end

local function normalize_yaw(yaw)
    return (yaw + 180) % 360 - 180
end

local function entity_can_fire(ent)
    return globals_curtime() >= entity_get_prop(ent, 'm_flNextAttack')
end

local function weapon_can_fire(ent)
    return globals_curtime() >= entity_get_prop(ent, 'm_flNextPrimaryAttack')
end

local color_to_hex = function (color)
    return string.format("\a%02X%02X%02X%02X", color[1], color[2], color[3], color[4])
end
-- main color
local color = { 186, 186, 249, 247 }
local color_hex = color_to_hex(color)
local color_hex_no_alpha = string.format("\a%02X%02X%02X", color[1], color[2], color[3])
local colors = {
    blue = "\aA9B7FFFF",
    bright = "\aE3E9FFFF",
    grey = "\aFFFFFF8D",
    default = "\aD5D5D5FF",
    bright_red = "\aFF9A9AFF",
    white = "\aFFFFFFFF",
    new_blue = "\aBABAF9F7",
    new_grey = "\a666666ff",
}

dpi = 0

local TAB = { "AA", "Anti-aimbot angles", "Fake lag", "Other" }

local master_switch = ui_new_checkbox(TAB[1], TAB[3], color_hex .. "✧ X O R  B Y T E S ✧")
local info = {}
local rage = {}
local antiaim = {}
local builder = {}
local visuals = {}
local misc = {}
local config = {}
local list = {
    color_hex.."Info",
    color_hex.."Rage",
    color_hex.."Antiaim",
    color_hex.."Builder",
    color_hex.."Visuals",
    color_hex.."Misc",
    color_hex.."Config"
}

local page = ui_new_listbox(TAB[1], TAB[3], "Page", list)
local Team = { "Counter Strike", "Counter Terrorist"}
local State_advanced = { "*", "Fakelag"}
local State = { "Global", "Standing", "Running", "Slow", "Ducking", "Duck Running", "Jumping", "Jump Duck"}
local Especial = { "Manual", "Freestanding",  "Height Above", "Height Below", "High Range"}
info.name = ui_new_label(TAB[1], TAB[2],  color_hex .. "             ₤ ".. script.name .." ₤ \n")
info.blank = ui_new_label(TAB[1], TAB[2],  colors.bright .. "\nblank")
info.update = ui_new_label(TAB[1], TAB[2], colors.grey .. "Latest update: ".. color_hex .. script.update)
info.text3 = ui_new_label(TAB[1], TAB[2],  colors.bright .. "# Release \n")
info.text4 = ui_new_label(TAB[1], TAB[2], "\ntext4")
info.build = ui_new_label(TAB[1], TAB[2], colors.grey .. "Build: " .. color_hex .. script.build)
info.user = ui_new_label(TAB[1], TAB[2], colors.grey .. "Enjoy! " .. color_hex .. script.user .. colors.grey .. " :D")

rage.main = ui_new_multiselect(TAB[1], TAB[2], "Rage Funcs", {"Strafe Fix", "Jump Scout", "Revolver Improvements", "Magnet Melee", "Friendly Fire"})
rage.jumpscout_distance = ui_new_slider(TAB[1], TAB[2], color_hex.."Jump Scout  \aFFFFFFFFDistance", 0, 4000, 700, true, 'u', 1, {[0] = '∞'})
rage.jumpscout_settings = ui_new_multiselect(TAB[1], TAB[2], color_hex.."Jump Scout  \aFFFFFFFFSettings", {"Allow Jump Duck"})
rage.revolver_indicator = ui_new_checkbox(TAB[1], TAB[2], color_hex.."Revolver  \aFFFFFFFFIndicator\n")
rage.revolver_indicator_settings = ui_new_multiselect(TAB[1], TAB[2], "\n Revolver Indicator Settings", {"Glow", "Custom Color"})
rage.revolver_indicator_color = ui_new_color_picker( TAB[1], TAB[2], " revolver", 255, 255, 255, 255 )
rage.revolver_force_second_fire = ui_new_hotkey(TAB[1], TAB[2], color_hex.."Revolver  \aFFFFFFFFForce Secondary Fire")
rage.revolver_second_fire_distance = ui_new_slider(TAB[1], TAB[2], "\n Revolver Force Secondary Fire Distance", 0, 1000, 150, true, 'u', 1, {[0] = '∞'})
-- rage.ragebot_logics = ui_new_multiselect(TAB[1], TAB[2], color_hex.."Ragebot Logics\n", {"Smart Safepoint", "Smart Bodyaim(Prefer)", "Smart Bodyaim(Force)"})
rage.magnet_key = ui_new_hotkey(TAB[1], TAB[2], color_hex.."Magnet Melee")
rage.friendly_fire = ui_new_hotkey(TAB[1], TAB[2], color_hex.."Firendly Fire")

antiaim.fakelag_mode = ui_new_combobox(TAB[1], TAB[2], color_hex.."Fakelag\nMode", {"Maximum", "Randomize", "Jitter", "Alternative"})
antiaim.fakelag_limit = ui_new_slider(TAB[1], TAB[2], "\aFFFFFFFFLimit\n Fakelag", 1, 15, 1, true)
antiaim.fakelag_limit2 = ui_new_slider(TAB[1], TAB[2], "\aFFFFFFFFLimit 2\n Fakelag", 1, 15, 1, true)
antiaim.fakelag_send = ui_new_slider(TAB[1], TAB[2], "\aFFFFFFFFSend\n Fakelag", 1, 15, 1, true)
antiaim.fakelag_choke = ui_new_slider(TAB[1], TAB[2], "\aFFFFFFFFChoke\n Fakelag", 1, 15, 1, true)
antiaim.fakelag_disablers = ui_new_multiselect(TAB[1], TAB[2], color_hex.."Fakelag  \aFFFFFFFFDisablers\n Fakelag", {"Shot", "Standing", "Running", "Slow", "Ducking", "Duck Running", "Jumping", "Jump Duck"})
antiaim.features = ui_new_multiselect(TAB[1], TAB[2], "Features\n", {"Manual AA", "Safe Head", "Inuse AA", "Anti Backstab", "Fast Ladder", "Smooth Landing Check", "Anti Bruteforce"})
antiaim.manual_left = ui_new_hotkey(TAB[1], TAB[2], color_hex.."Manual  \aFFFFFFFFLeft")
antiaim.manual_right = ui_new_hotkey(TAB[1], TAB[2], color_hex.."Manual  \aFFFFFFFFRight")
antiaim.manual_forward = ui_new_hotkey(TAB[1], TAB[2], color_hex.."Manual  \aFFFFFFFFForward")
antiaim.manual_back = ui_new_hotkey(TAB[1], TAB[2], color_hex.."Manual  \aFFFFFFFFBack")
antiaim.manual_freestand = ui_new_hotkey(TAB[1], TAB[2], color_hex.."Manual  \aFFFFFFFFFreestanding")
antiaim.safehead_mode = ui_new_combobox(TAB[1], TAB[2], color_hex.."Safe Head \n", {"Hide", "Bait"})
antiaim.fastladder_mode = ui_new_combobox(TAB[1], TAB[2], color_hex.."Fast Ladder \n", {"Normal", "Wait Choke"})
antiaim.anti_bruteforce_mode = ui_new_combobox(TAB[1], TAB[2], color_hex.."Anti Bruteforce \n", {"Invert", "Random", "Custom"})
antiaim.anti_bruteforce_amount = ui_new_slider(TAB[1], TAB[2], "\nAnti Bruteforce Amount", 0, 10, 0, true)
antiaim.anti_bruteforce_custom = {}
for i = 1, 10, 1 do
    antiaim.anti_bruteforce_custom[i] = ui_new_slider(TAB[1], TAB[2], color_hex.."Anti Bruteforce \aFFFFFFFF#"..tostring(i), -60, 60, 0, true)
end

builder.state_style = ui_new_combobox(TAB[1], TAB[2], "State\n", {"Advanced", "Especial"})
builder.team = ui_new_combobox(TAB[1], TAB[2], "\nteam", {"Counter Strike", "Counter Terrorist"})
builder.state_advanced = ui_new_combobox(TAB[1], TAB[2], "\nstate_advanced", State_advanced)
builder.state = ui_new_combobox(TAB[1], TAB[2], "\nstate", State)
builder.especial_state = ui_new_combobox(TAB[1], TAB[2], "\nespecial_state", Especial)

visuals.main = ui_new_multiselect(TAB[1], TAB[2], "Visuals", {"Main Indicator", "Damage Indicator", "Hitlog", "Watermark", "Defensive Indicator", "Slowdown Indicator", "Spectator List", "Optimize Skeet Indicators"})
visuals.main_indicator_settings = ui_new_multiselect(TAB[1], TAB[2], color_hex.."Main Indicator", {"Custom NameTag", "Disable Keybinds", "Custom colors", "Manual Dick"})
visuals.main_indicator_name_tag = ui_new_textbox(TAB[1], TAB[2], "   ")
visuals.main_indicator_colors = {
    Label_a = ui_new_label( TAB[1], TAB[2], color_hex.."Custom  \aFFFFFFFFLeft Color" ),
    left = ui_new_color_picker( TAB[1], TAB[2], " 1", 154, 226, 250, 255 ),
    Label_b = ui_new_label( TAB[1], TAB[2], color_hex.."Custom  \aFFFFFFFFLeft Alt Color" ),
    left_alt = ui_new_color_picker( TAB[1], TAB[2], " 2", 109, 213, 250, 255 ),
    Label_c = ui_new_label( TAB[1], TAB[2], color_hex.."Custom  \aFFFFFFFFRight Color" ),
    right = ui_new_color_picker( TAB[1], TAB[2], " 3", 255, 255, 255, 220 ),
    Label_d = ui_new_label( TAB[1], TAB[2], color_hex.."Custom  \aFFFFFFFFRight Alt Color" ),
    right_alt = ui_new_color_picker( TAB[1], TAB[2], " 4", 253, 163, 180, 220 ),
    Label_M = ui_new_label( TAB[1], TAB[2], color_hex.."Custom  \aFFFFFFFFManual Color" ),
    MM_CLR = ui_new_color_picker( TAB[1], TAB[2], " 5", 255, 255, 255, 220 ),
}
visuals.hitlog_settings = ui_new_multiselect(TAB[1], TAB[2], color_hex.."Hitlog\n", {"to screen", "to console"})

misc.console_filter = ui_new_checkbox(TAB[1], TAB[2], "Console Filter\n")
ui_set_callback(misc.console_filter, function()
    cvar.con_filter_text:set_string("X.O.R")
    cvar.con_filter_enable:set_int(ui_get(misc.console_filter) and 1 or 0)
end)
misc.clantag = ui_new_checkbox(TAB[1], TAB[2], "Clantag Spammer\n")
misc.shittalk =  ui_new_multiselect(TAB[1], TAB[2], "Fuck Talk\n", {"Death", "Kill", "Counter"})
misc.animate_tab = ui_new_multiselect("AA", "Anti-aimbot angles", color_hex..">> Anim Breakers", { "Fallen legs", "Reset pitch on land", "Body lean", "Air walk", "Slide walk", "Jitter legs",
"Allen walk", "Earthquake", "Flashed" })
misc.earthquake_value = ui_new_slider(TAB[1], TAB[2], color_hex..">> \aFFFFFFFFEarthquake", 1, 300, 1, false, "", 0.001)
misc.exploit_features = ui_new_multiselect(TAB[1], TAB[2], "Exploit Features\n", {"Force Charge", "Hideshot Peek", "Auto Discharge", "Lag Exploit", "Auto Hideshot"})
misc.auto_discharge_key = ui_new_hotkey(TAB[1], TAB[2], color_hex.."Auto Discharge \n")
misc.auto_discharge_mode = ui_new_combobox(TAB[1], TAB[2], "\n Auto Discharge Mode", {"Offensive", "Defensive"})
misc.lag_exploit = ui_new_hotkey(TAB[1], TAB[2], color_hex.."Lag Exploit \n")
misc.lag_exploit_settings = ui_new_multiselect(TAB[1], TAB[2], "\n Lag Exploit Settings", {"Air Only", "Maximum Teleport"})
misc.auto_hideshot_disablers = ui_new_multiselect(TAB[1], TAB[2], color_hex.."Auto Hideshot \aFFFFFFFFDisablers", {"Knife", "Heavy Pistols", "Rifles", "Pistols", "Auto Snipers"})

function linear(t, b, c, d)
    return c * t / d + b
end

function solve(easing_fn, prev, new, clock, duration)
    if clock <= 0 then return new end
    if clock >= duration then return new end

    prev = easing_fn(clock, prev, new - prev, duration)

    if type(prev) == "number" then
        if math.abs(new - prev) < 0.001 then
            return new
        end

        local remainder = math.fmod(prev, 1.0)

        if remainder < 0.001 then
            return math.floor(prev)
        end

        if remainder > 0.999 then
            return math.ceil(prev)
        end
    end

    return prev
end

function get_deltatime()
    return globals_frametime()
end

function interp(a, b, t)

    if type(b) == "boolean" then
        b = b and 1 or 0
    end

    return solve(linear, a, b, get_deltatime(), t)
end

builder.conditions = {}
for k1, v1 in pairs(Team) do
    builder.conditions[k1] = {}
    for k2, v2 in pairs(State_advanced) do
        builder.conditions[k1][k2] = {}
        for k3, v3 in pairs(State) do
            builder.conditions[k1][k2][k3] = {}
                builder.conditions[k1][k2][k3] = {}
                local idx = v1..v2..v3
                builder.conditions[k1][k2][k3].enable = ui_new_checkbox(TAB[1], TAB[2], ("Enable %s-%s-%s\n"):format(v1,v2,v3))
                builder.conditions[k1][k2][k3].pitch = ui_new_slider(TAB[1], TAB[2], "Pitch\n"..idx, -89, 89, 89, true, "°")
                builder.conditions[k1][k2][k3].base = ui_new_combobox(TAB[1], TAB[2], "Yaw Base\n"..idx, {"At targets", "Local View"})
                builder.conditions[k1][k2][k3].yaw = ui_new_combobox(TAB[1], TAB[2], "Yaw Logic\n"..idx, {"Off", "Backward", "Jitter"})
                builder.conditions[k1][k2][k3].offset_main = ui_new_slider(TAB[1], TAB[2], "\nOffset Value"..idx, -180, 180, 0, true, "°")
                builder.conditions[k1][k2][k3].offset_left = ui_new_slider(TAB[1], TAB[2], "\nOffset Left"..idx, -180, 180, 0, true, "°")
                builder.conditions[k1][k2][k3].offset_right = ui_new_slider(TAB[1], TAB[2], "\nOffset Right"..idx, -180, 180, 0, true, "°")
                builder.conditions[k1][k2][k3].yaw_modifier = ui_new_combobox(TAB[1], TAB[2], "Yaw Modifier\n"..idx, {"Off", "Center", "Offset", "Random", "Spin", "xWay"})
                builder.conditions[k1][k2][k3].yaw_modifier_main = ui_new_slider(TAB[1], TAB[2], "\nYaw Modifier Value"..idx, -180, 180, 0, true, "°")
                builder.conditions[k1][k2][k3].spin_step = ui_new_slider(TAB[1], TAB[2], "\nSpin step"..idx, -60, 60, 0, true, "°")
                builder.conditions[k1][k2][k3].way = ui_new_slider(TAB[1], TAB[2], "\nWay"..idx, 2, 10, 2, true, "way")
                builder.conditions[k1][k2][k3].bodyyaw = ui_new_combobox(TAB[1], TAB[2], "Body yaw\n"..idx, {"Off", "Static", "Jitter", "Automatic"})
                builder.conditions[k1][k2][k3].bodyyaw_main = ui_new_slider(TAB[1], TAB[2], "\nBody yaw Value"..idx, -60, 60, 0, true, "°")
                builder.conditions[k1][k2][k3].bodyyaw_left = ui_new_slider(TAB[1], TAB[2], "\nBody yaw Left"..idx, -60, 60, 0, true, "°")
                builder.conditions[k1][k2][k3].bodyyaw_right = ui_new_slider(TAB[1], TAB[2], "\nBody yaw Right"..idx, -60, 60, 0, true, "°")
                -- builder.conditions[k1][k2][k3].text = ui_new_label(TAB[1], TAB[2], colors.bright.."<--------"..color_hex.."Exploit Controller"..colors.bright.."-------->\n"..idx)
                if v2 == "Fakelag" then
                    builder.conditions[k1][k2][k3].defensive_features = ui_new_multiselect(TAB[1], TAB[2], "Features\n"..idx, {"Disable Anti Bruteforce"})
                    builder.conditions[k1][k2][k3].delay_mode = ui_new_combobox(TAB[1], TAB[4], "Delay\n"..idx, {"Static", "Random", "Adaptive", "Jitter"})
                    builder.conditions[k1][k2][k3].delay = ui_new_slider(TAB[1], TAB[4], "\nDelay value"..idx, 0, 32, 0, true, "t")
                    builder.conditions[k1][k2][k3].delay_features = ui_new_multiselect(TAB[1], TAB[4], "\nDelay Features"..idx, {"Modifier Ignore Delay"})
                else
                    builder.conditions[k1][k2][k3].breaklc_mode = ui_new_combobox(TAB[1], TAB[2], "Break LC Mode\n"..idx, {"Skeet", "Maximum"})
                    builder.conditions[k1][k2][k3].breaklc_trigger = ui_new_combobox(TAB[1], TAB[2], "\nBreak LC Trigger"..idx, {"Always", "On Peek"})
                    builder.conditions[k1][k2][k3].defensive_pitch = ui_new_combobox(TAB[1], TAB[2], "Defensive Pitch & Yaw\n"..idx, {"Off", "Static", "Jitter", "Randomize", "Spin"})
                    builder.conditions[k1][k2][k3].defensive_pitch_main = ui_new_slider(TAB[1], TAB[2], "\nDefensive Pitch Value"..idx, -89, 89, 0, true, "°")
                    builder.conditions[k1][k2][k3].defensive_pitch_spin_step = ui_new_slider(TAB[1], TAB[2], "\nDefensive Pitch Step"..idx, -30, 30, 0, true, "°")
                    builder.conditions[k1][k2][k3].defensive_yaw = ui_new_combobox(TAB[1], TAB[2], "\nDefensive Yaw"..idx, {"Off", "Static", "Jitter", "Randomize", "Spin"})
                    builder.conditions[k1][k2][k3].defensive_yaw_main = ui_new_slider(TAB[1], TAB[2], "\nDefensive Yaw Value"..idx, -180, 180, 0, true, "°")
                    builder.conditions[k1][k2][k3].defensive_yaw_spin_step = ui_new_slider(TAB[1], TAB[2], "\nDefensive Yaw Step"..idx, -60, 60, 0, true, "°")
                    builder.conditions[k1][k2][k3].defensive_features = ui_new_multiselect(TAB[1], TAB[2], "Features\n"..idx, {"Defensive Ignore Yaw", "Unsafe Defensive", "Nochoke Defensive", "Disable Anti Bruteforce"})
                    builder.conditions[k1][k2][k3].delay_mode = ui_new_combobox(TAB[1], TAB[4], "Delay\n"..idx, {"Static", "Random", "Adaptive", "Jitter"})
                    builder.conditions[k1][k2][k3].delay = ui_new_slider(TAB[1], TAB[4], "\nDelay value"..idx, 0, 32, 0, true, "t")
                    builder.conditions[k1][k2][k3].delay_features = ui_new_multiselect(TAB[1], TAB[4], "\nDelay Features"..idx, {"Modifier Ignore Delay", "Defensive Ignore Delay"})
                end
        end
    end
end
builder.especial_conditions = {}
for k, v in pairs(Especial) do
    builder.especial_conditions[k] = {}
    local idx = v
    builder.especial_conditions[k].enable = ui_new_checkbox(TAB[1], TAB[2], ("Enable %s\n"):format(v))
    builder.especial_conditions[k].pitch = ui_new_slider(TAB[1], TAB[2], "Pitch\n"..idx, -89, 89, 89, true, "°")
    builder.especial_conditions[k].base = ui_new_combobox(TAB[1], TAB[2], "Yaw Base\n"..idx, {"At targets", "Local View"})
    builder.especial_conditions[k].yaw = ui_new_combobox(TAB[1], TAB[2], "Yaw Logic\n"..idx, {"Off", "Backward", "Jitter"})
    builder.especial_conditions[k].offset_main = ui_new_slider(TAB[1], TAB[2], "\nOffset Value"..idx, -180, 180, 0, true, "°")
    builder.especial_conditions[k].offset_left = ui_new_slider(TAB[1], TAB[2], "\nOffset Left"..idx, -180, 180, 0, true, "°")
    builder.especial_conditions[k].offset_right = ui_new_slider(TAB[1], TAB[2], "\nOffset Right"..idx, -180, 180, 0, true, "°")
    builder.especial_conditions[k].yaw_modifier = ui_new_combobox(TAB[1], TAB[2], "Yaw Modifier\n"..idx, {"Off", "Center", "Offset", "Random", "Spin", "xWay"})
    builder.especial_conditions[k].yaw_modifier_main = ui_new_slider(TAB[1], TAB[2], "\nYaw Modifier Value"..idx, -180, 180, 0, true, "°")
    builder.especial_conditions[k].spin_step = ui_new_slider(TAB[1], TAB[2], "\nSpin step"..idx, -60, 60, 0, true, "°")
    builder.especial_conditions[k].way = ui_new_slider(TAB[1], TAB[2], "\nWay"..idx, 2, 10, 2, true, "way")
    builder.especial_conditions[k].bodyyaw = ui_new_combobox(TAB[1], TAB[2], "Body yaw\n"..idx, {"Off", "Static", "Jitter", "Automatic"})
    builder.especial_conditions[k].bodyyaw_main = ui_new_slider(TAB[1], TAB[2], "\nBody yaw Value"..idx, -60, 60, 0, true, "°")
    builder.especial_conditions[k].bodyyaw_left = ui_new_slider(TAB[1], TAB[2], "\nBody yaw Left"..idx, -60, 60, 0, true, "°")
    builder.especial_conditions[k].bodyyaw_right = ui_new_slider(TAB[1], TAB[2], "\nBody yaw Right"..idx, -60, 60, 0, true, "°")
    -- builder.especial_conditions[k].text = ui_new_label(TAB[1], TAB[2], colors.bright.."----------"..color_hex.."Exploit Controller"..colors.bright.."----------\n"..idx)
    builder.especial_conditions[k].breaklc_mode = ui_new_combobox(TAB[1], TAB[2], "Break LC Mode\n"..idx, {"Skeet", "Maximum"})
    builder.especial_conditions[k].breaklc_trigger = ui_new_combobox(TAB[1], TAB[2], "\nBreak LC Trigger"..idx, {"Always", "On Peek"})
    builder.especial_conditions[k].defensive_pitch = ui_new_combobox(TAB[1], TAB[2], "Defensive Pitch & Yaw\n"..idx, {"Off", "Static", "Jitter", "Randomize", "Spin"})
    builder.especial_conditions[k].defensive_pitch_main = ui_new_slider(TAB[1], TAB[2], "\nDefensive Pitch Value"..idx, -89, 89, 0, true, "°")
    builder.especial_conditions[k].defensive_pitch_spin_step = ui_new_slider(TAB[1], TAB[2], "\nDefensive Pitch Step"..idx, -30, 30, 0, true, "°")
    builder.especial_conditions[k].defensive_yaw = ui_new_combobox(TAB[1], TAB[2], "\nDefensive Yaw"..idx, {"Off", "Static", "Jitter", "Randomize", "Spin"})
    builder.especial_conditions[k].defensive_yaw_main = ui_new_slider(TAB[1], TAB[2], "\nDefensive Yaw Value"..idx, -180, 180, 0, true, "°")
    builder.especial_conditions[k].defensive_yaw_spin_step = ui_new_slider(TAB[1], TAB[2], "\nDefensive Yaw Step"..idx, -60, 60, 0, true, "°")
    builder.especial_conditions[k].defensive_features = ui_new_multiselect(TAB[1], TAB[2], "Features\n"..idx, {"Defensive Ignore Yaw", "Unsafe Defensive", "Nochoke Defensive", "Disable Anti Bruteforce"})
    builder.especial_conditions[k].delay_mode = ui_new_combobox(TAB[1], TAB[4], "Delay\n"..idx, {"Static", "Random", "Adaptive", "Jitter"})
    builder.especial_conditions[k].delay = ui_new_slider(TAB[1], TAB[4], "\nDelay value"..idx, 0, 32, 0, true, "t")
    builder.especial_conditions[k].delay_features = ui_new_multiselect(TAB[1], TAB[4], "\nDelay Features"..idx, {"Modifier Ignore Delay", "Defensive Ignore Delay"})
end

local clases = {}
function class(name) 
    return function(tab)
        if not tab then return clases[name] end  
        tab.__index, tab.__classname = tab, name
        if tab.call then tab.__call = tab.call end 
        setmetatable(tab, tab)
        clases[name], _G[name] = tab, tab
        return tab
    end
end

local g_ctx = { 
    local_player = nil, weapon = nil,
}

local exploits = class "exploits" {
    max_process_ticks = math.abs(client.get_cvar("sv_maxusrcmdprocessticks")) - 1, -- we lost 1 tick due to createmove processing
    tickbase_difference = 0, ticks_processed = 0, command_number = 0, choked_commands = 0, need_force_defensive = false, current_shift_amount = 0,
    reset_vars = function(self) self.ticks_processed = 0 self.tickbase_difference = 0 self.choked_commands = 0 self.command_number = 0 end,
    store_vars = function(self, ctx) self.command_number = ctx.command_number self.choked_commands = ctx.chokedcommands end,
    store_tickbase_difference = function(self, ctx)
        if ctx.command_number == self.command_number then
            self.ticks_processed = math_clamp(math.abs(entity_get_prop(g_ctx.local_player, "m_nTickBase") - self.tickbase_difference), 0, self.max_process_ticks - self.choked_commands)
            self.tickbase_difference = math.max(entity_get_prop(g_ctx.local_player, "m_nTickBase"), self.tickbase_difference or 0)
            self.command_number = 0
        end
    end,
    is_doubletap = function(self) return ui_get(ref.doubletap[2]) end,
    is_hideshots = function(self) return ui_get(ref.hideshot[2]) end,
    is_active = function(self) return self:is_doubletap() or self:is_hideshots() end,
    in_defensive = function(self) return self:is_active() and (self.ticks_processed > 1 and self.ticks_processed < self.max_process_ticks) end,
    is_defensive_ended = function(self) return not self:in_defensive() or (self.ticks_processed >= 0 and self.ticks_processed <= 5) and self.tickbase_difference > 0 end,
    is_lagcomp_broken = function(self) return not self:is_defensive_ended() or self.tickbase_difference < (entity_get_prop(g_ctx.local_player, "m_nTickBase") or math.huge) end,
    can_recharge = function(self)
        if not self:is_active() then return false end
        local curtime = globals_tickinterval() * (entity_get_prop(g_ctx.local_player, "m_nTickBase") - 16)
        if curtime < entity_get_prop(g_ctx.local_player, "m_flNextAttack") then return false end
        if curtime < entity_get_prop(g_ctx.weapon, "m_flNextPrimaryAttack") then return false end
        return true
    end,
    in_recharge = function(self)
        if not (self:is_active() and self:can_recharge()) or self:in_defensive() then return false end
        local latency_shift = math.ceil(toticks(client_latency()) * 1.25)
        local current_shift_amount = ((self.tickbase_difference - globals_tickcount()) * -1) + latency_shift
        local max_shift_amount, min_shift_amount = (self.max_process_ticks - 1) - latency_shift, -(self.max_process_ticks - 1) + latency_shift
        if latency_shift ~= 0 then
            return current_shift_amount > min_shift_amount and current_shift_amount < max_shift_amount
        else
            return current_shift_amount > (min_shift_amount / 2) and current_shift_amount < (max_shift_amount / 2)
        end
    end,
    should_force_defensive = function(self, state)
        if not self:is_active() then return false end
        self.need_force_defensive = state and self:is_defensive_ended()
    end,
    allow_unsafe_charge = function(self, state)
        if not (self:is_active() and self:can_recharge()) then ui_set(ref.aimbot, true) return end
        if not state then ui_set(ref.aimbot, true) return end
        if ui_get(ref.fakeduck) then ui_set(ref.aimbot, true) return end
        ui_set(ref.aimbot, not self:in_recharge())
    end,
    force_reload_exploits = function(self, state)
        if not state then 
            ui_set(ref.doubletap[1], true) ui_set(ref.hideshot[1], true)
            return
        end
        if self:is_doubletap() and not self:in_recharge() then
            ui_set(ref.doubletap[1], false)
        else
            ui_set(ref.doubletap[1], true)
        end
        if self:is_hideshots() and not self:in_recharge() then
            ui_set(ref.hideshot[1], false)
        else
            ui_set(ref.hideshot[1], true)
        end
    end
}
local event_list = {
    on_setup_command = function(ctx)
        if not (entity_get_local_player() and entity_is_alive(entity_get_local_player()) and entity_get_player_weapon(entity_get_local_player())) then return end
        g_ctx.local_player = entity_get_local_player()
        g_ctx.weapon = entity_get_player_weapon(g_ctx.local_player)
        if exploits.need_force_defensive then ctx.force_defensive = true end
    end,
    on_run_command = function(ctx) exploits:store_vars(ctx) end,
    on_predict_command = function(ctx) exploits:store_tickbase_difference(ctx) end,
    on_player_death = function(ctx)
        if not (ctx.userid and ctx.attacker) then return end
        if g_ctx.local_player ~= client_userid_to_entindex(ctx.userid) then return end
        exploits:reset_vars()
    end,
    on_level_init = function() exploits:reset_vars() end,
    on_round_start = function() exploits:reset_vars() end,
    on_round_end = function() exploits:reset_vars() end,
    on_shutdown = function() collectgarbage("collect") end
}
for k, v in next, event_list do client_set_event_callback(k:sub(4), function(ctx) v(ctx) end) end

local last_weapon
weapon_adap_fix = function ()
    weapon = entity_get_player_weapon(entity_get_local_player())
    if weapon ~= last_weapon then
        ui_set(ref.doubletap[1], true)
    end
    last_weapon = weapon
end

command_number = 0
update_command_num = function (cmd)
    command_number = cmd.command_number
end


MaxTickBase = 0
AbsTickBase = 0
tickbase = 0
local lag_corder = function (cmd)
    if cmd.command_number == command_number then
        local lp = entity_get_local_player()
        if not lp or not entity_is_alive(lp) then return end
        tickbase = entity_get_prop(lp, "m_nTickbase")
        AbsTickBase = math.abs(tickbase - MaxTickBase)
        MaxTickBase = math.max(tickbase, MaxTickBase or 0)
    end
end

-- MaxAbsTickbase = 0
-- MaxAbsTickbase_count = 0
-- MaxAbsTickbase_check = function ()
--     if not( AbsTickBase > 17) and AbsTickBase > MaxAbsTickbase then
--         MaxAbsTickbase_count = MaxAbsTickbase_count + 1
--         if MaxAbsTickbase_count > 6 then
--             MaxAbsTickbase_count = 0
--             MaxAbsTickbase = AbsTickBase
--         end
--     end
-- end

defen_diff = 0
last_sim_time = 0
defensive_until = 0
defensive_wait_tick = 0
is_defensive_active_tick = function(local_player)
    local tickcount = globals_tickcount()
    local sim_time = toticks(entity_get_prop(local_player, "m_flSimulationTime"))
    local sim_diff = sim_time - last_sim_time

    if sim_diff < 0 then
        defensive_until = tickcount + math_abs(sim_diff) - toticks(client_latency())
    end

    defen_diff = sim_diff
    last_sim_time = sim_time

    return defensive_until > tickcount
end

local is_defensive_active = function (unsafe)

    local lp = entity_get_local_player()
    if not lp then
        return false
    end
    return unsafe and exploits:in_defensive() or exploits:is_lagcomp_broken()

end

arrConfigs = database_read("xor Configs") or {
    arrList = {},
    arrData = {}
}


local arrConfigPackage = {}
WriteElementsPackage = function(arrPackage, szPrevKey)
	local szGroupKey = szPrevKey or ""
	if szGroupKey == "" then
        arrConfigPackage = {}
	end

	for szKey, nElement in pairs(arrPackage or {info, rage, antiaim, builder, visuals, misc}) do
		local szElementKey = ("%s%s"):format(szGroupKey, szKey)
		if type(nElement) == "table" then
            WriteElementsPackage(nElement, szElementKey)
		elseif type(nElement) == "number" and ui_type(nElement) ~= "button" then
            arrConfigPackage[szElementKey] = nElement
		end
	end
end

GetConfigsPackage = function()
	local arrExports = {}
    WriteElementsPackage()
	for szKey, nElement in pairs(arrConfigPackage) do
		local bNoAllow = ui_type(nElement) == "label" or ui_type(nElement) == "button"
		if not bNoAllow then
			local arrData = { ui_get(nElement) }
			arrExports[szKey] = ui_type(nElement) == "hotkey" and { "Hotkey", arrData[2], arrData[3] } or ui_type(nElement) == "color_picker" and {
				r = arrData[1], g = arrData[2], b = arrData[3], a = arrData[4]
			} or arrData[1]
		end
	end

	return arrExports
end

ExportConfigs = function()
	local arrExports = {}
    WriteElementsPackage()
	for szKey, nElement in pairs(arrConfigPackage) do
		local bNotAllow = ui_type(nElement) == "label" or ui_type(nElement) == "button"
		if not bNotAllow then
			local arrData = { ui_get(nElement) }
			arrExports[szKey] = ui_type(nElement) == "hotkey" and { "Hotkey", arrData[2], arrData[3] } or ui_type(nElement) == "color_picker" and {
				r = arrData[1], g = arrData[2], b = arrData[3], a = arrData[4]
			} or arrData[1]
		end
	end

    pClipboard.set(pBase64.encode(json_stringify(arrExports)))
end

ImportConfigs = function(szConfigs, bIsConfig)
    WriteElementsPackage()
	local szClipboard = szConfigs
	if not szClipboard or type(szClipboard) ~= "string" then
		szClipboard = pClipboard.get()
		if not szClipboard or szClipboard:len() < 10 then
			error("[xor]: failed import, invalid clipboard data")
			return
		end
	end

	local bSuccessfully, szJson = pcall(pBase64.decode, szClipboard)
	if not bSuccessfully then
		error("[xor]: failed import, invalid config data type")
		return
	end

	local bSuccessfullyParseJson, arrData = pcall(json_parse, szJson)
	if not bSuccessfullyParseJson then
		error("[xor]: failed import, invalid config data type")
		return
	end

	for szKey, nElement in pairs(arrConfigPackage) do
		local pValue = arrData[szKey]
		local bNotAllow = not pValue or ui_type(nElement) == "label" or ui_type(nElement) == "button"
		if not bNotAllow then
			if type(pValue) == "table" and type(pValue[1]) == "string" and pValue[1] == "Hotkey" and type(pValue[2]) == "number" then
				local szHotkeyType = ({"Always on", "On hotkey", "Toggle", "Off hotkey"})[math_clamp(pValue[2] + 1, 1, 4)]
				ui_set(nElement, unpack({ szHotkeyType, pValue[3] }))
			elseif type(pValue) == "table" and type(pValue.r) == "number" and type(pValue.g) == "number" and type(pValue.b) == "number" and type(pValue.a) == "number" then
				ui_set(nElement, unpack({ pValue.r, pValue.g, pValue.b, pValue.a }))
			else
				ui_set(nElement, pValue)
			end
		end
	end

	if not bIsConfig then
		client_color_log(0, 255, 0, "[xor]: import successfully")
	end
end

LoadConfigs = function()
	local nConfigIndex = ui_get(config.pConfigsList) + 1
	local szName = arrConfigs.arrList[nConfigIndex]
	if not arrConfigs.arrData[szName] then
		error("configs load: error load a not exist config")
		return
	end

    ImportConfigs(arrConfigs.arrData[szName], true)
	print("successfully load config")
end

SaveConfigs = function()
	local nConfigIndex = ui_get(config.pConfigsList) + 1
	local arrConfigData = GetConfigsPackage()
	local szName = arrConfigs.arrList[nConfigIndex]
	if not szName then
		error("configs save: try save a invalid index config")
		return
	end

    arrConfigs.arrData[szName] = pBase64.encode(json_stringify(arrConfigData))
	database_write("xor Configs", arrConfigs)
	print("successfully load config")
end

DeleteConfigs = function()
	local nConfigIndex = ui_get(config.pConfigsList) + 1
	local szName = arrConfigs.arrList[nConfigIndex]
	if not szName then
		error("configs delete: try delete a invalid index config")
		return
	end

    arrConfigs.arrData[szName] = nil
	for nIndex, szConfigName in pairs(arrConfigs.arrList) do
		if szConfigName == szName then
			table.remove(arrConfigs.arrList, nIndex)
			break
		end
	end

	ui_update(config.pConfigsList, arrConfigs.arrList)
	database_write("xor Configs", arrConfigs)
end

CreateConfigs = function()
	local szName = ui_get(config.pConfigName)
	if szName:len() <= 0 then
		error("configs create: cannot create empty name config")
		return
	end

	if contains(arrConfigs.arrList, szName) then
		error("configs create: cannot create a exist config")
		return
	end

	local arrConfigData = GetConfigsPackage()
	table.insert(arrConfigs.arrList, szName)
	arrConfigs.arrData[szName] = pBase64.encode(json_stringify(arrConfigData))
	ui_update(config.pConfigsList, arrConfigs.arrList)
	database_write("xor Configs", arrConfigs)
	print("successfully create config")
end

LoadPreset = function ()
    ImportConfigs("eyI0c3RhdGVfc3R5bGUiOiJBZHZhbmNlZCIsIjRjb25kaXRpb25zMTE0YnJlYWtsY19tb2RlIjoiTWF4aW11bSIsIjRjb25kaXRpb25zMTE1b2Zmc2V0X3JpZ2h0Ijo0MywiNGNvbmRpdGlvbnMyMTh5YXdfbW9kaWZpZXIiOiJPZmYiLCI0Y29uZGl0aW9uczIxNm9mZnNldF9yaWdodCI6MCwiNGNvbmRpdGlvbnMyMTN5YXdfbW9kaWZpZXIiOiJPZmYiLCI0Y29uZGl0aW9uczIxMWJvZHl5YXdfbWFpbiI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMzb2Zmc2V0X21haW4iOjAsIjRjb25kaXRpb25zMTI1Ym9keXlhd19tYWluIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczFiYXNlIjoiQXQgdGFyZ2V0cyIsIjRjb25kaXRpb25zMjIyb2Zmc2V0X3JpZ2h0IjowLCIyanVtcHNjb3V0X2Rpc3RhbmNlIjowLCI0Y29uZGl0aW9uczExNmJvZHl5YXdfbGVmdCI6LTQwLCI0Y29uZGl0aW9uczExNGRlZmVuc2l2ZV95YXciOiJPZmYiLCI0Y29uZGl0aW9uczIyN2RlbGF5X21vZGUiOiJTdGF0aWMiLCI0Y29uZGl0aW9uczEyNnlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMTIyYm9keXlhd19yaWdodCI6MCwiNGNvbmRpdGlvbnMyMTRvZmZzZXRfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTZ5YXdfbW9kaWZpZXIiOiJPZmZzZXQiLCI0Y29uZGl0aW9uczIyMW9mZnNldF9tYWluIjowLCI0Y29uZGl0aW9uczExNW9mZnNldF9tYWluIjowLCIyZnJpZW5kbHlfZmlyZSI6WyJIb3RrZXkiLDFdLCI0ZXNwZWNpYWxfY29uZGl0aW9uczVkZWZlbnNpdmVfcGl0Y2hfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTNvZmZzZXRfcmlnaHQiOjQzLCI0Y29uZGl0aW9uczEyNm9mZnNldF9yaWdodCI6MCwiNGNvbmRpdGlvbnMyMjhvZmZzZXRfbGVmdCI6MCwiNGNvbmRpdGlvbnMyMTZib2R5eWF3X3JpZ2h0IjowLCI0Y29uZGl0aW9uczExMmRlbGF5X21vZGUiOiJTdGF0aWMiLCI0Y29uZGl0aW9uczEyNmJvZHl5YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTdkZWxheV9tb2RlIjoiU3RhdGljIiwiNGNvbmRpdGlvbnMyMjFib2R5eWF3X2xlZnQiOjAsIjRzdGF0ZSI6IlJ1bm5pbmciLCI0Y29uZGl0aW9uczEyN3lhd19tb2RpZmllciI6Ik9mZiIsIjRjb25kaXRpb25zMTE3Ym9keXlhd19yaWdodCI6LTMwLCIzYW50aV9icnV0ZWZvcmNlX2N1c3RvbTUiOjAsIjRjb25kaXRpb25zMTExZGVmZW5zaXZlX3BpdGNoIjoiT2ZmIiwiNGNvbmRpdGlvbnMxMTRib2R5eWF3X3JpZ2h0Ijo0MCwiNGNvbmRpdGlvbnMxMjZkZWxheV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMTI2Ym9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczExNWJyZWFrbGNfdHJpZ2dlciI6IkFsd2F5cyIsIjRjb25kaXRpb25zMjExZGVmZW5zaXZlX3lhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjI0b2Zmc2V0X2xlZnQiOjAsIjRjb25kaXRpb25zMjEyYm9keXlhd19tYWluIjowLCI0Y29uZGl0aW9uczIxOGJyZWFrbGNfbW9kZSI6IlNrZWV0IiwiNGNvbmRpdGlvbnMyMjFvZmZzZXRfbGVmdCI6MCwiNGNvbmRpdGlvbnMxMjRvZmZzZXRfbGVmdCI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyYm9keXlhd19yaWdodCI6MCwiNGNvbmRpdGlvbnMxMjVvZmZzZXRfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTRvZmZzZXRfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTNib2R5eWF3X21haW4iOjAsIjRjb25kaXRpb25zMjI0b2Zmc2V0X21haW4iOjAsIjRjb25kaXRpb25zMTE2b2Zmc2V0X3JpZ2h0IjotMTUsIjRjb25kaXRpb25zMjI0eWF3X21vZGlmaWVyIjoiT2ZmIiwiNGNvbmRpdGlvbnMxMTN5YXdfbW9kaWZpZXIiOiJSYW5kb20iLCI0Y29uZGl0aW9uczIxN2JvZHl5YXdfcmlnaHQiOjAsIjRjb25kaXRpb25zMTI4Ym9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczEyM2JvZHl5YXdfcmlnaHQiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zM2RlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTVib2R5eWF3X2xlZnQiOjAsIjRjb25kaXRpb25zMTE3Ym9keXlhdyI6IkppdHRlciIsIjRjb25kaXRpb25zMTIzZGVsYXlfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczIxNGRlZmVuc2l2ZV9waXRjaCI6Ik9mZiIsIjRjb25kaXRpb25zMjEzeWF3X21vZGlmaWVyX21haW4iOjAsIjRjb25kaXRpb25zMjEyZGVmZW5zaXZlX3lhdyI6Ik9mZiIsIjRjb25kaXRpb25zMTI1ZW5hYmxlIjpmYWxzZSwiM21hbnVhbF9sZWZ0IjpbIkhvdGtleSIsMSw5MF0sIjRjb25kaXRpb25zMjEzZW5hYmxlIjpmYWxzZSwiNGNvbmRpdGlvbnMyMTdvZmZzZXRfcmlnaHQiOjAsIjRjb25kaXRpb25zMTE3YnJlYWtsY190cmlnZ2VyIjoiQWx3YXlzIiwiNGNvbmRpdGlvbnMxMTVkZWxheV9tb2RlIjoiU3RhdGljIiwiNW1haW5faW5kaWNhdG9yX2NvbG9yc3JpZ2h0X2FsdCI6eyJyIjoyNTMsImIiOjE4MCwiYSI6MjIwLCJnIjoxNjN9LCI0Y29uZGl0aW9uczIxM2RlZmVuc2l2ZV9waXRjaF9tYWluIjowLCI0Y29uZGl0aW9uczIxOG9mZnNldF9tYWluIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczJvZmZzZXRfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTNib2R5eWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMxMTZkZWZlbnNpdmVfcGl0Y2giOiJPZmYiLCI0Y29uZGl0aW9uczEyM3BpdGNoIjo4OSwiNGVzcGVjaWFsX2NvbmRpdGlvbnMzYm9keXlhd19tYWluIjowLCI0Y29uZGl0aW9uczIxM2RlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMxMjVib2R5eWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMxMjVkZWZlbnNpdmVfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczEyNW9mZnNldF9sZWZ0IjowLCI0Y29uZGl0aW9uczEyMmRlbGF5X21vZGUiOiJTdGF0aWMiLCIybWFnbmV0X2tleSI6WyJIb3RrZXkiLDEsNzBdLCIzZmFrZWxhZ19jaG9rZSI6MTUsIjRjb25kaXRpb25zMjE0c3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIxNGRlZmVuc2l2ZV95YXdfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIxNGJhc2UiOiJBdCB0YXJnZXRzIiwiNGNvbmRpdGlvbnMxMThib2R5eWF3X3JpZ2h0IjotNjAsIjRjb25kaXRpb25zMjE0ZGVmZW5zaXZlX3BpdGNoX21haW4iOjAsIjRjb25kaXRpb25zMTEyYmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczExN2JvZHl5YXdfbGVmdCI6NDIsIjJtYWluIjpbIlN0cmFmZSBGaXgiLCJKdW1wIFNjb3V0IiwiUmV2b2x2ZXIgSW1wcm92ZW1lbnRzIiwiTWFnbmV0IE1lbGVlIiwiRnJpZW5kbHkgRmlyZSJdLCI0Y29uZGl0aW9uczExNmRlbGF5X21vZGUiOiJTdGF0aWMiLCI0Y29uZGl0aW9uczExNWRlZmVuc2l2ZV95YXciOiJPZmYiLCI0Y29uZGl0aW9uczEyNGRlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMjI4Ym9keXlhd19tYWluIjowLCI0Y29uZGl0aW9uczEyNGJhc2UiOiJBdCB0YXJnZXRzIiwiNGNvbmRpdGlvbnMxMjFvZmZzZXRfbWFpbiI6OCwiNGNvbmRpdGlvbnMxMTNkZWxheSI6MSwiNGNvbmRpdGlvbnMxMjRzcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMTEyYnJlYWtsY190cmlnZ2VyIjoiQWx3YXlzIiwiNGNvbmRpdGlvbnMxMjRwaXRjaCI6ODksIjRjb25kaXRpb25zMjE1c3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczEyMmRlbGF5IjowLCI0Y29uZGl0aW9uczExNXlhd19tb2RpZmllciI6Ik9mZiIsIjRlc3BlY2lhbF9jb25kaXRpb25zNWJhc2UiOiJBdCB0YXJnZXRzIiwiM2Zhc3RsYWRkZXJfbW9kZSI6Ik5vcm1hbCIsIjRjb25kaXRpb25zMTI3b2Zmc2V0X3JpZ2h0IjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczNlbmFibGUiOmZhbHNlLCI0Y29uZGl0aW9uczEyM29mZnNldF9tYWluIjowLCI0Y29uZGl0aW9uczEyNG9mZnNldF9tYWluIjowLCI0Y29uZGl0aW9uczIyM3lhd19tb2RpZmllcl9tYWluIjowLCI0Y29uZGl0aW9uczIxNWRlZmVuc2l2ZV9waXRjaF9tYWluIjowLCI0Y29uZGl0aW9uczIxNWRlbGF5IjowLCI0Y29uZGl0aW9uczEyM3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMyMTFkZWZlbnNpdmVfeWF3X3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMTVkZWZlbnNpdmVfcGl0Y2giOiJPZmYiLCI0ZXNwZWNpYWxfY29uZGl0aW9uczR5YXdfbW9kaWZpZXJfbWFpbiI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1ZGVsYXlfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczEyMmJvZHl5YXciOiJPZmYiLCI0Y29uZGl0aW9uczEyMmRlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMjIxYm9keXlhd19tYWluIjowLCI0Y29uZGl0aW9uczEyMmJhc2UiOiJBdCB0YXJnZXRzIiwiNGNvbmRpdGlvbnMxMTNkZWxheV9mZWF0dXJlcyI6WyJNb2RpZmllciBJZ25vcmUgRGVsYXkiXSwiNGNvbmRpdGlvbnMxMjJ5YXdfbW9kaWZpZXJfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMThkZWZlbnNpdmVfeWF3X3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMjNiYXNlIjoiQXQgdGFyZ2V0cyIsIjRjb25kaXRpb25zMTIyc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIxNWJvZHl5YXdfcmlnaHQiOjAsIjRjb25kaXRpb25zMjIzYm9keXlhd19yaWdodCI6MCwiNGNvbmRpdGlvbnMyMTZ5YXdfbW9kaWZpZXJfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMjJwaXRjaCI6ODksIjRjb25kaXRpb25zMTEzYm9keXlhdyI6IkppdHRlciIsIjRjb25kaXRpb25zMTI0ZGVsYXlfbW9kZSI6IlN0YXRpYyIsIjRlc3BlY2lhbF9jb25kaXRpb25zMW9mZnNldF9tYWluIjotNiwiNGNvbmRpdGlvbnMxMjJ5YXdfbW9kaWZpZXIiOiJPZmYiLCI0Y29uZGl0aW9uczExM3lhd19tb2RpZmllcl9tYWluIjozLCI0Y29uZGl0aW9uczIyOG9mZnNldF9tYWluIjowLCI0Y29uZGl0aW9uczExNWRlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMTExYm9keXlhd19yaWdodCI6MCwiNGNvbmRpdGlvbnMxMjFkZWxheSI6MCwiNGNvbmRpdGlvbnMyMThib2R5eWF3X21haW4iOjAsIjRjb25kaXRpb25zMjE2YmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczEyNHlhd19tb2RpZmllciI6Ik9mZiIsIjRjb25kaXRpb25zMTI4ZGVsYXlfbW9kZSI6IlN0YXRpYyIsIjRjb25kaXRpb25zMTE4eWF3IjoiSml0dGVyIiwiNGNvbmRpdGlvbnMyMTZkZWZlbnNpdmVfcGl0Y2hfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTZkZWxheSI6MCwiNGNvbmRpdGlvbnMxMjR5YXciOiJPZmYiLCI0Y29uZGl0aW9uczEyMWRlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMTIxYmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczExNmRlZmVuc2l2ZV95YXciOiJPZmYiLCI0ZXNwZWNpYWxfY29uZGl0aW9uczNvZmZzZXRfcmlnaHQiOjAsIjRjb25kaXRpb25zMjIyYm9keXlhd19sZWZ0IjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczVkZWxheSI6MCwiNGNvbmRpdGlvbnMxMjh3YXkiOjIsIjRjb25kaXRpb25zMjE2ZGVmZW5zaXZlX3lhd19tYWluIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczN5YXciOiJPZmYiLCI0Y29uZGl0aW9uczEyNWRlbGF5X21vZGUiOiJTdGF0aWMiLCI0Y29uZGl0aW9uczIxNnlhd19tb2RpZmllciI6Ik9mZiIsIjRjb25kaXRpb25zMTEyb2Zmc2V0X21haW4iOjAsIjRjb25kaXRpb25zMTExZGVsYXlfbW9kZSI6IlN0YXRpYyIsIjRjb25kaXRpb25zMTE3cGl0Y2giOjg5LCI0Y29uZGl0aW9uczIxM2JvZHl5YXdfbWFpbiI6MCwiMmp1bXBzY291dF9zZXR0aW5ncyI6e30sIjRjb25kaXRpb25zMTE2YnJlYWtsY190cmlnZ2VyIjoiQWx3YXlzIiwiNGNvbmRpdGlvbnMyMjZ5YXciOiJPZmYiLCI0ZXNwZWNpYWxfY29uZGl0aW9uczFkZWxheV9tb2RlIjoiU3RhdGljIiwiNGNvbmRpdGlvbnMxMThib2R5eWF3IjoiSml0dGVyIiwiNGNvbmRpdGlvbnMxMTFib2R5eWF3X2xlZnQiOjAsIjRjb25kaXRpb25zMTE4ZGVmZW5zaXZlX3BpdGNoX3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMyMTN3YXkiOjIsIjRjb25kaXRpb25zMTIxZGVsYXlfbW9kZSI6IlN0YXRpYyIsIjRjb25kaXRpb25zMTI3ZGVsYXlfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczEyN2JvZHl5YXdfbWFpbiI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMxc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIxMmRlbGF5X21vZGUiOiJTdGF0aWMiLCI0Y29uZGl0aW9uczExN29mZnNldF9yaWdodCI6NDAsIjRjb25kaXRpb25zMTE4ZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMyMjZkZWxheSI6MCwiNGNvbmRpdGlvbnMyMjV5YXdfbW9kaWZpZXIiOiJPZmYiLCI0Y29uZGl0aW9uczExOGRlbGF5IjoxLCI1bWFpbl9pbmRpY2F0b3Jfc2V0dGluZ3MiOlsiQ3VzdG9tIGNvbG9ycyIsIk1hbnVhbCBEaWNrIl0sIjRjb25kaXRpb25zMTE4YmFzZSI6IkF0IHRhcmdldHMiLCI0ZXNwZWNpYWxfY29uZGl0aW9uczNib2R5eWF3X3JpZ2h0IjowLCI0Y29uZGl0aW9uczExN2RlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM0Ym9keXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjE0ZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMxMThlbmFibGUiOnRydWUsIjRlc3BlY2lhbF9jb25kaXRpb25zNGJhc2UiOiJBdCB0YXJnZXRzIiwiNGNvbmRpdGlvbnMxMjZkZWxheV9tb2RlIjoiU3RhdGljIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1b2Zmc2V0X3JpZ2h0IjowLCI0Y29uZGl0aW9uczIyN3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMTdkZWZlbnNpdmVfcGl0Y2hfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczExM2RlZmVuc2l2ZV95YXdfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIxMmJvZHl5YXciOiJPZmYiLCI0Y29uZGl0aW9uczExNnlhd19tb2RpZmllcl9tYWluIjo1MSwiNGVzcGVjaWFsX2NvbmRpdGlvbnM0b2Zmc2V0X3JpZ2h0IjowLCI0Y29uZGl0aW9uczExM29mZnNldF9sZWZ0IjotMjEsIjRjb25kaXRpb25zMTE3ZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMxMjR5YXdfbW9kaWZpZXJfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTNwaXRjaCI6ODksIjRjb25kaXRpb25zMjEzZGVmZW5zaXZlX3lhdyI6Ik9mZiIsIjRjb25kaXRpb25zMTIxd2F5IjoyLCI0Y29uZGl0aW9uczExNnBpdGNoIjo4OSwiNGNvbmRpdGlvbnMyMTJkZWZlbnNpdmVfcGl0Y2hfbWFpbiI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyZGVmZW5zaXZlX3BpdGNoX21haW4iOjAsIjRjb25kaXRpb25zMTE3YmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczExMmJyZWFrbGNfbW9kZSI6Ik1heGltdW0iLCI0Y29uZGl0aW9uczIxN2RlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMjI4Ym9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczExM2RlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTdlbmFibGUiOnRydWUsIjRlc3BlY2lhbF9jb25kaXRpb25zMXdheSI6MiwiNGNvbmRpdGlvbnMyMjdib2R5eWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMyMTd3YXkiOjIsIjRjb25kaXRpb25zMTI2YmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczExNmRlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTd5YXciOiJPZmYiLCI0Y29uZGl0aW9uczIyMmRlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMxMTZkZWZlbnNpdmVfZmVhdHVyZXMiOnt9LCI0ZXNwZWNpYWxfY29uZGl0aW9uczFkZWZlbnNpdmVfeWF3X3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMTZkZWxheSI6MCwiNGNvbmRpdGlvbnMyMTdvZmZzZXRfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMjJvZmZzZXRfcmlnaHQiOjAsIjRjb25kaXRpb25zMTE2YmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczIxMWJyZWFrbGNfbW9kZSI6IlNrZWV0IiwiNGNvbmRpdGlvbnMyMTV3YXkiOjIsIjRjb25kaXRpb25zMTE4YnJlYWtsY190cmlnZ2VyIjoiQWx3YXlzIiwiNGNvbmRpdGlvbnMyMTF5YXdfbW9kaWZpZXIiOiJPZmYiLCI0Y29uZGl0aW9uczIxNXlhd19tb2RpZmllcl9tYWluIjowLCI0Y29uZGl0aW9uczIxNmJvZHl5YXdfbGVmdCI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMzZGVmZW5zaXZlX3lhd19zcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMTE2ZGVmZW5zaXZlX3lhd19zcGluX3N0ZXAiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zMWRlZmVuc2l2ZV9waXRjaF9tYWluIjowLCI0Y29uZGl0aW9uczIxNm9mZnNldF9tYWluIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczFib2R5eWF3X21haW4iOi02MCwiNGNvbmRpdGlvbnMxMjV5YXciOiJPZmYiLCI0ZXNwZWNpYWxfY29uZGl0aW9uczFkZWxheV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMTEyYm9keXlhd19yaWdodCI6LTYwLCI0Y29uZGl0aW9uczIxNG9mZnNldF9yaWdodCI6MCwiNGNvbmRpdGlvbnMxMTZib2R5eWF3IjoiSml0dGVyIiwiNGNvbmRpdGlvbnMxMTFkZWZlbnNpdmVfcGl0Y2hfc3Bpbl9zdGVwIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczRkZWZlbnNpdmVfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczEyMWJvZHl5YXdfbGVmdCI6MCwiNGNvbmRpdGlvbnMyMThib2R5eWF3X3JpZ2h0IjowLCI0Y29uZGl0aW9uczIxMmVuYWJsZSI6ZmFsc2UsIjRjb25kaXRpb25zMTE1Ym9keXlhd19tYWluIjowLCI0Y29uZGl0aW9uczExNWJvZHl5YXciOiJKaXR0ZXIiLCI0Y29uZGl0aW9uczIxOHBpdGNoIjo4OSwiNGNvbmRpdGlvbnMyMjZvZmZzZXRfbGVmdCI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1b2Zmc2V0X21haW4iOjAsIjRjb25kaXRpb25zMjI2eWF3X21vZGlmaWVyIjoiT2ZmIiwiNGNvbmRpdGlvbnMxMTR3YXkiOjIsIjRjb25kaXRpb25zMTE0YmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczExNWRlbGF5IjoyLCI0Y29uZGl0aW9uczIxM2RlbGF5X21vZGUiOiJTdGF0aWMiLCI0Y29uZGl0aW9uczExNWRlZmVuc2l2ZV9waXRjaF9tYWluIjowLCI0Y29uZGl0aW9uczEyMndheSI6MiwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1ZGVmZW5zaXZlX3lhd19zcGluX3N0ZXAiOjAsIjNhbnRpX2JydXRlZm9yY2VfYW1vdW50IjowLCI0Y29uZGl0aW9uczIxOGRlZmVuc2l2ZV9waXRjaCI6Ik9mZiIsIjRjb25kaXRpb25zMTI1Ym9keXlhd19yaWdodCI6MCwiNGNvbmRpdGlvbnMxMTVlbmFibGUiOnRydWUsIjRjb25kaXRpb25zMjIyb2Zmc2V0X2xlZnQiOjAsIjRjb25kaXRpb25zMTE1YmFzZSI6IkF0IHRhcmdldHMiLCI0dGVhbSI6IkNvdW50ZXIgU3RyaWtlIiwiNGNvbmRpdGlvbnMxMTJ5YXdfbW9kaWZpZXJfbWFpbiI6MSwiNGNvbmRpdGlvbnMxMTF3YXkiOjIsIjRjb25kaXRpb25zMTE2YnJlYWtsY19tb2RlIjoiTWF4aW11bSIsIjRjb25kaXRpb25zMjEyeWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMyMjNib2R5eWF3X2xlZnQiOjAsIjRjb25kaXRpb25zMTE1c3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczExNGRlZmVuc2l2ZV9waXRjaF9zcGluX3N0ZXAiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zMWJyZWFrbGNfdHJpZ2dlciI6IkFsd2F5cyIsIjZlYXJ0aHF1YWtlX3ZhbHVlIjoxMzUsIjRjb25kaXRpb25zMjE4d2F5IjoyLCI0ZXNwZWNpYWxfY29uZGl0aW9uczVwaXRjaCI6ODksIjRlc3BlY2lhbF9jb25kaXRpb25zM2RlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMxMTRib2R5eWF3IjoiSml0dGVyIiwiNGNvbmRpdGlvbnMyMTFlbmFibGUiOmZhbHNlLCI0Y29uZGl0aW9uczExNGRlbGF5IjoxLCI0Y29uZGl0aW9uczExN3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMyMTdkZWZlbnNpdmVfcGl0Y2giOiJPZmYiLCI0ZXNwZWNpYWxfY29uZGl0aW9uczRvZmZzZXRfbGVmdCI6MCwiNGNvbmRpdGlvbnMxMTRkZWZlbnNpdmVfcGl0Y2hfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTJzcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMTI1eWF3X21vZGlmaWVyIjoiT2ZmIiwiNmNvbnNvbGVfZmlsdGVyIjp0cnVlLCI0Y29uZGl0aW9uczIyMmRlbGF5X21vZGUiOiJTdGF0aWMiLCI2Y2xhbnRhZyI6ZmFsc2UsIjRjb25kaXRpb25zMTIxeWF3X21vZGlmaWVyX21haW4iOjAsIjRjb25kaXRpb25zMTE1d2F5IjoyLCI0Y29uZGl0aW9uczIxMmJvZHl5YXdfcmlnaHQiOjAsIjRjb25kaXRpb25zMjE4b2Zmc2V0X2xlZnQiOjAsIjRjb25kaXRpb25zMTE4YnJlYWtsY19tb2RlIjoiTWF4aW11bSIsIjRjb25kaXRpb25zMTE0ZGVmZW5zaXZlX3lhd19zcGluX3N0ZXAiOjAsIjJyZXZvbHZlcl9zZWNvbmRfZmlyZV9kaXN0YW5jZSI6MTUwLCI0Y29uZGl0aW9uczExNXlhd19tb2RpZmllcl9tYWluIjowLCI0Y29uZGl0aW9uczExMmRlZmVuc2l2ZV95YXciOiJPZmYiLCI0Y29uZGl0aW9uczExNHNwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMyMjZvZmZzZXRfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTNib2R5eWF3X2xlZnQiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zMmRlZmVuc2l2ZV95YXdfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczExNGVuYWJsZSI6dHJ1ZSwiNGNvbmRpdGlvbnMxMTNkZWZlbnNpdmVfcGl0Y2hfc3Bpbl9zdGVwIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczNkZWxheV9tb2RlIjoiU3RhdGljIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnMxZGVmZW5zaXZlX3BpdGNoX3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMTJib2R5eWF3IjoiU3RhdGljIiwiNGNvbmRpdGlvbnMyMjVib2R5eWF3X3JpZ2h0IjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczNkZWxheSI6MCwiNGNvbmRpdGlvbnMxMjRvZmZzZXRfcmlnaHQiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zMWRlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRlc3BlY2lhbF9jb25kaXRpb25zNWJyZWFrbGNfdHJpZ2dlciI6IkFsd2F5cyIsIjNmZWF0dXJlcyI6WyJNYW51YWwgQUEiLCJTYWZlIEhlYWQiLCJJbnVzZSBBQSIsIkFudGkgQmFja3N0YWIiLCJGYXN0IExhZGRlciIsIlNtb290aCBMYW5kaW5nIENoZWNrIl0sIjRjb25kaXRpb25zMjIxZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiNGVzcGVjaWFsX2NvbmRpdGlvbnMzcGl0Y2giOjg5LCI0Y29uZGl0aW9uczIyM29mZnNldF9sZWZ0IjowLCI0Y29uZGl0aW9uczEyNGRlbGF5IjowLCI0Y29uZGl0aW9uczIyM2RlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMxMTFlbmFibGUiOnRydWUsIjRjb25kaXRpb25zMjE4YmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczEyNnNwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMyMjJwaXRjaCI6ODksIjRjb25kaXRpb25zMjI3b2Zmc2V0X21haW4iOjAsIjVtYWluX2luZGljYXRvcl9uYW1lX3RhZyI6IiIsIjRjb25kaXRpb25zMTExZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyZGVmZW5zaXZlX3BpdGNoIjoiT2ZmIiwiNGNvbmRpdGlvbnMxMTJ5YXciOiJCYWNrd2FyZCIsIjRlc3BlY2lhbF9jb25kaXRpb25zMmJvZHl5YXciOiJTdGF0aWMiLCI0Y29uZGl0aW9uczEyNWRlbGF5X2ZlYXR1cmVzIjp7fSwiNGVzcGVjaWFsX2NvbmRpdGlvbnMzYm9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczIyMmJhc2UiOiJBdCB0YXJnZXRzIiwiNGNvbmRpdGlvbnMxMTdkZWZlbnNpdmVfeWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMyMTJicmVha2xjX21vZGUiOiJTa2VldCIsIjRjb25kaXRpb25zMTExb2Zmc2V0X21haW4iOjAsIjRjb25kaXRpb25zMjIyYm9keXlhdyI6Ik9mZiIsIjRlc3BlY2lhbF9jb25kaXRpb25zMmRlbGF5IjowLCIzbWFudWFsX2ZyZWVzdGFuZCI6WyJIb3RrZXkiLDIsNV0sIjRjb25kaXRpb25zMjI0eWF3X21vZGlmaWVyX21haW4iOjAsIjRjb25kaXRpb25zMTI2ZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMxMTF5YXdfbW9kaWZpZXIiOiJPZmYiLCI0Y29uZGl0aW9uczIxMW9mZnNldF9sZWZ0IjowLCI0Y29uZGl0aW9uczIxNG9mZnNldF9sZWZ0IjowLCI0Y29uZGl0aW9uczExMXlhd19tb2RpZmllcl9tYWluIjowLCI0Y29uZGl0aW9uczIxNGRlZmVuc2l2ZV95YXciOiJPZmYiLCI0Y29uZGl0aW9uczExNGJyZWFrbGNfdHJpZ2dlciI6IkFsd2F5cyIsIjRjb25kaXRpb25zMTE3eWF3IjoiSml0dGVyIiwiNGNvbmRpdGlvbnMxMTRvZmZzZXRfcmlnaHQiOi0xNCwiNmxhZ19leHBsb2l0IjpbIkhvdGtleSIsMV0sIjVoaXRsb2dfc2V0dGluZ3MiOlsidG8gc2NyZWVuIiwidG8gY29uc29sZSJdLCI0ZXNwZWNpYWxfY29uZGl0aW9uczJvZmZzZXRfbGVmdCI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM0YnJlYWtsY190cmlnZ2VyIjoiQWx3YXlzIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyb2Zmc2V0X3JpZ2h0IjowLCIycmV2b2x2ZXJfaW5kaWNhdG9yX2NvbG9yIjp7InIiOjI1NSwiYiI6MjU1LCJhIjoyNTUsImciOjI1NX0sIjRjb25kaXRpb25zMTEzYm9keXlhd19yaWdodCI6LTYwLCI0Y29uZGl0aW9uczExN2RlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMyMjNib2R5eWF3X21haW4iOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zNWRlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMTI2eWF3X21vZGlmaWVyIjoiT2ZmIiwiNGNvbmRpdGlvbnMxMTJkZWxheV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMjExYm9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczEyNndheSI6MiwiNGVzcGVjaWFsX2NvbmRpdGlvbnMxeWF3IjoiQmFja3dhcmQiLCI0Y29uZGl0aW9uczEyMWJvZHl5YXdfbWFpbiI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyYnJlYWtsY19tb2RlIjoiTWF4aW11bSIsIjRlc3BlY2lhbF9jb25kaXRpb25zMmRlbGF5X2ZlYXR1cmVzIjp7fSwiM2Zha2VsYWdfbW9kZSI6IkFsdGVybmF0aXZlIiwiNGNvbmRpdGlvbnMxMTZib2R5eWF3X21haW4iOjAsIjRjb25kaXRpb25zMTEyYm9keXlhd19sZWZ0IjotNjAsIjRjb25kaXRpb25zMTI0Ym9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczIxNWRlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMxMThkZWxheV9mZWF0dXJlcyI6WyJNb2RpZmllciBJZ25vcmUgRGVsYXkiXSwiNGNvbmRpdGlvbnMxMTNzcGluX3N0ZXAiOjAsIjRlc3BlY2lhbF9zdGF0ZSI6IkhlaWdodCBCZWxvdyIsIjRlc3BlY2lhbF9jb25kaXRpb25zM29mZnNldF9sZWZ0IjowLCI0Y29uZGl0aW9uczExM2RlZmVuc2l2ZV9waXRjaF9tYWluIjowLCI0Y29uZGl0aW9uczExNXBpdGNoIjo4OSwiNGNvbmRpdGlvbnMxMjZib2R5eWF3X3JpZ2h0IjowLCI0Y29uZGl0aW9uczIxNXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjI4ZGVsYXkiOjAsIjRjb25kaXRpb25zMTI2b2Zmc2V0X21haW4iOjAsIjRjb25kaXRpb25zMjI0Ym9keXlhdyI6Ik9mZiIsIjRlc3BlY2lhbF9jb25kaXRpb25zM2RlZmVuc2l2ZV9waXRjaCI6Ik9mZiIsIjRjb25kaXRpb25zMTI0ZW5hYmxlIjpmYWxzZSwiM3NhZmVoZWFkX21vZGUiOiJIaWRlIiwiNGNvbmRpdGlvbnMxMTd5YXdfbW9kaWZpZXJfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTdib2R5eWF3X2xlZnQiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zMnlhd19tb2RpZmllcl9tYWluIjowLCI0Y29uZGl0aW9uczExNWRlZmVuc2l2ZV95YXdfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIyNW9mZnNldF9sZWZ0IjowLCI0Y29uZGl0aW9uczExMXNwaW5fc3RlcCI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMycGl0Y2giOjg5LCI0Y29uZGl0aW9uczExMndheSI6MiwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyZW5hYmxlIjp0cnVlLCI0ZXNwZWNpYWxfY29uZGl0aW9uczF5YXdfbW9kaWZpZXIiOiJPZmYiLCI0Y29uZGl0aW9uczExM2JyZWFrbGNfdHJpZ2dlciI6Ik9uIFBlZWsiLCI0Y29uZGl0aW9uczExOG9mZnNldF9tYWluIjowLCI0Y29uZGl0aW9uczEyN2VuYWJsZSI6dHJ1ZSwiNGVzcGVjaWFsX2NvbmRpdGlvbnMzYmFzZSI6IkF0IHRhcmdldHMiLCI0ZXNwZWNpYWxfY29uZGl0aW9uczR3YXkiOjIsIjRjb25kaXRpb25zMTE1ZGVmZW5zaXZlX3BpdGNoX3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMyMThvZmZzZXRfcmlnaHQiOjAsIjRjb25kaXRpb25zMjI3eWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMxMTFkZWZlbnNpdmVfcGl0Y2hfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTNkZWZlbnNpdmVfcGl0Y2giOiJPZmYiLCI0Y29uZGl0aW9uczIyMXNwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMyMjRvZmZzZXRfcmlnaHQiOjAsIjRjb25kaXRpb25zMjExb2Zmc2V0X3JpZ2h0IjowLCI0Y29uZGl0aW9uczEyOG9mZnNldF9tYWluIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczFkZWZlbnNpdmVfcGl0Y2giOiJPZmYiLCI0Y29uZGl0aW9uczIxM3lhdyI6Ik9mZiIsIjRjb25kaXRpb25zMTE2c3Bpbl9zdGVwIjowLCIzZmFrZWxhZ19kaXNhYmxlcnMiOlsiU2hvdCIsIlN0YW5kaW5nIiwiRHVja2luZyJdLCI0ZXNwZWNpYWxfY29uZGl0aW9uczRwaXRjaCI6ODksIjRjb25kaXRpb25zMjEzYm9keXlhd19yaWdodCI6MCwiNGNvbmRpdGlvbnMxMTVkZWxheV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMjI4c3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczExNmRlZmVuc2l2ZV9waXRjaF9tYWluIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczN5YXdfbW9kaWZpZXIiOiJPZmYiLCI0Y29uZGl0aW9uczIyNmJvZHl5YXciOiJPZmYiLCI0ZXNwZWNpYWxfY29uZGl0aW9uczF5YXdfbW9kaWZpZXJfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMjh5YXciOiJPZmYiLCI0ZXNwZWNpYWxfY29uZGl0aW9uczJicmVha2xjX3RyaWdnZXIiOiJBbHdheXMiLCI0Y29uZGl0aW9uczEyNHdheSI6MiwiNGNvbmRpdGlvbnMxMTNiYXNlIjoiQXQgdGFyZ2V0cyIsIjRjb25kaXRpb25zMTE2ZGVmZW5zaXZlX3BpdGNoX3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMjJib2R5eWF3X2xlZnQiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zMWJvZHl5YXdfcmlnaHQiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zMWVuYWJsZSI6dHJ1ZSwiNGNvbmRpdGlvbnMxMjdib2R5eWF3X3JpZ2h0IjowLCI0Y29uZGl0aW9uczExMWJhc2UiOiJBdCB0YXJnZXRzIiwiNGNvbmRpdGlvbnMxMTh3YXkiOjIsIjRjb25kaXRpb25zMjI4Ym9keXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjE1ZGVmZW5zaXZlX3lhdyI6Ik9mZiIsIjRlc3BlY2lhbF9jb25kaXRpb25zMWRlbGF5IjowLCI0Y29uZGl0aW9uczExN2RlZmVuc2l2ZV9waXRjaF9tYWluIjowLCI0Y29uZGl0aW9uczIyNmVuYWJsZSI6ZmFsc2UsIjRlc3BlY2lhbF9jb25kaXRpb25zMW9mZnNldF9sZWZ0IjowLCI0Y29uZGl0aW9uczIyNXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjIxZGVsYXlfbW9kZSI6IlN0YXRpYyIsIjRjb25kaXRpb25zMjE3eWF3X21vZGlmaWVyIjoiT2ZmIiwiNGNvbmRpdGlvbnMyMTNzcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMTIxeWF3IjoiQmFja3dhcmQiLCI0Y29uZGl0aW9uczExN2JvZHl5YXdfbWFpbiI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM0ZW5hYmxlIjpmYWxzZSwiNGVzcGVjaWFsX2NvbmRpdGlvbnM0eWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMyMjZib2R5eWF3X3JpZ2h0IjowLCI2YW5pbWF0ZV90YWIiOlsiSml0dGVyIGxlZ3MiLCJFYXJ0aHF1YWtlIl0sIjRjb25kaXRpb25zMjI0Ym9keXlhd19sZWZ0IjowLCIycmV2b2x2ZXJfaW5kaWNhdG9yX3NldHRpbmdzIjpbIkdsb3ciXSwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1eWF3X21vZGlmaWVyX21haW4iOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zMWJvZHl5YXciOiJTdGF0aWMiLCI0Y29uZGl0aW9uczIyNWJvZHl5YXciOiJPZmYiLCI0Y29uZGl0aW9uczEyMWRlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMyMTZzcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMjIzeWF3X21vZGlmaWVyIjoiT2ZmIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnMxb2Zmc2V0X3JpZ2h0IjowLCI0Y29uZGl0aW9uczIyM29mZnNldF9yaWdodCI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM0YnJlYWtsY19tb2RlIjoiU2tlZXQiLCI0Y29uZGl0aW9uczEyOGJvZHl5YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTFicmVha2xjX21vZGUiOiJTa2VldCIsIjRjb25kaXRpb25zMjI1ZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiNGVzcGVjaWFsX2NvbmRpdGlvbnM0ZGVsYXkiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zMWRlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyYm9keXlhd19tYWluIjo2MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM0ZGVsYXlfbW9kZSI6IlN0YXRpYyIsIjRjb25kaXRpb25zMTE3ZGVmZW5zaXZlX3lhd19zcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMTE3d2F5IjoyLCI0ZXNwZWNpYWxfY29uZGl0aW9uczRkZWZlbnNpdmVfeWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMyMTZkZWZlbnNpdmVfcGl0Y2giOiJPZmYiLCI0Y29uZGl0aW9uczExNHlhd19tb2RpZmllcl9tYWluIjo0MCwiNGNvbmRpdGlvbnMyMTFzcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMTEzYm9keXlhd19sZWZ0Ijo2MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMxYm9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczExOGRlbGF5X21vZGUiOiJKaXR0ZXIiLCI0Y29uZGl0aW9uczExOGRlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM0b2Zmc2V0X21haW4iOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zNGRlZmVuc2l2ZV9waXRjaCI6Ik9mZiIsIjRlc3BlY2lhbF9jb25kaXRpb25zM2RlZmVuc2l2ZV9waXRjaF9zcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMjEyZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiM2FudGlfYnJ1dGVmb3JjZV9jdXN0b20xIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczNicmVha2xjX3RyaWdnZXIiOiJBbHdheXMiLCIzYW50aV9icnV0ZWZvcmNlX2N1c3RvbTgiOjAsIjRjb25kaXRpb25zMTI4b2Zmc2V0X2xlZnQiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zNHlhd19tb2RpZmllciI6Ik9mZiIsIjRjb25kaXRpb25zMTE0b2Zmc2V0X2xlZnQiOi0xNCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM0Ym9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczExNWRlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM0Ym9keXlhd19yaWdodCI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1ZW5hYmxlIjpmYWxzZSwiNGNvbmRpdGlvbnMxMTFwaXRjaCI6ODksIjRjb25kaXRpb25zMTExYm9keXlhdyI6Ik9mZiIsIjRlc3BlY2lhbF9jb25kaXRpb25zMWJyZWFrbGNfbW9kZSI6IlNrZWV0IiwiNGNvbmRpdGlvbnMxMThvZmZzZXRfcmlnaHQiOjQxLCI0Y29uZGl0aW9uczExN29mZnNldF9tYWluIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczVib2R5eWF3X2xlZnQiOjAsIjRjb25kaXRpb25zMTE0eWF3IjoiSml0dGVyIiwiNGNvbmRpdGlvbnMyMTJkZWZlbnNpdmVfcGl0Y2hfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczEyNnBpdGNoIjo4OSwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1ZGVsYXlfbW9kZSI6IlN0YXRpYyIsIjRjb25kaXRpb25zMTE4Ym9keXlhd19sZWZ0Ijo0MCwiNGNvbmRpdGlvbnMxMjFib2R5eWF3IjoiU3RhdGljIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1b2Zmc2V0X2xlZnQiOjAsIjRjb25kaXRpb25zMjEycGl0Y2giOjg5LCI0Y29uZGl0aW9uczIyN2JvZHl5YXdfcmlnaHQiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zNWRlZmVuc2l2ZV9waXRjaF9zcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMTE2b2Zmc2V0X21haW4iOjAsIjRjb25kaXRpb25zMjEzZGVsYXkiOjAsIjRjb25kaXRpb25zMjI3b2Zmc2V0X3JpZ2h0IjowLCI0Y29uZGl0aW9uczIxMWJyZWFrbGNfdHJpZ2dlciI6IkFsd2F5cyIsIjRjb25kaXRpb25zMTIzeWF3X21vZGlmaWVyIjoiT2ZmIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1Ym9keXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjEyb2Zmc2V0X21haW4iOjAsIjRjb25kaXRpb25zMjEyb2Zmc2V0X3JpZ2h0IjowLCI0Y29uZGl0aW9uczExOHlhd19tb2RpZmllcl9tYWluIjozLCI0Y29uZGl0aW9uczIxMWRlZmVuc2l2ZV9waXRjaCI6Ik9mZiIsIjRjb25kaXRpb25zMTIzb2Zmc2V0X2xlZnQiOjAsIjRjb25kaXRpb25zMjE2ZGVsYXlfZmVhdHVyZXMiOnt9LCI0ZXNwZWNpYWxfY29uZGl0aW9uczRkZWxheV9mZWF0dXJlcyI6e30sIjZhdXRvX2Rpc2NoYXJnZV9tb2RlIjoiT2ZmZW5zaXZlIiwiNGNvbmRpdGlvbnMyMTVib2R5eWF3X21haW4iOjAsIjRjb25kaXRpb25zMjExYm9keXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjExeWF3IjoiT2ZmIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1ZGVmZW5zaXZlX3BpdGNoIjoiT2ZmIiwiNGNvbmRpdGlvbnMxMjhvZmZzZXRfcmlnaHQiOjAsIjRzdGF0ZV9hZHZhbmNlZCI6IioiLCI0Y29uZGl0aW9uczIxMXdheSI6MiwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1YnJlYWtsY19tb2RlIjoiU2tlZXQiLCI0Y29uZGl0aW9uczEyMm9mZnNldF9sZWZ0IjowLCI0Y29uZGl0aW9uczIyNGRlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMxMjV5YXdfbW9kaWZpZXJfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTFkZWZlbnNpdmVfeWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMxMTFkZWxheV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMjExZGVsYXkiOjAsIjNtYW51YWxfcmlnaHQiOlsiSG90a2V5IiwxLDY3XSwiNGVzcGVjaWFsX2NvbmRpdGlvbnMzYnJlYWtsY19tb2RlIjoiU2tlZXQiLCI0Y29uZGl0aW9uczEyMWVuYWJsZSI6ZmFsc2UsIjRjb25kaXRpb25zMjExeWF3X21vZGlmaWVyX21haW4iOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zMWRlZmVuc2l2ZV95YXciOiJPZmYiLCI0Y29uZGl0aW9uczIxMWRlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMxMTV5YXciOiJKaXR0ZXIiLCI0Y29uZGl0aW9uczEyM2VuYWJsZSI6ZmFsc2UsIjRlc3BlY2lhbF9jb25kaXRpb25zMmRlbGF5X21vZGUiOiJTdGF0aWMiLCI0Y29uZGl0aW9uczExMWRlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMzeWF3X21vZGlmaWVyX21haW4iOjAsIjJyZXZvbHZlcl9pbmRpY2F0b3IiOnRydWUsIjVtYWluX2luZGljYXRvcl9jb2xvcnNyaWdodCI6eyJyIjoyNTUsImIiOjI1NSwiYSI6MjIwLCJnIjoyNTV9LCI0Y29uZGl0aW9uczExMXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjE3YnJlYWtsY19tb2RlIjoiU2tlZXQiLCI0Y29uZGl0aW9uczEyM2JvZHl5YXciOiJPZmYiLCI0Y29uZGl0aW9uczEyOGJvZHl5YXciOiJPZmYiLCI0Y29uZGl0aW9uczEyM2RlbGF5IjowLCI0Y29uZGl0aW9uczExM29mZnNldF9tYWluIjotMzMsIjRjb25kaXRpb25zMTExYnJlYWtsY190cmlnZ2VyIjoiQWx3YXlzIiwiNGNvbmRpdGlvbnMxMTFkZWxheSI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1c3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIxNmRlZmVuc2l2ZV95YXciOiJPZmYiLCI0ZXNwZWNpYWxfY29uZGl0aW9uczV5YXdfbW9kaWZpZXIiOiJPZmYiLCI0Y29uZGl0aW9uczEyM2RlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRlc3BlY2lhbF9jb25kaXRpb25zM3NwaW5fc3RlcCI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1ZGVmZW5zaXZlX3lhdyI6Ik9mZiIsIjRjb25kaXRpb25zMTEyZW5hYmxlIjp0cnVlLCI0Y29uZGl0aW9uczExOGJvZHl5YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMjdkZWxheV9tb2RlIjoiU3RhdGljIiwiNGNvbmRpdGlvbnMxMTJwaXRjaCI6ODksIjRjb25kaXRpb25zMTEzZW5hYmxlIjp0cnVlLCI0Y29uZGl0aW9uczEyNGJvZHl5YXciOiJPZmYiLCI0Y29uZGl0aW9uczExMmRlZmVuc2l2ZV95YXdfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczEyN29mZnNldF9tYWluIjowLCI0Y29uZGl0aW9uczExNmVuYWJsZSI6dHJ1ZSwiNGNvbmRpdGlvbnMxMjVwaXRjaCI6ODksIjRjb25kaXRpb25zMTI1c3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczExMnlhd19tb2RpZmllciI6IkNlbnRlciIsIjRjb25kaXRpb25zMTEyZGVsYXkiOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zMmRlZmVuc2l2ZV9waXRjaF9zcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMTI3c3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczExMmRlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTJkZWZlbnNpdmVfcGl0Y2giOiJPZmYiLCI1bWFpbl9pbmRpY2F0b3JfY29sb3JzbGVmdF9hbHQiOnsiciI6MTA5LCJiIjoyNTAsImEiOjI1NSwiZyI6MjEzfSwiNGNvbmRpdGlvbnMyMTZvZmZzZXRfbGVmdCI6MCwiNGNvbmRpdGlvbnMxMTRkZWxheV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMTEzd2F5IjoyLCI2c2hpdHRhbGsiOnt9LCI1bWFpbiI6WyJNYWluIEluZGljYXRvciIsIkRhbWFnZSBJbmRpY2F0b3IiLCJIaXRsb2ciLCJXYXRlcm1hcmsiLCJEZWZlbnNpdmUgSW5kaWNhdG9yIiwiU2xvd2Rvd24gSW5kaWNhdG9yIiwiU3BlY3RhdG9yIExpc3QiLCJPcHRpbWl6ZSBTa2VldCBJbmRpY2F0b3JzIl0sIjRjb25kaXRpb25zMTExZGVmZW5zaXZlX3lhd19zcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMTEzeWF3IjoiSml0dGVyIiwiNGNvbmRpdGlvbnMyMjVib2R5eWF3X21haW4iOjAsIjRjb25kaXRpb25zMTIyYm9keXlhd19tYWluIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczRzcGluX3N0ZXAiOjAsIjNhbnRpX2JydXRlZm9yY2VfY3VzdG9tMiI6MCwiNGNvbmRpdGlvbnMyMTRkZWxheV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMjEyZGVmZW5zaXZlX3BpdGNoIjoiT2ZmIiwiNGNvbmRpdGlvbnMyMTZib2R5eWF3X21haW4iOjAsIjRjb25kaXRpb25zMjEyb2Zmc2V0X2xlZnQiOjAsIjRjb25kaXRpb25zMTI3eWF3X21vZGlmaWVyX21haW4iOjAsIjRjb25kaXRpb25zMTI3YmFzZSI6IkF0IHRhcmdldHMiLCI0ZXNwZWNpYWxfY29uZGl0aW9uczRkZWZlbnNpdmVfcGl0Y2hfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczEyN29mZnNldF9sZWZ0IjowLCI0Y29uZGl0aW9uczEyN2RlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMTI3d2F5IjoyLCI0Y29uZGl0aW9uczEyN3lhdyI6Ik9mZiIsIjRjb25kaXRpb25zMTI3Ym9keXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMTI3ZGVsYXkiOjAsIjRjb25kaXRpb25zMTIxb2Zmc2V0X2xlZnQiOjAsIjRjb25kaXRpb25zMTI3Ym9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczEyOGVuYWJsZSI6dHJ1ZSwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyZGVmZW5zaXZlX3lhdyI6Ik9mZiIsIjRjb25kaXRpb25zMTI4cGl0Y2giOjg5LCI0Y29uZGl0aW9uczEyOGRlbGF5X2ZlYXR1cmVzIjp7fSwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyeWF3X21vZGlmaWVyIjoiT2ZmIiwiNGNvbmRpdGlvbnMxMjhzcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMTI4eWF3X21vZGlmaWVyX21haW4iOjAsIjRjb25kaXRpb25zMTI4YmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczEyOGRlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMTI4eWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMyMTNvZmZzZXRfcmlnaHQiOjAsIjRjb25kaXRpb25zMTI4ZGVsYXkiOjAsIjRjb25kaXRpb25zMTI4eWF3X21vZGlmaWVyIjoiT2ZmIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczExNGRlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTFwaXRjaCI6ODksIjRjb25kaXRpb25zMTE3eWF3X21vZGlmaWVyIjoiT2ZmIiwiNGNvbmRpdGlvbnMxMTNkZWxheV9tb2RlIjoiSml0dGVyIiwiNGNvbmRpdGlvbnMxMjNib2R5eWF3X2xlZnQiOjAsIjRjb25kaXRpb25zMjE3b2Zmc2V0X2xlZnQiOjAsIjRjb25kaXRpb25zMTIyZW5hYmxlIjpmYWxzZSwiNGNvbmRpdGlvbnMyMTFiYXNlIjoiQXQgdGFyZ2V0cyIsIjRjb25kaXRpb25zMjExZGVmZW5zaXZlX3BpdGNoX21haW4iOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zM3dheSI6MiwiNGNvbmRpdGlvbnMyMjZib2R5eWF3X21haW4iOjAsIjJyZXZvbHZlcl9mb3JjZV9zZWNvbmRfZmlyZSI6WyJIb3RrZXkiLDEsNzBdLCI0Y29uZGl0aW9uczIxMWRlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMTE3b2Zmc2V0X2xlZnQiOi0yNSwiNGNvbmRpdGlvbnMyMTFkZWZlbnNpdmVfeWF3X21haW4iOjAsIjNmYWtlbGFnX2xpbWl0MiI6MSwiM2Zha2VsYWdfbGltaXQiOjEzLCI0Y29uZGl0aW9uczEyNWJhc2UiOiJBdCB0YXJnZXRzIiwiNGNvbmRpdGlvbnMxMjRib2R5eWF3X21haW4iOjAsIjRjb25kaXRpb25zMjI4eWF3X21vZGlmaWVyX21haW4iOjAsIjRjb25kaXRpb25zMTI0ZGVsYXlfZmVhdHVyZXMiOnt9LCIzbWFudWFsX2ZvcndhcmQiOlsiSG90a2V5IiwxLDg0XSwiNGNvbmRpdGlvbnMyMTFib2R5eWF3X3JpZ2h0IjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczRkZWZlbnNpdmVfeWF3X21haW4iOjAsIjRjb25kaXRpb25zMjIzd2F5IjoyLCI0Y29uZGl0aW9uczIxMnNwaW5fc3RlcCI6MCwiM2FudGlfYnJ1dGVmb3JjZV9jdXN0b202IjowLCI0Y29uZGl0aW9uczIxMmRlZmVuc2l2ZV95YXdfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczExNmRlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMyMTNwaXRjaCI6ODksIjRjb25kaXRpb25zMjEyYmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczExMmRlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMTE2b2Zmc2V0X2xlZnQiOi0xNSwiNGNvbmRpdGlvbnMyMTJkZWxheSI6MCwiNGNvbmRpdGlvbnMxMjZkZWxheSI6MCwiNGNvbmRpdGlvbnMyMTJ3YXkiOjIsIjRjb25kaXRpb25zMjE4c3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIyM2JvZHl5YXciOiJPZmYiLCI0Y29uZGl0aW9uczIxM2RlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTNicmVha2xjX21vZGUiOiJTa2VldCIsIjRjb25kaXRpb25zMTE4eWF3X21vZGlmaWVyIjoiUmFuZG9tIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnMxcGl0Y2giOjg5LCI0Y29uZGl0aW9uczIyNXlhd19tb2RpZmllcl9tYWluIjowLCI0Y29uZGl0aW9uczIyM3lhdyI6Ik9mZiIsIjRlc3BlY2lhbF9jb25kaXRpb25zM2RlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjVtYWluX2luZGljYXRvcl9jb2xvcnNsZWZ0Ijp7InIiOjE1NCwiYiI6MjUwLCJhIjoyNTUsImciOjIyNn0sIjRjb25kaXRpb25zMjI3ZGVsYXkiOjAsIjRjb25kaXRpb25zMjIzc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczExM2RlZmVuc2l2ZV9waXRjaCI6Ik9mZiIsIjRjb25kaXRpb25zMjI0c3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIyNGJhc2UiOiJBdCB0YXJnZXRzIiwiNGNvbmRpdGlvbnMyMjRkZWZlbnNpdmVfZmVhdHVyZXMiOnt9LCI0ZXNwZWNpYWxfY29uZGl0aW9uczJkZWZlbnNpdmVfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczIyNGJvZHl5YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMjRkZWxheSI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnM1ZGVmZW5zaXZlX3lhd19tYWluIjowLCI0Y29uZGl0aW9uczExN2RlbGF5IjozLCI0Y29uZGl0aW9uczIxNGRlbGF5IjowLCI0Y29uZGl0aW9uczIxNWVuYWJsZSI6ZmFsc2UsIjRjb25kaXRpb25zMjEyYm9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczIyNWVuYWJsZSI6ZmFsc2UsIjRjb25kaXRpb25zMTE0Ym9keXlhd19sZWZ0IjotNDAsIjRjb25kaXRpb25zMjI3eWF3X21vZGlmaWVyIjoiT2ZmIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyeWF3IjoiQmFja3dhcmQiLCI0Y29uZGl0aW9uczIyMWRlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMxMTNicmVha2xjX21vZGUiOiJNYXhpbXVtIiwiNGNvbmRpdGlvbnMxMjZib2R5eWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMyMjVvZmZzZXRfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMjN5YXdfbW9kaWZpZXJfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTdkZWZlbnNpdmVfeWF3X3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMjRib2R5eWF3X3JpZ2h0IjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczRkZWZlbnNpdmVfeWF3X3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMyMThkZWxheSI6MCwiNGNvbmRpdGlvbnMyMTNvZmZzZXRfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMjZwaXRjaCI6ODksIjZsYWdfZXhwbG9pdF9zZXR0aW5ncyI6WyJBaXIgT25seSJdLCI0Y29uZGl0aW9uczIyMXlhd19tb2RpZmllciI6Ik9mZiIsIjRjb25kaXRpb25zMjE0YnJlYWtsY19tb2RlIjoiU2tlZXQiLCI0Y29uZGl0aW9uczIxOGRlbGF5X2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMyMjNkZWZlbnNpdmVfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczExNnlhdyI6IkppdHRlciIsIjRjb25kaXRpb25zMjE2ZW5hYmxlIjpmYWxzZSwiNGNvbmRpdGlvbnMyMjJib2R5eWF3X3JpZ2h0IjowLCI0Y29uZGl0aW9uczIxNHdheSI6MiwiNGNvbmRpdGlvbnMyMjZkZWZlbnNpdmVfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczEyMW9mZnNldF9yaWdodCI6MCwiNGNvbmRpdGlvbnMyMjNkZWxheV9tb2RlIjoiU3RhdGljIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyd2F5IjoyLCI0Y29uZGl0aW9uczIyNHlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMTI2ZW5hYmxlIjpmYWxzZSwiNGNvbmRpdGlvbnMxMThwaXRjaCI6ODksIjRjb25kaXRpb25zMjI3Ym9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczIxNW9mZnNldF9sZWZ0IjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczJiYXNlIjoiQXQgdGFyZ2V0cyIsIjRjb25kaXRpb25zMjI4ZGVsYXlfZmVhdHVyZXMiOnt9LCI2ZXhwbG9pdF9mZWF0dXJlcyI6WyJGb3JjZSBDaGFyZ2UiLCJIaWRlc2hvdCBQZWVrIiwiTGFnIEV4cGxvaXQiLCJBdXRvIEhpZGVzaG90Il0sIjRjb25kaXRpb25zMjI3ZW5hYmxlIjpmYWxzZSwiNGNvbmRpdGlvbnMyMTdib2R5eWF3X21haW4iOjAsIjRjb25kaXRpb25zMjI3cGl0Y2giOjg5LCI0Y29uZGl0aW9uczIyNW9mZnNldF9yaWdodCI6MCwiNGNvbmRpdGlvbnMxMTVvZmZzZXRfbGVmdCI6LTI5LCI0Y29uZGl0aW9uczIxM2JyZWFrbGNfdHJpZ2dlciI6IkFsd2F5cyIsIjRjb25kaXRpb25zMjI3YmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczIxNHlhd19tb2RpZmllcl9tYWluIjowLCI0Y29uZGl0aW9uczEyNnlhd19tb2RpZmllcl9tYWluIjowLCI0Y29uZGl0aW9uczIyN3dheSI6MiwiNGNvbmRpdGlvbnMxMTJkZWZlbnNpdmVfcGl0Y2hfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIyNHBpdGNoIjo4OSwiNGNvbmRpdGlvbnMxMjNib2R5eWF3X21haW4iOjAsIjRjb25kaXRpb25zMTIzZGVsYXlfbW9kZSI6IlN0YXRpYyIsIjRjb25kaXRpb25zMTI4Ym9keXlhd19yaWdodCI6MCwiNGNvbmRpdGlvbnMyMjVkZWxheV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMTE0Ym9keXlhd19tYWluIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczV5YXciOiJPZmYiLCI0Y29uZGl0aW9uczIxMmRlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMjVkZWxheV9tb2RlIjoiU3RhdGljIiwiNGNvbmRpdGlvbnMxMjVkZWxheSI6MCwiM2Zha2VsYWdfc2VuZCI6MiwiNGNvbmRpdGlvbnMxMjFzcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMjE3ZGVmZW5zaXZlX3lhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjIyZGVsYXkiOjAsIjRjb25kaXRpb25zMjI2d2F5IjoyLCI0ZXNwZWNpYWxfY29uZGl0aW9uczVib2R5eWF3X3JpZ2h0IjowLCI0Y29uZGl0aW9uczIxNndheSI6MiwiNGNvbmRpdGlvbnMyMTJkZWxheV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMjI2Ym9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczIxN2RlbGF5X2ZlYXR1cmVzIjp7fSwiM2FudGlfYnJ1dGVmb3JjZV9jdXN0b200IjowLCI0Y29uZGl0aW9uczIyM2Jhc2UiOiJBdCB0YXJnZXRzIiwiM2FudGlfYnJ1dGVmb3JjZV9jdXN0b205IjowLCI0Y29uZGl0aW9uczIyM3BpdGNoIjo4OSwiNGNvbmRpdGlvbnMxMjF5YXdfbW9kaWZpZXIiOiJDZW50ZXIiLCI0Y29uZGl0aW9uczIxNGJyZWFrbGNfdHJpZ2dlciI6IkFsd2F5cyIsIjRjb25kaXRpb25zMjIzZW5hYmxlIjpmYWxzZSwiNGNvbmRpdGlvbnMyMTNkZWZlbnNpdmVfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczIxNGRlbGF5X21vZGUiOiJTdGF0aWMiLCI0Y29uZGl0aW9uczIyNnNwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMTR5YXdfbW9kaWZpZXIiOiJPZmZzZXQiLCI0Y29uZGl0aW9uczIyMmRlZmVuc2l2ZV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMjI0Ym9keXlhd19yaWdodCI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyYm9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczIyN29mZnNldF9sZWZ0IjowLCI0Y29uZGl0aW9uczIyMmJvZHl5YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMjJzcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMTIyeWF3IjoiT2ZmIiwiM21hbnVhbF9iYWNrIjpbIkhvdGtleSIsMSw4OF0sIjRjb25kaXRpb25zMTExb2Zmc2V0X3JpZ2h0IjowLCI0Y29uZGl0aW9uczIxM29mZnNldF9sZWZ0IjowLCI0Y29uZGl0aW9uczIxMnlhd19tb2RpZmllciI6Ik9mZiIsIjRjb25kaXRpb25zMTE1Ym9keXlhd19sZWZ0Ijo0NSwiNGNvbmRpdGlvbnMxMTNkZWZlbnNpdmVfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczIyMXdheSI6MiwiNGNvbmRpdGlvbnMyMTVkZWxheV9tb2RlIjoiU3RhdGljIiwiNGNvbmRpdGlvbnMxMTdkZWZlbnNpdmVfcGl0Y2giOiJPZmYiLCI0Y29uZGl0aW9uczExOHNwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMjdwaXRjaCI6ODksIjRjb25kaXRpb25zMjIxeWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMyMjRlbmFibGUiOmZhbHNlLCI0Y29uZGl0aW9uczIyMWJvZHl5YXciOiJPZmYiLCI0Y29uZGl0aW9uczIyMWRlbGF5IjowLCI0Y29uZGl0aW9uczIyNWRlbGF5IjowLCI2YXV0b19kaXNjaGFyZ2Vfa2V5IjpbIkhvdGtleSIsMSwxOF0sIjRjb25kaXRpb25zMjIyZW5hYmxlIjpmYWxzZSwiNGNvbmRpdGlvbnMyMjFwaXRjaCI6ODksIjRjb25kaXRpb25zMjIxZW5hYmxlIjpmYWxzZSwiNGNvbmRpdGlvbnMyMjVzcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMjIyeWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMyMjF5YXdfbW9kaWZpZXJfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMThicmVha2xjX3RyaWdnZXIiOiJBbHdheXMiLCI0Y29uZGl0aW9uczExOGRlZmVuc2l2ZV9waXRjaCI6Ik9mZiIsIjRjb25kaXRpb25zMjE4Ym9keXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjI4ZW5hYmxlIjpmYWxzZSwiNGNvbmRpdGlvbnMyMjJ5YXdfbW9kaWZpZXJfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTV5YXdfbW9kaWZpZXIiOiJPZmYiLCI0Y29uZGl0aW9uczIxOGRlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMThkZWZlbnNpdmVfeWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMyMTZkZWxheV9tb2RlIjoiU3RhdGljIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnMzZGVmZW5zaXZlX3lhdyI6Ik9mZiIsIjRjb25kaXRpb25zMTExb2Zmc2V0X2xlZnQiOjAsIjRjb25kaXRpb25zMjE4ZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMyMThkZWxheV9tb2RlIjoiU3RhdGljIiwiNGNvbmRpdGlvbnMxMTZ3YXkiOjIsIjRjb25kaXRpb25zMjE1Ym9keXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjExZGVsYXlfbW9kZSI6IlN0YXRpYyIsIjRjb25kaXRpb25zMTI1d2F5IjoyLCI0Y29uZGl0aW9uczIxOGRlZmVuc2l2ZV9waXRjaF9tYWluIjowLCI0Y29uZGl0aW9uczIyMndheSI6MiwiNGNvbmRpdGlvbnMyMThkZWZlbnNpdmVfeWF3X3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMjJkZWxheV9mZWF0dXJlcyI6e30sIjRjb25kaXRpb25zMjE4eWF3X21vZGlmaWVyX21haW4iOjAsIjRjb25kaXRpb25zMjI4ZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMyMjZkZWxheV9mZWF0dXJlcyI6e30sIjRlc3BlY2lhbF9jb25kaXRpb25zNXdheSI6MiwiNGNvbmRpdGlvbnMyMThlbmFibGUiOmZhbHNlLCI0Y29uZGl0aW9uczExOG9mZnNldF9sZWZ0IjotMjEsIjRjb25kaXRpb25zMTI2b2Zmc2V0X2xlZnQiOjAsIjRjb25kaXRpb25zMjI3ZGVsYXlfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczIxOGRlZmVuc2l2ZV95YXciOiJPZmYiLCI0Y29uZGl0aW9uczExMWJvZHl5YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTJ5YXdfbW9kaWZpZXJfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMThkZWZlbnNpdmVfcGl0Y2hfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTVicmVha2xjX21vZGUiOiJTa2VldCIsIjRjb25kaXRpb25zMjE3Ym9keXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjE3ZGVmZW5zaXZlX3BpdGNoX3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMyMjJ5YXdfbW9kaWZpZXIiOiJPZmYiLCI0Y29uZGl0aW9uczIxN2RlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTNiYXNlIjoiQXQgdGFyZ2V0cyIsIjRjb25kaXRpb25zMTE1Ym9keXlhd19yaWdodCI6LTM2LCI0Y29uZGl0aW9uczIyOHlhd19tb2RpZmllciI6Ik9mZiIsIjRjb25kaXRpb25zMjI4cGl0Y2giOjg5LCI0Y29uZGl0aW9uczIyNHdheSI6MiwiNGNvbmRpdGlvbnMyMThib2R5eWF3X2xlZnQiOjAsIjRjb25kaXRpb25zMjI3Ym9keXlhd19tYWluIjowLCI0Y29uZGl0aW9uczIxN2RlbGF5IjowLCI0Y29uZGl0aW9uczIxNW9mZnNldF9yaWdodCI6MCwiNGVzcGVjaWFsX2NvbmRpdGlvbnMzYm9keXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjI4d2F5IjoyLCI0Y29uZGl0aW9uczIyNGRlbGF5X21vZGUiOiJTdGF0aWMiLCI0Y29uZGl0aW9uczIxN2RlZmVuc2l2ZV9waXRjaF9tYWluIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczRkZWZlbnNpdmVfcGl0Y2hfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMjhiYXNlIjoiQXQgdGFyZ2V0cyIsIjRjb25kaXRpb25zMjI3eWF3X21vZGlmaWVyX21haW4iOjAsIjRlc3BlY2lhbF9jb25kaXRpb25zNWJvZHl5YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMjN3YXkiOjIsIjRjb25kaXRpb25zMTI1Ym9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczIxN2Jhc2UiOiJBdCB0YXJnZXRzIiwiNGNvbmRpdGlvbnMyMjdkZWZlbnNpdmVfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczExNWJyZWFrbGNfbW9kZSI6Ik1heGltdW0iLCI2YXV0b19oaWRlc2hvdF9kaXNhYmxlcnMiOlsiS25pZmUiLCJIZWF2eSBQaXN0b2xzIiwiQXV0byBTbmlwZXJzIl0sIjRjb25kaXRpb25zMjE3eWF3X21vZGlmaWVyX21haW4iOjAsIjRjb25kaXRpb25zMjE3c3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIxN3BpdGNoIjo4OSwiNGNvbmRpdGlvbnMyMjZvZmZzZXRfcmlnaHQiOjAsIjRjb25kaXRpb25zMjE3ZW5hYmxlIjpmYWxzZSwiNGNvbmRpdGlvbnMxMjFib2R5eWF3X3JpZ2h0IjowLCI0Y29uZGl0aW9uczEyMXBpdGNoIjo4OSwiM2FudGlfYnJ1dGVmb3JjZV9jdXN0b20zIjowLCI0Y29uZGl0aW9uczIxNWRlZmVuc2l2ZV95YXdfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMTZicmVha2xjX3RyaWdnZXIiOiJBbHdheXMiLCI0Y29uZGl0aW9uczExMm9mZnNldF9sZWZ0IjozNywiNGNvbmRpdGlvbnMyMTZib2R5eWF3IjoiT2ZmIiwiNGNvbmRpdGlvbnMyMTZkZWZlbnNpdmVfcGl0Y2hfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIyNmJhc2UiOiJBdCB0YXJnZXRzIiwiNGNvbmRpdGlvbnMyMTZ5YXciOiJPZmYiLCI0Y29uZGl0aW9uczIyNnlhd19tb2RpZmllcl9tYWluIjowLCI0Y29uZGl0aW9uczIyOGRlbGF5X21vZGUiOiJTdGF0aWMiLCI0Y29uZGl0aW9uczExMm9mZnNldF9yaWdodCI6LTE5LCI0Y29uZGl0aW9uczIyMW9mZnNldF9yaWdodCI6MCwiNGNvbmRpdGlvbnMyMTZkZWZlbnNpdmVfZmVhdHVyZXMiOnt9LCI0Y29uZGl0aW9uczExNGRlbGF5X21vZGUiOiJKaXR0ZXIiLCI0Y29uZGl0aW9uczIyNWJvZHl5YXdfbGVmdCI6MCwiNGNvbmRpdGlvbnMyMTR5YXciOiJPZmYiLCIzYW50aV9icnV0ZWZvcmNlX21vZGUiOiJDdXN0b20iLCI0Y29uZGl0aW9uczIxN2RlbGF5X21vZGUiOiJTdGF0aWMiLCI0Y29uZGl0aW9uczIxOHlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjE0Ym9keXlhd19tYWluIjowLCI0Y29uZGl0aW9uczIxNmRlZmVuc2l2ZV95YXdfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczIyNXBpdGNoIjo4OSwiNGNvbmRpdGlvbnMyMTZwaXRjaCI6ODksIjRjb25kaXRpb25zMjIzb2Zmc2V0X21haW4iOjAsIjRjb25kaXRpb25zMTE0ZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMyMjFiYXNlIjoiQXQgdGFyZ2V0cyIsIjRjb25kaXRpb25zMjE1YnJlYWtsY190cmlnZ2VyIjoiQWx3YXlzIiwiNGNvbmRpdGlvbnMyMjJvZmZzZXRfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMjViYXNlIjoiQXQgdGFyZ2V0cyIsIjRjb25kaXRpb25zMTEzZGVmZW5zaXZlX3lhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjE1ZGVmZW5zaXZlX3BpdGNoX3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMjVvZmZzZXRfcmlnaHQiOjAsIjRjb25kaXRpb25zMjE0Ym9keXlhd19sZWZ0IjowLCI0Y29uZGl0aW9uczEyM3lhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjE1ZGVmZW5zaXZlX2ZlYXR1cmVzIjp7fSwiNGNvbmRpdGlvbnMyMjV3YXkiOjIsIjRjb25kaXRpb25zMjE1ZGVmZW5zaXZlX3BpdGNoIjoiT2ZmIiwiNGNvbmRpdGlvbnMyMTNkZWZlbnNpdmVfeWF3X3NwaW5fc3RlcCI6MCwiNGNvbmRpdGlvbnMxMTJkZWZlbnNpdmVfcGl0Y2hfbWFpbiI6MCwiNGNvbmRpdGlvbnMyMjZkZWxheV9tb2RlIjoiU3RhdGljIiwiNGNvbmRpdGlvbnMyMTVvZmZzZXRfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTJib2R5eWF3X21haW4iOi02LCI0Y29uZGl0aW9uczExNGRlZmVuc2l2ZV9waXRjaCI6Ik9mZiIsIjRjb25kaXRpb25zMTIyb2Zmc2V0X21haW4iOjAsIjRjb25kaXRpb25zMjE1YmFzZSI6IkF0IHRhcmdldHMiLCI0Y29uZGl0aW9uczIyMWJvZHl5YXdfcmlnaHQiOjAsIjRjb25kaXRpb25zMjE1ZGVmZW5zaXZlX3lhd19zcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMjI4Ym9keXlhd19yaWdodCI6MCwiNGNvbmRpdGlvbnMyMTVwaXRjaCI6ODksIjRjb25kaXRpb25zMjEyYnJlYWtsY190cmlnZ2VyIjoiQWx3YXlzIiwiNGNvbmRpdGlvbnMyMTRib2R5eWF3X3JpZ2h0IjowLCI0Y29uZGl0aW9uczIxNHlhd19tb2RpZmllciI6Ik9mZiIsIjNhbnRpX2JydXRlZm9yY2VfY3VzdG9tMTAiOjAsIjRjb25kaXRpb25zMjE0Ym9keXlhdyI6Ik9mZiIsIjRjb25kaXRpb25zMjE0ZGVmZW5zaXZlX3BpdGNoX3NwaW5fc3RlcCI6MCwiNW1haW5faW5kaWNhdG9yX2NvbG9yc01NX0NMUiI6eyJyIjoyNTUsImIiOjI1NSwiYSI6MjIwLCJnIjoyNTV9LCIzYW50aV9icnV0ZWZvcmNlX2N1c3RvbTciOjAsIjRjb25kaXRpb25zMjE0ZGVmZW5zaXZlX3lhd19tYWluIjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczNkZWZlbnNpdmVfcGl0Y2hfbWFpbiI6MCwiNGNvbmRpdGlvbnMxMTdicmVha2xjX21vZGUiOiJNYXhpbXVtIiwiNGVzcGVjaWFsX2NvbmRpdGlvbnMyZGVmZW5zaXZlX3lhd19tYWluIjowLCI0Y29uZGl0aW9uczIxMW9mZnNldF9tYWluIjowLCI0Y29uZGl0aW9uczIxNHBpdGNoIjo4OSwiNGNvbmRpdGlvbnMyMTRlbmFibGUiOmZhbHNlLCI0Y29uZGl0aW9uczIyM2RlbGF5IjowLCI0ZXNwZWNpYWxfY29uZGl0aW9uczRib2R5eWF3X21haW4iOjAsIjRjb25kaXRpb25zMTE0cGl0Y2giOjg5LCI0Y29uZGl0aW9uczIxOGRlZmVuc2l2ZV9waXRjaF9zcGluX3N0ZXAiOjAsIjRjb25kaXRpb25zMjI4b2Zmc2V0X3JpZ2h0IjowLCI0Y29uZGl0aW9uczEyM29mZnNldF9yaWdodCI6MCwiNGNvbmRpdGlvbnMyMTNkZWZlbnNpdmVfcGl0Y2hfc3Bpbl9zdGVwIjowLCI0Y29uZGl0aW9uczExNmJvZHl5YXdfcmlnaHQiOjQwLCI0Y29uZGl0aW9uczIxN2JyZWFrbGNfdHJpZ2dlciI6IkFsd2F5cyIsIjRjb25kaXRpb25zMjE2YnJlYWtsY19tb2RlIjoiU2tlZXQiLCI0Y29uZGl0aW9uczIxMWRlZmVuc2l2ZV9waXRjaF9zcGluX3N0ZXAiOjB9", true)
	print("successfully load preset")
end

config.pLoadPreset = ui_new_button(TAB[1], TAB[2], "P R E S E T", LoadPreset)
config.pConfigsList = ui_new_listbox(TAB[1], TAB[2], "Configs", arrConfigs.arrList)
config.pConfigName = ui_new_textbox(TAB[1], TAB[2], "\n Config Name")
config.pCreateConfig = ui_new_button(TAB[1], TAB[2], "C R E A T E", CreateConfigs)
config.pLoadConfig = ui_new_button(TAB[1], TAB[2], "L O A D", LoadConfigs)
config.pSaveConfig = ui_new_button(TAB[1], TAB[2], "S A V E", SaveConfigs)
config.pDeleteConfig = ui_new_button(TAB[1], TAB[2], "D E L E T E", DeleteConfigs)
config.pImportConfig = ui_new_button(TAB[1], TAB[2], "I M P O R T", function() ImportConfigs() end)
config.pExportConfig = ui_new_button(TAB[1], TAB[2], "E X P O R T", ExportConfigs)

local bind_system = {
    l_press = false,
    r_press = false,
    f_press = false,
    b_press = false,
    last_manual = "reset",
}

local manual_state = 0


local manual = function ()
    if not ui_get(master_switch) then return end
    if not contains(ui_get(antiaim.features), "Manual AA") then return end

    local left_state, right_state, forward_state, back_state, freestand_state = ui_get(antiaim.manual_left), ui_get(antiaim.manual_right), ui_get(antiaim.manual_forward), ui_get(antiaim.manual_back), ui_get(antiaim.manual_freestand)
    local freestand = freestand_state and manual_state == 0
    ui_set(ref.freestanding[1], freestand )
    ui_set(ref.freestanding[2], freestand and "Always on" or "On hotkey")

    if (not right_state) and (not left_state) and (not forward_state) then
        bind_system.last_manual = "reset"
    end

    bind_system.r_press = right_state and bind_system.last_manual ~= "right"
    bind_system.l_press = left_state and bind_system.last_manual ~= "left"
    bind_system.f_press = forward_state and bind_system.last_manual ~= "forward"
    bind_system.b_press = back_state

    if bind_system.r_press then
        manual_state = manual_state == 2 and 0 or 2
        bind_system.last_manual = "right"
    end

    if bind_system.l_press then
        manual_state = manual_state == 1 and 0 or 1
        bind_system.last_manual = "left"
    end

    if bind_system.f_press then
        manual_state = manual_state == 3 and 0 or 3
        bind_system.last_manual = "forward"
    end

    if bind_system.b_press then
        manual_state = 0
        bind_system.last_manual = "reset"
    end
end


right_alpha = 0
left_alpha = 0
manual_alpha = 0
function manualDickWork()
    local lp = entity_get_local_player()
    if not lp or not entity_is_alive(lp) then return end

    local screen = vector(client_screen_size()) / 2
    local can_show_arrows = contains(ui_get(visuals.main_indicator_settings), "Manual Dick")

    manual_alpha = interp(manual_alpha, can_show_arrows and 1 or 0, 0.045)
    if manual_alpha <= 0 then
        return
    end

    local r, g, b, a = ui_get(visuals.main_indicator_colors.MM_CLR)
    a = 255 * manual_alpha
    left_alpha = interp(left_alpha, manual_state == 1 and 1 or 0, 0.045)
    if left_alpha ~= 0 then
        renderer_text(screen.x - 50, screen.y - 16, r, g, b, a * left_alpha, '+', nil, '<')
    end

    right_alpha = interp(right_alpha, manual_state == 2 and 1 or 0, 0.045)
    if right_alpha ~= 0 then
        renderer_text(screen.x + 39, screen.y - 16, r, g, b, a * right_alpha, '+', nil, '>')
    end
end

velocity = function(arg)
    local x, y, z = entity_get_prop(arg, "m_vecVelocity")
    return math.sqrt(x * x + y * y + z * z)
end

end_time = 0
ground_ticks = 0
last_player_status = 0

function on_pre_render()
    local local_player = entity_get_local_player()
    if not entity_is_alive(local_player) then
        return
    end
    local me = ent.get_local_player()
    local anim_settings = ui_get(misc.animate_tab)
    local p_velocity = velocity(local_player)
    local on_ground = bit_band(entity_get_prop(local_player, "m_fFlags"), 1)
    local timing = globals_tickcount() % 69

    if contains(anim_settings, "Fallen legs") then
        if on_ground == 0 and contains(anim_settings, "Air walk") then
            me:get_anim_overlay(6).weight = 1
        end
        entity_set_prop(local_player, "m_flPoseParameter", 0.5, 6)
    end

    if contains(anim_settings, "Reset pitch on land") then
        if on_ground == 1 then
            ground_ticks = ground_ticks + 1
        else
            ground_ticks = 0
            end_time = globals_curtime() + 1
        end
        if ground_ticks > ui_get(ref.fakelag_limit) + 1 and end_time > globals_curtime() then
            entity_set_prop(local_player, "m_flPoseParameter", 0.5, 12)
        end
    end

    if contains(anim_settings, "Body lean") then
        local x_velocity = entity_get_prop(local_player, "m_vecVelocity[0]")
        if math_abs(x_velocity) > 3 then
            me:get_anim_overlay(12).weight = 0.45
        end
    end

    if contains(anim_settings, "Slide walk") and ui_get(ref.slowwalk[1]) and ui_get(ref.slowwalk[2]) then
        local bodyyaw = entity_get_prop(local_player, "m_flPoseParameter", 11) * 120 - 60
        local side = bodyyaw > 0 and 1 or -1
        entity_set_prop(local_player, "m_flPoseParameter", 0.9 * side, 11)
        entity_set_prop(local_player, "m_flPoseParameter", 0, 9)
    end

    if contains(anim_settings, "Jitter legs") then
        if p_velocity > 3 and on_ground == 1 and timing > 1 and not ui_get(ref.slowwalk[2]) then
            entity_set_prop(local_player, "m_flPoseParameter", 1 - client_random_float(0.5, 1), 0)
            ui_set(ref.leg_movement, globals_tickcount() % 3 == 0 and "Always slide" or "Off")
        end
    end

    if contains(anim_settings, "Allen walk") then
        if on_ground == 0 and contains(anim_settings, "Air walk") then
            me:get_anim_overlay(6).weight = 1
        end
        entity_set_prop(local_player, "m_flPoseParameter", 1, 7)
    end

    if not (contains(anim_settings, "Slide walk") and ui_get(ref.slowwalk[1]) and ui_get(ref.slowwalk[2])) and
        not contains(anim_settings, "Jitter legs") and
        not contains(anim_settings, "Allen walk") then
        if not ui_get(ref.doubletap[2]) and not ui_get(ref.hideshot[2]) and
            not (entity_get_prop(local_player, "m_flDuckAmount") > 0.5) then
            if last_player_status == 2 then
                entity_set_prop(local_player, "m_flPoseParameter", 50 and 50 * 0.01 or 0, 14)
            elseif last_player_status == 4 then
                entity_set_prop(local_player, "m_flPoseParameter", 5 and 50 * 0.01 or 0, 10)
            else
                entity_set_prop(local_player, "m_flPoseParameter", 5 and 70 * 0.01 or 0, 8)
            end
        end
    end

    if contains(anim_settings, "Earthquake") then
        local value = ui_get(misc.earthquake_value)/100
        me:get_anim_overlay(12).weight = client_random_float(-value, value*1.5)
    end

    if contains(anim_settings, "Flashed") then
        local overlay = me:get_anim_overlay(9)
        overlay.weight = 1
        overlay.sequence = 224
    end
end

local Pistol = {
    "CWeaponHKP2000",
    "CWeaponElite",
    "CWeaponP250",
    "CWeaponFiveSeven",
    "CWeaponGlock",
    "CWeaponTec9",
}

local AutoSniper = {
    "CWeaponG3SG1",
    "CWeaponSCAR20",
}

local Rifle = {
    "CWeaponM4A1",
    "CWeaponFamas",
    "CWeaponAug",
    "CWeaponGalilAR",
    "CAK47",
    "CWeaponSG556",
}

local Nades = {
    "CHEGrenade",
    "CFlashbang",
    "CSmokeGrenade",
    "CMolotovGrenade",
    "CIncendiaryGrenade",
    "CDecoyGrenade",
}

local SMG = {
    "CWeaponMAC10",
    "CWeaponMP7",
    "CWeaponUMP45",
    "CWeaponP90",
    "CWeaponBizon",
    "CWeaponMP9",
}

local MachineGun = {
    "CWeaponNegev",
    "CWeaponM249",
}

local Shotgun = {
    "CWeaponNOVA",
    "CWeaponXM1014",
    "CWeaponMag7",
    "CWeaponSawedoff",
}

local get_distance = function(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
end

local last_land_tickcount = 0
local landtick = 0
local status = {
    inair = false,
    crouch = false,
    velocity = 0,
}
local get_status = function ()

    local lp = entity_get_local_player()
    if not lp or not entity_is_alive(lp) then
        return
    end

    local team = entity_get_prop(lp, "m_iTeamNum")

    local team_idx = (team == 2) and 1 or 2

    local fakelag = not ui_get(ref.doubletap[2]) and not ui_get(ref.hideshot[2])
    local state_advanced_idx = 1

    if fakelag then
        state_advanced_idx = 2
    end

    local inair = (bit_band(entity_get_prop(lp, "m_fFlags"), 1) == 0)
    local slowwalking = ui_get(ref.slowwalk[2]) and not inair
    local crouch = not(bit_band(entity_get_prop(lp, "m_fFlags"), 4) == 0)
    local velocity_x, velocity_y = entity_get_prop(lp, "m_vecVelocity")
    local velocity = math.sqrt(velocity_x ^ 2 + velocity_y ^ 2)

    landtick = inair and 0 or (globals_tickcount() ~= last_land_tickcount and (landtick + 1) or landtick)
    last_land_tickcount = globals_tickcount()
    local smoothed_inair = not (landtick >= 2)
    if contains(ui_get(antiaim.features),"Smooth Landing Check") then
        inair = smoothed_inair
    end

    status.inair = inair
    status.crouch = crouch
    status.velocity = velocity

    local state_idx = 1
    local especial_state_idx = 0

    if inair then
        if crouch then
            state_idx = 8 -- jump duck
        else
            state_idx = 7 -- jumping
        end
    else
        if velocity > 5 then
            if crouch then
                state_idx = 6 -- duck running
            elseif slowwalking then
                state_idx = 4 -- slow
            else
                state_idx = 3 -- running
            end
        else
            if crouch then
                state_idx = 5 -- ducking
            else
                state_idx = 2 -- standing
            end
        end
    end

    local localx, localy, localz = entity_get_prop(lp, "m_vecOrigin")
    local target = client_current_threat()
    local targetx, targety, targetz
    if target then
        targetx, targety, targetz = entity_get_prop(target, "m_vecOrigin")
    end
    local manual_on = contains(ui_get(antiaim.features), "Manual AA")
    local manual = manual_on and (manual_state ~= 0)
    local freestanding = manual_on and ui_get(antiaim.manual_freestand) and (manual_state == 0)

    if ui_get(builder.especial_conditions[1].enable) and manual then
        especial_state_idx = 1 -- manual
    elseif ui_get(builder.especial_conditions[2].enable) and freestanding then
        especial_state_idx = 2 -- freestanding
    elseif ui_get(builder.especial_conditions[3].enable) and target and (localz > targetz + 128) then
        especial_state_idx = 3 -- height above
    elseif ui_get(builder.especial_conditions[4].enable) and target and (localz < targetz - 128) then
        especial_state_idx = 4 -- height below
    elseif ui_get(builder.especial_conditions[5].enable) and target and (get_distance(localx, localy, localz, targetx, targety, targetz) > 1300) then
        especial_state_idx = 5 -- high range
    end

    last_player_status = state_idx
    return team_idx, state_advanced_idx, state_idx, especial_state_idx

end


handle_visible = function ()
    local enable = ui_get(master_switch)
    vanila_skeet_element(not enable)
    ui_set_visible(page, enable)
    if not ui_get(page) then return end

    local page_ = ui_get(page) + 1
    local info_ = (page_ == 1) and enable
    local rage_ = (page_ == 2) and enable
    local antiaim_ = (page_ == 3) and enable
    local builder_ = (page_ == 4) and enable
    local visuals_ = (page_ == 5) and enable
    local misc_ = (page_ == 6) and enable
    local config_ = (page_ == 7) and enable
    
    for k, v in pairs(info) do
        ui_set_visible(v,info_)
    end

    local ragefuncs = ui_get(rage.main)
    local revolver_settings = ui_get(rage.revolver_indicator_settings)
    local jumpscout = contains(ragefuncs, "Jump Scout")
    local revolver = contains(ragefuncs, "Revolver Improvements")
    local revolver_indicator = revolver and ui_get(rage.revolver_indicator)
    local revolver_custom = revolver_indicator and contains(revolver_settings, "Custom Color")
    -- local ragebot_logics = contains(ragefuncs, "Ragebot Logics")
    local magnet = contains(ragefuncs, "Magnet Melee")
    local friendly_fire = contains(ragefuncs, "Friendly Fire")
    
    ui_set_visible(rage.main, rage_)
    ui_set_visible(rage.jumpscout_distance, rage_ and jumpscout)
    ui_set_visible(rage.jumpscout_settings, rage_ and jumpscout)
    ui_set_visible(rage.revolver_indicator, rage_ and revolver)
    ui_set_visible(rage.revolver_indicator_settings, rage_ and revolver_indicator)
    ui_set_visible(rage.revolver_indicator_color, rage_ and revolver_custom)
    ui_set_visible(rage.revolver_force_second_fire, rage_ and revolver)
    ui_set_visible(rage.revolver_second_fire_distance, rage_ and revolver)
    -- ui_set_visible(rage.ragebot_logics, rage_ and ragebot_logics)
    ui_set_visible(rage.magnet_key, rage_ and magnet)
    ui_set_visible(rage.friendly_fire, rage_ and friendly_fire)

    local fakelag_mode = ui_get(antiaim.fakelag_mode)
    local advanced = builder_ and (ui_get(builder.state_style) == "Advanced")
    local especial = builder_ and (ui_get(builder.state_style) == "Especial")
    local manual = contains(ui_get(antiaim.features), "Manual AA")
    local safehead = contains(ui_get(antiaim.features), "Safe Head")
    local fastladder = contains(ui_get(antiaim.features), "Fast Ladder")
    local anti_bruteforce = contains(ui_get(antiaim.features), "Anti Bruteforce")
    local anti_bruteforce_custom = anti_bruteforce and ui_get(antiaim.anti_bruteforce_mode) == "Custom"
    local anti_bruteforce_amount = ui_get(antiaim.anti_bruteforce_amount)
    ui_set_visible(antiaim.fakelag_mode,antiaim_)
    ui_set_visible(antiaim.fakelag_limit,antiaim_ and fakelag_mode ~= "Alternative")
    ui_set_visible(antiaim.fakelag_limit2,antiaim_ and fakelag_mode == "Jitter")
    ui_set_visible(antiaim.fakelag_send,antiaim_ and fakelag_mode == "Alternative")
    ui_set_visible(antiaim.fakelag_choke,antiaim_ and fakelag_mode == "Alternative")
    ui_set_visible(antiaim.fakelag_disablers,antiaim_)
    ui_set_visible(antiaim.features,antiaim_)
    ui_set_visible(antiaim.manual_left,antiaim_ and manual)
    ui_set_visible(antiaim.manual_right,antiaim_ and manual)
    ui_set_visible(antiaim.manual_forward,antiaim_ and manual)
    ui_set_visible(antiaim.manual_back,antiaim_ and manual)
    ui_set_visible(antiaim.manual_freestand,antiaim_ and manual)
    ui_set_visible(antiaim.safehead_mode,antiaim_ and safehead)
    ui_set_visible(antiaim.fastladder_mode,antiaim_ and fastladder)
    ui_set_visible(antiaim.anti_bruteforce_mode,antiaim_ and anti_bruteforce)
    ui_set_visible(antiaim.anti_bruteforce_amount,antiaim_ and anti_bruteforce_custom)
    for i, v in ipairs(antiaim.anti_bruteforce_custom) do
        ui_set_visible(v,antiaim_ and anti_bruteforce_custom and i <= anti_bruteforce_amount)
    end

    local visual_settings = ui_get(visuals.main)
    local main_indicator_settings = ui_get(visuals.main_indicator_settings)
    local main_indicator = contains(visual_settings, "Main Indicator")
    local hitlog = contains(visual_settings, "Hitlog")
    local custom_name_tag = contains(main_indicator_settings, "Custom NameTag")
    local custom_colors = contains(main_indicator_settings, "Custom colors")

    ui_set_visible(visuals.main,visuals_)
    ui_set_visible(visuals.main_indicator_settings,visuals_ and main_indicator)
    ui_set_visible(visuals.main_indicator_name_tag,visuals_ and main_indicator and custom_name_tag)
    for k, v in pairs(visuals.main_indicator_colors) do
        ui_set_visible(v,visuals_ and main_indicator and custom_colors)
    end
    ui_set_visible(visuals.hitlog_settings,visuals_ and hitlog)

    local animates = ui_get(misc.animate_tab)
    local exploits = ui_get(misc.exploit_features)
    ui_set_visible(misc.console_filter,misc_)
    ui_set_visible(misc.clantag,misc_)
    ui_set_visible(misc.shittalk,misc_)
    ui_set_visible(misc.animate_tab,misc_)
    ui_set_visible(misc.earthquake_value,misc_ and contains(animates, "Earthquake"))
    ui_set_visible(misc.exploit_features,misc_)
    ui_set_visible(misc.auto_discharge_key,misc_ and contains(exploits, "Auto Discharge"))
    ui_set_visible(misc.auto_discharge_mode,misc_ and contains(exploits, "Auto Discharge"))
    ui_set_visible(misc.lag_exploit,misc_ and contains(exploits, "Lag Exploit"))
    ui_set_visible(misc.lag_exploit_settings,misc_ and contains(exploits, "Lag Exploit"))
    ui_set_visible(misc.auto_hideshot_disablers,misc_ and contains(exploits, "Auto Hideshot"))

    ui_set_visible(config.pConfigsList, config_)
    ui_set_visible(config.pConfigName, config_)
    ui_set_visible(config.pCreateConfig, config_)
    ui_set_visible(config.pLoadConfig, config_)
    ui_set_visible(config.pSaveConfig, config_)
    ui_set_visible(config.pDeleteConfig , config_)
    ui_set_visible(config.pImportConfig, config_)
    ui_set_visible(config.pExportConfig, config_)
    ui_set_visible(config.pLoadPreset, config_)

    ui_set_visible(builder.state_style,builder_)
    ui_set_visible(builder.team,advanced)
    ui_set_visible(builder.state_advanced,advanced)
    ui_set_visible(builder.state,advanced)
    ui_set_visible(builder.especial_state,especial)
    if advanced then
        for k, v in pairs(Especial) do
            for _, value in pairs(builder.especial_conditions[k]) do
                ui_set_visible(value,false)
            end
        end
        for k1, v1 in pairs(Team) do
            for k2, v2 in pairs(State_advanced) do
                for k3, v3 in pairs(State) do

                        if not builder_ then
                            goto invisible
                        end

                        if ui_get(builder.team) ~= v1 then
                            goto invisible
                        elseif ui_get(builder.state_advanced) ~= v2 then
                            goto invisible
                        elseif ui_get(builder.state) ~= v3 then
                            goto invisible
                        else
                            if not ui_get(builder.conditions[k1][k2][k3].enable) then
                                goto enable_only
                            end
                            ui_set_visible(builder.conditions[k1][k2][k3].enable,true)
                            goto visible
                        end

                        ::invisible::
                        for _, value in pairs(builder.conditions[k1][k2][k3]) do
                            ui_set_visible(value,false)
                        end
                        goto ennd

                        ::enable_only::
                        for _, value in pairs(builder.conditions[k1][k2][k3]) do
                            ui_set_visible(value,false)
                        end
                        ui_set_visible(builder.conditions[k1][k2][k3].enable,true)
                        goto ennd
                        
                        ::visible::
                        ui_set_visible(builder.conditions[k1][k2][k3].pitch,true)
                        ui_set_visible(builder.conditions[k1][k2][k3].base,true)
                        ui_set_visible(builder.conditions[k1][k2][k3].yaw,true)
                        ui_set_visible(builder.conditions[k1][k2][k3].offset_main,ui_get(builder.conditions[k1][k2][k3].yaw) == "Backward")
                        ui_set_visible(builder.conditions[k1][k2][k3].offset_left,ui_get(builder.conditions[k1][k2][k3].yaw) == "Jitter")
                        ui_set_visible(builder.conditions[k1][k2][k3].offset_right,ui_get(builder.conditions[k1][k2][k3].yaw) == "Jitter")
                        ui_set_visible(builder.conditions[k1][k2][k3].yaw_modifier,true)
                        ui_set_visible(builder.conditions[k1][k2][k3].yaw_modifier_main,ui_get(builder.conditions[k1][k2][k3].yaw_modifier) ~= "Off")
                        ui_set_visible(builder.conditions[k1][k2][k3].spin_step,ui_get(builder.conditions[k1][k2][k3].yaw_modifier) == "Spin")
                        ui_set_visible(builder.conditions[k1][k2][k3].way,ui_get(builder.conditions[k1][k2][k3].yaw_modifier) == "xWay")
                        ui_set_visible(builder.conditions[k1][k2][k3].bodyyaw,true)
                        ui_set_visible(builder.conditions[k1][k2][k3].bodyyaw_main,ui_get(builder.conditions[k1][k2][k3].bodyyaw) == "Static")
                        ui_set_visible(builder.conditions[k1][k2][k3].bodyyaw_left,ui_get(builder.conditions[k1][k2][k3].bodyyaw) == "Jitter" or ui_get(builder.conditions[k1][k2][k3].bodyyaw) == "Automatic")
                        ui_set_visible(builder.conditions[k1][k2][k3].bodyyaw_right,ui_get(builder.conditions[k1][k2][k3].bodyyaw) == "Jitter" or ui_get(builder.conditions[k1][k2][k3].bodyyaw) == "Automatic")
                        -- ui_set_visible(builder.conditions[k1][k2][k3].text,true)
                        if v2 == "Fakelag" then
                            ui_set_visible(builder.conditions[k1][k2][k3].defensive_features,true)
                            ui_set_visible(builder.conditions[k1][k2][k3].delay_mode,true)
                            ui_set_visible(builder.conditions[k1][k2][k3].delay,true)
                            ui_set_visible(builder.conditions[k1][k2][k3].delay_features,true)
                        else
                            ui_set_visible(builder.conditions[k1][k2][k3].breaklc_mode,true)
                            ui_set_visible(builder.conditions[k1][k2][k3].breaklc_trigger,true)
                            ui_set_visible(builder.conditions[k1][k2][k3].defensive_pitch,true)
                            ui_set_visible(builder.conditions[k1][k2][k3].defensive_pitch_main,ui_get(builder.conditions[k1][k2][k3].defensive_pitch) ~= "Off")
                            ui_set_visible(builder.conditions[k1][k2][k3].defensive_pitch_spin_step,ui_get(builder.conditions[k1][k2][k3].defensive_pitch) == "Spin")
                            ui_set_visible(builder.conditions[k1][k2][k3].defensive_yaw,true)
                            ui_set_visible(builder.conditions[k1][k2][k3].defensive_yaw_main,ui_get(builder.conditions[k1][k2][k3].defensive_yaw) ~= "Off")
                            ui_set_visible(builder.conditions[k1][k2][k3].defensive_yaw_spin_step,ui_get(builder.conditions[k1][k2][k3].defensive_yaw) == "Spin")
                            ui_set_visible(builder.conditions[k1][k2][k3].defensive_features,true)
                            ui_set_visible(builder.conditions[k1][k2][k3].delay_mode,true)
                            ui_set_visible(builder.conditions[k1][k2][k3].delay,true)
                            ui_set_visible(builder.conditions[k1][k2][k3].delay_features,true)
                        end
                        ::ennd::
                end
            end
        end
    elseif especial then
        for k1, v1 in pairs(Team) do
            for k2, v2 in pairs(State_advanced) do
                for k3, v3 in pairs(State) do
                    for _, value in pairs(builder.conditions[k1][k2][k3]) do
                        ui_set_visible(value,false)
                    end
                end
            end
        end



        for k, v in pairs(Especial) do
            if not (ui_get(builder.especial_state) == v) then
                for _, value in pairs(builder.especial_conditions[k]) do
                    ui_set_visible(value,false)
                end
            elseif not ui_get(builder.especial_conditions[k].enable) then
                for _, value in pairs(builder.especial_conditions[k]) do
                    ui_set_visible(value,false)
                end
                ui_set_visible(builder.especial_conditions[k].enable,true)
            else

                ui_set_visible(builder.especial_conditions[k].enable,true)
                ui_set_visible(builder.especial_conditions[k].pitch,true)
                ui_set_visible(builder.especial_conditions[k].base,true)
                ui_set_visible(builder.especial_conditions[k].yaw,true)
                ui_set_visible(builder.especial_conditions[k].offset_main,ui_get(builder.especial_conditions[k].yaw) == "Backward")
                ui_set_visible(builder.especial_conditions[k].offset_left,ui_get(builder.especial_conditions[k].yaw) == "Jitter")
                ui_set_visible(builder.especial_conditions[k].offset_right,ui_get(builder.especial_conditions[k].yaw) == "Jitter")
                ui_set_visible(builder.especial_conditions[k].yaw_modifier,true)
                ui_set_visible(builder.especial_conditions[k].yaw_modifier_main,ui_get(builder.especial_conditions[k].yaw_modifier) ~= "Off")
                ui_set_visible(builder.especial_conditions[k].spin_step,ui_get(builder.especial_conditions[k].yaw_modifier) == "Spin")
                ui_set_visible(builder.especial_conditions[k].way,ui_get(builder.especial_conditions[k].yaw_modifier) == "xWay")
                ui_set_visible(builder.especial_conditions[k].bodyyaw,true)
                ui_set_visible(builder.especial_conditions[k].bodyyaw_main,ui_get(builder.especial_conditions[k].bodyyaw) == "Static")
                ui_set_visible(builder.especial_conditions[k].bodyyaw_left,ui_get(builder.especial_conditions[k].bodyyaw) == "Jitter" or ui_get(builder.especial_conditions[k].bodyyaw) == "Automatic")
                ui_set_visible(builder.especial_conditions[k].bodyyaw_right,ui_get(builder.especial_conditions[k].bodyyaw) == "Jitter" or ui_get(builder.especial_conditions[k].bodyyaw) == "Automatic")
                -- ui_set_visible(builder.especial_conditions[k].text,true)
                ui_set_visible(builder.especial_conditions[k].breaklc_mode,true)
                ui_set_visible(builder.especial_conditions[k].breaklc_trigger,true)
                ui_set_visible(builder.especial_conditions[k].defensive_pitch,true)
                ui_set_visible(builder.especial_conditions[k].defensive_pitch_main,ui_get(builder.especial_conditions[k].defensive_pitch) ~= "Off")
                ui_set_visible(builder.especial_conditions[k].defensive_pitch_spin_step,ui_get(builder.especial_conditions[k].defensive_pitch) == "Spin")
                ui_set_visible(builder.especial_conditions[k].defensive_yaw,true)
                ui_set_visible(builder.especial_conditions[k].defensive_yaw_main,ui_get(builder.especial_conditions[k].defensive_yaw) ~= "Off")
                ui_set_visible(builder.especial_conditions[k].defensive_yaw_spin_step,ui_get(builder.especial_conditions[k].defensive_yaw) == "Spin")
                ui_set_visible(builder.especial_conditions[k].defensive_features,true)
                ui_set_visible(builder.especial_conditions[k].delay_mode,true)
                ui_set_visible(builder.especial_conditions[k].delay,true)
                ui_set_visible(builder.especial_conditions[k].delay_features,true)
            end
        end

    else
        for k1, v1 in pairs(Team) do
            for k2, v2 in pairs(State_advanced) do
                for k3, v3 in pairs(State) do
                    for _, value in pairs(builder.conditions[k1][k2][k3]) do
                        ui_set_visible(value,false)
                    end
                end
            end
        end
        for k, v in pairs(Especial) do
            for _, value in pairs(builder.especial_conditions[k]) do
                ui_set_visible(value,false)
            end
        end
    end
    
end

if not pcall(ffi.sizeof, "AnimationState") then
	ffi.cdef([[
		typedef struct {
			int64_t pad_0;
			union {
				int xuid;
				struct {
					int xuidlow;
					int xuidhigh;
				};
			};

			char name[128];
			int userid;
			char guid[33];
			unsigned int friendsid;
			char friendsname[128];
			bool fakeplayer;
			bool ishltv;
			unsigned int customfiles[4];
			unsigned char filesdownloaded;
		} PlayerInfo;

		typedef struct {
			char pad[3];
			char m_bForceWeaponUpdate;
			char pad1[91];
			void* m_pBaseEntity;
 			void* m_pActiveWeapon;
			void* m_pLastActiveWeapon;
			float m_flLastClientSideAnimationUpdateTime;
			int m_iLastClientSideAnimationUpdateFramecount;
			float m_flAnimUpdateDelta;
			float m_flEyeYaw;
			float m_flPitch;
			float m_flGoalFeetYaw;
			float m_flCurrentFeetYaw;
			float m_flCurrentTorsoYaw;
			float m_flUnknownVelocityLean;
			float m_flLeanAmount;
			char pad2[4];
			float m_flFeetCycle;
			float m_flFeetYawRate;
			char pad3[4];
			float m_flDuckAmount;
			float m_fLandingDuckAdditiveSomething;
			char pad4[4];
			float m_vOriginX;
			float m_vOriginY;
			float m_vOriginZ;
			float m_vLastOriginX;
			float m_vLastOriginY;
			float m_vLastOriginZ;
			float m_vVelocityX;
			float m_vVelocityY;
			char pad5[4];
			float m_flUnknownFloat1;
			char pad6[8];
			float m_flUnknownFloat2;
			float m_flUnknownFloat3;
			float m_flUnknown;
			float m_flSpeed2D;
			float m_flUpVelocity;
			float m_flSpeedNormalized;
			float m_flFeetSpeedForwardsOrSideWays;
			float m_flFeetSpeedUnknownForwardOrSideways;
			float m_flTimeSinceStartedMoving;
			float m_flTimeSinceStoppedMoving;
			bool m_bOnGround;
			bool m_bInHitGroundAnimation;
			float m_flTimeSinceInAir;
			float m_flLastOriginZ;
			float m_flHeadHeightOrOffsetFromHittingGroundAnimation;
			float m_flStopToFullRunningFraction;
			char pad7[4];
			float m_flMagicFraction;
			char pad8[60];
			float m_flWorldForce;
			char pad9[458];
			float m_flMinYaw;
			float m_flMaxYaw;
            float ground_fraction;
		} AnimationState;
	]])
end
local GetClientEntity = vtable_bind("client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*, int)")
local GetAnimationState = function(Entity)
	local BaseEntity = GetClientEntity(Entity)
	return ffi.cast("AnimationState**",
		ffi.cast("char*", BaseEntity) + 0x9960
	)[0]
end

local at_targets = function(threat)
	if threat ~= nil then
        local lp = entity_get_local_player()
		local eyepos = vector(entity_get_origin(lp)) + vector(0, 0, 40)
		local target = vector(entity_get_origin(threat)) + vector(0, 0, 40)
		local pitch, yaw = eyepos:to(target):angles()
		return pitch, normalize_yaw(yaw + 180)
	else
		return 0, 0
	end
end

last_shift = false
shifted_time = 0
shifting_handler = function()
    local exploit_on = ((ui_get(ref.doubletap[1]) and ui_get(ref.doubletap[2])) or (ui_get(ref.hideshot[1]) and ui_get(ref.hideshot[2]))) and not (ui_get(ref.fakeduck))
    if last_shift and not exploit_on then
        shifted_time = globals_curtime()
    end
    last_shift = exploit_on
end

freestanding_yaw = 666
freestanding_handler = function ()
    if not(ui_get(ref.freestanding[1]) and ui_get(ref.freestanding[2])) or not (client_current_threat()) then
        freestanding_yaw = 666
        return
    end
    local lp = entity_get_local_player()
    local _, eyeyaw = entity_get_prop(lp, "m_angEyeAngles")
    local _, target = at_targets(client_current_threat())
    freestanding_yaw = normalize_yaw(eyeyaw - target)
end

local indicators = {
    auto_discharge = false,
}
local aa = {}
aa.backstab = false
aa.delay_value = 0
aa.delay_switch = false
aa.send_packet_commands = 0
aa.yaw_jitter_flip = false
aa.yaw_modifier = 0
aa.yaw_modifier_flip = false
aa.yaw_spin_amount = 0
aa.yaw_way = 0
aa.last_state = "0"
aa.defensive_pitch = 0
aa.defensive_yaw = 0
aa.defensive_active = false
aa.defensive_yaw_flip = false
aa.defensive_yaw_spin_amount = 0
aa.defensive_pitch_flip = false
aa.defensive_pitch_spin_amount = 0
aa.nochoke = false
aa.fakelag_limit = 1
aa.fakelag_switch = false
aa.alternative_count = 0
aa.alternative_switch = false
aa.alternative_limit = 0
aa.last_freestanding_yaw = 0
aa.last_freestanding_back_time = 0
aa.last_freestanding_time = 0
aa.freestand_extend = 0
aa.maxtickbase_normal = false
aa.check_cancel = 0
aa.force_defensive = false
aa.allow_bruteforce = false
aa.bruteforce = false
aa.bruteforce_enemy = {}
tickshot = 0
function get_camera_pos(enemy)
    local e_x, e_y, e_z = entity_get_prop(enemy, "m_vecOrigin")
    if e_x == nil then return end
    local _, _, ofs = entity_get_prop(enemy, "m_vecViewOffset")
    e_z = e_z + (ofs - (entity_get_prop(enemy, "m_flDuckAmount") * 16))
    return e_x, e_y, e_z
end

function fired_at(target, shooter, shot)
    local shooter_cam = { get_camera_pos(shooter) }
    if shooter_cam[1] == nil then return end
    local player_head = { entity_hitbox_position(target, 0) }
    local shooter_cam_to_head = { player_head[1] - shooter_cam[1],player_head[2] - shooter_cam[2],player_head[3] - shooter_cam[3] }
    local shooter_cam_to_shot = { shot[1] - shooter_cam[1], shot[2] - shooter_cam[2],shot[3] - shooter_cam[3]}
    local magic = ((shooter_cam_to_head[1]*shooter_cam_to_shot[1]) + (shooter_cam_to_head[2]*shooter_cam_to_shot[2]) + (shooter_cam_to_head[3]*shooter_cam_to_shot[3])) / (math.pow(shooter_cam_to_shot[1], 2) + math.pow(shooter_cam_to_shot[2], 2) + math.pow(shooter_cam_to_shot[3], 2))
    local closest = { shooter_cam[1] + shooter_cam_to_shot[1]*magic, shooter_cam[2] + shooter_cam_to_shot[2]*magic, shooter_cam[3] + shooter_cam_to_shot[3]*magic}
    local length = math.abs(math.sqrt(math.pow((player_head[1]-closest[1]), 2) + math.pow((player_head[2]-closest[2]), 2) + math.pow((player_head[3]-closest[3]), 2)))
    local frac_shot = client_trace_line(shooter, shot[1], shot[2], shot[3], player_head[1], player_head[2], player_head[3])
    local frac_final = client_trace_line(target, closest[1], closest[2], closest[3], player_head[1], player_head[2], player_head[3])
    return (length < 69) and (frac_shot > 0.99 or frac_final > 0.99)
end

anti_bruteforce_check = function (event)
    if not aa.allow_bruteforce then return end
    local lp = entity_get_local_player()
    if not lp or not entity_is_alive(lp) then return end
    local enemy = client_userid_to_entindex(event.userid)

    if enemy == lp or not entity_is_enemy(enemy) then return end
    if fired_at(lp, enemy, {event.x, event.y, event.z}) then
        if tickshot ~= globals_tickcount() then
            tickshot = globals_tickcount()
            local mode = ui_get(antiaim.anti_bruteforce_mode)
            local max = mode == "Invert" and 1 or mode == "Random" and 2 or ui_get(antiaim.anti_bruteforce_amount)
            aa.bruteforce = true
            if aa.bruteforce_enemy[enemy] then
                local v = aa.bruteforce_enemy[enemy].step + 1
                aa.bruteforce_enemy[enemy].step = v > max and 0 or v
            else
                aa.bruteforce_enemy[enemy] = {}
                aa.bruteforce_enemy[enemy].step = 1
                aa.bruteforce_enemy[enemy].invert = false
                aa.bruteforce_enemy[enemy].value = 666
            end
        end
    end
end

anti_bruteforce = function (enemy)
    if not aa.allow_bruteforce then return end
    if not enemy then return end
    if not aa.bruteforce_enemy[enemy] then return end

    if aa.bruteforce then
        local mode = ui_get(antiaim.anti_bruteforce_mode)
        local step = aa.bruteforce_enemy[enemy].step
        if mode == "Invert" then
            aa.bruteforce_enemy[enemy].invert = step == 1 and true or false
            aa.bruteforce_enemy[enemy].value = 666
        elseif mode == "Random" then
            aa.bruteforce_enemy[enemy].invert = step == 1 and not aa.bruteforce_enemy[enemy].invert or (math.random(0,1) == 1 and true or false)
            aa.bruteforce_enemy[enemy].value = 666
        else
            aa.bruteforce_enemy[enemy].invert = false
            aa.bruteforce_enemy[enemy].value = step > 0 and ui_get(antiaim.anti_bruteforce_custom[step]) or 666
        end
        aa.bruteforce = false
    end
    return true
end

local handle_antiaim = function (cmd)

    if not ui_get(master_switch) then return end

    ui_set(ref.antiaim_switch,true)
    ui_set(ref.correction,true)
    ui_set(ref.fakepeek[1],false)
    ui_set(ref.sv_maxusrcmdprocessticks_holdaim,true)

    manual()

    local lp = entity_get_local_player()
    if not lp then
        return
    end

    local weapon = entity_get_player_weapon(lp)
    local threat = client_current_threat() or lp

    local inuse_aa = false
    if contains(ui_get(antiaim.features), "Inuse AA") then
        if weapon ~= nil and entity_get_classname(weapon) == "CC4" then
            if cmd.in_attack == 1 then
                cmd.in_attack = 0
                cmd.in_use = 1
            end
        else
            if cmd.in_use == 1 then
                if cmd.chokedcommands == 0 then
                    inuse_aa = true
                    cmd.in_use = 0
                end
            end
        end
    end

    local manual = contains(ui_get(antiaim.features), "Manual AA")
    local left = (manual_state == 1 and manual)
    local right = (manual_state == 2 and manual)
    local forward = (manual_state == 3 and manual)

    local team_idx, state_advanced_idx, state_idx, especial_state_idx = get_status()
    local especial = (especial_state_idx ~= 0)
    local data = {}

    if especial then
        data = builder.especial_conditions[especial_state_idx]
    else
        local found = false
        for _, k1 in ipairs({team_idx, ((team_idx == 1) and 2 or 1)}) do
            for _, k2 in ipairs({state_advanced_idx, 1}) do
                for _, k3 in ipairs({state_idx, 1}) do
                        if ui_get(builder.conditions[k1][k2][k3].enable) then
                            data = builder.conditions[k1][k2][k3]
                            found = true
                            goto breakf
                        end
                end
            end
        end
        ::breakf::
        if not found then
            ui_set(ref.antiaim_switch,false)
            return
        end
    end

    local fakelag_mode = ui_get(antiaim.fakelag_mode)
    local fakelag_disablers = ui_get(antiaim.fakelag_disablers)
    local curtime = globals_curtime()
    if cmd.chokedcommands == 0 then
        aa.fakelag_switch = not aa.fakelag_switch
    end

    local exploit_on = ((ui_get(ref.doubletap[1]) and ui_get(ref.doubletap[2])) or (ui_get(ref.hideshot[1]) and ui_get(ref.hideshot[2]))) and not (ui_get(ref.fakeduck))
    aa.nochoke = false
    
    ui_set(ref.fakelag,false)
    ui_set(ref.fakelag_mode,"Maximum")
    ui_set(ref.fakelag_variance, 0)
    ui_set(ref.fakelag_limit,15)
    if not exploit_on then
        if contains(fakelag_disablers, "Shot") and weapon ~= nil and (curtime <= entity_get_prop(weapon, "m_fLastShotTime") + globals_tickinterval()*4+0.01) then
            aa.fakelag_limit = 1
            aa.nochoke = true
            ui_set(ref.sv_maxusrcmdprocessticks_holdaim,false)
        elseif contains(fakelag_disablers, "Standing") and state_idx == 2 then
            aa.fakelag_limit = 1
        elseif contains(fakelag_disablers, "Running") and state_idx == 3 then
            aa.fakelag_limit = 1
        elseif contains(fakelag_disablers, "Slow") and state_idx == 4 then
            aa.fakelag_limit = 1
        elseif contains(fakelag_disablers, "Ducking") and state_idx == 5 then
            aa.fakelag_limit = 1
        elseif contains(fakelag_disablers, "Duck Running") and state_idx == 6 then
            aa.fakelag_limit = 1
        elseif contains(fakelag_disablers, "Jumping") and state_idx == 7 then
            aa.fakelag_limit = 1
        elseif contains(fakelag_disablers, "Jump Duck") and state_idx == 8 then
            aa.fakelag_limit = 1
        else
            if fakelag_mode == "Maximum" then
                aa.fakelag_limit = ui_get(antiaim.fakelag_limit)
            elseif fakelag_mode == "Randomize" then
                aa.fakelag_limit = cmd.chokedcommands == 0 and math.random(1, ui_get(antiaim.fakelag_limit)) or aa.fakelag_limit
            elseif fakelag_mode == "Jitter" then
                aa.fakelag_limit = aa.fakelag_switch and ui_get(antiaim.fakelag_limit) or ui_get(antiaim.fakelag_limit2)
            elseif fakelag_mode == "Alternative" then
                if aa.alternative_switch then
                    aa.alternative_limit = 1
                    if aa.alternative_count >= ui_get(antiaim.fakelag_send) then
                        aa.alternative_count = 0
                        aa.alternative_switch = false
                    end
                else
                    aa.alternative_limit = ui_get(antiaim.fakelag_choke)
                    if aa.alternative_count >= ui_get(antiaim.fakelag_choke) then
                        aa.alternative_count = 0
                        aa.alternative_switch = true
                    end
                end
                aa.alternative_count = aa.alternative_count + 1
                aa.fakelag_limit = aa.alternative_limit
            end
        end
        if ui_get(ref.freestanding[1]) and ui_get(ref.freestanding[2]) then
            ui_set(ref.fakelag,true)
            ui_set(ref.fakelag_limit,aa.fakelag_limit)
        end
    end

    ui_set(ref.doubletap[3],"Defensive")
    local lag_exploit_on = false
    if contains(ui_get(misc.exploit_features), "Lag Exploit") then
        if contains(ui_get(misc.lag_exploit_settings), "Air Only") then
            if ui_get(misc.lag_exploit) and status.inair then
                lag_exploit_on = true
            end
        elseif ui_get(misc.lag_exploit) then
            lag_exploit_on = true
        end
    end
    if not data then return end
    aa.allow_bruteforce = contains(ui_get(antiaim.features), "Anti Bruteforce") and (not contains(ui_get(data.defensive_features), "Disable Anti Bruteforce"))
    aa.force_defensive = false
    local defensive_work = exploit_on and ((ui_get(data.defensive_pitch) ~= "Off") or (ui_get(data.defensive_yaw) ~= "Off")) and not lag_exploit_on
    if exploit_on then
        local breaklc_mode = ui_get(data.breaklc_mode)
        local breaklc_trigger = ui_get(data.breaklc_trigger)
        local unsafe = contains(ui_get(data.defensive_features), "Unsafe Defensive")
        local min = unsafe and 2 or 3
            if breaklc_trigger == "Always" then
                if breaklc_mode == "Skeet" then
                    aa.force_defensive = true
                else
                    aa.force_defensive = true
                    if defensive_work and aa.defensive_active then
                        aa.nochoke = (AbsTickBase == min) or (AbsTickBase == (min-1))
                    end
                end
            elseif breaklc_trigger == "On Peek" then
                if has_flag(threat, 'HIT') then
                    if breaklc_mode == "Skeet" then
                        aa.force_defensive = true
                    else
                        aa.force_defensive = true
                        if defensive_work and aa.defensive_active then
                            aa.nochoke = (AbsTickBase == min) or (AbsTickBase == (min-1))
                        end
                    end
                end
            end
        exploits:should_force_defensive(aa.force_defensive)
        aa.defensive_active = is_defensive_active(unsafe)
    else
        aa.defensive_active = false
    end

    local pitch = ui_get(data.pitch)
    local base = ui_get(data.base)

    local delay_mode = ui_get(data.delay_mode)
    local delay = ui_get(data.delay)
    local delay_features = ui_get(data.delay_features)
    local modifier_ignore_delay = contains(delay_features, "Modifier Ignore Delay")
    local defensive_ignore_delay = contains(delay_features, "Defensive Ignore Delay")
    local cstate = (especial and ("%s"):format(especial_state_idx + 10000)) or ("%s%s%s"):format(team_idx, state_advanced_idx, state_idx)

    local jitter_ = function ()
        aa.yaw_jitter_flip = not aa.yaw_jitter_flip
    end
    
    local modifier_ = function ()
        aa.yaw_modifier_flip = not aa.yaw_modifier_flip
        aa.yaw_way = math.max(aa.yaw_way, aa.yaw_way + 1)
        if ui_get(data.yaw_modifier_main) == 0 then
            aa.yaw_modifier = 0
        elseif ui_get(data.yaw_modifier) == "Center" then
            aa.yaw_modifier = aa.yaw_modifier_flip and ui_get(data.yaw_modifier_main) or -ui_get(data.yaw_modifier_main)
        elseif ui_get(data.yaw_modifier) == "Offset" then
            aa.yaw_modifier = aa.yaw_modifier_flip and ui_get(data.yaw_modifier_main) or 0
        elseif ui_get(data.yaw_modifier) == "Random" then
            aa.yaw_modifier = client_random_int(-ui_get(data.yaw_modifier_main), ui_get(data.yaw_modifier_main))
        elseif ui_get(data.yaw_modifier) == "Spin" then
            local spin_step = ui_get(data.spin_step)
            if spin_step == 0 then
                aa.yaw_modifier = 0
            else
                aa.yaw_spin_amount =  (aa.yaw_spin_amount + spin_step + ui_get(data.yaw_modifier_main)) % (ui_get(data.yaw_modifier_main)*2) - ui_get(data.yaw_modifier_main)
                
                local abs_value = math.abs(ui_get(data.yaw_modifier_main))
    
                if aa.yaw_spin_amount >= abs_value then
                    aa.yaw_spin_amount = -abs_value
                elseif aa.yaw_spin_amount <= -abs_value then
                    aa.yaw_spin_amount = abs_value
                end
    
                aa.yaw_modifier = aa.yaw_spin_amount
            end
        elseif ui_get(data.yaw_modifier) == "xWay" then
            local ways = ui_get(data.way)
            aa.yaw_way = aa.yaw_way % ways + 1
            aa.yaw_modifier = ui_get(data.yaw_modifier_main) * (2 * (aa.yaw_way - 1) / (ways - 1) - 1)
            -- local step = 2 * ui_get(data.yaw_modifier_main) / (ui_get(data.way) - 1)
    
            -- if aa.yaw_way > ui_get(data.way) then
            --     aa.yaw_way = 1
            -- end
            
            -- aa.yaw_modifier =  (aa.yaw_way - 1) * step -ui_get(data.yaw_modifier_main)
        end
    end
    
    local defensive_ = function ()
        aa.defensive_pitch_flip = not aa.defensive_pitch_flip
        aa.defensive_yaw_flip = not aa.defensive_yaw_flip
        if ui_get(data.defensive_pitch) == "Static" then
            aa.defensive_pitch = ui_get(data.defensive_pitch_main)
        elseif ui_get(data.defensive_pitch) == "Jitter" then
            aa.defensive_pitch = aa.defensive_pitch_flip and ui_get(data.defensive_pitch_main) or -ui_get(data.defensive_pitch_main)
        elseif ui_get(data.defensive_pitch) == "Randomize" then
            aa.defensive_pitch = client_random_int(-math.abs(ui_get(data.defensive_pitch_main)), math.abs(ui_get(data.defensive_pitch_main)))
        elseif ui_get(data.defensive_pitch) == "Spin" then
            local spin_step = ui_get(data.defensive_pitch_spin_step)
            if spin_step == 0 or (ui_get(data.defensive_pitch_main) == 0) then
                aa.defensive_pitch = 0
            else
                aa.defensive_pitch_spin_amount =  (aa.defensive_pitch_spin_amount + spin_step + ui_get(data.defensive_pitch_main)) % (ui_get(data.defensive_pitch_main)*2) - ui_get(data.defensive_pitch_main)
            
                local abs_value = math.abs(ui_get(data.defensive_pitch_main))
    
                if aa.defensive_pitch_spin_amount >= abs_value then
                    aa.defensive_pitch_spin_amount = -abs_value
                elseif aa.defensive_pitch_spin_amount <= -abs_value then
                    aa.defensive_pitch_spin_amount = abs_value
                end
                aa.defensive_pitch = aa.defensive_pitch_spin_amount
            end
        else
            aa.defensive_pitch = 0
        end

        if ui_get(data.defensive_yaw) == "Static" then
            aa.defensive_yaw = ui_get(data.defensive_yaw_main)
        elseif ui_get(data.defensive_yaw) == "Jitter" then
            aa.defensive_yaw = aa.defensive_yaw_flip and ui_get(data.defensive_yaw_main) or -ui_get(data.defensive_yaw_main)
        elseif ui_get(data.defensive_yaw) == "Randomize" then
            aa.defensive_yaw = client_random_int(-math.abs(ui_get(data.defensive_yaw_main)), math.abs(ui_get(data.defensive_yaw_main)))
        elseif ui_get(data.defensive_yaw) == "Spin" then
            local spin_step = ui_get(data.defensive_yaw_spin_step)
            if spin_step == 0 or (ui_get(data.defensive_yaw_main) == 0) then
                aa.defensive_yaw = 0
            else
                aa.defensive_yaw_spin_amount =  (aa.defensive_yaw_spin_amount + spin_step + ui_get(data.defensive_yaw_main)) % (ui_get(data.defensive_yaw_main)*2) - ui_get(data.defensive_yaw_main)
                local abs_value = math.abs(ui_get(data.defensive_yaw_main))
    
                if aa.defensive_yaw_spin_amount >= abs_value then
                    aa.defensive_yaw_spin_amount = -abs_value
                elseif aa.defensive_yaw_spin_amount <= -abs_value then
                    aa.defensive_yaw_spin_amount = abs_value
                end
    
                aa.defensive_yaw = aa.defensive_yaw_spin_amount
            end
        else
            aa.defensive_yaw = 0
        end
    end

    if delay_mode == "Static" then
        aa.delay_value = delay
    end
    if cmd.chokedcommands == 0 then
        aa.send_packet_commands = aa.send_packet_commands + 1
        if modifier_ignore_delay then
            modifier_()
        end
        if exploit_on and defensive_ignore_delay  then
            defensive_()
        end
    end
    if aa.send_packet_commands > aa.delay_value then
        aa.send_packet_commands = 0
        jitter_()
        if not modifier_ignore_delay then
            modifier_()
        end
        if exploit_on and not defensive_ignore_delay then
            defensive_()
        end
        if delay_mode == "Random" then
            aa.delay_value = client_random_int(0,delay)
        elseif delay_mode == "Adaptive" then
            if aa.delay_value > delay then
                aa.delay_value = delay
                aa.delay_switch = true
            else
                aa.delay_value = aa.delay_switch and aa.delay_value - 1 or aa.delay_value + 1
                if aa.delay_value <= 0 then
                    aa.delay_value = 0
                    aa.delay_switch = false
                end
            end
        elseif delay_mode == "Jitter" then
            if aa.delay_value == delay then
                aa.delay_value = 0
                aa.delay_switch = true
            elseif aa.delay_switch then
                aa.delay_value = 0
                aa.delay_switch = false
            else
                aa.delay_value = delay
            end
        end
    elseif aa.last_state ~= cstate then
        if delay_mode == "Random" then
            aa.delay_value = client_random_int(0,delay)
        elseif delay_mode == "Adaptive" then
            aa.delay_value = 0
        elseif delay_mode == "Jitter" then
            aa.delay_value = 0
        end
    end
    
    aa.last_state = cstate
    local yaw = 0
    if ui_get(data.yaw) == "Backward" then
        yaw = ui_get(data.offset_main)
    elseif ui_get(data.yaw) == "Jitter" then
        yaw = aa.yaw_jitter_flip and ui_get(data.offset_left) or ui_get(data.offset_right)
    end

    local final_yaw = normalize_yaw(yaw + aa.yaw_modifier + ((left and -90) or (right and 90) or (forward and 180) or 0))

    local safe_bodyyaw
    local fLastShotTime = entity_get_prop(weapon, "m_fLastShotTime")
    if contains(ui_get(antiaim.features), "Safe Head") and not (left or right or forward) then
        if status.inair then
            local crouch = status.crouch
            local teamnum = entity_get_prop(lp, "m_iTeamNum")
            local bait = (ui_get(antiaim.safehead_mode) == "Bait")

            if entity_get_classname(weapon) == "CKnife" then

                if teamnum == 2 then
                    if crouch then
                        if globals_curtime() < fLastShotTime + globals_tickinterval() * 50 then
                            final_yaw = -10
                            safe_bodyyaw = bait and -45 or 0
                        else
                            final_yaw = bait and 16 or -1
                            safe_bodyyaw = bait and -28 or 0
                        end
                    else
                        if curtime < fLastShotTime + globals_tickinterval() * 50 then
                            final_yaw = -10
                            safe_bodyyaw = bait and -50 or 0
                        else
                            final_yaw = bait and 5 or -11
                            safe_bodyyaw = bait and -28 or 0
                        end
                    end
                else
                    if crouch then
                        if curtime < fLastShotTime + globals_tickinterval() * 50 then
                            final_yaw = -8
                            safe_bodyyaw = bait and -50 or 0
                        else
                            final_yaw = bait and 21 or -1
                            safe_bodyyaw = bait and -28 or 0
                        end
                    else
                        if curtime < fLastShotTime + globals_tickinterval() * 50 then
                            final_yaw = -10
                            safe_bodyyaw = bait and -50 or 0
                        else
                            final_yaw = bait and 7 or -8
                            safe_bodyyaw = bait and -28 or 0
                        end
                    end
                end
            end
    
            if entity_get_classname(weapon) == "CWeaponTaser" then
                if teamnum == 2 then --t
                    if crouch then
                        final_yaw = bait and 2 or 5
                        safe_bodyyaw = bait and -26 or -1
                    else
                        final_yaw = bait and 3 or -1
                        safe_bodyyaw = bait and -19 or 0
                    end
                else  --ct
                    if crouch then
                        final_yaw = bait and -6 or 1
                        safe_bodyyaw = bait and -26 or 5
                    else
                        final_yaw = bait and 2 or 0
                        safe_bodyyaw = bait and -19 or 0
                    end
                end
            end
    
            if contains(Nades,entity_get_classname(weapon)) then
                if teamnum == 2 then
                    if crouch then
                        final_yaw = bait and 0 or -2
                        safe_bodyyaw = bait and -19 or 0
                    else
                        final_yaw = bait and 3 or -2
                        safe_bodyyaw = bait and -19 or 0
                    end
                else
                    if crouch then
                        final_yaw = bait and -2 or -1
                        safe_bodyyaw = bait and -19 or 0
                    else
                        final_yaw = bait and 2 or -2
                        safe_bodyyaw = bait and -19 or 0
                    end
                end
            end

        end
    end


    local real_yaw = final_yaw
    -- ensure
    ui_set(ref.pitch[1], "Custom")
    ui_set(ref.pitch[2], pitch)
    ui_set(ref.yaw_base, base)
    ui_set(ref.yaw[1], "180")
    ui_set(ref.yaw[2], final_yaw)
    ui_set(ref.yaw_jitter[1], "Off")
    ui_set(ref.yaw_jitter[2], 0)

    -- if not (AbsTickBase > 1 and exploit_on and AbsTickBase <= 24) then
    --     print(("X %s %s %s"):format(AbsTickBase,MaxTickBase,tickbase))
    -- else
    --     print(("✔ %s %s %s"):format(AbsTickBase,MaxTickBase,tickbase))
    -- end
    local ignore_yaw = contains(ui_get(data.defensive_features), "Defensive Ignore Yaw")
    local nochoke_defensive = contains(ui_get(data.defensive_features), "Nochoke Defensive")
    if aa.defensive_active and defensive_work and not (ui_get(ref.hideshot[1]) and ui_get(ref.hideshot[2]) and not (ui_get(ref.doubletap[1]) and ui_get(ref.doubletap[2]))and ((not aa.force_defensive) or curtime <= fLastShotTime + globals_tickinterval()+0.01)) then

        if nochoke_defensive then
            aa.nochoke = true
        end

        if aa.defensive_pitch then
            ui_set(ref.pitch[2], aa.defensive_pitch)
        end
        if aa.defensive_yaw then
            real_yaw = normalize_yaw(aa.defensive_yaw+(ignore_yaw and 0 or final_yaw))
            ui_set(ref.yaw[2], real_yaw)
        end
    end
    --bodyyaw
    if aa.backstab then
        final_yaw = 180
        real_yaw = 180
    end

    if inuse_aa then
        final_yaw = 0
        real_yaw = 0
        ui_set(ref.yaw_base, "Local View")
    end

                
    local bodyyaw = 0
    if safe_bodyyaw then
        bodyyaw = safe_bodyyaw
        if bodyyaw == 0 then
            ui_set(ref.bodyyaw[1], "Static")
            ui_set(ref.bodyyaw[2], 0)
            ui_set(ref.fakelag,true)
            ui_set(ref.fakelag_limit,aa.fakelag_limit)
            return
        end
    else
        if ui_get(data.bodyyaw) == "Static" then
            bodyyaw = ui_get(data.bodyyaw_main)
            if bodyyaw == 0 then
                ui_set(ref.bodyyaw[1], "Static")
                ui_set(ref.bodyyaw[2], 0)
                ui_set(ref.fakelag,true)
                ui_set(ref.fakelag_limit,aa.fakelag_limit)
                return
            end
        elseif ui_get(data.bodyyaw) == "Jitter" then
            if ui_get(data.bodyyaw_left) == 0 and ui_get(data.bodyyaw_right) == 0 then
                ui_set(ref.bodyyaw[1], "Static")
                ui_set(ref.bodyyaw[2], 0)
                ui_set(ref.fakelag,true)
                ui_set(ref.fakelag_limit,aa.fakelag_limit)
                return
            end
            bodyyaw = aa.yaw_jitter_flip and ui_get(data.bodyyaw_left) or ui_get(data.bodyyaw_right)
        elseif ui_get(data.bodyyaw) == "Automatic" then
            if ui_get(data.bodyyaw_left) == 0 and ui_get(data.bodyyaw_right) == 0 then
                ui_set(ref.bodyyaw[1], "Static")
                ui_set(ref.bodyyaw[2], 0)
                ui_set(ref.fakelag,true)
                ui_set(ref.fakelag_limit,aa.fakelag_limit)
                return
            end
            bodyyaw = (final_yaw == 0 and 0) or (final_yaw < 0 and ui_get(data.bodyyaw_left)) or ui_get(data.bodyyaw_right)
        end
    end

    if aa.allow_bruteforce and anti_bruteforce(threat) then
        if aa.bruteforce_enemy[threat].value ~= 666 then
            if bodyyaw < 0 then
                bodyyaw = -aa.bruteforce_enemy[threat].value
            else
                bodyyaw = aa.bruteforce_enemy[threat].value
            end
        elseif aa.bruteforce_enemy[threat].invert then
            bodyyaw = -bodyyaw
        end
    end

    cmd.allow_send_packet = true
    cmd.no_choke = aa.nochoke

    local sv_maxusrcmdprocessticks = ui_get(ref.sv_maxusrcmdprocessticks)
    local fakelag_limit = aa.fakelag_limit


    
    if (ui_get(ref.freestanding[1]) and ui_get(ref.freestanding[2])) and not (left or right or forward) and not (freestanding_yaw == 666) then --freestanding bodyyaw fix
        if curtime <= fLastShotTime + globals_tickinterval()*3+0.01 then
            aa.last_freestanding_back_time = curtime
        end
        if aa.freestand_extend > 0 then
            ui_set(ref.bodyyaw[1], "Static")
            ui_set(ref.bodyyaw[2], 60)
            aa.freestand_extend = aa.freestand_extend - 1
            goto ennd
        end
        if cmd.chokedcommands == 1 and math_abs(freestanding_yaw - real_yaw) > 10 then
            aa.last_freestanding_time = curtime
            aa.last_freestanding_yaw = freestanding_yaw
            ui_set(ref.bodyyaw[1], "Static")
            ui_set(ref.bodyyaw[2], 60)
            aa.freestand_extend = 7
            goto ennd
        end
    end

    if curtime <= aa.last_freestanding_time + globals_tickinterval()*6+0.01 then
        if curtime <= fLastShotTime + globals_tickinterval()*3+0.01 then
            aa.last_freestanding_back_time = curtime
        end
    end

    if curtime <= aa.last_freestanding_back_time + globals_tickinterval()*6+0.01 then
        ui_set(ref.yaw[2], aa.last_freestanding_yaw)
        ui_set(ref.bodyyaw[1], "Static")
        ui_set(ref.bodyyaw[2], 60)
        goto ennd
    end

    ui_set(ref.bodyyaw[1], "Off")
    ui_set(ref.bodyyaw[2], 0)

    if curtime - shifted_time < globals_tickinterval() * (sv_maxusrcmdprocessticks < 18 and sv_maxusrcmdprocessticks or 18) then
        bodyyaw = 0
        -- goto ennd
    end
    -- if curtime - fakelag_flip_time < globals_tickinterval() * 3 then
    --     cmd.allow_send_packet = true
    --     cmd.no_choke = true
    --     goto ennd
    -- end
    if not aa.nochoke then
        if exploit_on or (fakelag_limit == 1) then
            if cmd.chokedcommands == 0 then
                cmd.allow_send_packet = false
                cmd.no_choke = false

                ui_set(ref.yaw[2], normalize_yaw(final_yaw+(bodyyaw*2)))
            end
        else
            if cmd.chokedcommands < fakelag_limit and not (cmd.chokedcommands >= (sv_maxusrcmdprocessticks < 18 and (sv_maxusrcmdprocessticks - 2) or 16)) then
                cmd.allow_send_packet = false
                cmd.no_choke = false
                ui_set(ref.yaw[2], normalize_yaw(final_yaw+(bodyyaw*2)))
            end
        end
    end

    ::ennd::

    -- MaxAbsTickbase_check()
    -- if not aa.checking then
    --     if weapon and entity_is_alive(lp) and exploit_on and (aa.force_defensive == true) and not contains(Nades,entity_get_classname(weapon)) and not (bit_band(entity_get_prop(weapon, "m_iItemDefinitionIndex"), 0xFFFF) == 64) then
    --         aa.checking = true
    --         client_delay_call(5,function ()
    --             local weapon = entity_get_player_weapon(entity_get_local_player())
    --             if not weapon then aa.check_cancel = 0 aa.checking = false return end
    --             if entity_is_alive(lp) and exploit_on and (aa.force_defensive == true) and not contains(Nades,entity_get_classname(weapon)) and not (bit_band(entity_get_prop(weapon, "m_iItemDefinitionIndex"), 0xFFFF) == 64) then
    --                 if not (aa.check_cancel > 64) and (MaxAbsTickbase == 13 or MaxAbsTickbase == 14) then
    --                     aa.maxtickbase_normal = true
    --                 else
    --                     aa.maxtickbase_normal = false
    --                 end
    --                 aa.check_cancel = 0
    --             end
    --             aa.checking = false
    --         end)
    --     else
    --         aa.check_cancel = aa.check_cancel + 1
    --     end
    -- elseif weapon then
    --     if not(entity_is_alive(lp) and exploit_on and (aa.force_defensive == true) and not contains(Nades,entity_get_classname(weapon)) and not (bit_band(entity_get_prop(weapon, "m_iItemDefinitionIndex"), 0xFFFF) == 64)) then
    --         aa.check_cancel = aa.check_cancel + 1
    --     end
    -- end
end

local anti_backstab = function ()
    if not contains(ui_get(antiaim.features), "Anti Backstab") then aa.backstab = false return end
    local backstab_ = false
    local enemies = entity_get_players(true)
    local local_origin = vector(entity_get_origin(entity_get_local_player()))
    for i = 1, #enemies do
        local enemy_origin = vector(entity_get_origin(enemies[i]))
        local distance = local_origin:dist(enemy_origin)
        local weapon = entity_get_player_weapon(enemies[i])
        local class = entity_get_classname(weapon) -- we get enemy's weapon here
        if distance < 200 and class == "CKnife" then
            backstab_ = true
            ui_set(ref.yaw[2], 180)
        end
    end
    aa.backstab = backstab_
end

ladder_start = false
fast_ladder = function(cmd)

    if not contains(ui_get(antiaim.features), "Fast Ladder") then   
        return 
    end

    if ui_get(antiaim.fastladder_mode) == "Wait Choke" then
        local exploit_on = ((ui_get(ref.doubletap[1]) and ui_get(ref.doubletap[2])) or (ui_get(ref.hideshot[1]) and ui_get(ref.hideshot[2]))) and not (ui_get(ref.fakeduck))
        if not ui_get(ref.fakelag) and not exploit_on then
            if cmd.allow_send_packet then
                return
            end
        end
    end
    
    local lp = entity_get_local_player()
    local m_MoveType = entity_get_prop(lp, "m_MoveType")

    if m_MoveType ~= 9 or cmd.forwardmove == 0 then
        ladder_start = false

        return
    end

    if ladder_start == false then
        ladder_start = true
    else
        local pitch, yaw = client_camera_angles()
        local up = cmd.forwardmove < 0 or pitch > 45

        cmd.in_moveleft, cmd.in_moveright = up and 1 or 0, not up and 1 or 0
        cmd.in_forward, cmd.in_back = up and 1 or 0, not up and 1 or 0
        cmd.pitch, cmd.yaw = 89, normalize_yaw(cmd.move_yaw + 90)
    end

end

switch_move = false
micromove = function (cmd)
    local lp = entity_get_local_player()
    local speed = 1.01

    if status.velocity > 3 then
        return
    end

    if status.crouch or ui_get(ref.fakeduck) then
        speed = speed * 2.94117647
    end

    switch_move = switch_move or false

    if switch_move then
        cmd.sidemove = cmd.sidemove + speed
    else
        cmd.sidemove = cmd.sidemove - speed
    end

    switch_move = not switch_move
end

predict_velocity = {}
jumpscout = function (cmd, lp, weapon)

    if status.on_ground then
        return
    end

    local settings = ui_get(rage.jumpscout_settings)
    if not contains(settings, "Allow Jump Duck") and status.crouch then
        return
    end

    if entity_get_classname(weapon)  ~= "CWeaponSSG08" then
        return
    end

    if not entity_can_fire(lp) or not weapon_can_fire(weapon) then
        return
    end

    local threat = client_current_threat()

    if not threat or entity_is_dormant(threat) then
        return
    end

    local origin = vector(entity_get_origin(lp))
    local pos = vector(entity_get_origin(threat))

    local distance = pos:dist(origin)
    local max_distance = ui_get(rage.jumpscout_distance)

    if max_distance ~= 0 and distance > max_distance then
        return
    end

    local velocity = vector(entity_get_prop(lp, 'm_vecVelocity'))
    local calculate = velocity.z / (sv_gravity:get_float() * globals_tickinterval())
    if not (calculate < (status.crouch and 14 or 6) and calculate > 0) then
        return
    end
    local health = entity_get_prop(threat, 'm_iHealth')
    local mindmg = (ui_get(ref.mindmg_override[1]) and ui_get(ref.mindmg_override[2])) and ui_get(ref.mindmg_override[3]) or ui_get(ref.mindmg)
    if mindmg > 100 then
        mindmg = health + (mindmg - 100)
    else
        mindmg = math.min(mindmg, health)
    end

    local damage_math = 0
    for h = 0, 17 do
        local hitscan = vector(entity_hitbox_position(threat, h))

        if hitscan ~= nil then
            local origin = vector(client_eye_position(lp))
            local index,damage = client_trace_bullet(lp,origin.x,origin.y,origin.z,hitscan.x,hitscan.y,hitscan.z,false)
            if index then
                damage = client_scale_damage(index, h, damage)
                damage_math = math.max(damage,damage_math)
            end
        end
    end

    if damage_math < mindmg then
        return
    end

    local scoped = entity_get_prop(lp, 'm_bIsScoped') ~= 0
    if not scoped then
        cmd.in_attack2 = 1
    end

    local data = csgo_weapons(weapon)
    local max_speed = scoped and data.max_player_speed_alt or data.max_player_speed
    max_speed = max_speed * 0.34


    local speed = predict_velocity:length2d();

    if max_speed ~= nil and speed < max_speed then
        return
    end

    local direction = vector(velocity:angles());
    local real_view = vector(client_camera_angles());
    local modifier = status.crouch and 2.94117647 or 1
    direction.y = real_view.y - direction.y;
    local forward = vector(angle_to_forward(direction.x, direction.y));

    local negative_side_move = -cl_sidespeed:get_float() * modifier;
    local negative_direction = negative_side_move * forward;
    cmd.in_speed = 1;

    cmd.forwardmove = cmd.forwardmove +negative_direction.x;
    cmd.sidemove =  cmd.forwardmove +negative_direction.y;

end

nospread_restore = false
restroe_nospread = function ()
    if nospread_restore then
        weapon_accuracy_nospread:set_int(1)
        nospread_restore = false
        local enemies = entity_get_players(true)
        for i = 1, #enemies do
            plist_set(enemies[i], "High priority", false)
        end
    end
end
revolver_improvements = function (lp, weapon)
    if not (bit_band(entity_get_prop(weapon, "m_iItemDefinitionIndex"), 0xFFFF) == 64) then
        restroe_nospread()
        return
    end
    local second = ui_get(rage.revolver_force_second_fire)
    local enemies = entity_get_players(true)
    local local_origin = vector(entity_get_origin(lp))
    local distances = {}
    for i = 1, #enemies do
        local enemy_origin = vector(entity_get_origin(enemies[i]))
        plist_set(enemies[i], "High priority", false)
        distances[i] = {}
        distances[i][1] = local_origin:dist(enemy_origin)
        distances[i][2] = enemies[i]
    end
    local min_value = math.huge
    local min_index = -1

    for i = 1, #distances do
        if distances[i][1] < min_value then
            min_value = distances[i][1]
            min_index = i
        end
    end

    if min_index ~= -1 then
        if min_value > ui_get(rage.revolver_second_fire_distance) then
            restroe_nospread()
            return
        end
        if second then
            nospread_restore = true
            weapon_accuracy_nospread:set_int(0)
        else
            restroe_nospread()
        end
        plist_set(distances[min_index][2], "High priority", true)
    else
        restroe_nospread()
        return
    end

end

get_closest_player = function(pos, distance)
	local ent_
	local origin
	local enemies = entity_get_players(true)

	for i = 1, #enemies do
		local ent = enemies[i]
		local eorigin = vector(entity_get_origin(ent))
		local dis = eorigin:distsqr(pos)

		if dis < distance and not plist_get(ent, "Add to whitelist") then
			distance = dis
			ent_ = ent
			origin = eorigin
		end
	end

	return ent_, origin
end
last_magnet_origin = {}
magnet_melee = function(cmd, lp, weapon)
    if not ui_get(rage.magnet_key) then
        return
    end
    local classname = entity_get_classname(weapon)
    if classname ~= "CKnife" and classname ~= "CWeaponTaser"then
        return
    end
	local eyepos = vector(client_eye_position())
	local ent, origin = get_closest_player(eyepos, classname == "CKnife" and 50000 or 90000)

	if ent then
		local fraction, index = client_trace_line(lp, eyepos.x, eyepos.y, eyepos.z, origin.x, origin.y, origin.z)

		if fraction >= 1 or index == ent then
            last_magnet_origin = origin
			local pitch, yaw = eyepos:to(origin):angles()
			cmd.move_yaw = yaw
			cmd.forwardmove = 450

		end
	end
end

local handle_ragebot = function (cmd)
    last_magnet_origin = {}
    if not ui_get(master_switch) then return end

    local lp = entity_get_local_player()
    if not lp or not entity_is_alive(lp) then
       return
    end

    local weapon = entity_get_player_weapon(lp)

    if not weapon then
        return
    end

    local ragefuncs = ui_get(rage.main)

    if contains(ragefuncs, "Strafe Fix") then
        if status.inair and status.velocity < 5 then
            ui_set(ref.airstrafe, false)
        else
            ui_set(ref.airstrafe, true)
        end
    end

    if contains(ragefuncs, "Jump Scout") then
        jumpscout(cmd, lp, weapon)
    end

    if contains(ragefuncs, "Revolver Improvements") then
        revolver_improvements(lp, weapon)
    else
        restroe_nospread()
    end

    if contains(ragefuncs, "Magnet Melee") then
        magnet_melee(cmd, lp, weapon)
    end

    if contains(ragefuncs, "Friendly Fire") then
        mp_teammates_are_enemies:set_int(ui_get(rage.friendly_fire) and 1 or 0)
    end
end

clantags = {
    "×0|2",
    "☒øℜ",
    "ⅩОℛ",
    "✗◯Я",
    "X口℟",
    "ℵ⒪℟",
    "ℵÖℝ",
    "乂口尺",
    "><()|>",
    "10-0-12",
}
clantag_counter = 0
clantag_last_tick = 0
clantag = function ()
    if not ui_get(misc.clantag) then
        if not ui_get(ref.clantag) and globals_servertickcount() % 26 == 0 then client_set_clan_tag("") end
        return
    end
    ui_set(ref.clantag, false)
    local tickcount = globals_servertickcount()
    if tickcount ~= clantag_last_tick then
        for i = #clantags , 1, -1 do
            if tickcount % (30*i) == 0 then
                clantag_counter = i
                client_set_clan_tag(clantags[clantag_counter])
                clantag_last_tick = tickcount
                goto endd
            end
        end
        ::endd::
    end
end

force_charge_wait_tick = 0
hideshot_peek_wait_tick = 0
discharge_wait_tick = 0
lag_exploiting = false
visible_tick = 0
last_AbsTickBase = 0
local handle_exploit = function (cmd)
    local lp = entity_get_local_player()
    local threat = client_current_threat()
    local weapon = entity_get_player_weapon(lp)
    local weapon_name = entity_get_classname(weapon)
    local _, _, state_idx, _ = get_status()
    local tickcount = globals_tickcount()
    local curtime = globals_curtime()

    if contains(ui_get(misc.exploit_features), "Force Charge") then
        if not (ui_get(ref.doubletap[1]) and ui_get(ref.doubletap[2])) then
            ui_set(ref.aimbot, true)
        else
            local m_nTickBase = entity_get_prop(lp, 'm_nTickBase')
            local latency = client_latency()
            local shift = math.floor(m_nTickBase - tickcount - 3 - toticks(latency) * .5 + .5 * (latency * 10))
            local wanted = -14 + (ui_get(ref.doubletap_fakelag) - 1) + 3 --error margin

            local dt_charged = shift <= wanted
            if weapon_name == "CKnife" and has_flag(threat, 'HIT') then
                local local_origin = vector(entity_get_origin(lp))
                local enemies = entity_get_players(true)
                for i = 1, #enemies do
                    local enemy_origin = vector(entity_get_origin(enemies[i]))
                    local distance = local_origin:dist(enemy_origin)
                    if distance < 100 then
                        ui_set(ref.aimbot, true)
                        goto breakk
                    end
                end
            end
            if not dt_charged and threat and status.inair and has_flag(threat, 'HIT') then
                if curtime >= entity_get_prop(weapon, "m_flNextPrimaryAttack") and force_charge_wait_tick == 0 then
                    force_charge_wait_tick = tickcount + 2
                end
                if tickcount >= force_charge_wait_tick then
                    ui_set(ref.aimbot, false)
                    force_charge_wait_tick = 0
                else
                    ui_set(ref.aimbot, true)
                end
            else
                ui_set(ref.aimbot, true)
            end
        end
    else
        ui_set(ref.aimbot, true)
    end
    ::breakk::
    ui_set(ref.doubletap[1], true)
    ui_set(ref.hideshot[2], "Toggle")

    if contains(ui_get(misc.exploit_features), "Auto Hideshot") then
        if ui_get(ref.doubletap[2]) and not ui_get(ref.fakeduck) then
            if contains(ui_get(misc.auto_hideshot_disablers), "Knife") then
                if weapon_name == "CKnife" then
                    goto ennd
                end
            end
            if contains(ui_get(misc.auto_hideshot_disablers), "Pistols") then
                if contains(Pistol, weapon_name) then
                    goto ennd
                end
            end
            if contains(ui_get(misc.auto_hideshot_disablers), "Auto Snipers") then
                if contains(AutoSniper, weapon_name) then
                    goto ennd
                end
            end
            if contains(ui_get(misc.auto_hideshot_disablers), "Heavy Pistols") then
                if weapon_name == "CDEagle" then
                    goto ennd
                end
            end
            if contains(ui_get(misc.auto_hideshot_disablers), "Rifles") then
                if contains(Rifle, weapon_name) then
                    goto ennd
                end
            end

            if (state_idx == 5 or state_idx == 6 or state_idx == 2 or state_idx == 4) then
                ui_set(ref.doubletap[1], false)
                ui_set(ref.hideshot[1], true)
                ui_set(ref.hideshot[2], "Always on")
            end
            ::ennd::
        end
    end

    if contains(ui_get(misc.exploit_features), "Hideshot Peek") and (ui_get(ref.quick_peek[1]) and ui_get(ref.quick_peek[2])) and state_idx ~= 5 and state_idx ~= 2 then 
        local lp = entity_get_local_player()
        local weapon = entity_get_player_weapon(lp)
        local fLastShotTime = entity_get_prop(weapon, "m_fLastShotTime", 0)
        if weapon ~= nil and (curtime > fLastShotTime + globals_tickinterval() * 1) and (curtime < fLastShotTime + globals_tickinterval() * 3) and not contains(Nades, entity_get_classname(weapon)) then
            hideshot_peek_wait_tick = tickcount + 20
        end
        ui_set(ref.hideshot[1], tickcount >= hideshot_peek_wait_tick)
    else
        ui_set(ref.hideshot[1], true)
    end

    if contains(ui_get(misc.exploit_features), "Auto Discharge") then
        local threshold = 0
        local key = ui_get(misc.auto_discharge_key)
        if key then
            if ui_get(misc.auto_discharge_mode) == "Offensive" then
                threshold = 0
            else
                threshold = (visible_tick == 1 and 12) or (visible_tick >= 2 and 11) or 13
                if aa.maxtickbase_normal then
                    threshold = threshold - 2
                end
            end
        end
        if tickcount < discharge_wait_tick then
            ui_set(ref.doubletap[1], false)
        end
        if key then
            local hit = has_flag(threat, 'HIT')
            if hit then
                visible_tick = visible_tick + 1
            else
                visible_tick = 0
            end
            if hit and AbsTickBase >= threshold and tickcount > discharge_wait_tick then
                indicators.auto_discharge = true
                discharge_wait_tick = tickcount + 24
                ui_set(ref.doubletap[1], false)
                ui_set(ref.hideshot[1], false)
            else
                indicators.auto_discharge = tickcount < discharge_wait_tick
            end
        else
            visible_tick = 0
            indicators.auto_discharge = false
        end
    else
        indicators.auto_discharge = false
    end

    if contains(ui_get(misc.exploit_features), "Lag Exploit") then
        local settings = ui_get(misc.lag_exploit_settings)
        local threshold = 0
        local key = ui_get(misc.lag_exploit)
        if key then
            cmd.force_defensive = true
        end
        if contains(settings, "Maximum Teleport") and key then
            threshold = lag_exploiting and 0 or (aa.maxtickbase_normal and 13 or 13)
        else
            threshold = lag_exploiting and 0 or 12
        end
        if contains(settings, "Air Only") and key and status.inair and ui_get(ref.doubletap[2]) then
            ui_set(ref.aimbot, false)
            ui_set(ref.doubletap[1], true)
            ui_set(ref.hideshot[1], true)
            if AbsTickBase >= threshold and (last_AbsTickBase ~= AbsTickBase) then
                last_AbsTickBase = AbsTickBase
                lag_wait = true
                lag_exploiting = true
                ui_set(ref.aimbot, true)
                ui_set(ref.doubletap[1], false)
                ui_set(ref.hideshot[1], false)
            end
        elseif not contains(settings, "Air Only") and key and ui_get(ref.doubletap[2]) then
            ui_set(ref.aimbot, false)
            ui_set(ref.doubletap[1], true)
            ui_set(ref.hideshot[1], true)
            if AbsTickBase >= threshold and (last_AbsTickBase ~= AbsTickBase) then
                last_AbsTickBase = AbsTickBase
                lag_exploiting = true
                ui_set(ref.aimbot, true)
                ui_set(ref.doubletap[1], false)
                ui_set(ref.hideshot[1], false)
            end
        else
            lag_exploiting = false
        end
    else
        lag_exploiting = false
    end
end

rotate_point = function(x, y, rot, size)
    return math.cos(math.rad(rot)) * size + x, math.sin(math.rad(rot)) * size + y end

local render = {
    
    outline = function(x, y, w, h, t, r, g, b, a)
        renderer_rectangle(x, y, w, t, r, g, b, a)
        renderer_rectangle(x, y, t, h, r, g, b, a)
        renderer_rectangle(x, y+h-t, w, t, r, g, b, a)
        renderer_rectangle(x+w-t, y, t, h, r, g, b, a)
    end,

    gradient_text = function(r1, g1, b1, a1, r2, g2, b2, a2, text)
        local output = ''
    
        local len = #text-1
    
        local rinc = (r2 - r1) / len
        local ginc = (g2 - g1) / len
        local binc = (b2 - b1) / len
        local ainc = (a2 - a1) / len
    
        for i=1, len+1 do
            output = output .. ('\a%02x%02x%02x%02x%s'):format(r1, g1, b1, a1, text:sub(i, i))
    
            r1 = r1 + rinc
    
            g1 = g1 + ginc
            b1 = b1 + binc
            a1 = a1 + ainc
        end
    
        return output
    end,

    arrow =  function(x, y, r, g, b, a, rotation, size)
        local x0, y0 = rotate_point(x, y, rotation, 45)
        local x1, y1 = rotate_point(x, y, rotation + (size / 3.5), 45 - (size / 4))
        local x2, y2 = rotate_point(x, y, rotation - (size / 3.5), 45 - (size / 4))
        renderer_triangle(x0, y0, x1, y1, x2, y2, r, g, b, a)
    end,

    draw_circle_3d = function(x, y, z, radius, degrees, start_at, r, g, b, a , ctx, lineNum)
        if ctx == false then return end
        local accuracy = 10/10
        local old = { x, y }
    
        for rot=start_at, degrees+start_at, accuracy do
            local rot_t = math.rad(rot)
            local line_ = vector(radius * math.cos(rot_t) + x, radius * math.sin(rot_t) + y, z)
            local current = { x, y }
            current.x, current.y = renderer_world_to_screen(line_.x, line_.y, line_.z)
            if current.x ~=nil and old.x ~= nil then
                draw_line(current.x, current.y, old.x, old.y, r, g, b, a)
                --m_render_engine.render_glow_line(current.x, current.y, old.x, old.y, r, g, b, a, r, g, b, 10)
            end
            old.x, old.y = current.x, current.y
        end
    end,

    lerp = function(start, vend, time)
    return start + (vend - start) * (time * globals_frametime()) end,

}

local ind = {
    offset = {0, 0, 0},
    left = {0, 0, 0},
    right = {0, 0, 0},
    length = 0,
    left_offset = {4, 255, 0},
    right_offset = {-4, 0, 255},
    offset_final = {0, 0, 0},
    ----------------------------
    offsets = {0, 0, 0, 0, 0, 0},
    alpha = {0, 0, 0, 0, 0, 0},
    exp = {0, 0, 0, 0, 0, 0},
    exp_cache = {0, 0, 0, 0, 0, 0},
    text = {"PEEK", "BAIM", "SAFE", "DT", "HS", "FD"},
    line = {0, 0},
    ----------------------------
    manual_left = {0, 0},
    manual_right = {0, 0}
}
desync = 0
local main_indicator = function ()
    local settings = ui_get(visuals.main_indicator_settings)
    local screen_size = {client_screen_size()}
    -->> States Overlap/Desync
    desync = math.abs(antiaim_funcs.get_desync(1)) or 0
    -->> Import Color Config
    local custom_colors = contains(settings, "Custom colors")
    local color_settings = visuals.main_indicator_colors

    local l_r, l_g, l_b, left_a
    local l_ar, l_ag, l_ab, right_a
    local r_a, r_g, r_b, l_aa
    local r_ar, r_ag, r_ab, right_aa
    if custom_colors then
        l_r, l_g, l_b, left_a = ui_get(color_settings.left)
        l_ar, l_ag, l_ab, right_a = ui_get(color_settings.right)
    
        r_a, r_g, r_b, l_aa =  ui_get(color_settings.left_alt)
        r_ar, r_ag, r_ab, right_aa = ui_get(color_settings.right_alt)
    else
        l_r, l_g, l_b, left_a = 154, 226, 250, 255
        l_ar, l_ag, l_ab, right_a = 109, 213, 250, 255
    
        r_a, r_g, r_b, l_aa = 255, 255, 255, 220
        r_ar, r_ag, r_ab, right_aa = 253, 163, 180, 220
    end

    -->> State Customize Options
    local Nametag = contains(settings, "Custom NameTag")

    local colors = {
        left = {l_r, l_g, l_b},
        right = {l_ar, l_ag, l_ab},
        left_alt = {r_a, r_g, r_b},
        right_alt = {r_ar, r_ag, r_ab},
    }
    
    -->> Handling Indicator offset
    for i = 1, #ind.offset do
        if desync >= 30 then
            ind.offset[i] = render.lerp(ind.offset[i], ind.left_offset[i], 6)
        else 
            if desync <= 30 then
                ind.offset[i] = render.lerp(ind.offset[i], ind.right_offset[i], 6)
            else
                ind.offset[i] = render.lerp(ind.offset[i], ind.offset_final[i], 6)
            end
        end
    end

    local center_x, center_y = screen_size[1] / 2 + ind.offset[1], screen_size[2] / 2 

    -->> Handling Overlap offset
    for i = 1, 3 do
        ind.left[i] = render.lerp(ind.left[i], (desync > 30 and colors.left[i]) or colors.left_alt[i], 6)
        ind.right[i] = render.lerp(ind.right[i], (desync > 30 and colors.right[i]) or colors.right_alt[i], 6)
    end
    
    -->> Rendering Main Text
    local main = render.gradient_text(ind.left[1], ind.left[2], ind.left[3], 255, 
                                    ind.right[1], ind.right[2], ind.right[3], 255, 
                                    Nametag and ui_get(visuals.main_indicator_name_tag) or script.name)

    renderer_text(center_x + 3, center_y + 35, 255, 255, 255, 255, "cb", nil, main)

    -->> Rendering Overlap Bar
    local length = math.floor(desync)

    ind.length = render.lerp(ind.length, length, 6)

    -- Background Bar
    renderer_rectangle(center_x + 4 - 30, center_y + 42, 55, 3, 17, 17, 17, 190)

    -- Colorful bar
    renderer_gradient(center_x + 3 - 30, center_y + 42, ind.length, 3, 
                        ind.left[1], ind.left[2], ind.left[3], 255, 
                        ind.right[1], ind.right[2], ind.right[3], 255, true)


    -->> Rendering Overlap Text
    local text2 = render.gradient_text(ind.left[1], ind.left[2], ind.left[3], 
                                        (desync < 30 and 255) or 230,
                                        ind.right[1], ind.right[2], ind.right[3], 
                                        (desync < 30 and 255) or 150, 
                                        "LAP                               FAKE")
    renderer_text(center_x - 31, center_y + 45, 255, 255, 255, 255, "-", nil, text2)

    -->> Rendering Arrows

    -- Left
    render.arrow(center_x + 12, center_y + 36 + 8, ind.left[1], ind.left[2], ind.left[3], math.floor(ind.offset[3]), 180, 13)
    -- Right 
    render.arrow(center_x - 9, center_y + 36 + 8, ind.right[1], ind.right[2], ind.right[3], math.floor(ind.offset[2]), 361, 13)
    
    if not contains(settings, "Disable Keybinds") then
        local pk = ui_get(ref.quick_peek[1]) and ui_get(ref.quick_peek[2])
        local fb = ui_get(ref.force_bodyaim)
        local sp = ui_get(ref.force_safepoint)
        local dt = ui_get(ref.doubletap[1]) and ui_get(ref.doubletap[2])
        local os = ui_get(ref.hideshot[1]) and ui_get(ref.hideshot[2])
        local fd = ui_get(ref.fakeduck)
    
        local keybind ={
            key = {pk, fb, sp, dt, os, fd}
        }
    
        local line_offset = 0
        for i = 1, #keybind.key, 1 do
            ind.offsets[i] = render.lerp(ind.offsets[i], keybind.key[i] and 80 or 0 , 6)
            ind.alpha[i] = render.lerp(ind.alpha[i], keybind.key[i] and 255 or 0 , 6)
            ind.exp[i] = render.lerp(ind.exp[i], keybind.key[i] and 10 or 0 , 6)
            
            ind.exp_cache[i] =  (i == 1 and 0) or 
                                (i == 2 and ind.exp[1]) or 
                                (i == 3 and ind.exp[2] + ind.exp[1]) or 
                                (i == 4 and ind.exp[3] + ind.exp[2] + ind.exp[1]) or 
                                (i == 5 and ind.exp[4] + ind.exp[3] + ind.exp[2] + ind.exp[1]) or
                                (i == 6 and ind.exp[5] + ind.exp[4] + ind.exp[3] + ind.exp[2] + ind.exp[1])
    
            renderer_text(center_x + 3 + 60 + 4, center_y + 20 + 80 - ind.offsets[i] + ind.exp_cache[i], 255, 255, 255, ind.alpha[i], "-", nil, ind.text[i])
            line_offset = ind.exp_cache[i] + ind.exp[6]
        end
    
        if line_offset >= 1 then
            ind.line[1] = render.lerp(ind.line[1], 50, 6)
            ind.line[2] = render.lerp(ind.line[2], 50, 6)
        else
            ind.line[1] = render.lerp(ind.line[1], 0, 6)
            ind.line[2] = render.lerp(ind.line[2], 0, 6)
        end
    
        renderer_gradient(center_x + 3 + 55 + 4 , center_y + 20, 1, ind.line[1], 255, 255, 255, ind.line[2], 255, 255, 255, ind.line[2], true)
        renderer_gradient(center_x + 3 + 55 + 4, center_y + 20, 1, line_offset,  255, 255, 255, 255, 255, 255, 255, 255, true)
    end
end

damage_indicator = function ()
        local hp = {
            [0] = "Auto"
        }
        for i = 1, 100 do
            hp[i] = tostring(i)
        end
        for i = 1, 26 do
            hp[i + 100] = "HP+" .. tostring(i)
        end
        local sx, sy = client_screen_size()
        local cx, cy = sx / 2, sy / 2
        if entity_is_alive(entity_get_local_player()) then
            if ui_get(ref.mindmg_override[1]) then
                if ui_get(ref.mindmg_override[2]) then
                    renderer_text(cx + 4*dpi, cy - 14*dpi, 255, 255, 255, 225, "-d", 0,
                        hp[ui_get(ref.mindmg_override[3])])
                else
                    renderer_text(cx + 4*dpi, cy - 14*dpi, 255, 255, 255, 225, "-d", 0, hp[ui_get(ref.mindmg)])
                end
            else
                renderer_text(cx + 4*dpi, cy - 14*dpi, 255, 255, 255, 225, "-d", 0, hp[ui_get(ref.mindmg)])
            end
        end
end


dragging_fn=function(b,c,d)return(function()local e={}local f,g,h,i,j,k,l,m,n,o,p,q,r,s;local t={__index={drag=function(self,...)local u,v=self:get()local w,x,q=e.drag(u,v,...)if u~=w or v~=x then self:set(w,x)end;return w,x,q end,status=function(self,...)local w,x=self:get()local y,z=e.status(w,x,...)return y end,set=function(self,u,v)local n,o=client_screen_size()ui_set(self.x_reference,u/n*self.res)ui_set(self.y_reference,v/o*self.res)end,get=function(self)local n,o=client_screen_size()return ui_get(self.x_reference)/self.res*n,ui_get(self.y_reference)/self.res*o end}}function e.new(y,z,A,B)B=B or 10000;local n,o=client_screen_size()local C=ui_new_slider("LUA","A",y.." window position",0,B,z/n*B)local D=ui_new_slider("LUA","A","\n"..y.." window position y",0,B,A/o*B)ui_set_visible(C,false)ui_set_visible(D,false)return setmetatable({name=y,x_reference=C,y_reference=D,res=B},t)end;function e.drag(u,v,E,F,G,H,I)local t="n"if globals_framecount()~=f then g=ui_is_menu_open()j,k=h,i;h,i=ui_mouse_position()m=l;l=client_key_state(0x01)==true;q=p;p={}s=r;r=false;n,o=client_screen_size()end;if g and m~=nil then if(not m or s)and l and j>u and k>v and j<u+E and k<v+F then r=true;u,v=u+h-j,v+i-k;if not H then u=math_max(0,math_min(n-E,u))v=math_max(0,math_min(o-F,v))end end end;if g and m~=nil then if j>u and k>v and j<u+E and k<v+F then if l then t="c"else t="o"end end end;table_insert(p,{u,v,E,F})return u,v,t,E,F end;function e.status(u,v,E,F,G,H,I)if globals_framecount()~=f then g=ui_is_menu_open()j,k=h,i;h,i=ui_mouse_position()m=l;l=true;q=p;p={}s=r;r=false;n,o=client_screen_size()end;if g and m~=nil then if j>u and k>v and j<u+E and k<v+F then return true end end;return false end;return e end)().new(b,c,d)end
local logs = {
    hitgroup_names = { "body", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear" },
    screen = {client_screen_size()},
    ani = {
        logs = 0,
        handler = 0
    },
    last_fire = {
        damage = 0,
        hitbox = "?",
        breaklc = false,
        backtrack = 0
    }
}

logs.byaw_log = {
    info = '',
    state = false,
}
logs.drags = {
    logs = dragging_fn('indicator logs', 400 , logs.screen[2]/4),
}

logs.on_ragebot_fire = function(e)
    if not contains(ui_get(visuals.main), "Hitlog") then
        return
    end
    
    logs.last_fire = {
        damage = e.damage,
        hitbox = logs.hitgroup_names[e.hitgroup + 1],
        breaklc = e.teleported,
        backtrack = globals_tickcount() - e.tick
    }

end

logs.on_player_hurt = function(e)
    if not contains(ui_get(visuals.main), "Hitlog") then
        return
    end
    
    local attacker_id = client_userid_to_entindex(e.attacker)

    if attacker_id == nil then
        return
    end

    if attacker_id ~= entity_get_local_player() then
        return
    end
    local knife = false
    local nade = false
    local molotov = false
    if e.weapon == "knife" then
        knife = true
    elseif e.weapon == "hegrenade" then
        nade = true
    elseif e.weapon == "inferno" then
        molotov = true
    end
    local special_method = (knife or nade or molotov)

    local killed = e.health == 0
    local prefix = ((knife and "Stabbed") or (nade and "Boommbed") or (molotov and "Burnt")) or (killed and "Kill" or "Hit")
    local group = logs.hitgroup_names[e.hitgroup + 1] or "?"
    local hitbox_mismatch = group ~= logs.last_fire.hitbox
    local damage_mismatch = e.dmg_health ~= logs.last_fire.damage
    local target_id = client_userid_to_entindex(e.userid)
    local target_name = entity_get_player_name(target_id)
    
    logs.byaw_log.state = true
    if special_method then
        logs.byaw_log.info = ("%s \a90FF98alpha%s\aFFFFFFalpha in \aFFFDA6alpha%s\aFFFFFFalpha for \affbebealpha%s\aFFFFFFalpha%s"):format(
            prefix, target_name , (special_method and logs.hitgroup_names[1]) or (hitbox_mismatch and group.."("..logs.last_fire.hitbox..")" or group),
            e.dmg_health, (killed and "" or ", hp:"..e.health))
    else
        logs.byaw_log.info = ("%s \a90FF98alpha%s\aFFFFFFalpha in \aFFFDA6alpha%s\aFFFFFFalpha for \affbebealpha%s\aFFFFFFalpha, %s breaklc:\a98F5FFalpha%s\aFFFFFFalpha; bt:\aFFDEADalpha%s\aFFFFFFalpha"):format(
            prefix, target_name , (special_method and logs.hitgroup_names[1]) or (hitbox_mismatch and group.."("..logs.last_fire.hitbox..")" or group),
            (damage_mismatch and e.dmg_health.."("..logs.last_fire.damage..")" or e.dmg_health), killed and "" or "hp:"..e.health..";", logs.last_fire.breaklc, logs.last_fire.backtrack)
    end
    
    if contains(ui_get(visuals.hitlog_settings), "to console") then
        if special_method then
            client_color_log(color[1], color[2], color[3], "Xor -> \0")
            client_color_log(255, 255, 255, prefix.." \0")
            client_color_log(144, 255, 152, target_name.." \0")
            client_color_log(255, 255, 255, "in \0")
            client_color_log(255, 253, 166, logs.hitgroup_names[1].." \0")
            client_color_log(255, 255, 255, "for \0")
            client_color_log(255, 190, 190, e.dmg_health.."\0")
            client_color_log(255, 255, 255, killed and "\0" or ", \0")
            client_color_log(255, 255, 255, killed and "\0" or "hp:\0")
            client_color_log(255, 255, 255, killed and " " or e.health)
        else
            client_color_log(color[1], color[2], color[3], "Xor -> \0")
            client_color_log(255, 255, 255, prefix.." \0")
            client_color_log(144, 255, 152, target_name.." \0")
            client_color_log(255, 255, 255, "in \0")
            client_color_log(255, 253, 166, hitbox_mismatch and group.."("..logs.last_fire.hitbox..") \0" or group.." \0")
            client_color_log(255, 255, 255, "for \0")
            client_color_log(255, 190, 190, damage_mismatch and e.dmg_health.."("..logs.last_fire.damage..")\0" or e.dmg_health.."\0")
            client_color_log(255, 255, 255, ", \0")
            client_color_log(255, 255, 255, killed and "\0" or "hp:\0")
            client_color_log(255, 255, 255, killed and "\0" or e.health.."\0")
            client_color_log(255, 255, 255, killed and "\0" or "; \0")
            client_color_log(255, 255, 255, "breaklc:\0")
            client_color_log(152, 245, 255, tostring(logs.last_fire.breaklc).."\0")
            client_color_log(255, 255, 255, "; \0")
            client_color_log(255, 255, 255, "bt:\0")
            client_color_log(255, 222, 173, logs.last_fire.backtrack)
        end
    end
end


logs.miss_brute = function(e)
    if not contains(ui_get(visuals.main), "Hitlog") then
        return
    end

    -- credit to @ally https://gamesense.pub/forums/viewtopic.php?id=31914
    local function KaysFunction(A,B,C)
        local d = (A-B) / A:dist(B)
        local v = C - B
        local t = v:dot(d) 
        local P = B + d:scaled(t)
        
        return P:dist(C)
    end

	local local_player = entity_get_local_player()
	local shooter = client_userid_to_entindex(e.userid)

	if not entity_is_enemy(shooter) or not entity_is_alive(local_player) then return end

    local overlap = 100 - math.floor(antiaim_funcs.get_overlap() * 100)
	local shot_start_pos 	= vector(entity_get_prop(shooter, "m_vecOrigin"))
	shot_start_pos.z 		= shot_start_pos.z + entity_get_prop(shooter, "m_vecViewOffset[2]")
	local eye_pos			= vector(client_eye_position())
	local shot_end_pos 		= vector(e.x, e.y, e.z)
	local closest			= KaysFunction(shot_start_pos, shot_end_pos, eye_pos)

	if closest < 32 then
        logs.byaw_log.state = true
        logs.byaw_log.info = 'Miss Detected. Overlap: \aFFFDA6alpha('..overlap..'%\aFFFFFFalpha)'
	end
end

logs.on_aim_miss = function(e)
    if not contains(ui_get(visuals.main), "Hitlog") then
        return
    end

    local prefix = "Missed"
    local group = logs.hitgroup_names[e.hitgroup + 1] or "?"
    local target_name = entity_get_player_name(e.target)
    local reason
    if e.reason == "?" then
    	reason = "Resolver"
    else
    	reason = e.reason
    end
    logs.byaw_log.state = true
    logs.byaw_log.info = ("%s \a90FF98alpha%s\aFFFFFFalpha's \aFFFDA6alpha%s\aFFFFFFalpha due to \affbebealpha%s\aFFFFFFalpha, breaklc:\a98F5FFalpha%s\aFFFFFFalpha; bt:\aFFDEADalpha%s\aFFFFFFalpha"):format(
        prefix, target_name , group, reason.." \aFFFDA6alpha("..math.floor(e.hit_chance).."%)", logs.last_fire.breaklc, logs.last_fire.backtrack)

    if contains(ui_get(visuals.hitlog_settings), "to console") then
        client_color_log(color[1], color[2], color[3], "Xor -> \0")
        client_color_log(255, 255, 255, prefix.." \0")
        client_color_log(144, 255, 152, target_name.."\0")
        client_color_log(255, 255, 255, "'s \0")
        client_color_log(255, 253, 166, group.." \0")
        client_color_log(255, 255, 255, "due to \0")
        client_color_log(255, 190, 190, reason.."\0")
        client_color_log(255, 253, 166, " ("..math.floor(e.hit_chance).."%)\0" )
        client_color_log(255, 255, 255, ", \0")
        client_color_log(255, 255, 255, "breaklc:\0")
        client_color_log(152, 245, 255, tostring(logs.last_fire.breaklc).."\0")
        client_color_log(255, 255, 255, "; \0")
        client_color_log(255, 255, 255, "bt:\0")
        client_color_log(255, 222, 173, logs.last_fire.backtrack)
    end
end

local event_name
logs.draw = function(...)

    local animation_cache = {}
    local draw_event_list = {}

    local function lerp(start, vend, time)
        if not start then start = 0 end
        local cache_name = string.format('%s,%s,%s',start,vend,time)
        if animation_cache[cache_name] == nil then
            animation_cache[cache_name] = 0
        end

        animation_cache[cache_name] = start + (vend - start) * time
        return animation_cache[cache_name]
    end

    local function handler_event()
        if not contains(ui_get(visuals.main), "Hitlog") then
            return
        end

        local x, y = logs.drags.logs:get()
        if logs.byaw_log.state then
            logs.byaw_log.state = false
            table.insert(draw_event_list,{
                text = logs.byaw_log.info ,
                timer = globals_realtime() ,
                alpha = 0 ,
                x_add = x ,
            })
            logs.byaw_log.info = ''
        end
    end

    local function draw()
        if not contains(ui_get(visuals.main), "Hitlog") then
            return
        end

        if not contains(ui_get(visuals.hitlog_settings), "to screen") then
            return
        end

        local x, y = logs.drags.logs:get()
        local font = ''

        handler_event()
        event_name = event_name == nil and 0 or event_name
        if #draw_event_list > 0 then
            event_name = lerp(
                event_name, 200, globals_frametime() * 6
            )
        else
            event_name = lerp(
                event_name, 0, globals_frametime() * 6
            )
        end

        local _, normal_width = renderer_measure_text(font)
        local header = 'Log Events : '
        local width, height = renderer_measure_text(font, header)
        local _, _c, status = logs.drags.logs:drag(width + 5,  height + 5)
        local selected = (status == "n" and true) or false
        local clicked = (status == "c" and true) or false

        local function alt_lerp(start, vend, time)
        return start + (vend - start) * time end
            
        logs.ani.logs = alt_lerp(logs.ani.logs, (selected) and 0 or 255, 6 * globals_frametime())
        local menu = ui_is_menu_open()
        logs.ani.handler = alt_lerp(logs.ani.handler, menu and 255 or event_name, 6 * globals_frametime())
        render.outline(x + 20, y - 3, width + 6, height + 6, 2, 180, 180, 180, logs.ani.logs)

        renderer_text(x + 25, y - normal_width, 255,255,255,logs.ani.handler,font,0,header)

        for i,info in ipairs(draw_event_list) do

            if i > 10 then
                table.remove(draw_event_list,i)
            end

            if not info.text or info.text == '' then goto skip end

            local length, width = renderer_measure_text(font, header..info.text)
            
            if info.timer + 3.5 < globals_realtime() then
                info.alpha = lerp(
                    info.alpha, 0, globals_frametime() * 6
                )
                info.x_add = lerp(
                    info.x_add,x+80, globals_frametime() * 8
                )
            else
                info.alpha = lerp(
                    info.alpha, 255, globals_frametime() * 6
                )
                info.x_add = lerp(
                    info.x_add, x + 40, globals_frametime() * 8
                )
            end

            local info_text = info.text:gsub("alpha", string.format('%02X', info.alpha))
            local header = '['..color_hex_no_alpha..'alpha'..script.name..'\aFFFFFFalpha] '
            local header_sub = header:gsub("alpha", string.format('%02X', info.alpha))
            renderer_text(info.x_add,y+i * (width+3),255,255,255,info.alpha,font,0, header_sub..info_text)

            if info.timer + 4 < globals_realtime() then
                table.remove(draw_event_list,i)
            end

            ::skip::
        end
    end

    return {
        main = draw
    }
end

paint_log = logs.draw()
slowdown_icon = renderer_load_svg('<?xml version="1.0" ?><svg baseProfile="tiny" height="24px" id="Layer_1" version="1.2" viewBox="0 0 24 24" width="24px" xml:space="preserve" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><path d="M21.171,15.398l-5.912-9.854C14.483,4.251,13.296,3.511,12,3.511s-2.483,0.74-3.259,2.031l-5.912,9.856  c-0.786,1.309-0.872,2.705-0.235,3.83C3.23,20.354,4.472,21,6,21h12c1.528,0,2.77-0.646,3.406-1.771  C22.043,18.104,21.957,16.708,21.171,15.398z M12,17.549c-0.854,0-1.55-0.695-1.55-1.549c0-0.855,0.695-1.551,1.55-1.551  s1.55,0.696,1.55,1.551C13.55,16.854,12.854,17.549,12,17.549z M13.633,10.125c-0.011,0.031-1.401,3.468-1.401,3.468  c-0.038,0.094-0.13,0.156-0.231,0.156s-0.193-0.062-0.231-0.156l-1.391-3.438C10.289,9.922,10.25,9.712,10.25,9.5  c0-0.965,0.785-1.75,1.75-1.75s1.75,0.785,1.75,1.75C13.75,9.712,13.711,9.922,13.633,10.125z\" stroke=\"none\" fill=\"#ffffff\" fill-rule=\"evenodd\"/></svg>' , 48, 48)
defensive_icon = renderer_load_svg('<svg id=\"svg\" version=\"1.1\" width=\"608\" height=\"689\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" ><g id=\"svgg\"><path id=\"path0\" d=\"M185.803 18.945 C 184.779 19.092,182.028 23.306,174.851 35.722 C 169.580 44.841,157.064 66.513,147.038 83.882 C 109.237 149.365,100.864 163.863,93.085 177.303 C 88.686 184.901,78.772 202.072,71.053 215.461 C 63.333 228.849,53.959 245.069,50.219 251.505 C 46.480 257.941,43.421 263.491,43.421 263.837 C 43.421 264.234,69.566 264.530,114.025 264.635 L 184.628 264.803 181.217 278.618 C 179.342 286.217,174.952 304.128,171.463 318.421 C 167.974 332.714,160.115 364.836,153.999 389.803 C 147.882 414.770,142.934 435.254,143.002 435.324 C 143.127 435.452,148.286 428.934,199.343 364.145 C 215.026 344.243,230.900 324.112,234.619 319.408 C 238.337 314.704,254.449 294.276,270.423 274.013 C 286.397 253.750,303.090 232.582,307.519 226.974 C 340.870 184.745,355.263 166.399,355.263 166.117 C 355.263 165.937,323.554 165.789,284.798 165.789 C 223.368 165.789,214.380 165.667,214.701 164.831 C 215.039 163.949,222.249 151.366,243.554 114.474 C 280.604 50.317,298.192 19.768,298.267 19.444 C 298.355 19.064,188.388 18.576,185.803 18.945 \" stroke=\"none\" fill=\"#ffffff\" fill-rule=\"evenodd\"></path></g></svg>' , 30, 34)
watermark_icon = renderer_load_svg('<svg t="1737123606110" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="3257" width="256" height="256"><path d="M1024.744727 294.679273h-232.727272V232.727273h-558.545455v61.952h-232.727273v46.545454h232.727273v341.922909H0v46.545455h233.472V791.272727h558.545455V341.224727h232.727272v-46.545454zM319.674182 420.026182h225.047273v51.106909H319.720727V419.979636z m0 183.947636v-51.106909h225.047273v51.106909H319.720727z m413.463273 87.226182H655.732364V368.034909l-96.302546 18.618182V322.234182l117.201455-23.784727h56.599272v392.843636z" p-id="3258" stroke=\"none\" fill=\"#ffffff\" fill-rule=\"evenodd\"></path></svg>' , 128, 128)
rec_renderable = function(x, y, w, h, radius, color)
    radius = math.min(x / 2, y / 2, radius)
    local r, g, b, a = unpack(color)
    renderer_rectangle(x, y + radius, w, h - radius * 2, r, g, b, a)
    renderer_rectangle(x + radius, y, w - radius * 2, radius, r, g, b, a)
    renderer_rectangle(x + radius, y + h - radius, w - radius * 2, radius, r, g, b, a)
    renderer_circle(x + radius, y + radius, r, g, b, a, radius, 180, 0.25)
    renderer_circle(x - radius + w, y + radius, r, g, b, a, radius, 90, 0.25)
    renderer_circle(x - radius + w, y - radius + h, r, g, b, a, radius, 0, 0.25)
    renderer_circle(x + radius, y - radius + h, r, g, b, a, radius, -90, 0.25)
end

rec_outline_renderable = function(x, y, w, h, radius, thickness, color)
    radius = math.min(w / 2, h / 2, radius)
    local r, g, b, a = unpack(color)
    if radius == 1 then
        renderer_rectangle(x, y, w, thickness, r, g, b, a)
        renderer_rectangle(x, y + h - thickness, w, thickness, r, g, b, a)
    else
        renderer_rectangle(x + radius, y, w - radius * 2, thickness, r, g, b, a)
        renderer_rectangle(x + radius, y + h - thickness, w - radius * 2, thickness, r, g, b, a)
        renderer_rectangle(x, y + radius, thickness, h - radius * 2, r, g, b, a)
        renderer_rectangle(x + w - thickness, y + radius, thickness, h - radius * 2, r, g, b, a)
        renderer_circle_outline(x + radius, y + radius, r, g, b, a, radius, 180, 0.25, thickness)
        renderer_circle_outline(x + radius, y + h - radius, r, g, b, a, radius, 90, 0.25, thickness)
        renderer_circle_outline(x + w - radius, y + radius, r, g, b, a, radius, -90, 0.25, thickness)
        renderer_circle_outline(x + w - radius, y + h - radius, r, g, b, a, radius, 0, 0.25, thickness)
    end
end

glow_module = function(x, y, w, h, width, rounding, accent, accent_inner)
    local thickness = 1
    local offset = 1
    local r, g, b, a = unpack(accent)
    if accent_inner then
        rec_renderable(x, y, w+1, h + 1, rounding, accent_inner)
    end

    for k = 0, width do
        if a * (k / width) ^ (1) > 5 then
            local accent = { r, g, b, a * (k / width) ^ (2) }
            rec_outline_renderable(x + (k - width - offset) * thickness, y + (k - width - offset) * thickness,
                w - (k - width - offset) * thickness * 2, h + 1 - (k - width - offset) * thickness * 2,
                rounding + thickness * (width - k + offset), thickness, accent)
        end
    end
end

glow_circle = function(x, y, radius, width, accent)
    local thickness = 1
    local offset = 1
    local r, g, b, a = unpack(accent)

    for k = 0, width do
        local alpha = a * (1 - k / width) ^ 2
        if alpha > 5 then
            local current_radius = radius + k * thickness
            renderer_circle_outline(x, y, r, g, b, alpha, current_radius, 0, 1, thickness)
        end
    end
end

animates = {
    def_clamp1 = 0,
    def_clamp2 = 0,
    -- def_clamp3 = 0
    slowdown_clamp1 = 0,
    slowdown_clamp2 = 0,
}

rounded_rectangle = function(x, y, w, h, r, g, b, a, thickness)
    renderer_rectangle(x, y, w, h, r, g, b, a)
    renderer_circle(x, y, r, g, b, a, thickness, -180, 0.25)
    renderer_circle(x + w, y, r, g, b, a, thickness, 90, 0.25)
    renderer_rectangle(x, y - thickness, w, thickness, r, g, b, a)
    renderer_circle(x + w, y + h, r, g, b, a, thickness, 0, 0.25)
    renderer_circle(x, y + h, r, g, b, a, thickness, -90, 0.25)
    renderer_rectangle(x, y + h, w, thickness, r, g, b, a)
    renderer_rectangle(x - thickness, y, thickness, h, r, g, b, a)
    renderer_rectangle(x + w, y, thickness, h, r, g, b, a)
end

function defensive_ind()
    local local_player = entity_get_local_player()
    if not entity_is_alive(local_player) then
        return
    end
    local exploit_on = ((ui_get(ref.doubletap[1]) and ui_get(ref.doubletap[2])) or (ui_get(ref.hideshot[1]) and ui_get(ref.hideshot[2]))) and not (ui_get(ref.fakeduck))
    local is_defensive = exploit_on and (is_defensive_active_tick(local_player) or is_defensive_active())

    if is_defensive then
        animates.def_clamp1 = math_clamp(animates.def_clamp1 + globals_frametime() / 0.3, 0, 0.8)
        animates.def_clamp2 = math_clamp(animates.def_clamp2 + globals_frametime() / 0.15, 0, 1)
        -- animates.def_clamp3 = math_clamp(animates.def_clamp2 + globals_frametime() / 0.15, 0, 1)
    else
        animates.def_clamp1 = math_clamp(animates.def_clamp1 - globals_frametime() / 0.25, 0, 1)
        animates.def_clamp2 = math_clamp(animates.def_clamp2 - globals_frametime() / 0.25, 0, 1)
        -- animates.def_clamp3 = math_clamp(animates.def_clamp2 - globals_frametime() / 0.25, 0, 1)
    end

    local sx, sy = client_screen_size()
    local cx, cy = sx / 2, sy / 2

    local def_clamp1 = animates.def_clamp1 > 0.2 and animates.def_clamp1 + 0.2 or animates.def_clamp1
    local glow_color = desync > 30 and { ind.right[1], ind.right[2], ind.right[3] } or { ind.left[1], ind.left[2], ind.left[3] }
    local main_color = desync > 30 and { ind.left[1], ind.left[2], ind.left[3] } or { ind.right[1], ind.right[2], ind.right[3] }
    glow_module(
        cx - 55, cy - 220, def_clamp1 * 110, 0, 10, 0,
        { glow_color[1], glow_color[2], glow_color[3], def_clamp1 * 100 },
        { main_color[1], main_color[2], main_color[3], def_clamp1 * 100 }
    )

    rounded_rectangle(
        cx - 55, cy - 220, def_clamp1 * 110, 2,
        main_color[1], main_color[2], main_color[3], def_clamp1 * 140, 1
    )

    
    renderer_texture(defensive_icon, cx - 11, cy - 268, 40, 40, main_color[1], main_color[2], main_color[3], animates.def_clamp2 * 255, "f")

    local charged_mes = renderer_measure_text("", "defensive manager ") + renderer_measure_text("", "ready")

    renderer_text(cx, cy - 230, 255, 255, 255, animates.def_clamp2 * 255, "c",
        animates.def_clamp2 * charged_mes + 1, "defensive manager ",
        "\aB4B4B4FFready")
end

function slowdown_ind()
    local local_player = entity_get_local_player()
    if not entity_is_alive(local_player) then
        return
    end

    local m_flVelocityModifier = math.max(entity_get_prop(local_player, "m_flVelocityModifier")-0.3,0)/0.7
    if m_flVelocityModifier == 1 and animates.slowdown_clamp2 == 0 then
        return
    end

    animates.slowdown_clamp1 = math_clamp(animates.slowdown_clamp1 + globals_frametime() / 0.7, 0, m_flVelocityModifier)
    animates.slowdown_clamp2 = (animates.slowdown_clamp1 == 1 and math_clamp(animates.slowdown_clamp2 - globals_frametime() / 0.5, 0, 1)) or 1


    local sx, sy = client_screen_size()
    local cx, cy = sx / 2, sy / 2

    local slow = math_floor(m_flVelocityModifier * 255)
    local r, g, b, a = 255 - (slow),slow, 0, animates.slowdown_clamp2 * 255
    local main_color = { ui_get(visuals.main_indicator_colors.right_alt) }
    glow_module(
        cx - 55, cy - 120, 110, 0, 10, 0,
        { r, g, b, a },
        m_flVelocityModifier == 1 and {r, g, b, a} or { 0, 0, 0, 100}
    )

    rounded_rectangle(
        cx - 55, cy - 120, animates.slowdown_clamp1 * 110, 2,
        r, g, b, a, 1
    )

    
    renderer_texture(slowdown_icon, cx - 60, cy - 160, 40, 40, r, g, b, a, "f")

    renderer_text(cx + 35, cy - 130, r, g, b, a, "c",
        0, "Slowdown ")
end

spects_ = (function()
    local spects_ = {}

    spects_.spect = {
        rec = function(x, y, w, h, radius, color)
            radius = math.min(x/2, y/2, radius)
            local r, g, b, a = unpack(color)
            renderer_rectangle(x, y + radius, w, h - radius*2, r, g, b, a)
            renderer_rectangle(x + radius, y, w - radius*2, radius, r, g, b, a)
            renderer_rectangle(x + radius, y + h - radius, w - radius*2, radius, r, g, b, a)
            renderer_blur(x, y + radius, w, h - radius*2, 255, 0.5)
            renderer_blur(x + radius, y, w - radius*2, radius, 255, 0.5)
            renderer_blur(x + radius, y + h - radius, w - radius*2, radius, 255, 0.5)
            renderer_circle(x + radius, y + radius, r, g, b, a, radius, 180, 0.25)
            renderer_circle(x - radius + w, y + radius, r, g, b, a, radius, 90, 0.25)
            renderer_circle(x - radius + w, y - radius + h, r, g, b, a, radius, 0, 0.25)
            renderer_circle(x + radius, y - radius + h, r, g, b, a, radius, -90, 0.25)
        end,
        get_spects = function()
            local spects = {}
            local me, target = entity_get_local_player()

            if me ~= nil then 
                local m_iObserverMode = entity_get_prop(me, 'm_iObserverMode')
                local m_hObserverTarget = entity_get_prop(me, 'm_hObserverTarget')
                if m_hObserverTarget and m_iObserverMode == 4 or m_iObserverMode == 5 then
                    target = m_hObserverTarget
                else
                    target = me
                end
            end

            for i = 1, globals_maxplayers() do
                if entity_get_classname(i) == 'CCSPlayer' then
                    if i ~= -1 and not entity_is_alive(i) then
                        local m_hObserverTarget = entity_get_prop(i, 'm_hObserverTarget')
                        local m_iObserverMode = entity_get_prop(i, 'm_iObserverMode')
                        if m_hObserverTarget and m_hObserverTarget == target and i ~= me and (m_iObserverMode == 4 or m_iObserverMode == 5) then
                            spects[#spects + 1] = i
                        end
                    end
                end
            end

            return spects
        end,
        render = function()
            local spect = spects_.spect:get_spects()
            local X, Y = client_screen_size()
            for i = 1, #spect do
                if i > 10 then return end

                local name = entity_get_player_name(spect[i])
                local steam_id = entity_get_steam64(spect[i])

                local text_size = vector(renderer_measure_text("", name))
                spects_.spect.rec(X - text_size.x - 60, Y / 2 - 30 / 2 - 40 + (i - 1) * 37, text_size.x + 15, 30, 2, {255,255,255,15})
                renderer_text(X - text_size.x - 53, Y / 2 - 30 / 2 - 32 + (i - 1) * 37, 255, 255, 255, 255, "", 0, name)

                local img = images.get_steam_avatar(steam_id)
                if img then
                    img:draw(X - 40, Y / 2 - 30 / 2 - 40 + (i - 1) * 37, 29, 29)
                end
            end
        end
    }

    return spects_
end)()

am_offset = -120
time_offset = -120
info_offset = -120
nickname_offset = -120
images = require 'gamesense/images'

local_steamid64 = panorama_loadstring([[
    return MyPersonaAPI.GetXuid()
]])()

local_name = panorama_loadstring([[
    return MyPersonaAPI.GetName()
]])()

jmp_ecx = client_find_signature('engine.dll', '\xFF\xE1')
fnGetModuleHandle = ffi.cast('uint32_t(__fastcall*)(unsigned int, unsigned int, const char*)', jmp_ecx)
fnGetProcAddress = ffi.cast('uint32_t(__fastcall*)(unsigned int, unsigned int, uint32_t, const char*)', jmp_ecx)

pGetProcAddress = ffi.cast('uint32_t**', ffi.cast('uint32_t', client_find_signature('engine.dll', '\xFF\x15\xCC\xCC\xCC\xCC\xA3\xCC\xCC\xCC\xCC\xEB\x05')) + 2)[0][0]
pGetModuleHandle = ffi.cast('uint32_t**', ffi.cast('uint32_t', client_find_signature('engine.dll', '\xFF\x15\xCC\xCC\xCC\xCC\x85\xC0\x74\x0B')) + 2)[0][0]
BindExports = function(sModuleName, sFunctionName, sTypeOf) local ctype = ffi.typeof(sTypeOf) return function(...) return ffi.cast(ctype, jmp_ecx)(fnGetProcAddress(pGetProcAddress, 0, fnGetModuleHandle(pGetModuleHandle, 0, sModuleName), sFunctionName), 0, ...) end end
        
fnEnumDisplaySettingsA = BindExports("user32.dll", "EnumDisplaySettingsA", "int(__fastcall*)(unsigned int, unsigned int, unsigned int, unsigned long, void*)");
pLpDevMode = ffi.new("struct { char pad_0[120]; unsigned long dmDisplayFrequency; char pad_2[32]; }[1]")
fnEnumDisplaySettingsA(0, 4294967295, pLpDevMode[0])

framerate = 0

watermark = function()
    if contains(ui_get(visuals.main), "Watermark") then
        time_offset = render.lerp(time_offset, 30, 0.8)
        info_offset = render.lerp(info_offset, 60, 0.8)
        nickname_offset = render.lerp(nickname_offset, 90, 0.8)
        am_offset = render.lerp(am_offset, 120, 0.8)
    else
        time_offset = render.lerp(time_offset, -120, 0.8)
        info_offset = render.lerp(info_offset, -120, 0.8)
        nickname_offset = render.lerp(nickname_offset, -120, 0.8)
        am_offset = render.lerp(am_offset, -120, 0.8)
        return
    end

    h,m = client_system_time()
    local sx, sy = client_screen_size()
    framerate = 0.9 * framerate + (1.0 - 0.9) * globals_absoluteframetime()
    local fps = math.floor(1/framerate)
    local fps_prefix = (string.len(fps) == 2 and "\aFFFFFF000\aFFFFFFFF") or (string.len(fps) == 1 and "\aFFFFFF0000\aFFFFFFFF") or "\aFFFFFFFF"
    local display_frequency = pLpDevMode[0].dmDisplayFrequency
    local timestr = h >= 12 and 'pm' or 'am'
    local main_color = desync > 30 and { ind.left[1], ind.left[2], ind.left[3] } or { ind.right[1], ind.right[2], ind.right[3] }
    local t_text = "\aFFFFFFFF"..h..":"..m.." "..timestr
    local i_text = ("%s / %shz"):format(fps_prefix..fps, display_frequency)
    local n_text = "\aFFFFFFFF"..local_name
    local a_text = "Xor ["..script.build.."]"
    local t_text_w, t_text_h = renderer_measure_text("bdc",  t_text)
    local i_text_w, i_text_h = renderer_measure_text("bdc", i_text)
    local n_text_w, t_text_h = renderer_measure_text("bdc", n_text)
    local a_text_w, a_text_h = renderer_measure_text("bdc", a_text)
    local lp_avatar = images.get_steam_avatar(local_steamid64)
    local avatar_texture = renderer_load_rgba(lp_avatar.contents, lp_avatar.width, lp_avatar.height)

    renderer_rectangle(sx - t_text_w - time_offset + 4, 10, t_text_w + 10, 25, 255,255,255,15)
    renderer_blur(sx - t_text_w - time_offset + 4, 10, t_text_w + 10, 25, 255, 0.5)
    renderer_text(sx - t_text_w / 2 - time_offset + 9, 22, 255,255,255,200, "bdc", 0, t_text)

    renderer_rectangle(sx - i_text_w - info_offset - t_text_w + 20, 10, i_text_w + 10, 25, 255,255,255,15)
    renderer_blur(sx - i_text_w - info_offset - t_text_w + 20, 10, i_text_w + 10, 25, 255, 0.5)
    renderer_text(sx - i_text_w / 2 - info_offset - t_text_w +25, 22, 255,255,255,200, "bdc", 0, i_text)

    renderer_rectangle(sx - n_text_w - nickname_offset - i_text_w - t_text_w - 5, 10, n_text_w + 50, 25, 255,255,255,15)
    renderer_blur(sx - n_text_w - nickname_offset - i_text_w - t_text_w - 5 , 10, n_text_w + 50, 25, 255, 0.5)
    renderer_text(sx - n_text_w / 2 - nickname_offset - i_text_w - t_text_w + 40, 22, 255,255,255,200, "bdc", 0, n_text)
    renderer_texture(avatar_texture, sx - n_text_w - i_text_w - nickname_offset - t_text_w + 20 - 5* dpi , 20 - 5* dpi, lp_avatar.width / (1.85 + 0.2 * dpi) * dpi, lp_avatar.height / (1.85 + 0.2 * dpi) * dpi, 255,255,255,255, "f")

    renderer_rectangle(sx - a_text_w - am_offset - n_text_w - i_text_w - t_text_w - 12 *dpi, 10, a_text_w + 15 + 15*dpi, 25, 255,255,255,15)
    renderer_blur(sx - a_text_w - am_offset - n_text_w - i_text_w - t_text_w - 12 *dpi, 10, a_text_w + 15 + 15*dpi, 25, 255, 0.5)
    renderer_text(sx - a_text_w / 2 - am_offset - n_text_w - i_text_w - t_text_w + 15, 22, main_color[1], main_color[2], main_color[3], 255, "bdc", 0, a_text)
    renderer_texture(watermark_icon, sx - a_text_w - am_offset - n_text_w - i_text_w - t_text_w - 10*dpi, 20 - 6* dpi, lp_avatar.width / 1.85 * dpi, lp_avatar.height / 1.85 * dpi, main_color[1], main_color[2], main_color[3], 255, "f")
end

pClientEntityList = client_create_interface("client_panorama.dll", "VClientEntityList003") or error("invalid interface", 2)
fnGetClientEntity = vtable_thunk(3, "void*(__thiscall*)(void*, int)")

ffi.cdef('typedef struct { float x; float y; float z; } bbvec3_t;')

fnGetAttachment = vtable_thunk(84, "bool(__thiscall*)(void*, int, bbvec3_t&)")
fnGetMuzzleAttachmentIndex1stPerson = vtable_thunk(468, "int(__thiscall*)(void*, void*)")
fnGetMuzzleAttachmentIndex3stPerson = vtable_thunk(469, "int(__thiscall*)(void*)")
local get_attachment_vector = function (lp, weapon, world_model)
    
    if lp == nil or weapon == nil then
        return
    end

    local model =
        world_model and 
        entity_get_prop(weapon, 'm_hWeaponWorldModel') or
        entity_get_prop(lp, 'm_hViewModel[0]')

    local active_weapon = fnGetClientEntity(pClientEntityList, weapon)
    local g_model = fnGetClientEntity(pClientEntityList, model)

    if active_weapon == nil or g_model == nil then
        return
    end

    local attachment_vector = ffi.new("bbvec3_t[1]")

    if attachment_vector == nil then
        return
    end

    local att_index = world_model and
        fnGetMuzzleAttachmentIndex3stPerson(active_weapon) or
        fnGetMuzzleAttachmentIndex1stPerson(active_weapon, g_model)

    if att_index > 0 and fnGetAttachment(g_model, att_index, attachment_vector[0]) then 
        return { attachment_vector[0].x, attachment_vector[0].y, attachment_vector[0].z }
    end
end

revolver_ind = {
    clamp1 = 0,
    clamp2 = 0,
}
lastready_time = 0
charge_time = 0
draw_revolver_indicator = function ()
    if ui_get(rage.revolver_force_second_fire) and weapon_accuracy_nospread:get_int() == 1 then
        return
    end
    local lp = entity_get_local_player()
    local weapon = entity_get_player_weapon(lp)
    if not weapon then
        return
    end

    if not (bit_band(entity_get_prop(weapon, "m_iItemDefinitionIndex"), 0xFFFF) == 64) then
        return
    end
    local thirdperson = ui_get(ref.thirdperson[1]) and ui_get(ref.thirdperson[2])
    local curtime = globals_curtime()
    local ready_time = entity_get_prop(weapon, "m_flPostponeFireReadyTime")
    if ready_time > curtime and ready_time < curtime + 0.5 and ready_time ~= lastready_time then
        charge_time = curtime
        lastready_time = ready_time
    end
    local ss = {client_screen_size()}
    local timediff = math.min((curtime - charge_time),0.231171875)
    local charge_time = (entity_can_fire(lp) and weapon_can_fire(weapon)) and ((timediff > 0 and timediff < 100) and timediff) or 0
    local percent = charge_time == 0 and 0 or charge_time/0.231171875
    local pos = get_attachment_vector(lp, weapon, thirdperson)
    if pos then
        local x, y = renderer_world_to_screen(pos[1], pos[2], pos[3])
        if x == nil then
            return
        end
        revolver_ind.clamp1 = math_clamp(revolver_ind.clamp1 + (revolver_ind.clamp1 < x and (x - revolver_ind.clamp1) or -(revolver_ind.clamp1 - x)) * (globals_frametime() / 0.4), 0, ss[1])
        revolver_ind.clamp2 = math_clamp(revolver_ind.clamp2 + (revolver_ind.clamp2 < y and (y - revolver_ind.clamp2) or -(revolver_ind.clamp2 - y)) * (globals_frametime() / 0.4), 0, ss[2])
        local settings = ui_get(rage.revolver_indicator_settings)
        if contains(settings, "Custom Color") then
            r,g,b,a = ui_get(rage.revolver_indicator_color)
        else
            local c = math.max((percent-0.6)*255, 0)*2.5
            r,g,b,a  = 255 - (c), c, 0, 255
        end
        local x_, y_ = revolver_ind.clamp1-(60*dpi), revolver_ind.clamp2-(15*dpi)
        if contains(settings, "Glow") then
            glow_circle(x_, y_, 25*dpi, 10*dpi, {r,g,b,a})
        end
        renderer_circle_outline(x_, y_, r, g, b, a, 25*dpi, 270, percent, 8*dpi)
    end
end

arrindicators = {}
on_indicator = function(data)
    if contains(ui_get(visuals.main), "Optimize Skeet Indicators") then
        table.insert(arrindicators, data)
    end
end

indicator_icons = {
    ["DT"] = renderer_load_svg('<svg t="1739902392975" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="3697" width="256" height="256"><path d="M378.56 365.013333L0 737.834667l209.130667 28.522666L70.4 1024l364.544-367.018667-173.994667-35.797333 117.589334-256.149333z m145.002667-209.984c-21.269333 0-38.485333 17.344-38.506667 38.762667v310.037333c0 21.418667 17.237333 38.762667 38.506667 38.762667h230.976c21.248 0 38.464-17.344 38.485333-38.741333a38.634667 38.634667 0 0 0-38.485333-38.762667h-192.490667V193.792a38.634667 38.634667 0 0 0-38.485333-38.762667zM562.048 0C307.136 0 100.117333 208.512 100.117333 465.066667H177.066667c0-213.930667 172.458667-387.562667 384.96-387.562667 212.48 0 384.96 173.653333 384.96 387.584 0 213.930667-172.458667 387.562667-384.96 387.562667-62.72 0.085333-124.458667-15.36-179.84-44.928l-49.92 60.8a457.088 457.088 0 0 0 229.76 61.653333C816.981333 930.176 1024 721.749333 1024 465.066667 1024 208.512 816.96 0 562.048 0z" p-id="3698" fill="#ffffff"></path></svg>',64,64),
    ["DA"] = renderer_load_svg('<svg t="1739902772891" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="6615" width="256" height="256"><path d="M619.242394 33.370353C511.362292 69.283683 427.068235 156.821279 395.672552 266.685217c36.40045 15.134772 79.153105 0.848532 98.755765-34.432327 22.734895-40.918097 55.937637-75.342568 96.007202-99.565013 34.543632-20.882005 47.254588-64.133565 30.792021-99.957851l-1.985146 0.641636zM980.673801 365.850844c-85.04045-75.469586-202.99687-104.700726-313.838977-76.959754 5.093811 39.091396 38.841289 68.97334 79.196317 68.309442 46.802824-0.769964 93.218046 10.772951 134.230424 33.362496 35.355499 19.474332 79.167509 8.857207 101.96133-23.312368l-1.549094-1.398507zM873.453668 845.101176c22.837033-111.382916-10.82533-228.150343-90.270445-310.272-31.307949 23.956624-40.311816 68.123499-19.559448 102.740461 24.067928 40.148133 37.280409 86.11421 38.223222 132.927509 0.811867 40.355028 31.912921 72.989463 71.16931 76.645483l0.437361-2.041453zM404.800818 991.871018c107.878793-35.91333 192.17154-123.449616 223.568532-233.313555-36.40045-15.134772-79.153105-0.848532-98.755764 34.432327-22.733586 40.918097-55.937637 75.342568-96.007202 99.565013-34.543632 20.882005-47.254588 64.133565-30.792021 99.957852l1.986455-0.641637zM43.369412 659.389217c85.04045 75.470895 202.99556 104.702036 313.838977 76.961064-5.093811-39.091396-38.842598-68.97334-79.196317-68.309442-46.804133 0.769964-93.218046-10.772951-134.230425-33.362496-35.355499-19.474332-79.170128-8.857207-101.962639 23.312368l1.549094 1.398506zM150.588235 180.140194c-22.837033 111.382916 10.82533 228.150343 90.270445 310.272 31.307949-23.956624 40.311816-68.123499 19.559448-102.74046-24.067928-40.148133-37.280409-86.11421-38.223223-132.927509-0.811867-40.355028-31.911611-72.989463-71.169309-76.645483l-0.436051 2.041452z" fill="#ffffff" p-id="6616"></path><path d="M511.345269 395.457801c64.002619 0 115.887468 51.884849 115.887468 115.887468S575.347887 627.232737 511.345269 627.232737 395.457801 575.347887 395.457801 511.345269s51.884849-115.887468 115.887468-115.887468z m0 78.567774c-20.610946 0-37.319693 16.708747-37.319694 37.319694s16.708747 37.319693 37.319694 37.319693 37.319693-16.708747 37.319693-37.319693-16.708747-37.319693-37.319693-37.319694z" fill="#ffffff" p-id="6617"></path><path d="M471.40665 349.626598m39.283887 0l0 0q39.283887 0 39.283888 39.283888l0 26.189258q0 39.283887-39.283888 39.283888l0 0q-39.283887 0-39.283887-39.283888l0-26.189258q0-39.283887 39.283887-39.283888Z" fill="#ffffff" p-id="6618"></path><path d="M631.667909 396.792455m19.641943 34.020844l0 0q19.641944 34.020845-14.3789 53.662788l-22.680563 13.09463q-34.020845 19.641944-53.662789-14.378901l0 0q-19.641944-34.020845 14.378901-53.662788l22.680563-13.09463q34.020845-19.641944 53.662788 14.378901Z" fill="#ffffff" p-id="6619"></path><path d="M670.951796 559.165856m-19.641944 34.020845l0 0q-19.641944 34.020845-53.662788 14.378901l-22.680563-13.09463q-34.020845-19.641944-14.378901-53.662788l0 0q19.641944-34.020845 53.662789-14.378901l22.680563 13.09463q34.020845 19.641944 14.3789 53.662788Z" fill="#ffffff" p-id="6620"></path><path d="M549.974425 674.373402m-39.283888 0l0 0q-39.283887 0-39.283887-39.283888l0-26.189258q0-39.283887 39.283887-39.283888l0 0q39.283887 0 39.283888 39.283888l0 26.189258q0 39.283887-39.283888 39.283888Z" fill="#ffffff" p-id="6621"></path><path d="M389.713166 627.207545m-19.641944-34.020844l0 0q-19.641944-34.020845 14.378901-53.662788l22.680563-13.09463q34.020845-19.641944 53.662788 14.378901l0 0q19.641944 34.020845-14.378901 53.662788l-22.680563 13.09463q-34.020845 19.641944-53.662788-14.378901Z" fill="#ffffff" p-id="6622"></path><path d="M350.429278 464.834144m19.641944-34.020845l0 0q19.641944-34.020845 53.662788-14.378901l22.680563 13.09463q34.020845 19.641944 14.378901 53.662788l0 0q-19.641944 34.020845-53.662788 14.378901l-22.680563-13.09463q-34.020845-19.641944-14.378901-53.662788Z" fill="#ffffff" p-id="6623"></path></svg>',64,64),
    ["DUCK"] = renderer_load_svg('<svg t="1739903063555" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="12651" width="256" height="256"><path d="M903.2 848 903.2 848l-144 160 0 0c-8.8 9.6-21.6 16-35.2 16-14.4 0-26.4-6.4-35.2-16l0 0-144-160 0 0c-8-8.8-12.8-20-12.8-32 0-26.4 21.6-48 48-48 14.4 0 26.4 6.4 35.2 16l0 0 60 67.2L675.2 624l0 0L675.2 416l0 0L675.2 172.8l0 0L675.2 48c0-26.4 21.6-48 48-48 26.4 0 48 21.6 48 48l0 304 0 112c0 0 0 0 0 0l0 96 0 291.2L832 784l0 0c8.8-9.6 21.6-16 35.2-16 26.4 0 48 21.6 48 48C916 828 911.2 839.2 903.2 848zM452 256c-14.4 0-26.4-6.4-35.2-16l0 0-60-67.2L356.8 464c0 0 0 0 0 0l0 96 0 112 0 304c0 26.4-21.6 48-48 48-26.4 0-48-21.6-48-48l0-124.8 0 0L260.8 608l0 0L260.8 400l0 0L260.8 172.8 200 240l0 0c-8.8 9.6-21.6 16-35.2 16-26.4 0-48-21.6-48-48 0-12 4.8-23.2 12.8-32l0 0L272 16l0 0c8.8-9.6 21.6-16 35.2-16 14.4 0 26.4 6.4 35.2 16l0 0 144 160 0 0c8 8.8 12.8 20 12.8 32C500 234.4 478.4 256 452 256z" p-id="12652" fill="#ffffff"></path></svg>',64,64),
    ["MD"] = renderer_load_svg('<svg t="1739903746729" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="29308" width="256" height="256"><path d="M555.495118 885.939621l-6.933923 0.24764L548.561196 643.7343c0-7.093559-5.027503-12.125155-12.125155-12.125155l-45.456285 0c-7.097652 0-12.126178 5.031597-12.126178 12.125155l-0.082888 242.883773-9.008164-0.551562c-88.270393-6.983041-177.408549-66.661236-220.487693-109.735263-44.884256-44.88528-104.934934-135.588071-106.826004-220.48667l-3.031033-9.092076 242.456031 0c6.794753 0 11.103896-0.935302 12.122085-6.063089l0.438998-54.914704c-0.525979-4.831029-2.473331-7.996115-6.501064-8.730848l-248.930489-0.055259L142.449851 464.921775c0-74.489528 63.085804-173.695994 102.290711-212.900901 66.281589-66.284659 144.108119-100.359732 234.092549-114.777093l0.021489 242.821351c0 6.79373 2.399653 6.65149 6.063089 12.122085l54.552453 0 9.092076-6.062066L548.562219 137.608078l12.148691-0.021489c154.620543 7.504928 324.256058 178.709171 324.256058 336.426239L642.510938 474.012827c-9.31618 0-12.123109 8.880251-12.123109 18.187221l0 42.427298c0 7.067976 8.085142 15.155165 15.155165 15.155165l239.422951 0C884.965945 706.916295 704.984804 879.520421 555.495118 885.939621L555.495118 885.939621zM530.374998 958.920796c128.35125 0 239.764736-72.151273 305.34843-137.128147C905.449465 752.71334 960.734606 642.538055 960.734606 504.323157l0-9.093099c0-230.572376-209.28556-430.358585-445.51068-430.358585l-21.212114 0c-126.357849 0-239.207034 74.387197-303.82575 138.655943C122.170992 271.176143 66.682213 383.77871 66.682213 519.471159l0 12.124132c0 126.356826 74.389244 239.203964 138.65799 303.823704 67.64668 68.01814 180.25027 123.500778 315.945789 123.500778L530.374998 958.919772z" p-id="29309" fill="#ffffff"></path></svg>',64,64),
    ["FS"] = renderer_load_svg('<svg t="1739903824653" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="33502" width="256" height="256"><path d="M999.301 373.243l-260.07-260.069c-6.408-6.422-15.474-10.179-24.55-10.179-19.46 0-34.935 15.706-34.935 34.511v111.895l-135.79 2.895c-19.23 0-34.5 15.703-34.5 34.704 0 19.025 15.269 34.511 34.5 34.511v0.105l170.725-0.105c19.025 0 33.28-15.486 33.28-34.511l0.115-3.767 0.885-61.921 177.135 176.479L748.962 574.71V511.892a34.153 34.153 0 0 0-34.28-34.269H343.139V365.705c0-19.219-15.486-34.705-34.28-34.705-9.513 0-18.36 3.756-24.55 10.178L24.023 601.466c-13.269 13.474-13.269 35.382 0 48.856l260.286 260.069c13.499 14.151 35.383 14.151 49.1 0 6.628-6.399 9.73-15.246 9.73-24.092V774.163h136.009c19.23 0 34.499-14.808 34.499-34.485 0-19.025-15.268-34.512-34.499-34.512H308.859c-19.46 0-34.717 15.486-34.717 34.512v63.229l-176.7-176.892 176.7-177.135v63.012c0 19.243 15.257 34.946 34.717 34.946h370.888v111.894c0 8.41 3.538 17.475 10.396 24.332 13.271 13.041 35.385 13.041 49.089 0l259.633-259.848 1.437-1.115c13.484-13.04 12.484-35.385-1.001-48.858z" fill="#ffffff" p-id="33503"></path></svg>',64,64),
    ["SAFE"] = renderer_load_svg('<svg t="1739904240669" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="37264" width="256" height="256"><path d="M371.776 85.333333v117.397334h98.133333V85.333333h64v117.397334h98.133334V85.333333h64v117.397334h119.338666v110.933333h115.989334v64H815.36v98.133333h115.989333v64H815.36v98.133334h115.989333v64H815.36v112h-119.338667v117.44h-64v-117.44h-98.133333v117.44h-64v-117.44h-98.133333v117.44h-64v-117.44H204.181333v-112H85.333333v-64h118.848v-98.133334H85.333333v-64h118.848v-98.133333H85.333333v-64h118.848v-110.933333h103.594667V85.333333h64z m379.605333 181.397334h-483.2v483.2h483.2v-483.2z m-98.133333 98.133333v286.933333h-286.933333v-286.933333h286.933333z m-64 64h-158.933333v158.933333h158.933333v-158.933333z" fill="#ffffff" p-id="37265"></path></svg>',64,64),
    ["BODY"] = renderer_load_svg('<svg t="1739904612115" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="44391" width="256" height="256"><path d="M512 933.577c-232.834 0-421.577-188.749-421.577-421.577s188.743-421.577 421.577-421.577c232.828 0 421.577 188.749 421.577 421.577s-188.749 421.577-421.577 421.577zM512 146.634c-201.789 0-365.366 163.578-365.366 365.366 0 201.784 163.578 365.366 365.366 365.366 201.784 0 365.366-163.582 365.366-365.366 0-201.789-163.582-365.366-365.366-365.366zM736.841 540.104h-449.682c-15.525 0-28.104-12.585-28.104-28.104 0-15.525 12.579-28.104 28.104-28.104h449.682c15.519 0 28.104 12.579 28.104 28.104 0 15.519-12.585 28.104-28.104 28.104z" p-id="44392" fill="#ffffff"></path></svg>',64,64),
    ["PING"] = renderer_load_svg('<svg t="1739904675644" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="45501" width="256" height="256"><path d="M120.22 568c-30.91 0-56.01 25.08-56.01 56.01v261.35c0 30.91 25.08 56.01 56.01 56.01s56.01-25.08 56.01-56.01V624.01c-0.01-30.93-25.1-56.01-56.01-56.01z m261.35-149.34c-30.91 0-56.01 25.08-56.01 56.01v410.7c0 30.91 25.08 56.01 56.01 56.01s56.01-25.08 56.01-56.01V474.65c0-30.91-25.1-55.99-56.01-55.99z m261.35-149.35c-30.91 0-56.01 25.08-56.01 56.01v560.04c0 30.91 25.08 56.01 56.01 56.01 30.91 0 56.01-25.08 56.01-56.01V325.31c0-30.91-25.09-56-56.01-56zM904.27 82.63c-30.91 0-56.01 25.08-56.01 56.01v746.73c0 30.91 25.08 56.01 56.01 56.01 30.91 0 56.01-25.08 56.01-56.01V138.63c0-30.91-25.08-56-56.01-56z" fill="#ffffff" p-id="45502"></path></svg>',64,64),
    ["OSAA"] = renderer_load_svg('<svg t="1739904935360" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="65156" width="256" height="256"><path d="M866.05824 190.92992c-86.87616 0-269.59872-101.35552-332.14976-140.44672a28.96896 28.96896 0 0 0-30.69952 0C440.66304 89.5744 257.93536 190.92992 171.0592 190.92992a28.9536 28.9536 0 0 0-28.95872 28.9536v318.5408c0 223.26784 273.9456 434.37568 376.45312 434.37568 102.50752 0 376.45824-211.10272 376.45824-434.37568V219.88352a28.94336 28.94336 0 0 0-28.9536-28.9536z m-28.9536 347.4944c0 189.68064-249.33376 376.45824-318.54592 376.45824-69.20704 0-318.5408-186.7776-318.5408-376.45824V246.528c108.01664-15.63648 268.15488-107.43296 318.5408-137.5488 50.39616 28.95872 210.52928 121.91232 318.54592 137.5488v291.89632z" p-id="65157" fill="#ffffff"></path><path d="M431.68768 277.80608l-57.91744 289.58208h115.82976L460.6464 770.0992l231.66976-318.5408h-144.7936l86.87616-173.7472H431.68768v-0.00512z" p-id="65158" fill="#ffffff"></path></svg>',64,64),
    ["$Lag Exploit"] = renderer_load_svg('<svg t="1739905006264" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="66223" width="256" height="256"><path d="M887.488 609.088c8.384-32.576 11.008-110.208 8.384-145.28-18.688-253.504-306.752-377.92-511.104-326.016 153.856 53.376 310.336 198.784 311.488 371.008 0.128 21.184-1.536 41.92-4.672 62.272L526.4 553.664l107.072 124.16 107.008 124.224 138.176-88.256 138.176-88.128L887.488 609.088z" fill="#ffffff" p-id="66224"></path><path d="M136.128 422.144C126.848 454.4 122.368 532.032 124.032 567.104c12.224 253.952 297.088 385.536 502.656 338.88-152.512-57.344-305.216-206.592-302.016-378.752 0.448-21.184 2.624-41.92 6.272-62.08l164.672 21.376-103.808-126.72L288 232.896 147.648 317.504 7.232 402.24 136.128 422.144z" fill="#ffffff" p-id="66225"></path></svg>',64,64),
    ["$Discharge"] = renderer_load_svg('<svg t="1739905337828" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="68407" width="256" height="256"><path d="M719.980333 508.365216c11.525498-59.919694-0.985444-120.737852-35.224246-171.252339-34.232662-50.504254-86.079494-84.656075-145.993049-96.1652-14.301727-2.743484-28.872584-4.134157-43.308365-4.134157-109.219517 0-203.476251 77.960583-224.12043 185.370895-11.508102 59.916625 1.004887 120.729665 35.237549 171.240059 34.231639 50.512441 86.080517 84.667332 145.994072 96.172363 14.32424 2.753717 28.916587 4.149507 43.372833 4.149507 34.381042 0 68.739571-7.971555 99.754958-23.098068 0.789992 1.810229 1.74576 3.557012 2.866281 5.231141l65.143673 96.15292c6.15928 9.096169 16.402575 14.525831 27.399023 14.525831 6.594185 0 12.973476-1.959631 18.436908-5.665023 15.07023-10.19213 19.039635-30.779004 8.846482-45.902446l-65.11809-96.116081c-1.140986-1.697665-2.411933-3.263323-3.808746-4.687766C686.242951 600.782046 710.580243 557.404096 719.980333 508.365216zM632.508119 448.946942l-25.295106-19.683295c-3.426029-3.453658-8.411577-5.677303-14.014178-6.261611-0.995677-0.12075-2.073218-0.165776-3.174296-0.140193l-0.063445 0c-5.037736 0-9.906627 1.362021-13.68672 3.816932-4.116761 2.639107-6.822382 6.483668-7.529487 10.649548l-22.390963 52.725852-36.259832-112.568798c-2.460028-7.275707-10.987239-12.357446-20.736277-12.357446l-0.381693 0.00307-0.36225-0.00307c-8.699126 0-16.455787 3.961218-19.763113 10.090822l-0.11154 0.205685-47.718815 111.935372-43.286875-33.464159c-4.01443-3.099594-9.354042-4.806469-15.035438-4.806469l-28.629038 0c0.490164-4.816702 1.184989-9.637498 2.110057-14.45113 14.682397-76.346829 81.673138-131.760906 159.293983-131.760906 10.270924 0 20.641109 0.992607 30.818913 2.947122 42.594097 8.178263 79.456656 32.458249 103.799064 68.366064 15.369036 22.670326 24.571628 48.257074 27.212782 74.756611L632.508119 448.946942zM353.598852 482.432591l61.243853 47.370891c4.051269 3.080152 9.444093 4.776793 15.180747 4.776793l0.206708-0.001023 0.421602 0.004093c8.617261 0 16.334014-3.960195 19.659759-10.088776l0.11461-0.211824 35.724643-83.791381 36.46961 113.255437c2.422166 7.274684 10.916631 12.356422 20.658506 12.356422l0.37146 0.001023c10.316973 0 19.000749-5.614881 20.920472-13.43601l34.913161-82.10088 8.484232 6.610558c1.810229 1.396813 3.845585 2.496867 6.051833 3.270487 3.114944 1.234107 6.445806 1.859347 9.905604 1.859347l33.231869 0c-0.488117 4.535293-1.154289 9.071609-2.025123 13.599739-14.684444 76.352969-81.661881 131.770116-159.25919 131.770116-10.276041 0-20.649296-0.99363-30.834262-2.951215-42.600237-8.170077-79.466889-32.44597-103.804181-68.353784-15.20633-22.434965-24.384363-47.728024-27.137057-73.940013L353.598852 482.432591z" p-id="68408" fill="#ffffff"></path><path d="M511.720126 0c-282.153148 0-511.699148 229.53679-511.699148 511.674589 0 282.154171 229.546 511.703241 511.699148 511.703241 102.07991 0 200.771653-30.181393 285.420565-87.285972l0.168846-0.001023 1.324158-0.935302c8.17724-5.776563 13.059434-15.175631 13.059434-25.142633 0-16.946974-13.801331-30.731932-30.764678-30.731932-7.011694 0-13.888312 2.503007-19.392676 7.055696-73.768097 50.595328-157.812235 76.245522-249.814626 76.245522-248.615311 0-450.877921-202.27489-450.877921-450.906573 0-248.603031 202.26261-450.856431 450.877921-450.856431 248.616334 0 450.879967 202.252377 450.879967 450.856431 0 102.710266-24.973788 182.081988-80.977289 257.357416l-2.808976 3.827165 0.325411 0.280386c-2.185782 4.269233-3.323699 8.952906-3.323699 13.765515 0 16.873296 13.740956 30.601972 30.629601 30.601972 7.692193 0 15.084557-2.978844 20.754696-8.273431l0.547469 0.182149 2.196015-3.01773c0.103354-0.141216 0.199545-0.281409 0.294712-0.420579 0.039909-0.057305 0.077771-0.11461 0.119727-0.171915 1.041726-1.329275 1.944282-2.701528 2.75781-4.186346 56.545854-80.499405 90.301655-188.865485 90.301655-289.945625C1023.41825 229.535767 793.871227 0 511.720126 0z" p-id="68409" fill="#ffffff"></path></svg>',64,64),
}
indicator_dpis = {
    ["DT"] = 1,
    ["DA"] = 1,
    ["DUCK"] = 0.9,
    ["MD"] = 1,
    ["FS"] = 1,
    ["SAFE"] = 1,
    ["BODY"] = 1,
    ["PING"] = 1,
    ["OSAA"] = 1,
    ["$Lag Exploit"] = 0.98, --mihoyo present
    ["$Discharge"] = 0.93,
}
DPI_SCALE_FACTORS = {
    [1] = 2.0,
    [1.25] = 2.5,
    [1.75] = 3.3,
    [2] = 4.0,
}

 function draw_indicator(x, y, width, height, r, g, b, a, text, dpi)
    local half_width = width / 2
    local text_width, text_height = renderer_measure_text("bd+", text)
    

    local gradient_width = text_width / 2 +40*dpi
    local scale_factor = DPI_SCALE_FACTORS[dpi] or 1
    local gradient_height = (text_height / scale_factor) * 2 * dpi
    
    renderer_gradient(
        x + half_width - 40*dpi,
        y + (height - text_height) / 2,
        gradient_width + 0.1 ,
        gradient_height,
        0, 0, 0, 0,
        0, 0, 0, 77,
        true
    )
    
    renderer_gradient(
        x + half_width + gradient_width- 40*dpi,
        y + (height - text_height) / 2,
        gradient_width,
        gradient_height,
        0, 0, 0, 77,
        0, 0, 0, 0,
        true
    )
    
    renderer_text(
        x + half_width+8*(DPI_SCALE_FACTORS[dpi] or 1),
        y + (height - text_height) / 2,
        r, g, b, a,
        "bd+",
        nil,
        text
    )
end

function draw_indicator_list()
    local screen_size = {client_screen_size()}
    local screen_center_y = screen_size[2] / 2
    local vertical_offset = (screen_center_y / 1.8) * (0.9 / dpi)
    local current_height = 0
    
    for i, data in pairs(arrindicators) do
        local indicator_height = 35 * dpi
        local y_position = screen_center_y + vertical_offset - 20 + current_height
        

        draw_indicator(
            0,
            y_position,
            120,
            indicator_height,
            data.r, data.g, data.b, data.a,
            data.text,
            dpi
        )

        renderer_texture(
            indicator_icons[data.text] or watermark_icon,
            35,
            y_position + indicator_height - 28 * dpi,
            25 * dpi * (indicator_dpis[data.text] or 1.1),
            25 * dpi * (indicator_dpis[data.text] or 1.1),
            data.r, data.g, data.b, data.a,
            "f"
        )
        current_height = current_height - indicator_height
    end
end

local renderer = function ()
    if contains(ui_get(visuals.main), "Optimize Skeet Indicators") then
        draw_indicator_list()
        arrindicators = {}
    end
    local lp = entity_get_local_player()
    if not lp then
        return
    end
    if not entity_is_alive(lp) then
        return
    end
    if not ui_get(master_switch) then return end
    dpi = tonumber(string.sub(ui_get(ref.dpi_scale), 1, -2)) * 0.01 or 1
    watermark()
    local visual_features = ui_get(visuals.main)
    manualDickWork()
    if contains(visual_features, "Defensive Indicator") then
        defensive_ind()
    end
    if contains(visual_features, "Slowdown Indicator") then
        slowdown_ind()
    end
    if contains(visual_features, "Spectator List") then
        spects_.spect:render()
    end
    if contains(visual_features, "Main Indicator") then
        main_indicator()
    end

    if contains(visual_features, "Damage Indicator") then
        damage_indicator()
    end

    if contains(visual_features, "Hitlog") then
        ui_set(ref.log_spread, false)
        ui_set(ref.log_damage, false)
        paint_log.main()
    end
    local exploits = ui_get(misc.exploit_features)
    if contains(exploits, "Auto Discharge") and ui_get(misc.auto_discharge_key) then
        if indicators.auto_discharge then
            renderer_indicator(255, 0, 50, 255, "$Discharge")
        else
            renderer_indicator(255, 255, 255, 200, "$Discharge")
        end
    end

    if contains(exploits, "Lag Exploit") and ui_get(misc.lag_exploit) then
        if lag_exploiting then
            renderer_indicator(255, 0, 50, 255, "$Lag Exploit")
        else
            renderer_indicator(255, 255, 255, 200, "$Lag Exploit")
        end
    end
    local ragefuncs = ui_get(rage.main)
    local revolver_indicator = contains(ragefuncs, "Revolver Improvements") and ui_get(rage.revolver_indicator)
    if revolver_indicator then
        draw_revolver_indicator()
    end

    if last_magnet_origin.x then
        local x,y = renderer_world_to_screen(last_magnet_origin.x, last_magnet_origin.y, last_magnet_origin.z+35)
        glow_circle(x,y,20*dpi, 10*dpi,{255,0,0,255})
    end
end

words = {
    "1",
    "你全家死绝了换你这枪不空",
    "你婊子妈当年也是这么死的",
    "我操你妈 窝囊废",
    "这个头是我让你的窝囊废",
    "别急着高兴，你爹马上换真参了",
    "'别激动,你狗运好罢了",
    "让你一把 怕你玻璃心砸电脑",
    "你这个窝囊废，你妈当年也是这么死的",
    "叫爹可以再放你一分",
    "只有你爹死了这把游戏才能公平 废物",
    "是的孩子 你赢了^^",
    "1,我帮你扣的 你还不配给我扣1",
    "我在游戏里被你杀死,你妈在现实里被我杀死",
    "打的我好困,先睡会Zzzz", 
    "据说你爸妈当年也是这么死的",
}

shittalk_counter = 0
function shittalk(e)
    local shittalk = ui_get(misc.shittalk)
    if not contains(shittalk, "Kill") then
        return
    end

    local userid = client_userid_to_entindex(e.userid)
    local killer = client_userid_to_entindex(e.attacker)
    local localplayer = entity_get_local_player()

    if userid ~= killer and killer == localplayer then
        if contains(shittalk, "Counter") then
            shittalk_counter = shittalk_counter + 1
            say_phrases({shittalk_counter})
            return
        end
        local current_phrase = rutrashtalk[math.random(1, #rutrashtalk)]
        say_phrases(current_phrase)
    end
end

function shittalk2(e)
    if not contains(ui_get(misc.shittalk), "Death") then
        return
    end

    local userid = client_userid_to_entindex(e.userid)
    local localplayer = entity_get_local_player()
    if userid == localplayer then
        client_exec("say " .. words[math.random(1, #words)])
    end
end

client_set_event_callback(
    "player_death",
    function(e)
        shittalk(e)
        shittalk2(e)
    end
)
client_set_event_callback(
    "round_start",
    function()
        shittalk_counter = 0
    end
)
client_set_event_callback(
    "round_end",
    function()
        shittalk_counter = 0
    end
)
restore_antiaim = function ()
    ui_set(ref.pitch[1], "Off")
    ui_set(ref.pitch[2], 0)
    ui_set(ref.yaw_base, "Local View")
    ui_set(ref.yaw[1], "Off")
    ui_set(ref.yaw[2], 0)
    ui_set(ref.yaw_jitter[1], "Off")
    ui_set(ref.yaw_jitter[2], 0)
    ui_set(ref.bodyyaw[1], "Off")
    ui_set(ref.bodyyaw[2], 0)
    ui_set(ref.freestanding_bodyyaw, false)
    ui_set(ref.roll, 0)
    ui_set(ref.freestanding[1], false)
    ui_set(ref.freestanding[2], "On hotkey")
    ui_set(ref.edgeyaw, false)
    ui_set(ref.antiaim_switch, false)
end
restore_antiaim()

reset_vars = function ()
    MaxAbsTickbase = 0
    aa.maxtickbase_normal = false
    MaxTickBase = 0
    AbsTickBase = 0
    shittalk_counter = 0
    shifted_time = 0
    force_charge_wait_tick = 0
    hideshot_peek_wait_tick = 0
    discharge_wait_tick = 0
    lag_exploiting = false
    visible_tick = 0
    last_AbsTickBase = 0
    aa.backstab = false
    aa.delay_value = 0
    aa.delay_switch = false
    aa.send_packet_commands = 0
    aa.yaw_jitter_flip = false
    aa.yaw_modifier = 0
    aa.yaw_modifier_flip = false
    aa.yaw_spin_amount = 0
    aa.yaw_way = 0
    aa.last_state = "0"
    aa.defensive_pitch = 0
    aa.defensive_yaw = 0
    aa.defensive_active = false
    aa.defensive_yaw_flip = false
    aa.defensive_yaw_spin_amount = 0
    aa.defensive_pitch_flip = false
    aa.defensive_pitch_spin_amount = 0
    aa.nochoke = false
    aa.fakelag_limit = 1
    aa.fakelag_switch = false
    aa.alternative_count = 0
    aa.alternative_switch = false
    aa.alternative_limit = 0
    aa.last_freestanding_yaw = 0
    aa.last_freestanding_back_time = 0
    aa.last_freestanding_time = 0
    aa.freestand_extend = 0
    aa.maxtickbase_normal = false
    aa.check_cancel = 0
    aa.force_defensive = false
    aa.allow_bruteforce = false
    aa.bruteforce = false
    aa.bruteforce_enemy = {}
    tickshot = 0
end

-- local bodyyaw_anim = function ()
--     local lp = entity_get_local_player()
--     local animstate = GetAnimationState(lp)
--     if not animstate then return end
--     animstate.m_flGoalFeetYaw = normalize_yaw(vector(client_camera_angles()).y + 180 + last_bodyyaw)
--     animstate.m_flCurrentFeetYaw = normalize_yaw(vector(client_camera_angles()).y + 180 +last_bodyyaw)

-- end

local call_backs = {
    shutdown = function()
        vanila_skeet_element(true)
        restore_antiaim()
        ui_set(ref.aimbot, true)
        ui_set(ref.airstrafe, true)
        if nospread_restore then
            weapon_accuracy_nospread:set_int(0)
        end
    end,
    setup_command = function(cmd)
        handle_antiaim(cmd)
        handle_exploit(cmd)
        anti_backstab()
        fast_ladder(cmd)
        micromove(cmd)
        handle_ragebot(cmd)
    end,
    predict_command = function(cmd)
        lag_corder(cmd)
        shifting_handler()
        freestanding_handler()
        predict_velocity = vector(entity_get_prop(entity_get_local_player(), 'm_vecVelocity'))
    end,
    run_command = function(cmd)
        weapon_adap_fix()
        update_command_num(cmd)
    end,
    paint_ui = function()
        handle_visible()
        renderer()
        clantag()
    end,
    level_init = function ()
        reset_vars()
    end,
    aim_fire = function (shot)
        if not ui_get(master_switch) then return end
        logs.on_ragebot_fire(shot)
    end,
    aim_miss = function(shot)
        if not ui_get(master_switch) then return end
        logs.on_aim_miss(shot)
    end,
    player_hurt = function(shot)
        if not ui_get(master_switch) then return end
        logs.on_player_hurt(shot)
    end,
    bullet_impact = function(shot)
        if not ui_get(master_switch) then return end
        logs.miss_brute(shot)
        anti_bruteforce_check(shot)
    end,

    pre_render = function ()
        on_pre_render()
    end,
    
    indicator = function (indicator_data)
        on_indicator(indicator_data)
    end
    -- post_render = function ()
    --     bodyyaw_anim()
    -- end
}

local add_indicator_cb = false
local function invoke_indicator_cb()
    if contains(ui_get(visuals.main), "Optimize Skeet Indicators") then
        if not add_indicator_cb then
            add_indicator_cb = true
            client_set_event_callback("indicator", call_backs.indicator)
        end
    else
        if add_indicator_cb then
            add_indicator_cb = false
            client_unset_event_callback("indicator", call_backs.indicator)
        end
    end
end

invoke_indicator_cb()
ui_set_callback(visuals.main, invoke_indicator_cb)
client_set_event_callback("run_command", call_backs.run_command)
client_set_event_callback("predict_command", call_backs.predict_command)
client_set_event_callback('shutdown', call_backs.shutdown)
client_set_event_callback("setup_command", call_backs.setup_command)
client_set_event_callback("paint_ui", call_backs.paint_ui)
client_set_event_callback("level_init", call_backs.level_init)
client_set_event_callback("aim_fire", call_backs.aim_fire)
client_set_event_callback("aim_miss", call_backs.aim_miss)
client_set_event_callback("player_hurt", call_backs.player_hurt)
client_set_event_callback("bullet_impact", call_backs.bullet_impact)
client_set_event_callback("pre_render", call_backs.pre_render)
-- client_set_event_callback("post_render", call_backs.post_render)

client_exec("clear")
client_delay_call(0.1,function ()
client_color_log(color[1], color[2], color[3], "         ,-.--,  _,.---._                  ")
client_color_log(color[1], color[2], color[3], ".--.-.  /=/, .',-.' , -  `.    .-.,.---.   ")
client_color_log(color[1], color[2], color[3], "\\==\\ -\\/=/- / /==/_,  ,  - \\  /==/  `   \\  ")
client_color_log(color[1], color[2], color[3], " \\==\\ `-' ,/ |==|   .=.     ||==|-, .=., | ")
client_color_log(color[1], color[2], color[3], "  |==|,  - | |==|_ : ;=:  - ||==|   '='  / ")
client_color_log(color[1], color[2], color[3], " /==/   ,   \\|==| , '='     ||==|- ,   .'  ")
client_color_log(color[1], color[2], color[3], "/==/, .--, - \\\\==\\ -    ,_ / |==|_  . ,'.  ")
client_color_log(color[1], color[2], color[3], "\\==\\- \\/=/ , / '.='. -   .'  /==/  /\\ ,  ) ")
client_color_log(color[1], color[2], color[3], " `--`-'  `--`    `--`--''    `--`-`--`--'  ")
end)


