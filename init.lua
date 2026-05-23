hs.loadSpoon("DoubaoVoice")
spoon.DoubaoVoice:start()

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- 按下 / 切换到 ABC 输入法
local log = hs.logger.new("SlashToABC", "debug")
local ABC_INPUT_SOURCE = "ABC"
local slashWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local keycode = event:getKeyCode()
    log.df("keyDown: keycode=%d", keycode)
    -- / 键的 keycode 是 44
    if keycode == 44 then
        log.df("检测到 / 键，切换到 %s", ABC_INPUT_SOURCE)
        local ok = hs.keycodes.setLayout(ABC_INPUT_SOURCE)
        log.df("切换结果: %s, 当前layout: %s, 当前method: %s", tostring(ok), tostring(hs.keycodes.currentLayout()), tostring(hs.keycodes.currentMethod()))
    end
    return false
end)
slashWatcher:start()
log.i("SlashToABC 已启动")
