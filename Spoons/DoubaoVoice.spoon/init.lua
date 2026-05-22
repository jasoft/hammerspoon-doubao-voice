-- ============================================
-- DoubaoVoice Spoon
-- 右Option长按 -> 豆包语音输入 -> 松开关闭
-- ============================================
local obj = {}
obj.__index = obj

-- Spoon 元信息
obj.name = "DoubaoVoice"
obj.version = "1.0"
obj.author = "weiwang"
obj.license = "MIT"

-- 配置参数（可通过 obj.config 覆盖）
obj.config = {
    targetInputSource = "豆包输入法",
    defaultInputSource = "微信输入法",
    longPressThreshold = 0,
    optionDoubleTapInterval = 0.05,
    imeReadyDelay = 0.05,
    voicePanelPopUpDelay = 0.3,
    restoreImeDelay = 0.3,
    activateSound = "Funk",
    switchRetryCount = 3,
    switchRetryDelay = 0.1,
}

-- 物理按键 keycode
local KEYCODE_RIGHT_OPT = 61

-- 日志消息常量
local LOG_DOUBLE_TAP_START = "模拟双击左 Option"
local LOG_DOUBLE_TAP_DONE = "双击左 Option 完成"
local LOG_SWITCH_IME = "切换到: %s, 结果: %s"
local LOG_SWITCH_VERIFY = "验证输入法: 当前=%s, 目标=%s"
local LOG_SWITCH_RETRY = "输入法未就绪，重试 %d/%d"
local LOG_RIGHT_OPT_DOWN = "右Option按下"
local LOG_RIGHT_OPT_UP = "右Option松开，按住 %.3f 秒"
local LOG_LONG_PRESS_TRIGGERED = "长按已触发，松开时单击左Option关闭豆包语音"
local LOG_SHORT_PRESS = "短按，不触发豆包语音"
local LOG_LONG_PRESS_DETECT = "检测到长按 (%.3f秒)，触发豆包语音"
local LOG_FLAGS_CHANGED = "flagsChanged: keycode=%d, alt=%s, cmd=%s"
local LOG_EVENT_ERROR = "eventtap 回调报错:\n%s"
local LOG_STARTED = "豆包语音快捷键已启动\n长按右Option触发"
local LOG_TARGET_IME = "目标输入法: %s"
local LOG_DEFAULT_IME = "默认输入法: %s"
local LOG_THRESHOLD = "长按阈值: %.2f 秒"

-- 内部状态
local log = hs.logger.new(obj.name, "debug")
local rightOptIsDown = false
local rightOptDownTime = 0
local longPressTriggered = false

function obj:tapLeftOptionOnce()
    hs.eventtap.event.newKeyEvent(hs.keycodes.map.alt, true):post()
    hs.eventtap.event.newKeyEvent(hs.keycodes.map.alt, false):post()
end

function obj:doubleTapLeftOption()
    log.df(LOG_DOUBLE_TAP_START)
    self:tapLeftOptionOnce()
    hs.timer.doAfter(self.config.optionDoubleTapInterval, function()
        self:tapLeftOptionOnce()
        log.df(LOG_DOUBLE_TAP_DONE)
    end)
end

function obj:switchToInput(source, retryCount)
    retryCount = retryCount or 0

    local ok = hs.keycodes.setMethod(source)
    log.df(LOG_SWITCH_IME, source, tostring(ok))

    if not ok then return false end

    -- 验证是否真的切换成功
    local current = hs.keycodes.currentMethod()
    log.df(LOG_SWITCH_VERIFY, tostring(current), source)

    if current == source then
        return true
    end

    -- 切换未生效，重试
    if retryCount < self.config.switchRetryCount then
        log.df(LOG_SWITCH_RETRY, retryCount + 1, self.config.switchRetryCount)
        hs.timer.doAfter(self.config.switchRetryDelay, function()
            self:switchToInput(source, retryCount + 1)
        end)
    end

    return false
end

function obj:onRightOptDown()
    if rightOptIsDown then return end

    rightOptIsDown = true
    rightOptDownTime = hs.timer.absoluteTime()
    longPressTriggered = false
    log.df(LOG_RIGHT_OPT_DOWN)

    -- 按下立即开始切换输入法，减少等待时间
    self:switchToInput(self.config.targetInputSource)
end

function obj:onRightOptUp()
    if not rightOptIsDown then return end

    rightOptIsDown = false
    local holdDuration = (hs.timer.absoluteTime() - rightOptDownTime) / 1e9
    log.df(LOG_RIGHT_OPT_UP, holdDuration)

    if longPressTriggered then
        log.df(LOG_LONG_PRESS_TRIGGERED)
        self:tapLeftOptionOnce()

        hs.timer.doAfter(self.config.restoreImeDelay, function()
            self:switchToInput(self.config.defaultInputSource)
        end)
    else
        log.df(LOG_SHORT_PRESS)
    end
end

function obj:checkLongPress()
    if not rightOptIsDown then return end

    local holdDuration = (hs.timer.absoluteTime() - rightOptDownTime) / 1e9
    if holdDuration >= self.config.longPressThreshold and not longPressTriggered then
        longPressTriggered = true
        log.df(LOG_LONG_PRESS_DETECT, holdDuration)

        -- 输入法已在按下时切换，这里只需延迟执行双击
        hs.timer.doAfter(self.config.imeReadyDelay, function()
            self:doubleTapLeftOption()
        end)

        hs.timer.doAfter(self.config.voicePanelPopUpDelay, function()
            hs.sound.getByName(self.config.activateSound):play()
        end)
    end
end

function obj:handleFlagsChanged(event)
    local keycode = event:getKeyCode()
    local flags = event:getFlags()

    log.df(LOG_FLAGS_CHANGED, keycode, tostring(flags.alt), tostring(flags.cmd))

    if keycode ~= KEYCODE_RIGHT_OPT then
        return false
    end

    local optIsDown = flags.alt

    if optIsDown and not rightOptIsDown then
        self:onRightOptDown()
        hs.timer.doUntil(
            function() return not rightOptIsDown or longPressTriggered end,
            function() self:checkLongPress() end,
            0.05
        )
    elseif not optIsDown and rightOptIsDown then
        self:onRightOptUp()
    end

    return false
end

function obj:safeEventHandler(event)
    local self_ref = self
    local ok, result = xpcall(function()
        return self_ref:handleFlagsChanged(event)
    end, debug.traceback)

    if not ok then
        log.ef(LOG_EVENT_ERROR, tostring(result))
        return false
    end

    return result
end

function obj:start()
    self:switchToInput(self.config.defaultInputSource)

    self.watcher = hs.eventtap.new(
        {hs.eventtap.event.types.flagsChanged},
        function(event) return self:safeEventHandler(event) end
    )
    self.watcher:start()

    hs.alert.show(LOG_STARTED)
    log.i(string.format(LOG_TARGET_IME, self.config.targetInputSource))
    log.i(string.format(LOG_DEFAULT_IME, self.config.defaultInputSource))
    log.i(string.format(LOG_THRESHOLD, self.config.longPressThreshold))

    return self
end

function obj:stop()
    if self.watcher then
        self.watcher:stop()
        self.watcher = nil
    end
    return self
end

return obj
