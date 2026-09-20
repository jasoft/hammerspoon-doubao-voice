-- ============================================
-- OptionSpaceFn Spoon
-- 按下 Option + 空格，停留 0.1 秒，再按下 Fn
-- 支持：
-- 1. 宏执行模式：直接调用 triggerSequence() 模拟整套按键
-- 2. 监听模式：监听物理键盘 Option+空格，延时自动按下 Fn
-- 3. URL Scheme：hammerspoon://option-space-fn 触发
-- 4. 快捷键绑定：通过 bindHotkeys() 自定义热键触发
-- ============================================
local obj = {}
obj.__index = obj

-- Spoon 元信息
obj.name = "OptionSpaceFn"
obj.version = "1.0"
obj.author = "weiwang"
obj.homepage = "https://github.com/jasoft/hammerspoon-doubao-voice"
obj.license = "MIT"

-- 配置参数（可通过 obj.config 覆盖）
obj.config = {
    delay = 0.1,                  -- Option+空格 与 按下 Fn 之间的等待停留时间（秒）
    fnHoldDuration = 0.05,        -- 按下 Fn 到松开的保持时间（秒）
    fnPressCount = 1,             -- 按下 Fn 的次数（默认 1 次，部分系统听写若需双击 Fn 可配置为 2）
    fnInterval = 0.05,            -- 多次按 Fn 之间的间隔时间（秒）
    listenOptionSpace = true,     -- 是否监听物理键盘的 Option+空格，触发后自动延时补按 Fn
    passThroughOptionSpace = true,-- 监听模式下是否放行 Option+空格 给系统或前台程序
    enableUrlEvent = true,        -- 是否开启 URL Scheme (hammerspoon://option-space-fn)
    urlActionName = "option-space-fn", -- URL Scheme 事件名
    showNotification = false,     -- 触发时是否显示 Hammerspoon 浮动通知
}

-- 内部状态与日志
local log = hs.logger.new(obj.name, "debug")
obj.logger = log
local KEYCODE_SPACE = 49
local KEYCODE_FN = 63

obj.isSimulating = false
obj.watcher = nil

--- OptionSpaceFn:pressOptionSpace(callback)
--- Method
--- 模拟按下 Option + 空格
function obj:pressOptionSpace(callback)
    self.isSimulating = true
    log.df("模拟按下 Option + 空格")
    hs.eventtap.keyStroke({"alt"}, "space", 10000)
    
    -- 50ms 后解除自模拟标记，防止误触发自身的 eventtap 监听
    hs.timer.doAfter(0.05, function()
        self.isSimulating = false
        if callback then callback() end
    end)
end

--- OptionSpaceFn:pressFn(callback)
--- Method
--- 模拟按下 Fn 键（通过 keycode 63 的 flagsChanged 事件）
function obj:pressFn(callback)
    local count = self.config.fnPressCount or 1
    log.df("模拟按下 Fn (共 %d 次)", count)
    
    local function tapOnce(idx)
        -- 按下 Fn
        hs.eventtap.event.newKeyEvent(KEYCODE_FN, true):post()
        hs.timer.doAfter(self.config.fnHoldDuration, function()
            -- 松开 Fn
            hs.eventtap.event.newKeyEvent(KEYCODE_FN, false):post()
            if idx < count then
                hs.timer.doAfter(self.config.fnInterval, function()
                    tapOnce(idx + 1)
                end)
            else
                log.df("Fn 按键模拟完成")
                if callback then callback() end
            end
        end)
    end

    tapOnce(1)
end

--- OptionSpaceFn:triggerSequence(callback)
--- Method
--- 依次模拟：按下 Option + 空格 -> 停留 delay 秒 -> 按下 Fn
function obj:triggerSequence(callback)
    log.i(string.format("触发宏序列: Option+空格 -> 停留 %.2f秒 -> Fn", self.config.delay))
    if self.config.showNotification then
        hs.alert.show(string.format("Option+Space -> (%.2fs) -> Fn", self.config.delay))
    end

    local binPath = "/Users/weiwang/.local/bin/option-space-fn"
    if hs.fs.attributes(binPath) then
        local t = hs.task.new(binPath, function(exitCode, stdOut, stdErr)
            log.df("option-space-fn 任务完成, exitCode=%d", exitCode)
            if callback then callback() end
        end, {"-d", tostring(self.config.delay)})
        t:start()
        return
    end

    self:pressOptionSpace(function()
        hs.timer.doAfter(self.config.delay, function()
            self:pressFn(callback)
        end)
    end)
end

--- OptionSpaceFn:bindHotkeys(mapping)
--- Method
--- 绑定快捷键触发宏序列
--- Parameters:
---  * mapping - 键值表，如 { trigger = {{"ctrl", "alt"}, "space"} }
function obj:bindHotkeys(mapping)
    local def = {
        trigger = hs.fnutils.partial(self.triggerSequence, self)
    }
    hs.spoons.bindHotkeysToSpec(def, mapping)
    return self
end

-- 内部按键事件处理
function obj:handleKeyEvent(event)
    local keycode = event:getKeyCode()
    local flags = event:getFlags()

    -- 仅当按下 Space (49) 且修饰键仅有 Option (alt) 时匹配
    local isOptionSpace = (keycode == KEYCODE_SPACE) and flags.alt and not flags.cmd and not flags.ctrl and not flags.shift and not flags.fn

    if isOptionSpace then
        if self.isSimulating then
            -- 自己模拟发出的按键，放行且不重复触发
            return false
        end

        log.df("检测到物理按下 Option + 空格，等待 %.2f 秒后自动按下 Fn", self.config.delay)
        if self.config.showNotification then
            hs.alert.show("Option+Space -> 延时按 Fn")
        end

        hs.timer.doAfter(self.config.delay, function()
            self:pressFn()
        end)

        -- passThroughOptionSpace 为 true 时返回 false（放行事件给系统/其它软件）
        return not self.config.passThroughOptionSpace
    end

    return false
end

--- OptionSpaceFn:start()
--- Method
--- 启动监听器与 URL Scheme
function obj:start()
    self:stop()

    -- 1. 注册 URL Scheme 事件 (hammerspoon://option-space-fn)
    if self.config.enableUrlEvent and self.config.urlActionName then
        hs.urlevent.bind(self.config.urlActionName, function(eventName, params)
            log.df("收到 URL Scheme 触发: hammerspoon://%s", eventName)
            self:triggerSequence()
        end)
    end

    -- 2. 监听物理 Option + 空格
    if self.config.listenOptionSpace then
        self.watcher = hs.eventtap.new(
            {hs.eventtap.event.types.keyDown},
            function(event)
                local ok, result = pcall(function()
                    return self:handleKeyEvent(event)
                end)
                if not ok then
                    log.ef("事件处理出错: %s", tostring(result))
                    return false
                end
                return result
            end
        )
        self.watcher:start()
        log.i("Option+空格 物理按键监听已启动")
    end

    log.i("OptionSpaceFn 已启动 (delay = " .. tostring(self.config.delay) .. "s)")
    return self
end

--- OptionSpaceFn:stop()
--- Method
--- 停止监听器
function obj:stop()
    if self.watcher then
        self.watcher:stop()
        self.watcher = nil
        log.df("Option+空格 物理按键监听已停止")
    end
    return self
end

return obj
