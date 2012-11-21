-- Standard awesome library
require("awful")
require("awful.autofocus")
require("awful.rules")
-- Theme handling library
require("beautiful")
-- Notification library
require("naughty")

-- {{{ Variable definitions
-- Themes define colours, icons, and wallpapers
beautiful.init(awful.util.getdir("config") .. "/theme.lua")

-- This is used later as the default terminal and editor to run.
terminal = "terminal"
editor = "gvim"
editor_cmd = editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
layouts =
{
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier
}
-- }}}

-- {{{ Tags
-- Define a tag table which hold all screen tags.
tags = {}
for s = 1, screen.count() do
    -- Each screen has its own tag table.
    tags[s] = awful.tag({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, s, awful.layout.suit.tile)
end
-- }}}

-- {{{ Menu
-- Create a laucher widget and a main menu
myawesomemenu = {
   { "manual", terminal .. " -e 'man awesome'" },
   { "edit config", editor_cmd .. " " .. awful.util.getdir("config") .. "/rc.lua" },
   { "restart", awesome.restart },
   { "quit", awesome.quit }
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "open terminal", terminal }
                                  }
                        })

mylauncher = awful.widget.launcher({ image = image(beautiful.awesome_icon),
                                     menu = mymainmenu })
-- }}}

-- {{{ Wibox
-- Create a textclock widget
os.setlocale('ja_JP.UTF-8')
mytextclock = awful.widget.textclock({ align = "right" },
    --" %a %b %d, %H:%M:%S ", 1)
    "%m.%d(%a) %H:%M:%S", 0.5)

-- Create a systray
mysystray = widget({ type = "systray" })

batterywidget = widget({ type = "textbox", name = "batterywidget", align = "right" })

mpdwidget = widget({ type = "textbox", name = "mpdwidget", align = "right" })

function widgetpopup(widget, textfunc, options)
    local popup
    widget:add_signal("mouse::enter", function ()
        local title, text = textfunc()
        popup = naughty.notify(awful.util.table.join(options,
            { title = title, text = text }))
    end)
    widget:add_signal("mouse::leave", function()
        if popup then
            popup:die()
            popup = nil
        end
    end)
end

widgetpopup(batterywidget, function ()
    local f = io.popen("(acpi -V) | python -c 'import sys,cgi;sys.stdout.write(cgi.escape(sys.stdin.read()))'")
    local text = f:read("*a")
    return "acpi -V", text
end, { font = "Monospace 8" })

widgetpopup(mytextclock, function ()
    -- hacks to force cal to think we're isatty
    local preload = awful.util.getdir("config") .. "/libfaketty.so"
    local f = io.popen("env TERM=xterm LD_PRELOAD=" .. preload .. " cal -3")
    local text = f:read("*a")
    -- now deal with the highlight
    text = text:gsub("\027%[7m", string.format(
        "<span fgcolor='%s' bgcolor='%s'>", beautiful.fg_focus, beautiful.bg_focus))
    text = text:gsub("\027%[27m", "</span>")
    return "cal -3", text
end, { font = "Monospace 8" })

function batterytext(path)
    if os.execute("test -d " .. path) ~= 0 then
        batterywidget.text = ""
        return
    end

    local function read(fn)
        local file = io.open(path .. "/" .. fn)
        local contents = file:read()
        file:close()
        return contents
    end

    local function round(x, digits)
        return math.floor(x * 10^digits + 0.5) * 10^-digits
    end

    local energy_now = tonumber(read("energy_now"))
    local energy_full = tonumber(read("energy_full"))
    local power_now = tonumber(read("power_now"))
    local status = read("status")

    local left = 0
    local timeformat = " [%s%d:%02d]"
    if status:match("Charging") then
        left = energy_full - energy_now
        timeprefix = "↑"
    elseif status:match("Discharging") then
        left = energy_now
        timeprefix = "↓"
    else
        timeprefix = "-"
        timeformat = " [%s]"
    end
    if power_now <= 1000 then
        timeformat = " [%s]"
    end

    local percent = math.min(round(energy_now / energy_full * 100, 1), 100)
    local time = left / power_now
    local time_h = math.floor(time)
    local time_m = math.floor(time * 60) - 60 * time_h

    local timestr = string.format(timeformat, timeprefix, time_h, time_m)

    return string.format(" %.1f%%%s ", percent, timestr)
end

function batteryinfo()
    local dirlist = io.popen("ls -d /sys/class/power_supply/BAT*/ 2>/dev/null")
    totaltext = ""
    for path in dirlist:lines() do
        local text = batterytext(path)
        if text then
            totaltext = totaltext .. text
        end
    end
    dirlist:close()
    batterywidget.text = totaltext
end

function mpdinfo()
    local text = io.popen("mpc status 2>/dev/null")
    local symbols = {
        playing = "▶",
        paused = "▮▮",
        stopped = "■",
    }
    local lines = {}
    for line in text:lines() do
        table.insert(lines, line)
    end
    if #lines == 0 then
        mpdwidget.text = ""
        return
    elseif #lines < 3 then
        mpdwidget.text = string.format(" [%s] ", symbols.stopped)
    else
--        local track, statuspos = lines[1], lines[2]
--        local status, pos = string.match(statuspos, "%[(%a+)%]%s+%S+%s+(%S+).*")
--        mpdwidget.text = string.format(" %s %s [%s] ", track, pos, symbols[status])
        local status, pos = string.match(lines[2], "%[(%a+)%]%s+%S+%s+(%S+).*")
        mpdwidget.text = string.format(" [%s] ", symbols[status])
    end
end

widgetpopup(mpdwidget, function ()
    local f = io.popen("mpc")
    local text = f:read("*a")
    return "mpc", text
--end, { font = "Monospace 8" })
end)

mpdwidget:buttons(awful.util.table.join(
    awful.button({ }, 1, function()
        awful.util.spawn("ario")
    end)
))

local thresh = {0.10, 0.05, 0.02}
local battery_status = {}

function batterycheck()
    local dirlist = io.popen("ls -d /sys/class/power_supply/BAT*/ 2>/dev/null")
    for path in dirlist:lines() do
        if battery_status[path] == nil then
            battery_status[path] = 0
            print("reset " .. path)
        end
    end

    for path, status in pairs(battery_status) do
        if os.execute("test -d " .. path) ~= 0 then
            battery_status[path] = nil
        else
            local function read(fn)
                local file = io.open(path .. "/" .. fn)
                local contents = file:read()
                file:close()
                return contents
            end

            local function pread(cmd)
                local file = io.popen(cmd)
                local contents = file:read()
                file:close()
                return contents
            end

            local function round(x, digits)
                return math.floor(x * 10^digits + 0.5) * 10^-digits
            end

            local charge_now = tonumber(read("charge_now"))
            local charge_full = tonumber(read("charge_full"))
            local charge_status = read("status")

            local charge_amt = charge_now / charge_full
            local old_status = status

            if charge_status:match("Discharging") then
                while status < #thresh and charge_amt < thresh[status + 1] do
                    status = status + 1
                end
            else
                status = 0
            end

            if old_status < status then
                naughty.notify({
                    title = string.format("Battery %s Low", pread("basename " .. path)),
                    text = string.format("%d%% remaining.", round(charge_amt * 100, 0)),
                    icon = "/usr/share/icons/gnome/32x32/status/battery-caution.png",
                    timeout = 0,
                })
            end

            battery_status[path] = status
            print("set " .. path .. " to " .. status)
        end
    end
    dirlist:close()
end

do
    local t = timer({timeout = 1})
    t:add_signal("timeout", batteryinfo)
    t:add_signal("timeout", batterycheck)
    t:add_signal("timeout", mpdinfo)

    t:start()
end

-- Create a wibox for each screen and add it
mywibox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
                    awful.button({ }, 1, awful.tag.viewonly),
                    awful.button({ modkey }, 1, awful.client.movetotag),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),
                    awful.button({ }, 4, awful.tag.viewnext),
                    awful.button({ }, 5, awful.tag.viewprev)
                    )
mytasklist = {}
mytasklist.buttons = awful.util.table.join(
                     awful.button({ }, 1, function (c)
                                              if not c:isvisible() then
                                                  awful.tag.viewonly(c:tags()[1])
                                              end
                                              client.focus = c
                                              c:raise()
                                          end),
                     awful.button({ }, 3, function ()
                                              if instance then
                                                  instance:hide()
                                                  instance = nil
                                              else
                                                  instance = awful.menu.clients({ width=250 })
                                              end
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                              if client.focus then client.focus:raise() end
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                              if client.focus then client.focus:raise() end
                                          end))

for s = 1, screen.count() do
    -- Create a promptbox for each screen
    mypromptbox[s] = awful.widget.prompt({ layout = awful.widget.layout.horizontal.leftright })
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    -- Create a taglist widget
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.label.all, mytaglist.buttons)

    -- Create a tasklist widget
    mytasklist[s] = awful.widget.tasklist(function(c)
                                              return awful.widget.tasklist.label.currenttags(c, s)
                                          end, mytasklist.buttons)

    -- Create the wibox
    mywibox[s] = awful.wibox({ position = "top", screen = s })
    -- Add widgets to the wibox - order matters
    mywibox[s].widgets = {
        {
            mylauncher,
            mytaglist[s],
            mypromptbox[s],
            layout = awful.widget.layout.horizontal.leftright
        },
        mylayoutbox[s],
        mytextclock,
        batterywidget,
        s == 1 and mysystray or nil,
        mpdwidget,
        mytasklist[s],
        layout = awful.widget.layout.horizontal.rightleft
    }
end
-- }}}

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = awful.util.table.join(
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "w", function () mymainmenu:show({keygrabber=true}) end),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.util.spawn(terminal) end),
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1)      end),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1)      end),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    -- Prompt
    --awful.key({ modkey },            "r",     function () mypromptbox[mouse.screen]:run() end),
    awful.key({ modkey,           }, "r",     function () awful.util.spawn("dmenu_run") end),
    awful.key({ modkey,           }, "p",     function () awful.util.spawn("dmenu_run") end),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run({ prompt = "Run Lua code: " },
                  mypromptbox[mouse.screen].widget,
                  awful.util.eval, nil,
                  awful.util.getdir("cache") .. "/history_eval")
              end)
)

clientkeys = awful.util.table.join(
    awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, "o",      awful.client.movetoscreen                        ),
    awful.key({ modkey, "Shift"   }, "r",      function (c) c:redraw()                       end),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey,           }, "n",      function (c) c.minimized = not c.minimized    end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end)
)

-- Compute the maximum number of digit we need, limited to 9
keynumber = 0
for s = 1, screen.count() do
   keynumber = math.min(9, math.max(#tags[s], keynumber));
end

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, keynumber do
    globalkeys = awful.util.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = mouse.screen
                        if tags[screen][i] then
                            awful.tag.viewonly(tags[screen][i])
                        end
                  end),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = mouse.screen
                      if tags[screen][i] then
                          awful.tag.viewtoggle(tags[screen][i])
                      end
                  end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.movetotag(tags[client.focus.screen][i])
                      end
                  end),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.toggletag(tags[client.focus.screen][i])
                      end
                  end))
end

clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = true,
                     keys = clientkeys,
                     buttons = clientbuttons } },
    { rule = { class = "MPlayer" },
      properties = { floating = true } },
    { rule = { class = "pinentry" },
      properties = { floating = true } },
    { rule = { class = "gimp" },
      properties = { floating = true } },
    { rule = { class = "Thunderbird" },
      properties = { tag = tags[1][8] } },
    { rule = { class = "Kvirc4" },
      properties = { tag = tags[1][9] } },
    { rule = { class = "Pidgin" },
      properties = { tag = tags[1][9] } },
    { rule = { class = "Mikutter.rb" },
      properties = { tag = tags[1][7] } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.add_signal("manage", function (c, startup)
    -- Add a titlebar
    -- awful.titlebar.add(c, { modkey = modkey })

    -- Enable sloppy focus
    c:add_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        -- awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end
end)

client.add_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.add_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

function run_once(prg)
    if not prg then
        do return nil end
    end
    awful.util.spawn_with_shell("pgrep -u $USER -x $(basename " .. prg .. ") || (" .. prg .. ")")
end

-- Autostart
function autostart(dir)
    if not dir then
        do return nil end
    end
    local fd = io.popen("ls -1 -F " .. dir)
    if not fd then
        do return nil end
    end
    for file in fd:lines() do
        local c= string.sub(file,-1)   -- last char
        executable = string.sub( file, 1,-2 )
        run_once(dir .. "/" .. executable .. "") -- launch in bg
    end
    io.close(fd)
end

autostart_dir = awful.util.getdir("config") .. "/autostart"
autostart(autostart_dir)
