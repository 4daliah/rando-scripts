///
/// Title: Dinkelberg UI ( to be changed )
/// Author: april#0001
///

/// TODO
/// 
/// User interface
///   [x] Crosshair
///   [x] Health/ammo bars
///   [x] Inventory/ammo display
///     [x] Cycletime animation
///   [ ] Score counter
///   [x] Kill counter
///   [x] Kill feed
///     [x] Assists
///   [ ] Announcers
///   [x] Chat
///     [ ] Fix Y/U input
///     [x] Scrolling and scissor rects
/// 
/// Indicators
///   [x] Misc.
///   [x] Anti-aim
///   [x] Keybinds
///   [ ] Spectators
/// 
/// Chams
///   [x] History chams
///   [x] Weapon chams
///   [x] Material builder
///
/// Others
///   [x] Pose parameters
///   [x] 3D hitmarker/damage indicator
///   [x] 2D hitmarker

/// Reference the Onetap's types so ESLint can do its job
/// <reference path="./onetap.d.ts" />

// #region Classes
// #region Animation
const Anim = (function type() {
    function Anim(duration, loop) {
      // Fields
      this.duration = duration || 1;
      this.loop = loop || false;
      this.weight = 0;

      // Methods
      this.update = update;
      this.get = get;
      this.value = value;
      this.color = color;
      this.string = string;

      // Static methods
      Anim.value = staticValue;
      Anim.color = staticColor;
      Anim.string = staticString;
      Anim.approximate = approximate;
      Anim.toRGB = toRGB;
      Anim.fromRGB = fromRGB;
    }

    function update(active) {
      const time = Globals.Frametime() / this.duration;

      this.weight += active ? time : -time;

      if (this.loop)
        this.weight = Utils.clamp(this.weight, 0, 1) % 1;
      else
        this.weight = Utils.clamp(this.weight, 0, 1);
    }

    function get() {
      return this.weight * this.weight * this.weight;
    }

    function value(from, to) {
      return from + (to - from) * this.get();
    }

    function color(from, to) {
      const frac = this.get();
      const fromHSV = Anim.fromRGB(from);
      const toHSV = Anim.fromRGB(to);

      return Anim.toRGB([
        fromHSV[0] + (toHSV[0] - fromHSV[0]) * frac,
        fromHSV[1] + (toHSV[1] - fromHSV[1]) * frac,
        fromHSV[2] + (toHSV[2] - fromHSV[2]) * frac,
        fromHSV[3] + (toHSV[3] - fromHSV[3]) * frac
      ]);
    }

    function string(str) {
      return str.substr(0, str.length * this.get())
    }

    function staticValue(from, to, frac) {
      return from + (to - from) * frac;
    }

    function staticColor(from, to, frac) {
      const fromHSV = Anim.fromRGB(from);
      const toHSV = Anim.fromRGB(to);

      return Anim.toRGB([
        fromHSV[0] + (toHSV[0] - fromHSV[0]) * frac,
        fromHSV[1] + (toHSV[1] - fromHSV[1]) * frac,
        fromHSV[2] + (toHSV[2] - fromHSV[2]) * frac,
        fromHSV[3] + (toHSV[3] - fromHSV[3]) * frac
      ]);
    }

    function staticString(str, frac) {
      return str.substr(0, str.length * frac)
    }

    function approximate(from, to, factor) {
      return from + (to - from) * factor * Globals.Frametime();
    }

    function fromRGB(clr) {
      var r = clr[0] / 255,
        g = clr[1] / 255,
        b = clr[2] / 255;
      var max = Math.max(r, g, b),
        min = Math.min(r, g, b);
      var h, s, v = max;

      var d = max - min;
      s = max == 0 ? 0 : d / max;

      if (max == min) {
        h = 0; // achromatic
      } else {
        switch (max) {
          case r:
            h = (g - b) / d + (g < b ? 6 : 0);
            break;
          case g:
            h = (b - r) / d + 2;
            break;
          case b:
            h = (r - g) / d + 4;
            break;
        }
        h /= 6;
      }

      return [h, s, v, clr[3]];
    }

    function toRGB(clr) {
      var h = clr[0],
        s = clr[1],
        v = clr[2];
      var r, g, b;

      var i = Math.floor(h * 6);
      var f = h * 6 - i;
      var p = v * (1 - s);
      var q = v * (1 - f * s);
      var t = v * (1 - (1 - f) * s);

      switch (i % 6) {
        case 0:
          r = v, g = t, b = p;
          break;
        case 1:
          r = q, g = v, b = p;
          break;
        case 2:
          r = p, g = v, b = t;
          break;
        case 3:
          r = p, g = q, b = v;
          break;
        case 4:
          r = t, g = p, b = v;
          break;
        case 5:
          r = v, g = p, b = q;
          break;
      }

      return [r * 255, g * 255, b * 255, clr[3]];
    }

    return Anim;
  }
  ());
// #endregion Animation

// #region Font
const Font = (function type() {
    function Font(name, size, def) {
      // Fields
      this.name = name
      this.size = size || 12;
      this.default = def == null ? true : def;
    }

    return Font;
  }
  ());
// #endregion Font

// #region Draggable
const Draggable = (function type() {
    function Draggable(x, y, w, h) {
      // Fields
      this.x = x || 100;
      this.y = y || 100;
      this.w = w || 100;
      this.h = h || 100;
      this.dragging = false;

      // Methods
      this.update = update;
    }

    function update() {
      if (!InputSys.isDown(0x01))
        this.dragging = false;

      else if (this.dragging || InputSys.isDragging(this.x, this.y, this.w, this.h)) {
        const dx = InputSys.getDX(),
          dy = InputSys.getDY();

        this.x += dx;
        this.y += dy;

        this.dragging = true;
      }
    }

    return Draggable;
  }
  ());
// #endregion Draggable

// #region KillInfo
const KillInfo = (function type() {
    function KillInfo(attacker, victim, assister, weapon, headshot, priority) {
      // Fields
      this.attacker = attacker;
      this.victim = victim;
      this.assister = assister;
      this.weapon = weapon;
      this.headshot = headshot;
      this.priority = priority;

      this.anim = new Anim((priority && !Client.isWarmup()) ? 9999 : 10, false);
      this.anim.weight = 1;

      this.begin = new Anim(0.5, false);

      // Methods
      this.run = run;
      this.getTimeLeft = getTimeLeft;
      this.getBeginTime = getBeginTime;
    }

    function run() {
      this.anim.update(false);
      this.begin.update(this.anim.weight > 0);
    }

    function getTimeLeft() {
      return this.anim.get();
    }

    function getBeginTime() {
      return this.begin.get();
    }

    return KillInfo;
  }
  ());
// #endregion KillInfo

// #region Indicators
const Indicator = (function type() {
    function Indicator(label, menu) {
      // Fields
      this.label = label;
      this.menu = menu;
      this.active = new Anim(0.25, false);
      this.weight = 1;

      // Methods
      this.update = update;
    }

    function update() {
      this.active.update(UI.GetValue(this.menu));
    }

    return Indicator;
  }
  ());
// #endregion Indicators

// #region Impact
const Impact = (function type() {
    function Impact(position, time, damage, type) {
      // Fields
      this.position = position;
      this.begin = new Anim(0.1, false);
      this.roundup = new Anim(0.5, false);
      this.anim = new Anim(time, false);
      this.anim.weight = 1;
      this.damage = damage || 0;
      this.type = type || 'default';

      // Methods
      this.update = update;
      this.getTimeLeft = getTimeLeft;
      this.getBeginTime = getBeginTime;
      this.getPosition = getPosition;
      this.getDamage = getDamage;
    }

    function update() {
      this.anim.update(false);
      this.roundup.update(true);
      this.begin.update(this.anim.weight > 0);
    }

    function getTimeLeft() {
      return this.anim.get();
    }

    function getBeginTime() {
      return this.begin.get();
    }

    function getPosition() {
      return Render.WorldToScreen(this.position);
    }

    function getDamage() {
      return Math.floor(this.damage * this.roundup.get());
    }

    return Impact;
  }
  ());
// #endregion Impact

// #region Message
const Message = (function type() {
    function Message(message, author, team) {
      // Fields
      this.message = message
      this.author = author;
      this.team = team;
      this.anim = new Anim(0.5, false);

      // Methods
      this.getAuthor = getAuthor;
      this.getMessage = getMessage;
      this.getTeam = getTeam;
    }

    function getAuthor() {
      return this.author;
    }

    function getMessage() {
      return this.message;
    }

    function getTeam() {
      return this.team;
    }

    return Message;
  }
  ());
// #endregion Message

// #region StringBuilder
const StringBuilder = (function type() {
    const keyMapDefault = [
      "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", " ", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "", "0", "1",
      "2", "3", "4", "5", "6", "7", "8", "9", "", "", "", "", "", "",
      "", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u",
      "v", "w", "x", "y", "z", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "*", "+", "-", "", ".", "/", "", "", "",
      "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "",
      "", "", "", "", ";", "=", ",", "", ".", "/", "`", "", "",
      "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "[", "\\|", "]", "'"
    ];

    const keyMapAlternative = [
      "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", " ", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "", ")", "!",
      "@", "#", "$", "%", "^", "&", "*", "(", "", "", "", "", "", "",
      "", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U",
      "V", "W", "X", "Y", "Z", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "*", "+", "_", "", ".", "/", "", "", "",
      "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "",
      "", "", "", "", ":", "+", "<", "", ">", "?", "~", "", "",
      "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "", "", "",
      "", "", "", "", "", "", "{", "\\|", "}", "\""
    ];

    function StringBuilder() {
      // Fields
      this.text = "";
      this.ckeys = [];
      this.lkeys = [];
      this.active = false;
      this.shift = false;
      this.ctrl = false;
      this.esc = false;
      this.bspace = false;
      this.bspacedelay = new Anim(0.1, false);
      this.upper = false;
      this.enter = false;
      this.inputdelay = new Anim(0.2, false);

      // Methods
      this.run = run;
      this.toggle = toggle;
    }

    function run() {
      this.inputdelay.update(this.active);

      if (!this.active && this.inputdelay.weight < 1)
        return;

      // Won't work in the first frame, I'm aware.
      this.bspace = this.ckeys[0x08];
      this.enter = this.ckeys[0x0D];
      this.shift = this.ckeys[0x10];
      this.ctrl = this.ckeys[0x11];
      this.esc = this.ckeys[0x1B];

      for (var i = 1; i < 0xFF - 1; ++i) {
        const char = this.shift ? keyMapAlternative[i] || "" : keyMapDefault[i] || "";

        this.lkeys[i] = this.ckeys[i];
        this.ckeys[i] = Input.IsKeyPressed(i);

        if (!this.lkeys[i] && this.ckeys[i] && char != "") {
          this.text += this.upper ? char.toUpperCase() : char;
        }
      }

      if (this.ckeys[0x14] && !this.lkeys[0x14]) {
        this.upper = !this.upper;
      }

      if (this.bspace && this.bspacedelay.weight === 0) {
        this.bspacedelay.weight = 1;
        this.text = this.text.slice(0, -1);
      }

      if (this.enter) {
        this.text = "";
      }

      this.bspacedelay.update(false);
    }

    function toggle() {
      this.active = !this.active
    }

    return StringBuilder;
  }
  ());
// #endregion StringBuilder

// #region Keybind
const Keybind = (function type() {
    function Keybind(path, label) {
      // Fields
      this.path = path;
      this.anim = new Anim(0.5, false);
      this.label = label;
      this.active = false;

      // Methods
      this.update = update;
    }

    function update() {
      this.active = UI.GetValue(this.path) && UI.GetHotkeyState(this.path) !== 'Always';
      this.anim.update(this.active);
    }

    return Keybind;
  }
  ());
// #endregion Keybind
// #endregion Classes

// #region Consts
const fontMain = new Font('segoeuib.ttf', 32, true);
const fontAverageBold = new Font('segoeuib.ttf', 14, true);
const fontAverage = new Font('segoeui.ttf', 14, true);
const fontSmall = new Font('seguibl.ttf', 12, true);
const fontTiny = new Font('seguibl.ttf', 8, true);
const fontChat = new Font('seguibl.ttf', 14, true);
const fontList = new Font('segoeui.ttf', 12, true);
const fontWeapons = new Font('weapon_new.ttf', 28, false);
const fontWeaponsSmall = new Font('weapon_new.ttf', 16, false);
const fontIcon = new Font('icons.ttf', 28, false);
const fontIconSmall = new Font('icons.ttf', 16, false);
const fontIconTiny = new Font('icons.ttf', 10, false);

const idToIconMap = {
  1: "!",
  2: "\"",
  3: "#",
  4: "$",
  36: "%",
  30: "&",
  32: "'",
  61: "(",
  63: ")",
  64: "*",
  23: "+",
  17: ",",
  34: "-",
  26: ".",
  24: "/",
  33: "0",
  19: "1",
  60: "2",
  16: "3",
  7: "4",
  39: "5",
  8: "6",
  10: "7",
  13: "8",
  9: "9",
  11: ":",
  38: ";",
  40: "<",
  14: "=",
  28: ">",
  36: "?",
  29: "@",
  25: "A",
  27: "B",
  48: "C",
  46: "D",
  45: "E",
  47: "F",
  43: "G",
  44: "H",
  41: "I",
  42: "I",
  59: "J",
  500: "K",
  514: "L",
  515: "M",
  512: "N",
  505: "O",
  506: "P",
  507: "Q",
  508: "R",
  509: "S",
  516: "T",
  519: "U",
  520: "V",
  521: "W",
  525: "X",
  522: "Y",
  523: "Z",
  503: "[",
  517: "\\",
  518: "]",
  31: "^",
  60: "_",
  61: "`"
}
const idtoNameMap = {
  31: "Zeus x27",
  37: "Riot shield",
  61: "USP",
  4: "Glock",
  2: "Dual berettas",
  64: "Revolver R8",
  1: "Deagle",
  36: "P250",
  30: "Tec-9",
  34: "MP9",
  17: "Mac10",
  26: "PP-Bizon",
  24: "UMP45",
  7: "AK47",
  39: "SG553",
  8: "AUG",
  60: "M4A1-S",
  16: "M4A4",
  40: "SSG08",
  9: "AWP",
  11: "G3SG1",
  38: "SCAR20",
  25: "XM1014",
  27: "MAG7",
  14: "M249",
  28: "Negev",
  32: "P2000",
  10: "FAMAS",
  3: "Five Seven",
  33: "MP7",
  24: "UMP45",
  19: "P90",
  63: "CZ-75",
  23: "MP5",
  13: "GALIL",
  29: "Sawed off",
  35: "Nova",
  41: "Knife",
  42: "Knife",
  43: "Flashbang",
  44: "HE grenade",
  45: "Smoke grenade",
  46: "Molotov cocktail",
  47: "Decoy grenade",
  48: "Incendiary grenade",
  49: "C4 Explosive",
  57: "Medi-shot",
  500: "Bayonet",
  503: "Classic knife",
  505: "Flip knife",
  506: "Gut knife",
  507: "Karambit",
  508: "M9 bayonet",
  509: "Huntsman knife",
  512: "Falchion knife",
  514: "Bowie knife",
  515: "Butterfly knife",
  516: "Shadow daggers",
  517: "Paracord knife",
  518: "Survival knife",
  519: "Ursus knife",
  520: "Navaja knife",
  521: "Nomad knife",
  522: "Stiletto knife",
  523: "Talon knife"
};
const idToSlotMap = {
  7: 1,
  8: 1,
  9: 1,
  10: 1,
  11: 1,
  13: 1,
  14: 1,
  16: 1,
  17: 1,
  19: 1,
  23: 1,
  24: 1,
  25: 1,
  26: 1,
  27: 1,
  28: 1,
  29: 1,
  33: 1,
  34: 1,
  35: 1,
  38: 1,
  39: 1,
  40: 1,
  60: 1,
  1: 2,
  2: 2,
  3: 2,
  4: 2,
  30: 2,
  32: 2,
  36: 2,
  61: 2,
  63: 2,
  64: 2,
  31: 3,
  41: 3,
  42: 3,
  500: 3,
  503: 3,
  505: 3,
  506: 3,
  507: 3,
  508: 3,
  509: 3,
  512: 3,
  514: 3,
  515: 3,
  516: 3,
  517: 3,
  518: 3,
  519: 3,
  520: 3,
  521: 3,
  522: 3,
  523: 3,
  525: 3,
  43: 4,
  44: 4,
  45: 4,
  46: 4,
  47: 4,
  48: 4,
  49: 5
}

const nameToTabMap = {
  "usp s": "USP",
  "glock 18": "Glock",
  "dual berettas": "Dualies",
  "r8 revolver": "Revolver",
  "desert eagle": "Deagle",
  "p250": "P250",
  "tec 9": "Tec-9",
  "mp9": "MP9",
  "mac 10": "Mac10",
  "pp bizon": "PP-Bizon",
  "ump 45": "UMP45",
  "ak 47": "AK47",
  "sg 553": "SG553",
  "aug": "AUG",
  "m4a1 s": "M4A1-S",
  "m4a4": "M4A4",
  "ssg 08": "SSG08",
  "awp": "AWP",
  "g3sg1": "G3SG1",
  "scar 20": "SCAR20",
  "xm1014": "XM1014",
  "mag 7": "MAG7",
  "m249": "M249",
  "negev": "Negev",
  "p2000": "P2000",
  "famas": "FAMAS",
  "five seven": "Five Seven",
  "mp7": "MP7",
  "ump 45": "UMP45",
  "p90": "P90",
  "cz75 auto": "CZ-75",
  "mp5 sd": "MP5",
  "galil ar": "GALIL",
  "sawed off": "Sawed off"
}

const hitgroupToHitboxMap = {
  1: [0, 1],
  2: [4, 5, 6],
  3: [2, 3],
  4: [13, 15, 16],
  5: [14, 17, 18],
  6: [7, 9, 11],
  7: [8, 10, 12]
};

const materialMap = ['sprites/light_glow03', 'random01', 'random02', 'random03', 'random04', 'random05', 'random06', 'random07', 'random08', 'random09', 'random10', 'random11', 'random12', 'random13', 'random14', 'random15', 'random16', 'random17', 'random18', 'random19', 'random20', 'random21', 'random22', 'random23'];
// #endregion Consts

// #region Menu
UI.AddSubTab(['Config', 'SUBTAB_MGR'], 'Signal');
UI.AddSubTab(['Config', 'SUBTAB_MGR'], 'Signal | Materials');
UI.AddSubTab(['Config', 'SUBTAB_MGR'], 'Signal | Colors');
// #endregion Menu

// #region Namespaces
// #region Utils
const Utils = (function namespace() {
    function clamp(value, min, max) {
      return Math.min(Math.max(value, min), max);
    }

    function distance(a, b) {
      return Math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]);
    }

    return {
      // Methods
      clamp: clamp,
      distance: distance
    };
  }
  ());
// #endregion Utils

// #region Renderer
const Renderer = (function namespace() {
    function updateAlphaSpace(color) {
      return [
        color[0],
        color[1],
        color[2],
        color[3] * this.renderWeight
      ];
    }

    function drawLine(x, y, x2, y2, color) {
      color = this.updateAlphaSpace(color);

      Render.Line(x, y, x2, y2, color);
    }

    function drawGlowLine(x, y, x2, y2, w, color) {
      color = this.updateAlphaSpace(color);

      Renderer.drawLine(x, y, x2, y2, color);

      for (var i = 1, alphaMultiplier = Math.abs(Math.cos(Globals.Curtime())); i < w; ++i) {
        const color2 = [color[0], color[1], color[2], (color[3] - color[3] * i / w) * alphaMultiplier];

        Renderer.drawLine(x + i, y - i, x2 + i, y2 - i, color2);
        Renderer.drawLine(x - i, y + i, x2 - i, y2 + i, color2);
      }
    }

    function drawRect(x, y, w, h, color, outline) {
      color = this.updateAlphaSpace(color);

      Render[outline ? 'Rect' : 'FilledRect'](x + 1, y, w - 2, h, color);
      Render[outline ? 'Rect' : 'FilledRect'](x, y + 1, w - 2, h, color);
    }

    function drawRectOutlined(x, y, w, h, color, color2) {
      this.drawRect(x - 1, y - 1, w + 2, h + 2, color2, true);
      this.drawRect(x, y, w, h, color);
    }

    function drawGradient(x, y, w, h, color, color2, vertical, percentage, fixed) {
      color = this.updateAlphaSpace(color);
      color2 = this.updateAlphaSpace(color2);

      percentage = percentage || 1;

      if (percentage === 0) {
        Render.GradientRect(x, y, w, h, +!vertical, color2, color);
        return;
      } else if (percentage === 1) {
        Render.GradientRect(x, y, w, h, +!vertical, color, color2);
        return;
      }

      if (vertical) {
        Render.GradientRect(x, y, w, h * percentage + (fixed ? 1 : 0), 0, color, color2);
        Render.GradientRect(x, y + h * percentage, w, h * (1 - percentage), 0, color2, color);
      } else {
        Render.GradientRect(x, y, w * percentage + (fixed ? 1 : 0), h, 1, color, color2);
        Render.GradientRect(x + w * percentage, y, w * (1 - percentage), h, 1, color2, color);
      }
    }

    function drawString(x, y, color, font, string, type, alignment) {
      color = this.updateAlphaSpace(color);

      var centered = 0;
      var alignmentXOffset = 0;
      var alignmentYOffset = 0;

      type = type || 'default';
      alignment = alignment || 'left';

      string = string.toString();

      if (font instanceof Font) {
        font = Render.GetFont(font.name, font.size, font.default);
      }

      if (alignment === 'right') {
        alignmentXOffset = Render.TextSize(string, font)[0];
      } else if (alignment === 'center') {
        alignmentYOffset = Render.TextSize(string, font)[1] / 2;
        centered = 1;
      }

      if (type === 'default') {
        Render.String(x - alignmentXOffset, y - alignmentYOffset, centered, string, color, font);
      } else {
        var secondaryColor;
        const xyOffsets = ({
          'shadow': [
            [0, 1]
          ], // SHADOW
          'outline': [
            [1, 1],
            [1, -1],
            [-1, 1],
            [-1, -1]
          ], // OUTLINE
          'glow': [
            [1, 1],
            [1, -1],
            [-1, 1],
            [-1, -1]
          ], // GLOW
        })[type];

        if (type === 'glow') {
          secondaryColor = [color[0], color[1], color[2], 125 * color[3] / 255]
        } else {
          secondaryColor = [25, 25, 25, 125 * color[3] / 255]
        }

        for (var i = 0; i < xyOffsets.length; ++i) {
          Render.String(x - alignmentXOffset + xyOffsets[i][0], y - alignmentYOffset + xyOffsets[i][1], centered, string, secondaryColor, font);
        }

        Render.String(x - alignmentXOffset, y - alignmentYOffset, centered, string, color, font);
      }
    }

    function getStringSize(string, font) {
      if (font instanceof Font) {
        font = Render.GetFont(font.name, font.size, font.default);
      }

      return Render.TextSize(string.toString(), font);
    }

    function drawTriangle(x0, y0, x1, y1, x2, y2, color, outline) {
      color = this.updateAlphaSpace(color);

      var _x1 = x1,
        _y1 = y1,
        _x2 = x2,
        _y2 = y2;

      // Sorts the vertexes out.
      if ((x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0) < 0) {
        _x1 = x2;
        _y1 = y2;
        _x2 = x1;
        _y2 = y1;
      }

      if (!outline) {
        Render.Polygon([
          [x0, y0],
          [_x1, _y1],
          [_x2, _y2]
        ], color);
      } else {
        const lines = [
          [x0, y0, _x1, _y1],
          [x0, y0, _x2, _y2],
          [_x1, _y1, _x2, _y2]
        ];

        for (var i = 0; i < lines.length; ++i) {
          const current = lines[i];

          Render.Line(current[0], current[1], current[2], current[3], color);
        }
      }
    }

    function setRenderWeight(fraction) {
      this.renderWeight = fraction;
    }

    function resetRenderWeight() {
      this.renderWeight = 1;
    }

    return {
      // Fields
      renderWeight: 1,

      // Methods
      drawLine: drawLine,
      drawGlowLine: drawGlowLine,
      drawRect: drawRect,
      drawRectOutlined: drawRectOutlined,
      drawGradient: drawGradient,
      drawString: drawString,
      drawTriangle: drawTriangle,

      getStringSize: getStringSize,

      setRenderWeight: setRenderWeight,
      resetRenderWeight: resetRenderWeight,

      updateAlphaSpace: updateAlphaSpace
    };
  }
  ());
// #endregion Renderer

// #region InputSys
const InputSys = (function namespace() {
    function update() {
      const currTime = Globals.Realtime();

      if (currTime === this.lastTime)
        return;

      this.lastTime = currTime;

      for (var i = 0; i < 0xFF; ++i) {
        this.lastPressedKeys[i] = this.pressedKeys[i];
        this.pressedKeys[i] = Input.IsKeyPressed(i);
      }

      const newMousePos = Input.GetCursorPosition();

      this.mouseDelta[0] = newMousePos[0] - this.mousePos[0];
      this.mouseDelta[1] = newMousePos[1] - this.mousePos[1];

      this.mousePos = newMousePos;
    }

    function getX() {
      this.update();

      return this.mousePos[0];
    }

    function getY() {
      this.update();

      return this.mousePos[1];
    }

    function getDX() {
      this.update();

      return this.mouseDelta[0];
    }

    function getDY() {
      this.update();

      return this.mouseDelta[1];
    }

    function isPressed(key) {
      this.update();

      return !this.lastPressedKeys[key] && this.pressedKeys[key];
    }

    function isDown(key) {
      this.update();

      return this.pressedKeys[key];
    }

    function isInBounds(x, y, w, h) {
      this.update();

      return this.mousePos[0] >= x && this.mousePos[1] >= y && this.mousePos[0] <= x + w && this.mousePos[1] <= y + h;
    }

    function isDragging(x, y, w, h) {
      return this.isDown(0x01) && this.isInBounds(x, y, w, h);
    }

    function isInteracting(x, y, w, h) {
      return this.isPressed(0x01) && this.isInBounds(x, y, w, h);
    }

    function getScrollDelta() {
      this.update();

      return this.scrollDelta * this.scrollDirection;
    }

    return {
      // Fields
      mousePos: [0, 0],
      mouseDelta: [0, 0],
      pressedKeys: [],
      lastPressedKeys: [],
      lastTime: 0,
      scrollDelta: 0,
      scrollDirection: 1,

      // Methods
      update: update,

      getX: getX,
      getY: getY,
      getDX: getDX,
      getDY: getDY,

      isPressed: isPressed,
      isDown: isDown,
      isInBounds: isInBounds,
      isDragging: isDragging,
      isInteracting: isInteracting,

      getScrollDelta: getScrollDelta
    };
  }
  ());
// #endregion InputSys

// #region ModuleManager
const ModuleManager = (function namespace() {
    function run() {
      for (var i = 0; i < this.modules.length; ++i) {
        const module = this.modules[i];

        if (module.shouldRun())
          module.run();
      }
    }

    function add(module) {
      this.modules[this.modules.length] = module;
    }

    return {
      // Fields
      modules: [],

      // Methods
      run: run,
      add: add
    };
  }
  ());
// #endregion ModuleManager

// #region Client
const Client = (function namespace() {
    function update() {
      this.local = Entity.GetLocalPlayer();
      this.spectating = false;

      if (!Entity.IsAlive(this.local)) {
        const spectator = Entity.GetProp(this.local, 'CBasePlayer', 'm_hObserverTarget');

        if (spectator === 'm_hObserverTarget' || !Entity.IsValid(spectator))
          return;

        this.local = spectator;
        this.spectating = true;
      }
    }

    function getOrigin(entity) {
      entity = entity || this.local;
      return Entity.GetRenderOrigin(entity);
    }

    function getName(entity) {
      entity = entity || this.local;
      return Entity.GetName(entity);
    }

    function getHealth(entity) {
      entity = entity || this.local;
      return Entity.GetProp(entity, 'CBasePlayer', 'm_iHealth');
    }

    function getArmor(entity) {
      entity = entity || this.local;
      return Entity.GetProp(entity, 'CCSPlayerResource', 'm_iArmor');
    }

    function getWeapon(entity) {
      entity = entity || this.local;
      return Entity.GetWeapon(entity);
    }

    function getWeapons(entity) {
      entity = entity || this.local;
      return Entity.GetWeapons(entity);
    }

    function getWeaponID(entity) {
      const weapon = this.getWeapon(entity);

      if (!Entity.IsValid(weapon))
        return -1;

      return Entity.GetProp(weapon, 'CBaseAttributableItem', 'm_iItemDefinitionIndex') & 0xFFFF;
    }

    function getWeaponIDS(entity) {
      const weapons = this.getWeapons(entity);

      if (!weapons)
        return false;

      var ids = [];

      for (var i = 0; i < weapons.length; ++i)
        ids[i] = Entity.GetProp(weapons[i], 'CBaseAttributableItem', 'm_iItemDefinitionIndex') & 0xFFFF;

      return ids;
    }

    function getWeaponName(entity) {
      const weapon = this.getWeapon(entity);

      if (!Entity.IsValid(weapon))
        return "";

      return Entity.GetName(weapon);
    }

    function getWeaponAmmo(entity) {
      if (!this.isAlive(entity))
        return {
          primary: -1,
          reserve: -1,
          max: -1
        };

      const weapon = this.getWeapon(entity);

      if (!Entity.IsValid(weapon))
        return {
          primary: -1,
          reserve: -1,
          max: -1
        };

      const primary = Entity.GetProp(weapon, 'CBaseCombatWeapon', 'm_iClip1');
      const reserve = Entity.GetProp(weapon, 'CBaseCombatWeapon', 'm_iPrimaryReserveAmmoCount');
      const info = Entity.GetCCSWeaponInfo(weapon);

      return {
        primary: primary,
        reserve: reserve,
        max: info ? info.max_clip : 1
      };
    }

    function getFromUserID(userid) {
      return Entity.GetEntityFromUserID(userid);
    }

    function getAnimationInfo(entity, layer) {
      entity = entity || this.local;
      return Entity.GetAnimationLayer(entity, layer);
    }

    function isAnimationActive(entity, layer, act) {
      const layer = this.getAnimationInfo(entity, layer);

      if (layer.Activity !== act)
        return false;

      return layer.Weight > 0;
    }

    function isDormant(entity) {
      entity = entity || this.local;
      return Entity.IsDormant(entity);
    }

    function isAlive(entity) {
      entity = entity || this.local;
      return Entity.IsAlive(entity);
    }

    function isEnemy(entity) {
      return Entity.IsEnemy(entity);
    }

    function isScoped(entity) {
      entity = entity || this.local;
      return Entity.GetProp(entity, 'CCSPlayer', 'm_bIsScoped');
    }

    function getGameRulesProxy() {
      return Entity.GetGameRulesProxy();
    }

    function getRoundTime() {
      const grProxy = this.getGameRulesProxy();
      return Entity.GetProp(grProxy, 'CCSGameRulesProxy', 'm_iRoundTime');
    }

    function getFreezeTime() {
      return Convar.GetFloat('mp_freezetime');
    }

    function getBombTime() {
      return Convar.GetFloat('mp_c4timer');
    }

    function isFreezeTime() {
      return Entity.GetProp(this.getGameRulesProxy(), 'CCSGameRulesProxy', 'm_bFreezePeriod');
    }

    function isWarmup() {
      return Entity.GetProp(this.getGameRulesProxy(), 'CCSGameRulesProxy', 'm_bWarmupPeriod');
    }

    function getHitboxPosition(entity, hitbox) {
      return Entity.GetHitboxPosition(entity, hitbox);
    }

    function getHitboxPositionScreen(entity, hitbox) {
      return Render.WorldToScreen(this.getHitboxPosition(entity, hitbox));
    }

    function getRoundKills(entity) {
      entity = entity || this.local;
      return Entity.GetProp(entity, 'CCSPlayer', 'm_iNumRoundKills')
    }

    function isThirdPerson() {
      return UI.GetValue(['Misc.', 'Keys', 'Keys', 'Thirdperson']);
    }

    function isLeftHand() {
      const rightHand = Convar.GetFloat('cl_righthand');
      const inverted = UI.GetValue(['Misc.', 'View', 'Viewmodel', 'Flip knife hand']);

      if (inverted) {
        const weaponId = Client.getWeaponID();
        var isKnife = false;

        if (weaponId === 41 || weaponId === 42 || weaponId === 59 || weaponId > 500)
          isKnife = true;

        return isKnife ? (rightHand ? true : false) : (rightHand ? false : true);
      }

      return rightHand ? false : true;
    }

    function getFlags(entity) {
      entity = entity || this.local;
      return Entity.GetProp(entity, 'CBasePlayer', 'm_fFlags');
    }

    function setPoseParameter(pose, fraction) {
      Local.OverridePoseParam(pose, fraction);
    }

    function getViewAngles() {
      return Local.GetViewAngles();
    }

    function getTeamID(entity) {
      entity = entity || this.local;
      return Entity.GetProp(entity, 'CBaseEntity', 'm_iTeamNum');
    }

    function getPlayerCount() {
      const enemies = Entity.GetEnemies();
      const teammates = Entity.GetTeammates();

      var enemyCount = 0;
      var teamCount = 0;

      for (var i = 0; i < enemies.length; ++i) {
        if (Entity.IsAlive(enemies[i]))
          enemyCount++;
      }

      for (var i = 0; i < teammates.length; ++i) {
        if (Entity.IsAlive(teammates[i]))
          teamCount++;
      }

      return {
        enemy: enemyCount,
        team: teamCount
      };
    }

    function getNextPrimaryAttack(entity) {
      entity = entity || this.local;

      const weapon = Client.getWeapon(entity);

      if (!weapon)
        return 1;

      const info = Entity.GetCCSWeaponInfo(weapon);

      if (!info)
        return 1;

      const nextPrimaryAttack = Entity.GetProp(weapon, 'CBaseCombatWeapon', 'm_flNextPrimaryAttack');

      return 1 - Math.max(nextPrimaryAttack - Globals.Curtime(), 0) / info.cycle_time;
    }

    return {
      // Fields
      local: 0,
      spectating: false,

      roundStartTime: 0,

      // Methods
      update: update,
      getOrigin: getOrigin,
      getName: getName,
      getHealth: getHealth,
      getArmor: getArmor,
      getFromUserID: getFromUserID,
      getWeapon: getWeapon,
      getWeapons: getWeapons,
      getWeaponID: getWeaponID,
      getWeaponIDS: getWeaponIDS,
      getWeaponName: getWeaponName,
      getWeaponAmmo: getWeaponAmmo,
      getAnimationInfo: getAnimationInfo,
      getGameRulesProxy: getGameRulesProxy,
      getRoundTime: getRoundTime,
      getFreezeTime: getFreezeTime,
      getBombTime: getBombTime,
      getFlags: getFlags,
      getTeamID: getTeamID,
      getHitboxPosition: getHitboxPosition,
      getHitboxPositionScreen: getHitboxPositionScreen,
      getRoundKills: getRoundKills,
      getViewAngles: getViewAngles,
      getPlayerCount: getPlayerCount,
      getNextPrimaryAttack: getNextPrimaryAttack,
      setPoseParameter: setPoseParameter,
      isAnimationActive: isAnimationActive,
      isAlive: isAlive,
      isDormant: isDormant,
      isEnemy: isEnemy,
      isScoped: isScoped,
      isThirdPerson: isThirdPerson,
      isLeftHand: isLeftHand,
      isFreezeTime: isFreezeTime,
      isWarmup: isWarmup
    };
  }
  ());
// #endregion Client

// #region MaterialSystem
const MaterialSystem = (function namespace() {
    function add(matname, properties) {
      var mat = "";

      for (var name in properties) {
        var param = properties[name];

        if (name === 'proxies') {
          mat += "proxies { ";

          for (var proxy in param) {
            var props = param[proxy];

            mat += proxy + " { ";

            for (var prop in props) {
              var _param = props[prop];

              mat += prop + " " + _param + " ";
            }

            mat += " }";
          }

          mat += " }";
        } else {
          mat += "$" + name + " " + param + " ";
        }
      }

      this.materialList[this.materialList.length] = matname;

      Material.CreateInitialized(matname, mat);
    }

    function destroy(matname) {
      const indexOf = this.materialList.indexOf(matname)

      if (indexOf !== -1)
        this.materialList.slice(indexOf, 1);

      Material.Destroy(matname);
    }

    function reset() {
      for (var i = 0; i < this.materialList.length; ++i) {
        Material.Destroy(this.materialList[i]);
      }
    }

    function setKey(matname, key, value) {
      const index = Material.Get(matname);

      if (value instanceof Array) {
        value = "[ " + value[0] + " " + value[1] + " " + value[2] + " ]";
      } else {
        value = value.toString();
      }

      Material.SetKeyValue(index, key, value);
    }

    function update(matname) {
      const index = Material.Get(matname);

      Material.Refresh(index);
    }

    return {
      // Fields
      materialList: [],

      // Methods
      add: add,
      destroy: destroy,
      reset: reset,
      setKey: setKey,
      update: update
    };
  }
  ());
// #endregion MaterialSystem

// #region Colors
const Colors = (function namespace() {
    function update() {
      for (var label in this.pickerList) {
        const path = this.pickerList[label];

        this[label] = UI.GetColor(path);
      }
    }

    function initialize() {
      for (var label in this.pickerList) {
        const path = this.pickerList[label];
        const color = UI.GetColor(path);

        if (
          color[0] === 255 &&
          color[1] === 255 &&
          color[2] === 255 &&
          color[3] === 255
        ) {
          UI.SetColor(path, this[label]);
        }
      }
    }

    return {
      // Fields
      pickerList: {
        mainAccent: UI.AddColorPicker(['Config', 'Signal | Colors', 'Signal | Colors'], 'Main accent color'),
        secAccent: UI.AddColorPicker(['Config', 'Signal | Colors', 'Signal | Colors'], 'Secondary accent color'),
        killfeed: UI.AddColorPicker(['Config', 'Signal | Colors', 'Signal | Colors'], 'Killfeed color'),
        inventoryDormant: UI.AddColorPicker(['Config', 'Signal | Colors', 'Signal | Colors'], 'Inventory dormant color'),
        inventoryActive: UI.AddColorPicker(['Config', 'Signal | Colors', 'Signal | Colors'], 'Inventory active color'),
        indicators: UI.AddColorPicker(['Config', 'Signal | Colors', 'Signal | Colors'], 'Indicator primary color'),
        indicatorsSec: UI.AddColorPicker(['Config', 'Signal | Colors', 'Signal | Colors'], 'Indicators secondary color'),
      },

      mainAccent: [34, 36, 36, 175],
      secAccent: [235, 235, 235, 225],
      killfeed: [96, 36, 36, 125],
      inventoryDormant: [125, 125, 125, 75],
      inventoryActive: [200, 200, 200, 125],
      indicators: [225, 225, 225, 125],
      indicatorsSec: [125, 125, 125, 75],

      // Methods
      update: update,
      initialize: initialize
    };
  }
  ());
// #endregion Colors
// #endregion Namespaces

// #region Modules
// #region Health
const HealthBar = (function module() {
    function run() {
      this.render();
      this.update();
    }

    function shouldRun() {
      return Client.local && Client.isAlive();
    }

    function render() {
      const bgWidth = 550
      const bgHeight = 50;
      const barWidth = 100;
      const barHeight = 10;
      const x = 0
      const y = Render.GetScreenSize()[1] - bgHeight;

      const activeAnimFrac = this.activeAnim.get();
      const hurtAnimFrac = this.hurtAnim.get();
      const wearAnimFrac = this.wearAnim.get();

      const health = Client.getHealth();
      const healthFrac = Utils.clamp(this.displayHealth * 0.01, 0, 1);
      const hpWidth = Utils.clamp(healthFrac * barWidth, 10, barWidth);
      const hpColor = Anim.color(Colors.secAccent, Anim.color([255, 35, 35, 225], [200, 255, 35, 225], healthFrac), hurtAnimFrac);
      const hpColor2 = [hpColor[0], hpColor[1], hpColor[2], 75];

      const armor = Client.getArmor();
      const armorFrac = Utils.clamp(this.displayArmor * 0.01, 0, 1);
      const armorWidth = armorFrac * barWidth;
      const armorColor = Anim.color(Colors.secAccent, [65, 180, 245, 225], wearAnimFrac);
      const armorColor2 = [armorColor[0], armorColor[1], armorColor[2], 75];

      const sinTime = Math.abs(Math.sin(Globals.Curtime() * 0.25));
      const cosTime = Math.abs(Math.cos(Globals.Curtime() * 0.25));

      this.displayHealth = Anim.approximate(this.displayHealth, health, 5);
      this.displayArmor = Anim.approximate(this.displayArmor, armor, 5);

      Renderer.setRenderWeight(activeAnimFrac);

      // Background
      Renderer.drawGradient(x, y, bgWidth, bgHeight, [Colors.mainAccent[0], Colors.mainAccent[1], Colors.mainAccent[2], 0],
        Colors.mainAccent, false, 0.25);

      // Damage bar
      if (hurtAnimFrac > 0) {
        const hurtFrac = Utils.clamp(this.hurtDisplayHealth * 0.01, 0, 1);
        const hurtWidth = Utils.clamp(hurtFrac * barWidth, 40, barWidth);
        const hurtColor = [235, 145, 145, 245];

        Renderer.setRenderWeight(activeAnimFrac * hurtAnimFrac);

        Renderer.drawRect(x + 122, y + 27, hurtWidth - 4, barHeight - 4, hurtColor);

        Renderer.setRenderWeight(activeAnimFrac);
      }

      // Health bar
      Renderer.drawString(x + 35, y + 22, hpColor, fontSmall, 'HP', 'shadow');
      Renderer.drawString(x + 85, y + 17, hpColor, fontMain, health.toString(), 'shadow', 'center');
      Renderer.drawRectOutlined(x + 120, y + 25, barWidth, barHeight, [24, 26, 26, 125], [44, 46, 46, 55]);
      Renderer.drawGradient(x + 122, y + 27, hpWidth - 4, barHeight - 4, hpColor2, hpColor, false, sinTime);
      Renderer.drawGradient(x + 122, y + 27, hpWidth - 4, barHeight - 4, hpColor2, hpColor, true, 1 - cosTime);

      if (armor <= 0)
        return;

      // Wear bar
      x += barWidth + 125;

      if (wearAnimFrac > 0) {
        const wearFrac = Utils.clamp(this.wearDisplayArmor * 0.01, 0, 1);
        const wearWidth = Utils.clamp(wearFrac * barWidth, 40, barWidth);
        const wearColor = [45, 160, 225, 245];

        Renderer.setRenderWeight(activeAnimFrac * wearAnimFrac);

        Renderer.drawRect(x + 122, y + 27, wearWidth - 4, barHeight - 4, wearColor);

        Renderer.setRenderWeight(activeAnimFrac);
      }

      // Armor bar
      Renderer.drawString(x + 35, y + 22, armorColor, fontSmall, 'AP', 'shadow');
      Renderer.drawString(x + 85, y + 17, armorColor, fontMain, armor.toString(), 'shadow', 'center');
      Renderer.drawRectOutlined(x + 120, y + 25, barWidth, barHeight, [24, 26, 26, 125], [44, 46, 46, 55]);
      Renderer.drawGradient(x + 122, y + 27, armorWidth - 4, barHeight - 4, armorColor2, armorColor, false, sinTime);
      Renderer.drawGradient(x + 122, y + 27, armorWidth - 4, barHeight - 4, armorColor2, armorColor, true, 1 - cosTime);
    }

    function update() {
      this.hurtAnim.update(false);
      this.wearAnim.update(false);
      this.activeAnim.update(Client.isAlive());

      if (this.hurtAnim.weight === 0)
        this.hurtDisplayHealth = 0;

      if (this.wearAnim.weight === 0)
        this.wearDisplayArmor = 0;
    }

    function onHurt() {
      if (Client.getFromUserID(Event.GetInt('userid')) !== Client.local)
        return;

      const dmgHealth = Event.GetInt('dmg_health');
      const dmgArmor = Event.GetInt('dmg_armor');

      const health = dmgHealth + Event.GetInt('health');
      const armor = dmgArmor + Event.GetInt('armor');

      if (dmgHealth >= 1) {
        this.hurtAnim.weight = 1;
        this.hurtDisplayHealth = Math.max(this.hurtDisplayHealth, health);
      }

      if (dmgArmor >= 1) {
        this.wearAnim.weight = 1;
        this.wearDisplayArmor = Math.max(this.wearDisplayArmor, armor);
      }
    }

    return {
      module: 'HealthBar',

      // Fields
      hurtAnim: new Anim(2.5, false),
      wearAnim: new Anim(2.5, false),
      activeAnim: new Anim(0.5, false),

      displayHealth: 100,
      displayArmor: 100,
      hurtDisplayHealth: 0,
      wearDisplayArmor: 0,

      // Methods
      run: run,
      shouldRun: shouldRun,

      render: render,
      update: update,

      onHurt: onHurt
    };
  }
  ());

ModuleManager.add(HealthBar);
// #endregion Health

// #region Inventory
const Inventory = (function module() {
    function run() {
      this.update();
      this.render();
    }

    function shouldRun() {
      return Client.local && Client.isAlive();
    }

    function render() {
      const inventory = this.getSortedInventory();
      const weaponId = Client.getWeaponID();
      const weaponAmmo = Client.getWeaponAmmo();

      const activeAnimFrac = this.activeAnim.get();
      const fireAnimFrac = this.fireAnim.get();
      const reloadAnimFrac = this.reloadAnim.get();

      const bgWidth = 350;
      const bgHeight = 50;
      const barWidth = 100;
      const barHeight = 10;
      const x = Render.GetScreenSize()[0] - bgWidth;
      const y = Render.GetScreenSize()[1] - bgHeight;

      const ammoColor = Anim.color(Colors.secAccent, [255, 225, 155, 245], fireAnimFrac);
      const ammoColor2 = [ammoColor[0], ammoColor[1], ammoColor[2], 125];
      const ammoSize = Renderer.getStringSize(weaponAmmo.reserve.toString(), fontSmall)[0];

      const roundKills = Client.getRoundKills();

      Renderer.setRenderWeight(activeAnimFrac);

      // Background
      Renderer.drawGradient(x, y, bgWidth, bgHeight, [Colors.mainAccent[0], Colors.mainAccent[1], Colors.mainAccent[2], 0],
        Colors.mainAccent, false, 0.75);

      // Weapon icon
      if (Client.spectating || !this.isFiring)
        Renderer.drawString(x + bgWidth - 75, y + 25, ammoColor, fontWeapons,
          idToIconMap[weaponId] || '', 'shadow', 'center');

      else {
        const iconSize = Renderer.getStringSize(idToIconMap[weaponId] || '', fontWeapons)[0];

        Renderer.drawString(x + bgWidth - 75, y + 25, [100, 100, 100, 235], fontWeapons,
          idToIconMap[weaponId] || '', 'default', 'center');

        Renderer.drawString(x + bgWidth - 75, y + 25, ammoColor, fontWeapons, idToIconMap[weaponId] || '', 'default', 'center');
      }

      // Weapon ammo
      if (weaponAmmo.primary >= 0) {
        Renderer.setRenderWeight(activeAnimFrac * (1 - reloadAnimFrac));

        Renderer.drawString(x + bgWidth - 135, y + 20, ammoColor2, fontSmall, weaponAmmo.reserve.toString(), 'shadow', 'right');
        Renderer.drawString(x + bgWidth - ammoSize - 145, y + 3, ammoColor, fontMain, weaponAmmo.primary.toString(), 'shadow', 'right');
      }

      if (reloadAnimFrac > 0) {
        const reloadWidth = this.reloadAmt * barWidth;
        const reloadColor = Anim.color([255, 35, 35, 225], [200, 255, 35, 225], this.reloadAmt)
        const reloadColor2 = [reloadColor[0], reloadColor[1], reloadColor[2], 75];

        const sinTime = Math.abs(Math.sin(Globals.Curtime() * 0.25));
        const cosTime = Math.abs(Math.cos(Globals.Curtime() * 0.25));

        Renderer.setRenderWeight(activeAnimFrac * reloadAnimFrac);

        Renderer.drawRectOutlined(x + bgWidth - barWidth - 140, y + 20, barWidth, barHeight, [24, 26, 26, 125], [44, 46, 46, 55]);
        Renderer.drawGradient(x + bgWidth - barWidth - 138, y + 22, reloadWidth - 4, barHeight - 4, reloadColor2, reloadColor, false, sinTime);
        Renderer.drawGradient(x + bgWidth - barWidth - 138, y + 22, reloadWidth - 4, barHeight - 4, reloadColor2, reloadColor, true, 1 - cosTime);
      }

      Renderer.setRenderWeight(activeAnimFrac);

      if (roundKills > 0) {
        Renderer.drawString(x + bgWidth - 270, y + bgHeight - 33, this.killAnim.color(Colors.secAccent, [235, 145, 145, 225]), fontSmall,
          roundKills.toString(), 'shadow', 'right');
        Renderer.drawString(x + bgWidth - 265, y + bgHeight - 32, [235, 145, 145, 225], fontIconSmall, 'a', 'shadow', 'left');
      }

      if (Client.spectating)
        return;

      for (var i = 0, offset = 0; i < inventory.length; ++i) {
        const current = inventory[i];
        const name = idtoNameMap[current.id];
        const animFrac = this.inventoryAnim[i].get();
        const color = Anim.color(Colors.inventoryDormant, Colors.inventoryActive, animFrac);
        const color2 = [color[0], color[1], color[2], 0];

        Renderer.drawGradient(x + bgWidth - 125, y - offset - 40, bgWidth - 125, 35, color2, color, false, 0.25)

        Renderer.drawRect(x + bgWidth - 25, y - offset - 30, 15, 15, [155, 155, 155, 125]);
        Renderer.drawString(x + bgWidth - 19, y - offset - 24, [45, 45, 45, 225], fontSmall, current.slot.toString(), 'default', 'center');

        Renderer.drawString(x + bgWidth - 75, y - offset - 25, Colors.secAccent, fontWeapons,
          idToIconMap[current.id] || '', 'shadow', 'center');
        Renderer.drawString(x + bgWidth - 125, y - offset - 30, [Colors.secAccent[0], Colors.secAccent[1], Colors.secAccent[2],
          Anim.value(0, 125, animFrac)
        ], fontSmall, name, 'shadow', 'right');

        offset += 40;
      }
    }

    function update() {
      const layer = Client.getAnimationInfo(Client.local, 1);
      const inventory = this.getSortedInventory();
      const weapon = Client.getWeaponID();

      const isFiring = layer.Activity >= 961 && layer.Activity <= 966 && layer.Weight > 0.5;
      const isReloading = layer.Activity >= 967 && layer.Activity <= 970 && layer.Weight > 0

      this.activeAnim.update(Client.isAlive());
      this.fireAnim.update(isFiring);
      this.reloadAnim.update(isReloading);
      this.killAnim.update(false);

      if (isReloading)
        this.reloadAmt = Anim.approximate(this.reloadAmt, layer.Cycle, 8);

      for (var i = 0; i < inventory.length; ++i)
        this.inventoryAnim[i].update(inventory[i].id === weapon);

      this.isFiring = layer.Activity >= 961 && layer.Activity <= 966;

      if (isFiring & !this.lastFiring)
        this.cycleTime = 0;

      this.cycleTime = Anim.approximate(this.cycleTime, Client.getNextPrimaryAttack(), 12);
      this.lastFiring = isFiring;
    }

    function getSortedInventory() {
      const inventory = Client.getWeaponIDS();
      const order = [5, 3, 2, 1, 4];

      if (!inventory)
        return [];

      var sortedInventory = [];

      for (var j = 0; j < order.length; j++) {
        const slot = order[j];

        for (var i = 0; i < inventory.length; ++i) {
          const id = inventory[i];

          if (idToSlotMap[id] === slot)
            sortedInventory[sortedInventory.length] = {
              id: id,
              slot: slot
            };
        }
      }

      return sortedInventory;
    }

    function onDeath() {
      if (Client.getFromUserID(Event.GetInt('attacker')) === Client.local)
        this.killAnim.weight = 1;
    }

    return {
      module: 'Inventory',

      // Fields
      activeAnim: new Anim(0.5, false),
      killAnim: new Anim(0.5, false),
      fireAnim: new Anim(0.15, false),
      reloadAnim: new Anim(0.25, false),
      inventoryAnim: (function () {
        var arr = [];
        for (var i = 0; i < 10; ++i) arr[i] = new Anim(0.25, false);
        return arr;
      })(),

      reloadAmt: 0,

      cycleTime: 0,

      isFiring: false,
      lastFiring: false,

      // Methods
      run: run,
      shouldRun: shouldRun,

      render: render,
      update: update,

      onDeath: onDeath,

      getSortedInventory: getSortedInventory
    };
  }
  ());

ModuleManager.add(Inventory);
// #endregion Inventory

// #region Killfeed
const Killfeed = (function module() {
    function run() {
      this.render();
    }

    function shouldRun() {
      return Client.local && Entity.IsValid(Entity.GetLocalPlayer());
    }

    function render() {
      const feedWidth = 100; // Redudant?
      const feedHeight = 25;
      const x = Render.GetScreenSize()[0] - feedWidth;
      const y = UI.GetValue(['Misc.', 'Helpers', 'General', 'Watermark']) ? 25 : 10;

      for (var i = this.killfeedList.length - 1, offset = 0; i >= 0; --i) {
        const current = this.killfeedList[i];

        const fx = x + feedWidth;
        const fy = y + offset;

        const timeLeft = current.getTimeLeft();
        const beginTime = current.getBeginTime();

        const attackerSize = Renderer.getStringSize(current.attacker, fontAverage)[0];
        const victimSize = Renderer.getStringSize(current.victim, fontAverage)[0];
        const weaponSize = Renderer.getStringSize(current.weapon, fontWeaponsSmall)[0];

        const backgroundColor = current.priority ? Colors.killfeed : Colors.mainAccent;

        if (current.headshot)
          victimSize += 25;

        const totalSize = attackerSize + victimSize + weaponSize + 20;

        current.run();

        if (timeLeft === 0 && beginTime === 0) {
          this.killfeedList.splice(i, 1);
          continue;
        }

        Renderer.setRenderWeight(beginTime);

        Renderer.drawGradient(fx - totalSize, fy + 12, totalSize, feedHeight, [Colors.mainAccent[0], Colors.mainAccent[1], Colors.mainAccent[2], 0],
          backgroundColor, false, 0.75);

        Renderer.drawString(fx - 5, fy + feedHeight / 2, Colors.secAccent, fontAverage, current.begin.string(current.victim), 'shadow', 'right');
        Renderer.drawString(fx - victimSize - 10, fy + feedHeight / 2 + 5, Colors.secAccent, fontWeaponsSmall, current.weapon, 'shadow', 'right');
        Renderer.drawString(fx - victimSize - weaponSize - 15, fy + feedHeight / 2, Colors.secAccent, fontAverage, current.begin.string(current.attacker), 'shadow', 'right');

        if (current.headshot)
          Renderer.drawString(fx - victimSize + 12, fy + feedHeight / 2 + 5, [195, 145, 145, 245], fontWeaponsSmall, 's', 'shadow', 'right');

        if (current.assister)
          Renderer.drawString(fx - totalSize, fy + feedHeight / 2, [225, 225, 225, 200], fontAverage, current.begin.string(current.assister) + " + ", 'shadow', 'right');

        offset += (feedHeight + 10) * beginTime;
      }
    }

    function reset() {
      this.killfeedList = [];
    }

    function onDeath() {
      const attacker = Client.getName(Client.getFromUserID(Event.GetInt('attacker'))) || "World";
      const victim = Client.getName(Client.getFromUserID(Event.GetInt('userid')));
      const weapon = idToIconMap[Client.getWeaponID(Client.getFromUserID(Event.GetInt('attacker')))] || "";
      const headshot = Event.GetInt('headshot');

      const weaponName = Event.GetString('weapon');
      if (weaponName === 'hegrenade') {
        weapon = idToIconMap[44];
      } else if (weaponName === 'inferno') {
        weapon = idToIconMap[46];
      }

      const assister = Event.GetInt('assister');
      if (assister) {
        assister = Client.getName(Client.getFromUserID(assister));
      }

      this.killfeedList.unshift(new KillInfo(attacker, victim, assister, weapon, headshot,
        Client.getFromUserID(Event.GetInt('attacker')) === Client.local || Client.getFromUserID(Event.GetInt('assister')) === Client.local));

      if (this.killfeedList.length > 16)
        this.killfeedList.pop();
    }

    return {
      module: 'Killfeed',

      // Fields
      killfeedList: [],
      killAmount: 0,

      // Methods
      run: run,
      shouldRun: shouldRun,

      render: render,
      reset: reset,

      onDeath: onDeath
    };
  }
  ());

ModuleManager.add(Killfeed);
// #endregion Killfeed

// #region Crosshair
const Crosshair = (function module() {
    function run() {
      this.render();
      this.update();
    }

    function shouldRun() {
      return UI.GetValue(this.enabled) && Client.local && Entity.IsValid(Entity.GetLocalPlayer()) && !Client.isScoped();
    }

    function render() {
      const size = this.scopedAnim.value(24, 512);
      const x = Render.GetScreenSize()[0] / 2;
      const y = Render.GetScreenSize()[1] / 2;

      Renderer.setRenderWeight(this.activeAnim.get());

      Renderer.drawGradient(x - size / 2, y, size, 1, [235, 235, 235, 245], [125, 125, 125, 0], false, 0.5);
      Renderer.drawGradient(x, y - size / 2, 1, size, [235, 235, 235, 245], [125, 125, 125, 0], true, 0.5);
    }

    function update() {
      this.activeAnim.update(Client.isAlive());
      this.scopedAnim.update(Client.isScoped());
    }

    return {
      module: 'Crosshair',

      // Fields
      activeAnim: new Anim(0.5, false),
      scopedAnim: new Anim(0.1, false),
      enabled: UI.AddCheckbox(['Config', 'Signal', 'Signal'], 'Enable crosshair'),

      // Methods
      run: run,
      shouldRun: shouldRun,

      render: render,
      update: update
    };
  }
  ());

ModuleManager.add(Crosshair);
// #endregion Crosshair

// #region Chat
const Chat = (function module() {
    function run() {
      this.render();
      this.update();
    }

    function shouldRun() {
      return Client.local && Entity.IsValid(Client.local) && UI.GetValue(this.enabled);
    }

    function render() {
      const x = 0;
      const y = Render.GetScreenSize()[1] - 125;
      const max = 4;

      if (this.strBuilder.active) {
        Renderer.drawGradient(x, y + 30, 225, 25, Colors.mainAccent, [Colors.mainAccent[0], Colors.mainAccent[2], Colors.mainAccent[2], 0], false, 1);
        Renderer.drawString(x + 5, y + 34, Colors.secAccent, fontChat, this.strBuilder.text, 'shadow');
      }

      this.chatOffset = !this.strBuilder.active ? 0 : Utils.clamp(this.chatOffset + InputSys.getScrollDelta(), 0, this.messageList.length * 15);

      for (var i = 0, oy = 0; i < this.messageList.length; ++i) {
        const current = this.messageList[i];
        const visible = i <= max || this.strBuilder.active;

        if (!visible)
          continue;

        const animFrac = current.anim.get();
        const authorSize = Renderer.getStringSize(current.getAuthor(), fontChat)[0];
        const teamColor = ({
          1: [200, 200, 200, 225],
          2: [235, 125, 125, 225],
          3: [125, 125, 235, 225]
        })[current.getTeam()];

        current.anim.update(visible);

        Renderer.setRenderWeight(animFrac);

        Renderer.drawGradient(x, y - oy + this.chatOffset, 225, 30, Colors.mainAccent, [Colors.mainAccent[0], Colors.mainAccent[2], Colors.mainAccent[2], 0], false, 1);
        Renderer.drawString(x + 5, y - oy + 5 + this.chatOffset, teamColor, fontChat, current.getAuthor(), 'outline');
        Renderer.drawString(x + authorSize + 10, y - oy + 5 + this.chatOffset, Colors.secAccent, fontChat, current.anim.string(current.getMessage()), 'shadow');

        oy += 30 * animFrac;
      }
    }

    function update() {
      const shouldOpen = InputSys.isPressed(0x55) || InputSys.isPressed(0x59);
      const shouldClose = InputSys.isPressed(0x1B);
      const shouldSend = InputSys.isPressed(0x0D);

      const isConsoleOpen = Input.IsConsoleOpen();

      this.activeAnim.update(Client.isAlive());

      if (shouldSend && this.strBuilder.active) {
        Cheat.ExecuteCommand('say ' + this.strBuilder.text);
        Input.ForceCursor(0);

        this.strBuilder.active = false;
        this.strBuilder.text = "";
      }

      if (shouldOpen && !isConsoleOpen && !this.lastKeyState && !this.strBuilder.active) {
        Input.ForceCursor(1);

        this.strBuilder.active = true;
      }

      this.lastState = shouldOpen;

      if (shouldClose) {
        Input.ForceCursor(0);

        this.strBuilder.active = false;
      }

      if (!isConsoleOpen)
        this.strBuilder.run();
    }

    function onChat() {
      const author = Client.getFromUserID(Event.GetInt('userid'));
      const message = Event.GetString('text');
      const team = Client.getTeamID(author);

      if (this.messageList.length > 64)
        this.messageList.pop();

      this.messageList.unshift(new Message(message, Client.getName(author), team));
    }

    function onCreateMove() {
      if (this.strBuilder.active) {
        const buttons = UserCMD.GetButtons();

        buttons &= ~(1 << 1);
        buttons &= ~(1 << 2);

        UserCMD.SetButtons(buttons);
        UserCMD.SetMovement([0, 0, 0]);
      }
    }

    function reset() {
      this.strBuilder.text = "";
      this.messageList = [];
    }

    return {
      module: 'Chat',

      // Fields
      enabled: UI.AddCheckbox(['Config', 'Signal', 'Signal'], 'Chat'),
      activeAnim: new Anim(0.5, false),

      strBuilder: new StringBuilder(),
      lastState: false,
      chatOffset: 0,

      messageList: [],

      // Methods
      run: run,
      shouldRun: shouldRun,

      render: render,
      update: update,
      reset: reset,

      onChat: onChat,
      onCreateMove: onCreateMove
    };
  }
  ());

ModuleManager.add(Chat);
// #endregion Chat

// #region Antiaim
const Antiaim = (function module() {
    function run() {
      this.render();
      this.update();
    }

    function shouldRun() {
      return Client.local && Entity.IsValid(Entity.GetLocalPlayer());
    }

    function render() {
      const gap = 75;
      const size = 20;
      const x = Render.GetScreenSize()[0] / 2;
      const y = Render.GetScreenSize()[1] / 2;

      Renderer.setRenderWeight(this.activeAnim.get());

      for (var i = 0; i < size; i += size / 10) {
        Renderer.drawTriangle(x - gap - i, y, x - gap, y - i / 2, x - gap, y + i / 2, this.leftSideAnim.color([25, 25, 25, 45], [235, 235, 235, 55]), false);
        Renderer.drawTriangle(x + gap, y - i / 2, x + gap + i, y, x + gap, y + i / 2, this.rightSideAnim.color([25, 25, 25, 45], [235, 235, 235, 55]), false);
      }
    }

    function update() {
      const pressingLeft = UI.GetValue(this.leftHotkey);
      const pressingRight = UI.GetValue(this.rightHotkey);

      if (pressingLeft && this.lastActiveInput !== 1) {
        this.side = this.side === -1 ? 0 : -1;
        this.lastActiveInput = 1;
      } else if (pressingRight && this.lastActiveInput !== 2) {
        this.side = this.side === 1 ? 0 : 1;
        this.lastActiveInput = 2;
      } else if (!pressingRight && !pressingLeft) {
        this.lastActiveInput = 0;
      }

      UI.SetValue(['Rage', 'Anti Aim', 'Directions', 'Yaw offset'], this.side === 0 ? 0 : UI.GetValue(this.offset) * this.side);

      this.activeAnim.update(
        Client.isAlive() &&
        !Client.spectating &&
        this.side !== 0
      );

      this.leftSideAnim.update(this.side === -1);
      this.rightSideAnim.update(this.side === 1);
    }

    return {
      module: 'Antiaim',

      // Fields
      activeAnim: new Anim(0.25, false),
      leftSideAnim: new Anim(0.1, false),
      rightSideAnim: new Anim(0.1, false),
      side: 0,

      leftHotkey: UI.AddHotkey(['Config', 'Scripts', 'Keys', 'JS Keybinds'], '[Signal] Override left', 'Override left'),
      rightHotkey: UI.AddHotkey(['Config', 'Scripts', 'Keys', 'JS Keybinds'], '[Signal] Override right', 'Override right'),
      offset: UI.AddSliderInt(['Config', 'Signal', 'Signal'], 'Manual anti-aim yaw offset', 0, 90),
      lastActiveInput: 0,

      // Methods
      run: run,
      shouldRun: shouldRun,

      render: render,
      update: update
    };
  }
  ());

ModuleManager.add(Antiaim);
// #endregion Antiaim

// #region Indicators
const Indicators = (function module() {
    function run() {
      this.render();
      this.update();
    }

    function shouldRun() {
      return Client.local && Client.isAlive() && Entity.IsValid(Entity.GetLocalPlayer());
    }

    function render() {
      const indWidth = 25;
      const indHeight = 25;

      var x, y;

      if (UI.GetValue(this.dynamic) && Client.isThirdPerson()) {
        const thirdPerson = Client.isThirdPerson();
        const leftHand = Client.isLeftHand();

        const pos = Client.getHitboxPositionScreen(Client.local, 3)

        if (pos) {
          this.x = Anim.approximate(this.x, pos[0] + (thirdPerson ? -150 : (leftHand ? 75 : -75)), 2.5);
          this.y = Anim.approximate(this.y, pos[1] + (thirdPerson ? -75 : -50), 2.5);

          this.x = Utils.clamp(this.x, pos[0] - 150, pos[0] + 75);
          this.y = Utils.clamp(this.y, pos[1] - 75, pos[1] - 50);
        }

        x = this.x;
        y = this.y;
      } else {
        x = Render.GetScreenSize()[0] / 2
        y = Render.GetScreenSize()[1] / 2 + 45;
      }

      for (var i = 0, ox = 0, oy = 0; i < this.indicatorList.length; ++i) {
        const current = this.indicatorList[i];
        const cosTime = Math.abs(Math.cos(Globals.Curtime() * 0.5 + i))
        const sinTime = Math.abs(Math.sin(Globals.Curtime() * 0.5 + i))

        const ix = x + ox;
        const iy = y + oy;

        const activeAnimFrac = current.active.get();

        if (current.label === 'DT' || current.label === 'HS') {
          current.weight = Anim.approximate(current.weight, Exploit.GetCharge(), 5);
        }

        current.update();

        Renderer.setRenderWeight(activeAnimFrac);

        Renderer.drawGradient(ix - indWidth / 2, iy, indWidth, indHeight, [Colors.indicatorsSec[0], Colors.indicatorsSec[1], Colors.indicatorsSec[2], 0],
          Anim.color(Colors.indicatorsSec, Colors.indicators, sinTime * cosTime), false, sinTime, true);
        Renderer.drawGradient(ix - indWidth / 2, iy, indWidth, indHeight, [Colors.indicatorsSec[0], Colors.indicatorsSec[1], Colors.indicatorsSec[2], 0],
          Colors.indicatorsSec, true, cosTime, true);

        if (current.weight < 1) {
          Renderer.drawString(ix, iy + indHeight / 2 - 2, [125, 125, 125, 225], fontSmall, current.label, 'outline', 'center');
        }

        Renderer.drawString(ix, iy + indHeight / 2 - 2, Colors.secAccent, fontSmall, current.label, 'outline', 'center');

        oy += 30 * activeAnimFrac;
      }
    }

    function update() {
      this.activeAnim.update(Client.isAlive());
    }

    return {
      module: 'Indicators',

      // Fields
      dynamic: UI.AddCheckbox(['Config', 'Signal', 'Signal'], 'Dynamic indicators'),
      x: 960,
      y: 540,

      activeAnim: new Anim(0.25, false),

      indicatorList: [
        new Indicator('DT', ['Rage', 'Exploits', 'Keys', 'Key assignment', 'Double tap']),
        new Indicator('HS', ['Rage', 'Exploits', 'Keys', 'Key assignment', 'Hide shots']),
        new Indicator('FD', ['Rage', 'Anti Aim', 'General', 'Key assignment', 'Fake duck']),
        new Indicator('DMG', ['Rage', 'General', 'General', 'Key assignment', 'Damage override']),
        new Indicator('HIT', ['Rage', 'General', 'General', 'Key assignment', 'Hitbox override']),
        new Indicator('AP', ['Misc.', 'Keys', 'Keys', 'Key assignment', 'Auto peek']),
        new Indicator('BA', ['Rage', 'General', 'General', 'Key assignment', 'Force body aim']),
        new Indicator('HC', ['Config', 'Scripts', 'Keys', 'JS Keybinds', '[Signal] Hitchance override'])
      ],

      // Methods
      run: run,
      shouldRun: shouldRun,

      render: render,
      update: update
    };
  }
  ());

ModuleManager.add(Indicators);
// #endregion Indicators

// #region Clock
const Clock = (function module() {
    function run() {
      this.render();
    }

    function shouldRun() {
      return Client.local && Entity.IsValid(Entity.GetLocalPlayer());
    }

    function render() {
      const x = Render.GetScreenSize()[0] / 2
      const y = 0;
      const w = 100;
      const h = this.isPlanted ? 50 : 35;

      const timeLeft = this.getTimeLeft();
      const isWarmup = Client.isWarmup();

      if (!timeLeft && !isWarmup)
        return;

      Renderer.setRenderWeight(1)

      Renderer.drawGradient(x - w / 2, y, w, h, [Colors.mainAccent[0], Colors.mainAccent[1], Colors.mainAccent[2], 0], Colors.mainAccent, false, 0.5)
      Renderer.drawString(x, y + 14, Colors.secAccent, fontAverage, isWarmup ? "Warm-up" : timeLeft, 'shadow', 'center');

      if (this.isPlanted) {
        Renderer.drawString(x, y + 40, Anim.color(Colors.secAccent, [235, 145, 145, 200], Math.abs(Math.sin(Globals.Curtime() * 4))), fontWeaponsSmall, 'o', 'shadow', 'center');
      }
    }

    function onRound() {
      this.isPlanted = false;
      this.roundStartTime = Globals.Curtime();
    }

    function onPlant() {
      this.isPlanted = true;
      this.roundStartTime = Globals.Curtime();
    }

    function getTimeLeft() {
      const freezetime = Client.getFreezeTime();
      const time = this.isPlanted ? Client.getBombTime() : Client.isFreezeTime() ? freezetime : Client.getRoundTime() + freezetime;
      const timeLeft = (this.roundStartTime + time) - Globals.Curtime();

      if (timeLeft <= 0)
        return false;

      const minutes = Math.floor(timeLeft / 60);
      const seconds = timeLeft.toFixed(0) % 59;

      return (minutes ? minutes + ":" : "0:") + (seconds ? seconds > 9 ? seconds.toString() : "0" + seconds : "00");
    }

    return {
      module: 'Clock',

      // Fields
      activeAnim: new Anim(0.25, false),

      roundStartTime: 0,
      isPlanted: false,

      // Methods
      run: run,
      shouldRun: shouldRun,

      render: render,

      onRound: onRound,
      onPlant: onPlant,

      getTimeLeft: getTimeLeft
    };
  }
  ());

ModuleManager.add(Clock);
// #endregion Clock

// #region PlayerCounter
const PlayerCounter = (function module() {
    function run() {
      this.render();
      this.update();
    }

    function shouldRun() {
      return Client.local && !Client.isWarmup();
    }

    function render() {
      const x = Render.GetScreenSize()[0] / 2;
      const y = 90;
      const w = 35;
      const h = 35;

      const activeAnimFrac = this.beginAnim.get()
      const enemyFrac = this.enemyCount / Entity.GetEnemies().length;
      const teamFrac = this.teamCount / Entity.GetTeammates().length;

      const sinTime = Math.abs(Math.sin(Globals.Curtime() * 0.25));

      this.enemyFrac = Anim.approximate(this.enemyFrac, enemyFrac, 5);
      this.teamFrac = Anim.approximate(this.teamFrac, teamFrac, 5);

      Renderer.setRenderWeight(activeAnimFrac);

      Renderer.drawGradient(x - 25 - w, y + (1 - this.enemyFrac) * h, w, h * this.enemyFrac, [235, 125, 125, 0], [235, 125, 125, 225], false, sinTime);
      Renderer.drawGradient(x - 25 - w, y, w, h * (1 - this.enemyFrac), [235, 235, 235, 0], [235, 235, 235, 225], false, sinTime);

      Renderer.drawString(x - 25 - w / 2, y + 15, Anim.color([235, 235, 235, 225], [235, 200, 200, 225], this.enemyFrac), fontChat, this.enemyCount.toString(), 'outline', 'center');

      Renderer.drawGradient(x + 25, y + (1 - this.teamFrac) * h, w, h * this.teamFrac, [125, 125, 235, 0], [125, 125, 235, 225], false, sinTime);
      Renderer.drawGradient(x + 25, y, w, h * (1 - this.teamFrac), [235, 235, 235, 0], [235, 235, 235, 225], false, sinTime);

      Renderer.drawString(x + 25 + w / 2, y + 15, Anim.color([235, 235, 235, 225], [200, 200, 235, 225], this.teamFrac), fontChat, this.teamCount.toString(), 'outline', 'center');
    }

    function update() {
      const playerCount = Client.getPlayerCount();

      if (playerCount.enemy > this.enemyCount) {
        this.enemyCount = playerCount.enemy;
        this.activeAnim.weight = 1;
      }

      if (playerCount.team > this.teamCount) {
        this.teamCount = playerCount.team;
        this.activeAnim.weight = 1;
      }

      this.enemyCount = Utils.clamp(this.enemyCount, 0, Entity.GetEnemies().length)
      this.teamCount = Utils.clamp(this.teamCount, 0, Entity.GetTeammates().length)

      this.activeAnim.update(false);
      this.beginAnim.update(this.activeAnim.weight > 0);
    }

    function onPreRound() {
      this.enemyCount = 0;
      this.teamCount = 0;

      this.activeAnim.weight = 1;
    }

    function onSpawn() {
      if (Client.isEnemy(Client.getFromUserID(Event.GetInt('userid')))) {
        this.enemyCount++;
      } else {
        this.teamCount++;
      }

      this.activeAnim.weight = 1;
    }

    function onDeath() {
      if (Client.isEnemy(Client.getFromUserID(Event.GetInt('userid')))) {
        this.enemyCount = Math.max(this.enemyCount - 1, 0);
      } else {
        this.teamCount = Math.max(this.teamCount - 1, 0);
      }

      this.activeAnim.weight = 1;
    }

    return {
      module: 'PlayerCounter',

      activeAnim: new Anim(5, false),
      beginAnim: new Anim(0.5, false),

      enemyCount: 0,
      teamCount: 0,

      enemyFrac: 1,
      teamFrac: 1,

      // Methods
      run: run,
      shouldRun: shouldRun,

      render: render,
      update: update,

      onPreRound: onPreRound,
      onSpawn: onSpawn,
      onDeath: onDeath
    };
  }
  ());

ModuleManager.add(PlayerCounter);
// #endregion PlayerCounter

// #region Clock
const Impacts = (function module() {
    function run() {
      this.render();
      this.update();
    }

    function shouldRun() {
      return Client.local && Entity.IsValid(Entity.GetLocalPlayer());
    }

    function render() {
      const options = UI.GetValue(this.options);

      if (!options)
        return;

      const hitmarkerAnimFrac = this.hitmarkerAnim.get();

      const markerColor = UI.GetColor(this.markerColor);
      const markerColorSec = UI.GetColor(this.markerColorSec);
      const damageColor = UI.GetValue(this.damageColorMatch) ? UI.GetColor(['Visuals', 'Chams', 'Enemy', 'History material color']) : UI.GetColor(this.damageColor);
      const marker2DColor = UI.GetColor(this.marker2DColor);

      if (hitmarkerAnimFrac) {
        const w1 = 10 + hitmarkerAnimFrac * 10;
        const w2 = 5 + hitmarkerAnimFrac * 10;

        const sx = Render.GetScreenSize()[0] / 2;
        const sy = Render.GetScreenSize()[1] / 2;

        Renderer.setRenderWeight(hitmarkerAnimFrac);

        Renderer.drawLine(sx - w1, sy - w1, sx - w2, sy - w2, marker2DColor);
        Renderer.drawLine(sx - w1, sy + w1, sx - w2, sy + w2, marker2DColor);
        Renderer.drawLine(sx + w2, sy - w2, sx + w1, sy - w1, marker2DColor);
        Renderer.drawLine(sx + w2, sy + w2, sx + w1, sy + w1, marker2DColor);
      }

      for (var i = 0; i < this.impactList.length; ++i) {
        const impact = this.impactList[i];

        impact.update();

        if (impact.anim.weight === 0 && impact.begin.weight === 0) {
          this.impactList.splice(i, 1);
          continue;
        }

        const position = impact.getPosition();

        if (!position)
          continue;

        const timeLeft = impact.getTimeLeft();

        const x = position[0],
          y = position[1];

        Renderer.setRenderWeight(timeLeft * impact.getBeginTime())

        if (impact.type === 'default') {
          if (options & (1 << 0)) {
            Renderer.drawLine(x - 10, y - 10, x - 5, y - 5, markerColor);
            Renderer.drawLine(x - 10, y + 10, x - 5, y + 5, markerColor);
            Renderer.drawLine(x + 5, y - 5, x + 10, y - 10, markerColor);
            Renderer.drawLine(x + 5, y + 5, x + 10, y + 10, markerColor);
          }

          if (options & (1 << 2)) {
            Renderer.drawString(x + Math.cos(Globals.Curtime() * 2 + i) * 5, y - 25 - (1 - timeLeft) * 50, damageColor, fontSmall, impact.getDamage().toString(), 'shadow', 'center');
          }
        } else if (impact.type === 'ragebot') {
          if (options & (1 << 1)) {
            Renderer.drawLine(x - 8, y - 8, x - 4, y - 4, markerColorSec);
            Renderer.drawLine(x - 8, y + 8, x - 4, y + 4, markerColorSec);
            Renderer.drawLine(x + 4, y - 4, x + 8, y - 8, markerColorSec);
            Renderer.drawLine(x + 4, y + 4, x + 8, y + 8, markerColorSec);
          }
        }
      }
    }

    function update() {
      const options = UI.GetValue(this.options);

      UI.SetEnabled(this.markerColor, options & (1 << 0));
      UI.SetEnabled(this.markerColorSec, options & (1 << 1));
      UI.SetEnabled(this.damageColor, options & (1 << 2));
      UI.SetEnabled(this.damageColorMatch, options & (1 << 2));
      UI.SetEnabled(this.marker2DColor, options & (1 << 3));

      this.hitmarkerAnim.update(false);
    }

    function onImpact() {
      const userid = Client.getFromUserID(Event.GetInt('userid'));

      if (userid !== Client.local)
        return;

      const tickCount = Globals.Tickcount();

      if (this.lastTickCount !== tickCount) {
        this.lastTickCount = tickCount;
        this.tempImpactList = [];
      }

      this.tempImpactList[this.tempImpactList.length] = [
        Event.GetFloat('x'),
        Event.GetFloat('y'),
        Event.GetFloat('z')
      ];
    }

    function onHurt() {
      const attacker = Client.getFromUserID(Event.GetInt('attacker'));
      const victim = Client.getFromUserID(Event.GetInt('userid'));

      if (attacker !== Client.local || victim === Client.local)
        return;

      this.hitmarkerAnim.weight = 1;

      if (this.tempImpactList.length === 0)
        return;

      const hitboxes = hitgroupToHitboxMap[Event.GetInt('hitgroup')];

      if (!hitboxes)
        return;

      var lowestDistance = 8192;
      var closestPoint;

      for (var i = 0; i < hitboxes.length; ++i) {
        const hitbox = hitboxes[i];

        for (var j = 0; j < this.tempImpactList.length; ++j) {
          const position = this.tempImpactList[j];

          const distance = Utils.distance(Client.getHitboxPosition(victim, hitbox), position);

          if (lowestDistance > distance) {
            lowestDistance = distance;
            closestPoint = position;
          }
        }
      }

      if (!closestPoint)
        return;

      this.impactList.unshift(new Impact(closestPoint, 10, Event.GetInt('dmg_health'), 'default'));
    }

    function onRagebot() {
      const hitbox = Event.GetInt('hitbox');
      const target = Event.GetInt('target_index');

      this.impactList.unshift(new Impact(Client.getHitboxPosition(target, hitbox), 5, 0, 'ragebot'));
    }

    return {
      module: 'Impacts',

      // Fields
      options: UI.AddMultiDropdown(['Config', 'Signal', 'Signal'], 'Bullet impacts', ['3D hitmarker', '3D hitmarker (ragebot)', '3D damage indicator', '2D hitmarker'], 0),
      markerColor: UI.AddColorPicker(['Config', 'Signal', 'Signal'], '3D hitmarker color'),
      markerColorSec: UI.AddColorPicker(['Config', 'Signal', 'Signal'], '3D hitmarker color (ragebot)'),
      damageColor: UI.AddColorPicker(['Config', 'Signal', 'Signal'], '3D damage color'),
      marker2DColor: UI.AddColorPicker(['Config', 'Signal', 'Signal'], '2D hitmarker color'),
      damageColorMatch: UI.AddCheckbox(['Config', 'Signal', 'Signal'], 'Match damage color'),

      tempImpactList: [],
      impactList: [],

      lastTickCount: 0,

      hitmarkerAnim: new Anim(3.5, false),

      // Methods
      run: run,
      shouldRun: shouldRun,

      render: render,
      update: update,

      onImpact: onImpact,
      onHurt: onHurt,
      onRagebot: onRagebot
    };
  }
  ());

ModuleManager.add(Impacts);
// #endregion Impacts

// #region Viewmodel
const Viewmodel = (function module() {
    function run() {
      const options = UI.GetValue(this.options);

      if (options & (1 << 0) || options & (1 << 1) || options & (1 << 2))
        this.modulateColor();

      if (options & (1 << 3))
        this.modulateRoll();

      this.update();
    }

    function shouldRun() {
      return UI.GetValue(this.options) && Client.local && Client.isAlive();
    }

    function update() {
      const weaponId = Client.getWeaponID();
      const options = UI.GetValue(this.options);

      if (weaponId !== this.lastWeaponId)
        this.activeAnim.weight = 0;

      this.activeAnim.update(true);
      this.activeAnim.duration = UI.GetValue(this.duration);

      this.lastWeaponId = weaponId;

      UI.SetEnabled(this.color, options & (1 << 0));
      UI.SetEnabled(this.colorSec, options & (1 << 0));
      UI.SetEnabled(this.color2, options & (1 << 1));
      UI.SetEnabled(this.color2Sec, options & (1 << 1));
      UI.SetEnabled(this.colorL2, options & (1 << 2));
      UI.SetEnabled(this.colorL2Sec, options & (1 << 2));
      UI.SetEnabled(this.duration, options);
    }

    function modulateColor() {
      const options = UI.GetValue(this.options);

      const sinTime = Math.abs(Math.sin(Globals.Curtime()));
      const cosTime = Math.abs(Math.cos(Globals.Curtime()));

      if (options & (1 << 0)) {
        UI.SetColor(['Visuals', 'Chams', 'Self', 'Weapon material color'],
          this.activeAnim.color([45, 45, 45, 0], Anim.color(UI.GetColor(this.color), UI.GetColor(this.colorSec), sinTime)));
      }

      if (options & (1 << 1)) {
        UI.SetColor(['Visuals', 'Chams', 'Self', 'Weapon material color (secondary)'],
          this.activeAnim.color([45, 45, 45, 0], Anim.color(UI.GetColor(this.color2), UI.GetColor(this.color2Sec), cosTime)));
      }

      if (options & (1 << 2)) {
        UI.SetColor(['Visuals', 'Chams', 'Self', 'Weapon (L2) material color'],
          this.activeAnim.color([45, 45, 45, 0], Anim.color(UI.GetColor(this.colorL2), UI.GetColor(this.colorL2Sec), cosTime)));
      }
    }

    function modulateRoll() {
      const runLayer = Client.getAnimationInfo(Client.local, 6);
      const jumpLayer = Client.getAnimationInfo(Client.local, 4);

      this.rollFrac = Utils.clamp(Anim.approximate(this.rollFrac, 1 - runLayer.Weight, 2.5), 0, 1);
      this.jumpFrac = Utils.clamp(Anim.approximate(this.jumpFrac, jumpLayer.Weight, 2.5), 0, 1);

      UI.SetValue(['Misc.', 'View', 'Viewmodel', 'Roll'], this.rollFrac * -1.5)
      UI.SetValue(['Misc.', 'View', 'Viewmodel', 'X offset'], this.rollFrac * -8)
      UI.SetValue(['Misc.', 'View', 'Viewmodel', 'Y offset'], this.rollFrac * -8)
      UI.SetValue(['Misc.', 'View', 'Viewmodel', 'Z offset'], (jumpLayer.Activity === 988 || jumpLayer.Activity === 989) ? -this.jumpFrac : this.jumpFrac * 8)
    }

    return {
      module: 'Viewmodel',

      // Fields
      options: UI.AddMultiDropdown(['Config', 'Signal', 'Signal'], 'Dynamic viewmodel', ['Color easing', 'Color easing (secondary)', 'Color easing (layer 2)', 'Movement roll']),
      color: UI.AddColorPicker(['Config', 'Signal', 'Signal'], 'Viewmodel color (first)'),
      colorSec: UI.AddColorPicker(['Config', 'Signal', 'Signal'], 'Viewmodel color (second)'),
      color2: UI.AddColorPicker(['Config', 'Signal', 'Signal'], 'Viewmodel color secondary (first)'),
      color2Sec: UI.AddColorPicker(['Config', 'Signal', 'Signal'], 'Viewmodel color secondary (second)'),
      colorL2: UI.AddColorPicker(['Config', 'Signal', 'Signal'], 'Viewmodel color layer 2 (first)'),
      colorL2Sec: UI.AddColorPicker(['Config', 'Signal', 'Signal'], 'Viewmodel color layer 2 (second)'),
      duration: UI.AddSliderFloat(['Config', 'Signal', 'Signal'], 'Viewmodel fade-in duration', 0.25, 1.5),

      activeAnim: new Anim(0.5, false),
      rollFrac: 0,
      jumpFrac: 0,
      lastWeaponId: 0,

      // Methods
      run: run,
      shouldRun: shouldRun,

      update: update,

      modulateColor: modulateColor,
      modulateRoll: modulateRoll
    };
  }
  ());

ModuleManager.add(Viewmodel);
// #endregion Viewmodel

// #region Backtrack
const Backtrack = (function module() {
    function run() {
      const sinTime = Math.abs(Math.sin(Globals.Curtime() * 2.5));

      this.update();

      UI.SetColor(['Visuals', 'Chams', 'Enemy', 'History material color'], Anim.color(UI.GetColor(this.color), UI.GetColor(this.colorSec), sinTime));
    }

    function shouldRun() {
      return true;
    }

    function update() {
      const enabled = UI.GetValue(this.active);

      UI.SetEnabled(this.color, enabled);
      UI.SetEnabled(this.colorSec, enabled);
    }

    return {
      module: 'Backtrack',

      // Fields
      active: UI.AddCheckbox(['Config', 'Signal', 'Signal'], 'Dynamic backtrack chams'),
      color: UI.AddColorPicker(['Config', 'Signal', 'Signal'], 'Backtrack color (first)'),
      colorSec: UI.AddColorPicker(['Config', 'Signal', 'Signal'], 'Backtrack color (second)'),

      // Methods
      run: run,
      shouldRun: shouldRun,

      update: update
    };
  }
  ());

ModuleManager.add(Backtrack);
// #endregion Backtrack

// #region Poses
const Poses = (function module() {
    function onCreateMove() {
      if (!Client.local)
        return;

      const mode = UI.GetValue(this.modes);

      if (!mode)
        return;

      const landLayer = Client.getAnimationInfo(Client.local, 5);

      if (!landLayer)
        return;

      if (mode & (1 << 0) && (landLayer.Activity === 988 || landLayer.Activity === 989) && landLayer.Weight > 0 && this.lastLanded)
        Client.setPoseParameter(12, 0.5);
      else if (mode & (1 << 1) && !(UserCMD.GetButtons() & (1 << 5)) && !(Client.getFlags() & (1 << 5)) && !Client.isFreezeTime())
        Client.setPoseParameter(12, 1);

      if (mode & (1 << 2))
        Client.setPoseParameter(6, 1);

      this.lastLanded = Client.getFlags() & (1 << 0);
    }

    function onUpdate() {
      const mode = UI.GetValue(Poses.modes);

      Convar.SetFloat('cl_ragdoll_physics_enable', (mode & (1 << 3)) ? 0 : 1);
    }

    return {
      module: 'Poses',

      // Fields
      modes: UI.AddMultiDropdown(['Config', 'Signal', 'Signal'], 'Pose adjusments', ['Legacy land animation', 'Legacy firing animation', 'Legacy in-air animation', 'Fade-out on death']),

      lastLanded: false,

      // Methods
      onCreateMove: onCreateMove,
      onUpdate: onUpdate
    };
  }
  ());
// #endregion Poses

// #region Target
const Target = (function module() {
    function onCreateMove() {
      if (!Client.local)
        return;

      if (!UI.GetValue(this.active))
        return;

      if (UI.GetValue(['Misc.', 'Keys', 'Keys', 'Key assignment', 'Thirdperson']) && Ragebot.GetTargets().length > 0)
        UI.ToggleHotkey(['Misc.', 'Keys', 'Keys', 'Key assignment', 'Thirdperson']);
    }

    return {
      module: 'Target',

      // Fields
      active: UI.AddCheckbox(['Config', 'Signal', 'Signal'], 'Disable third-person on target'),

      // Methods
      onCreateMove: onCreateMove
    };
  }
  ());
// #endregion Target

// #region Keybinds
const Keybinds = (function module() {
    function run() {
      this.update();
      this.render();
    }

    function shouldRun() {
      return Client.local && UI.GetValue(this.active);
    }

    function render() {
      const x = UI.GetValue(this.x);
      const y = UI.GetValue(this.y);
      const w = 225;
      const h = 25;

      this.hasActiveKeybind = false;

      Renderer.setRenderWeight(this.activeAnim.get());

      Renderer.drawGradient(x, y, w, h, [125, 125, 125, 0], [125, 125, 125, 125], false, x / Render.GetScreenSize()[0]);
      Renderer.drawString(x + 10, y + 5, [200, 200, 200, 225], fontIconSmall, 'c', 'shadow');
      Renderer.drawString(x + 35, y + 2, [235, 235, 235, 225], fontAverageBold, 'Keybinds', 'shadow')

      for (var i = 0, oy = 0; i < this.keybindList.length; ++i) {
        const current = this.keybindList[i];
        const animFrac = current.anim.get();

        current.update();

        if (current.anim.weight === 0)
          continue;

        else if (!this.hasActiveKeybind)
          this.hasActiveKeybind = true;

        Renderer.setRenderWeight(animFrac);

        Renderer.drawString(x + 12, y + oy + 35, [200, 200, 200, 225], fontIconTiny, current.active ? 'j' : 'k', 'shadow');
        Renderer.drawString(x + 32, y + oy + 32, [235, 235, 235, 225], fontList, current.label, 'shadow');

        oy += 20 * animFrac;
      }
    }

    function update() {
      UI.SetEnabled(this.x, 0);
      UI.SetEnabled(this.y, 0);

      UI.SetValue(this.x, this.draggable.x);
      UI.SetValue(this.y, this.draggable.y);

      this.draggable.update();
      this.activeAnim.update(this.hasActiveKeybind || UI.IsMenuOpen());
    }

    function initialize() {
      for (var i = 0; i < this.keybindPaths.length; ++i) {
        const current = this.keybindPaths[i];
        const contents = UI.GetChildren(current);

        for (var j = 0; j < contents.length; ++j) {
          const element = contents[j];

          this.keybindList[this.keybindList.length] = new Keybind(current.concat(element), element);
        }
      }

      this.draggable.x = UI.GetValue(this.x);
      this.draggable.y = UI.GetValue(this.y);
    }

    return {
      module: 'Keybinds',

      // Fields
      activeAnim: new Anim(0.25, false),
      draggable: new Draggable(100, 100, 225, 25),

      hasActiveKeybind: false,

      active: UI.AddCheckbox(['Config', 'Signal', 'Signal'], 'Show keybind list'),
      x: UI.AddSliderInt(['Config', 'Signal', 'Signal'], 'keybind_x', 10, 2560),
      y: UI.AddSliderInt(['Config', 'Signal', 'Signal'], 'keybind_y', 10, 1440),

      keybindList: [],
      keybindPaths: [
        ['Legit', 'General', 'General', 'Key assignment'],
        ['Rage', 'General', 'General', 'Key assignment'],
        ['Rage', 'Anti Aim', 'General', 'Key assignment'],
        ['Rage', 'Exploits', 'Keys', 'Key assignment'],
        ['Misc.', 'Keys', 'Keys', 'Key assignment'],
        ['Config', 'Scripts', 'Keys', 'JS Keybinds']
      ],

      // Methods
      run: run,
      shouldRun: shouldRun,

      update: update,
      render: render,
      initialize: initialize
    };
  }
  ());

ModuleManager.add(Keybinds);
// #endregion Keybinds

// #region MaterialBuilder
const MaterialBuilder = (function module() {
    function run() {
      const adjustments = UI.GetValue(this.adjustments);
      const effects = UI.GetValue(this.effects);

      UI.SetEnabled(this.scrollDir, effects & (1 << 0));
      UI.SetEnabled(this.scrollVel, effects & (1 << 0));
      UI.SetEnabled(this.envMapColor, effects & (1 << 1));
      UI.SetEnabled(this.envMapColorSec, effects & (1 << 1));
      UI.SetEnabled(this.envMapPulseRate, effects & (1 << 2));

      UI.SetEnabled(this.pearlescent, adjustments & (1 << 4));

      if (this.shouldInitialize && UI.GetValue(this.createButton)) {
        this.shouldInitialize = false;

        this.onUpdate();
      }
    }

    function shouldRun() {
      return true;
    }

    function onUpdate() {
      Cheat.Print(UI.GetValue(MaterialBuilder.createButton) + '\n')
      if (!UI.GetValue(MaterialBuilder.createButton)) {
        MaterialSystem.destroy('Signal');
        return;
      }

      var proxies = null;
      var properties = {
        basetexture: materialMap[UI.GetValue(MaterialBuilder.baseTexture)],
      };

      const adjustments = UI.GetValue(MaterialBuilder.adjustments);
      const effects = UI.GetValue(MaterialBuilder.effects);

      // Additive
      if (adjustments & (1 << 0))
        properties['additive'] = '1';

      // Reflective
      if (adjustments & (1 << 1)) {
        properties['envmap'] = 'env_cubemap';
        properties['envmapcontrast'] = '1';
      }

      // Wireframe
      if (adjustments & (1 << 2)) {
        properties['wireframe'] = '1';
      }

      // Ignore Z
      if (adjustments & (1 << 3)) {
        properties['ignorez'] = '1';
      }

      // Pearlescent
      if (adjustments & (1 << 4)) {
        properties['pearlescent'] = UI.GetValue(MaterialBuilder.pearlescent).toString();
      }

      // Bumpmap
      if (adjustments & (1 << 4) || adjustments & (1 << 5)) {
        properties['bumpmap'] = 'de_nuke/hr_nuke/pool_water_normals_002';
        properties['envmap'] = "env_cubemap";
        properties['envmaptint'] = "[0.0 0.1 0.1]";
        properties['envmapfresnel'] = "1.0";
        properties['envmapfresnelminmaxexp'] = "[1.0 1.0 1.0]";
        properties['phong'] = "1";
        properties['phongexponent'] = "1024";
        properties['phongboost'] = "8.0";
        properties['phongfresnelranges'] = "[1.0 1.0 0.0]";
      }

      if (effects)
        proxies = {};

      // Texture scroll
      if (effects & (1 << 0)) {
        const direction = UI.GetValue(MaterialBuilder.scrollDir);
        const velocity = UI.GetValue(MaterialBuilder.scrollVel);

        proxies['texturescroll'] = {
          texturescrollvar: "$basetexturetransform",
          texturescrollrate: velocity.toString(),
          texturescrollangle: direction.toString()
        };
      }

      if (proxies instanceof Object)
        properties['proxies'] = proxies;

      MaterialSystem.add('Signal', properties);
    }

    function onMaterial() {
      if (!UI.GetValue(this.createButton))
        return;

      const effects = UI.GetValue(this.effects);

      if (!(effects & (1 << 1)))
        return;

      this.frameCount++;

      if (this.frameCount % 10 !== 0)
        return;

      const cosTime = Math.abs(Math.cos(Globals.Curtime()));

      const color = Anim.color(UI.GetColor(this.envMapColor), UI.GetColor(this.envMapColorSec), cosTime);

      MaterialSystem.setKey('Signal', '$envmaptint', [color[0] / 255, color[1] / 255, color[2] / 255]);
      MaterialSystem.update('Signal');
    }

    return {
      module: 'MaterialBuilder',

      // Fields
      baseTexture: UI.AddDropdown(['Config', 'Signal | Materials', 'Signal | Materials'], 'Chams base texture', materialMap, 1),
      adjustments: UI.AddMultiDropdown(['Config', 'Signal | Materials', 'Signal | Materials'], 'Chams adjustments', ['Additive', 'Reflective', 'Wireframe', 'Ignore Z', 'Pearlescent', 'Bumpmap']),
      pearlescent: UI.AddSliderFloat(['Config', 'Signal | Materials', 'Signal | Materials'], 'Chams pearlessence', -5, 5),
      effects: UI.AddMultiDropdown(['Config', 'Signal | Materials', 'Signal | Materials'], 'Chams effects', ['Texture scroll', 'Envmap color easing']),
      scrollDir: UI.AddSliderInt(['Config', 'Signal | Materials', 'Signal | Materials'], 'Texture scroll direction', -180, 180),
      scrollVel: UI.AddSliderFloat(['Config', 'Signal | Materials', 'Signal | Materials'], 'Texture scroll speed', 0, 2.5),
      envMapColor: UI.AddColorPicker(['Config', 'Signal | Materials', 'Signal | Materials'], 'Envmap color'),
      envMapColorSec: UI.AddColorPicker(['Config', 'Signal | Materials', 'Signal | Materials'], 'Envmap color (secondary)'),
      envMapPulseRate: UI.AddSliderFloat(['Config', 'Signal | Materials', 'Signal | Materials'], 'Envmap pulse duration', 0.25, 5),
      createButton: UI.AddCheckbox(['Config', 'Signal | Materials', 'Signal | Materials'], 'Create/delete material'),

      shouldFix: false,
      index: 0,
      frameCount: 0,

      shouldInitialize: true,

      // Methods
      run: run,
      shouldRun: shouldRun,

      onUpdate: onUpdate,
      onMaterial: onMaterial
    };
  }
  ());

ModuleManager.add(MaterialBuilder);
// #endregion MaterialBuilder

// #region Hitchance
const Hitchance = (function module() {
    function run() {}

    function onCreateMove() {
      if (!UI.GetValue(this.enabled))
        return;

      const weaponName = Client.getWeaponName();

      if (!weaponName)
        return;

      const tabName = nameToTabMap[weaponName];

      if (!tabName)
        return;

      if (!UI.GetValue(['Rage', 'Accuracy', tabName, 'Override hitchance']))
        return;

      const enemies = Entity.GetEnemies();

      enemies.forEach(function (enemy) {
        if (!enemy)
          return;

        Ragebot.ForceTargetHitchance(enemy, UI.GetValue(['Rage', 'Accuracy', tabName, 'Hitchance (override)']));
      })
    }

    function shouldRun() {
      return false;
    }

    function initialize() {
      for (var id in nameToTabMap) {
        const tabName = nameToTabMap[id];

        UI.AddCheckbox(['Rage', 'Accuracy', tabName], 'Override hitchance');
        UI.AddSliderInt(['Rage', 'Accuracy', tabName], 'Hitchance (override)', 0, 100);
      }
    }

    return {
      // Fields
      enabled: UI.AddHotkey(['Config', 'Scripts', 'Keys', 'JS Keybinds'], '[Signal] Hitchance override', 'Hitchance override'),

      // Methods
      run: run,
      shouldRun: shouldRun,

      onCreateMove: onCreateMove,

      initialize: initialize
    };
  }
  ());

ModuleManager.add(Hitchance);
// #endregion Hitchance

// #region Killchance
const Killchance = (function module() {
  function run() {
    for (var player in this.playerData) {
      const id = Number(player);
      const chance = this.playerData[player];
      
      if (!Client.isAlive(id) || Client.isDormant(id))
        continue;

      const box = Entity.GetRenderBox(id);

      if (!box[0])
        continue;

      Renderer.setRenderWeight(1)
      // Renderer.drawRectOutlined(
      //   box[1],
      //   box[2] - 25,
      //   (box[3] - box[1]) * chance,
      //   10,
      //   Anim.color([235, 125, 125, 225], [125, 235, 125, 225], chance),
      //   [10, 10, 10, 100]
      // );
      Renderer.drawString(
        box[1] + (box[3] - box[1]) / 2,
        box[2] - 22,
        Anim.color([235, 125, 125, 225], [125, 235, 125, 225], chance),
        fontTiny,
        (chance * 100).toFixed(0) + "%",
        'outline',
        'center'
      );
    }
  }

  function shouldRun() {
    return UI.GetValue(this.enabled);
  }

  function onCreateMove() {
    const players = Entity.GetEnemies();

    for (var i = 0; i < players.length; ++i) {
      const player = players[i];

      if (!Client.isAlive(player) || Client.isDormant(player))
        continue;

      const chance = this.determineKillChance(player);

      this.playerData[player] = chance;
    }

  }

  function determineKillChance(player) {
    const weight = {
      HEALTH: 2,
      ARMOR: 1,
      WEAPON_DAMAGE: 2,
      POSITION: 1,
      KDA: 1
    };

    const localHealth = Client.getHealth(), playerHealth = Client.getHealth(player);
    const localArmor = Client.getArmor(), playerArmor = Client.getArmor(player);
    // const localWpnDamage = Entity.GetCCSWeaponInfo(Client.local).damage, playerWpnDamage = Entity.GetCCSWeaponInfo(player).damage;
    const localZPos = Client.getOrigin()[2], playerZPos = Client.getOrigin(player)[2];

    return 0.5 + (
      Utils.clamp((localHealth - playerHealth) / 100, 0, 1) * weight.HEALTH +
      Utils.clamp((localArmor - playerArmor) / 100, 0, 1) * weight.ARMOR 
      // Utils.clamp(localWpnDamage / playerWpnDamage, 0, 1) * weight.WEAPON_DAMAGE
    ) / 6;
  }

  return {
    // Fields
    enabled: UI.AddCheckbox(['Config', 'Signal', 'Signal'], 'Show kill chance'),
    playerData: [],

    // Methods 
    run: run,
    shouldRun: shouldRun,
    onCreateMove: onCreateMove,
    determineKillChance: determineKillChance
  }
})();

ModuleManager.add(Killchance);
// #endregion Killchance
// #endregion Modules

// #region Functions
// #region Callbacks
function onDrawCallback() {
  ModuleManager.run();
  Colors.update();
}

function onUpdateCallback() {
  Client.update();
}

function onMoveCallback() {
  Poses.onCreateMove();
  Target.onCreateMove();
  Chat.onCreateMove();
  Hitchance.onCreateMove();
  Killchance.onCreateMove();
}

function onMaterialCallback() {
  MaterialBuilder.onMaterial();
}

function onHurtCallback() {
  HealthBar.onHurt();
  Impacts.onHurt();
}

function onDeathCallback() {
  Killfeed.onDeath();
  Inventory.onDeath();
  PlayerCounter.onDeath();
}

function onUnloadCallback() {
  Convar.SetFloat('cl_drawhud', 1);
  Convar.SetFloat('r_3dsky', 1);

  Cheat.ExecuteCommand('bind y "messagemode"');
  Cheat.ExecuteCommand('bind u "messagemode2"');

  Input.ForceCursor(0);

  MaterialSystem.reset();
}

function onRoundCallback() {
  Clock.onRound();
}

function onPreRoundCallback() {
  PlayerCounter.onPreRound();
  Killfeed.reset();
}

function onConnectCallback() {
  Killfeed.reset();
  Chat.reset();
}

function onPlantCallback() {
  Clock.onPlant();
}

function onImpactCallback() {
  Impacts.onImpact();
}

function onRagebotCallback() {
  Impacts.onRagebot();
}

function onChatCallback() {
  Chat.onChat();
}

function onSpawnCallback() {
  PlayerCounter.onSpawn();
}

function onLoadCallback() {
  Cheat.RegisterCallback('Draw', 'onDrawCallback');
  Cheat.RegisterCallback('CreateMove', 'onMoveCallback');
  Cheat.RegisterCallback('Unload', 'onUnloadCallback');
  Cheat.RegisterCallback('FRAME_NET_UPDATE_START', 'onUpdateCallback');
  Cheat.RegisterCallback('Material', 'onMaterialCallback');
  Cheat.RegisterCallback('player_hurt', 'onHurtCallback');
  Cheat.RegisterCallback('player_death', 'onDeathCallback');
  Cheat.RegisterCallback('round_start', 'onRoundCallback');
  Cheat.RegisterCallback('round_prestart', 'onPreRoundCallback');
  Cheat.RegisterCallback('player_connect_full', 'onConnectCallback');
  Cheat.RegisterCallback('bomb_planted', 'onPlantCallback');
  Cheat.RegisterCallback('bullet_impact', 'onImpactCallback');
  Cheat.RegisterCallback('ragebot_fire', 'onRagebotCallback');
  Cheat.RegisterCallback('player_say', 'onChatCallback');
  Cheat.RegisterCallback('player_spawn', 'onSpawnCallback');

  UI.RegisterCallback(Poses.modes, 'Poses.onUpdate');
  UI.RegisterCallback(MaterialBuilder.createButton, 'MaterialBuilder.onUpdate');

  Convar.SetFloat('cl_drawhud', 0);
  Convar.SetFloat('r_3dsky', 0);

  Cheat.ExecuteCommand('unbind y');
  Cheat.ExecuteCommand('unbind u');

  Keybinds.initialize();
  Colors.initialize();
  Hitchance.initialize();
}

onLoadCallback();
// #endregion Callbacks
// #endregion Functions
