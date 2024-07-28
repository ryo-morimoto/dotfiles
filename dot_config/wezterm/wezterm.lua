local wezterm = require 'wezterm'

local config = {}

-- 起動設定


-- キーバインド


-- 見た目
function get_random_color_scheme()
    math.randomseed(os.time())
    local schemes = {
        "Capptino Frappe",
	"Capptino Macchiato",
        "Capptino Mocha",
	"Dracula+",
	"rebecca",
	"Japanesque",
	"Chalkboard"
    }
    local i = math.random(#schemes)
    return schemes[i]
end

function set_random_color_scheme()
    local overrides = window:get_config_overrides() or {}
    local scheme = get_random_color_scheme()
    overrides.color_scheme = scheme
    window:set_config_overrides(overrides)
end

config.color_scheme = get_random_color_scheme()

wezterm.on('window-config-reloaded', function(window, pane)
    if not window:get_config_overrides() then
        set_random_color_scheme()
    end
end)

return config
