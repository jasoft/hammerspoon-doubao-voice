
require("hs.ipc")
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- 按下 Option + 空格，停留 0.1 秒，再按下 Fn
hs.loadSpoon("OptionSpaceFn")
-- 由 Karabiner DriverKit 驱动接管物理 Option+空格 -> 延时 0.1 秒触发硬件级 Fn
spoon.OptionSpaceFn.config.listenOptionSpace = false
spoon.OptionSpaceFn:start()

-- 按下 / 切换到 ABC 输入法（仅无修饰键时触发），空格时切回原输入法
local slashLog = hs.logger.new("SlashToABC", "debug")
local ABC_INPUT_SOURCE = "ABC"
local FALLBACK_INPUT_METHOD = " 微信输入法"
local switchedBySlash = false
local SWITCH_RETRY_COUNT = 3
local SWITCH_RETRY_DELAY = 0.1

-- 缓存上次使用的非 ABC 输入法（启动时和运行中持续更新）
local lastInputMethod = nil

-- 切换输入法并验证，失败则重试（参考 DoubaoVoice.spoon）
local function switchToInput(source, retryCount)
    retryCount = retryCount or 0
    local ok = hs.keycodes.setMethod(source)
    slashLog.df("setMethod(%s) = %s", source, tostring(ok))

    if not ok then return false end

    local current = hs.keycodes.currentMethod()
    if current == source then
        return true
    end

    if retryCount < SWITCH_RETRY_COUNT then
        slashLog.df("输入法未就绪，重试 %d/%d", retryCount + 1, SWITCH_RETRY_COUNT)
        hs.timer.doAfter(SWITCH_RETRY_DELAY, function()
            switchToInput(source, retryCount + 1)
        end)
    else
        slashLog.w("切换失败，已达最大重试次数")
    end

    return false
end

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
        switchToInput(target)
    end

    return false
end)
_G.slashWatcher:start()
slashLog.i("SlashToABC 已启动")

-- 按下 F13 执行 obsidian-typeless-diary
local diaryLog = hs.logger.new("ObsidianDiary", "info")
local DIARY_SCRIPT = "/Users/weiwang/.local/bin/obsidian-typeless-diary"

_G.f13DiaryHotkey = hs.hotkey.bind({}, "f13", function()
    diaryLog.i("F13 按下，执行 " .. DIARY_SCRIPT)
    local task = hs.task.new(DIARY_SCRIPT, function(exitCode, stdOut, stdErr)
        if exitCode ~= 0 then
            diaryLog.ef("执行失败 (code %d): %s", exitCode, stdErr or "")
        else
            diaryLog.df("执行成功: %s", stdOut or "")
        end
    end)

    local env = task:environment()
    env["PATH"] = "/Users/weiwang/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:" .. (env["PATH"] or "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")
    task:setEnvironment(env)
    task:start()
end)
diaryLog.i("F13 -> obsidian-typeless-diary 热键已注册")
