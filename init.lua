hs.loadSpoon("DoubaoVoice")
spoon.DoubaoVoice:start()

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- 按下 / 切换到 ABC 输入法（仅无修饰键时触发），空格时切回原输入法
local slashLog = hs.logger.new("SlashToABC", "debug")
local ABC_INPUT_SOURCE = "ABC"
local previousMethod = nil
local switchedBySlash = false

_G.slashWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local keycode = event:getKeyCode()
    local flags = event:getFlags()
    local hasModifier = flags.shift or flags.ctrl or flags.alt or flags.cmd

    -- 每个 keyDown 都记录，确认事件是否被接收
    slashLog.df("keyDown: keycode=%d, switched=%s, hasMod=%s",
        keycode, tostring(switchedBySlash), tostring(hasModifier))

    -- 只在无修饰键时处理
    if hasModifier then
        return false
    end

    -- / 键的 keycode 是 44
    if keycode == 44 then
        local currentMethod = hs.keycodes.currentMethod()
        local currentLayout = hs.keycodes.currentLayout()
        slashLog.df("Slash: method=%s, layout=%s", tostring(currentMethod), tostring(currentLayout))
        if currentLayout ~= ABC_INPUT_SOURCE then
            previousMethod = currentMethod
            switchedBySlash = true
        end
        slashLog.df("切换到 %s（原输入法: %s）", ABC_INPUT_SOURCE, tostring(previousMethod))
        hs.keycodes.setLayout(ABC_INPUT_SOURCE)
        return false
    end

    -- 空格键（keycode 49）且由 slash 触发过切换，切回原输入法
    if keycode == 49 and switchedBySlash then
        switchedBySlash = false
        if previousMethod then
            slashLog.df("检测到空格，切回原输入法: %s", tostring(previousMethod))
            hs.keycodes.setMethod(previousMethod)
        else
            slashLog.w("原输入法为空，无法切回")
        end
    end

    return false
end)
_G.slashWatcher:start()
slashLog.i("SlashToABC 已启动")
