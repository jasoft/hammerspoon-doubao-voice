--- === RightOptionMacro ===
--- Long-press Right Option: activate voice input on press, stop on release

local obj = {}
obj.__index = obj

obj.name = "RightOptionMacro"
obj.version = "1.0"
obj.author = "weiwang"

-- Configuration
obj.longPressDuration = 0.3
obj.fnTapDelay = 0.08

-- Internal state
local rightOptDown = false
local longPressTimer = nil
local triggered = false
local simulating = false
local suppressReleaseUntil = 0 -- timestamp: ignore release events before this

local RIGHT_OPT_KEYCODE = 61

local function doubleTapFN(reholdRightOpt)
    simulating = true
    hs.printf("RightOptionMacro: [sim] doubleTapFN start, rehold=%s", tostring(reholdRightOpt))

    -- Release Right Option first so system doesn't see alt modifier
    hs.eventtap.event.newKeyEvent(RIGHT_OPT_KEYCODE, false):post()
    hs.timer.usleep(50000)

    -- Double-tap FN
    hs.eventtap.event.newKeyEvent(63, true):post()
    hs.timer.usleep(30000)
    hs.eventtap.event.newKeyEvent(63, false):post()
    hs.timer.usleep(obj.fnTapDelay * 1000000)
    hs.eventtap.event.newKeyEvent(63, true):post()
    hs.timer.usleep(30000)
    hs.eventtap.event.newKeyEvent(63, false):post()
    hs.timer.usleep(50000)

    -- Re-hold Right Option if still physically pressed
    if reholdRightOpt then
        hs.eventtap.event.newKeyEvent(RIGHT_OPT_KEYCODE, true):post()
        -- Suppress release events for 200ms to absorb confused state
        suppressReleaseUntil = hs.timer.secondsSinceEpoch() + 0.2
    end

    hs.printf("RightOptionMacro: [sim] doubleTapFN done")
    simulating = false
end

function obj:start()
    self.eventTap = hs.eventtap.new(
        {hs.eventtap.event.types.flagsChanged},
        function(event)
            local keyCode = event:getKeyCode()
            local flags = event:getFlags()

            -- Ignore synthetic events from our own simulation
            if simulating then return false end

            if keyCode ~= RIGHT_OPT_KEYCODE then return false end

            if flags.alt then
                -- Right Option pressed
                if not rightOptDown then
                    rightOptDown = true
                    triggered = false
                    longPressTimer = hs.timer.doAfter(self.longPressDuration, function()
                        if rightOptDown and not triggered then
                            triggered = true
                            hs.printf("RightOptionMacro: ACTIVATE voice input")
                            hs.eventtap.keyStroke({"ctrl", "cmd"}, "2")
                            hs.timer.doAfter(0.3, function()
                                hs.printf("RightOptionMacro: starting voice input")
                                doubleTapFN(true)
                            end)
                        end
                    end)
                end
            else
                -- Right Option released
                -- Ignore if in cooldown period (fake release from rehold)
                local now = hs.timer.secondsSinceEpoch()
                if now < suppressReleaseUntil then
                    hs.printf("RightOptionMacro: [event] suppressed fake release (cooldown)")
                    return false
                end

                if rightOptDown then
                    rightOptDown = false
                    if longPressTimer then
                        longPressTimer:stop()
                        longPressTimer = nil
                    end
                    if triggered then
                        hs.printf("RightOptionMacro: STOP voice input")
                        doubleTapFN(false)
                        return true
                    end
                end
            end

            return false
        end
    )

    self.eventTap:start()
    hs.printf("RightOptionMacro: started")
    return self
end

function obj:stop()
    if self.eventTap then
        self.eventTap:stop()
        self.eventTap = nil
    end
    return self
end

return obj
