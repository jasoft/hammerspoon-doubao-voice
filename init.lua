
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- 按下 / 切换到 ABC 输入法（仅无修饰键时触发），空格时切回原输入法
local slashLog = hs.logger.new("SlashToABC", "debug")
local ABC_INPUT_SOURCE = "ABC"
local FALLBACK_INPUT_METHOD = "com.bytedance.inputmethod.doubaoime.pinyin"
local switchedBySlash = false

-- 缓存上次使用的非 ABC 输入法（启动时和运行中持续更新）
local lastInputMethod = nil

-- 初始化：读取当前输入法
do
    local m = hs.keycodes.currentMethod()
    local l = hs.keycodes.currentLayout()
    slashLog.df("启动: method=%s, layout=%s", tostring(m), tostring(l))
    if m and l ~= ABC_INPUT_SOURCE then
        lastInputMethod = m
    end
end

-- 监听输入法变化，持续缓存非 ABC 的输入法
_G.imeWatcher = hs.keycodes.inputSourceChanged(function()
    local m = hs.keycodes.currentMethod()
    local l = hs.keycodes.currentLayout()
    if m and l ~= ABC_INPUT_SOURCE then
        lastInputMethod = m
        slashLog.df("输入法变化，缓存: %s", m)
    end
end)

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
        switchedBySlash = true
        slashLog.df("检测到 / 键，切换到 %s（切回目标: %s）", ABC_INPUT_SOURCE, tostring(lastInputMethod))
        hs.keycodes.setLayout(ABC_INPUT_SOURCE)
        return false
    end

    -- 空格键（keycode 49）且由 slash 触发过切换，切回原输入法
    if keycode == 49 and switchedBySlash then
        switchedBySlash = false
        local target = lastInputMethod or FALLBACK_INPUT_METHOD
        slashLog.df("检测到空格，切回: %s", target)
        hs.keycodes.setMethod(target)
    end

    return false
end)
_G.slashWatcher:start()
slashLog.i("SlashToABC 已启动")
