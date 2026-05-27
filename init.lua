hs.loadSpoon("DoubaoVoice")
spoon.DoubaoVoice:start()

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- 按下 / 切换到 ABC 输入法（仅无修饰键时触发），空格时切回原输入法
local slashLog = hs.logger.new("SlashToABC", "debug")
local ABC_INPUT_SOURCE = "ABC"
local previousLayout = nil
local switchedBySlash = false

_G.slashWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local keycode = event:getKeyCode()
    local flags = event:getFlags()
    local hasModifier = flags.shift or flags.ctrl or flags.alt or flags.cmd

    -- 只在无修饰键时处理
    if hasModifier then
        return false
    end

    -- / 键的 keycode 是 44
    if keycode == 44 then
        local current = hs.keycodes.currentLayout()
        if current ~= ABC_INPUT_SOURCE then
            previousLayout = current
            switchedBySlash = true
        end
        slashLog.df("检测到 / 键，切换到 %s（原输入法: %s）", ABC_INPUT_SOURCE, tostring(previousLayout))
        hs.keycodes.setLayout(ABC_INPUT_SOURCE)
        return false
    end

    -- 空格键（keycode 49）且由 slash 触发过切换，切回原输入法
    if keycode == 49 and switchedBySlash then
        switchedBySlash = false
        if previousLayout then
            slashLog.df("检测到空格，切回原输入法: %s", tostring(previousLayout))
            hs.keycodes.setLayout(previousLayout)
        end
    end

    return false
end)
_G.slashWatcher:start()
slashLog.i("SlashToABC 已启动")
