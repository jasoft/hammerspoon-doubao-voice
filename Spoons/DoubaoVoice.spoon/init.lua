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
    longPressThreshold = 0.25,
    optionDoubleTapInterval = 0.18,
    imeReadyDelay = 0.2,
    voicePanelPopUpDelay = 0.3,
    restoreImeDelay = 0.3,
    activateSound = "Funk",
    micCheckDelay = 1.0,
    micCheckRegion = {x = 0, y = 0, w = 400, h = 25},
}

-- 物理按键 keycode
local KEYCODE_RIGHT_OPT = 61

-- 日志消息常量
local LOG_DOUBLE_TAP_START = "模拟双击左 Option"
local LOG_DOUBLE_TAP_DONE = "双击左 Option 完成"
local LOG_SWITCH_IME = "切换到: %s, 结果: %s"
local LOG_MIC_CHECK = "检测麦克风图标..."
local LOG_MIC_FOUND = "麦克风图标已出现"
local LOG_MIC_NOT_FOUND = "麦克风图标未出现，重试激活"
local LOG_RETRY_ACTIVATE = "重试激活豆包语音"
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

function obj:checkMicIcon()
    local screen = hs.screen.primaryScreen()
    if not screen then return false end

    local region = self.config.micCheckRegion
    local截图 = hs.screen.snapshotOfArea(screen, region)

    if not截图 then return false end

    -- 检查截图中是否有麦克风图标的颜色特征（白色/亮色图标）
    local size =截图:size()
    local hasLightPixels = false

    -- 采样检查菜单栏区域是否有亮色像素（麦克风图标通常是白色）
    for x = 0, size.w - 1, 5 do
        for y = 0, size.h - 1, 2 do
            local pixel =截图:pixelAt(x, y)
            if pixel then
                local brightness = (pixel.red + pixel.green + pixel.blue) / 3
                if brightness > 0.8 then
                    hasLightPixels = true
                    break
                end
            end
        end
        if hasLightPixels then break end
    end

    return hasLightPixels
end

function obj:retryActivate()
    log.df(LOG_RETRY_ACTIVATE)

    -- 切回默认输入法
    self:switchToInput(self.config.defaultInputSource)

    -- 等待一下再切回豆包
    hs.timer.doAfter(0.3, function()
        self:switchToInput(self.config.targetInputSource)

        -- 再等待后双击
        hs.timer.doAfter(self.config.imeReadyDelay, function()
            self:doubleTapLeftOption()
        end)
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

        self:switchToInput(self.config.targetInputSource)

        hs.timer.doAfter(self.config.imeReadyDelay, function()
            self:doubleTapLeftOption()

            -- 检测麦克风图标是否出现
            hs.timer.doAfter(self.config.micCheckDelay, function()
                log.df(LOG_MIC_CHECK)
                local micFound = self:checkMicIcon()

                if micFound then
                    log.df(LOG_MIC_FOUND)
                    hs.sound.getByName(self.config.activateSound):play()
                else
                    log.df(LOG_MIC_NOT_FOUND)
                    self:retryActivate()
                end
            end)
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
