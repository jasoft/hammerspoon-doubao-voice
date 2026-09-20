# OptionSpaceFn Spoon

按下 Option + 空格，停留 0.1 秒，再按下 Fn。

## 功能

1. **宏执行模式 (`triggerSequence`)**：一次性自动模拟执行【按下 Option + 空格 -> 停留 0.1秒 -> 按下 Fn】。
2. **监听模式 (`listenOptionSpace`)**：监听物理键盘上按下的 Option + 空格，在设定的延迟（默认 0.1 秒）后自动补按 Fn 键，并将原 Option + 空格事件正常放行给系统或前台应用。
3. **URL Scheme 触发**：支持通过 `hammerspoon://option-space-fn` 触发，方便外部硬件（如 Ulanzi Deck / Stream Deck）、系统快捷指令（Shortcuts）、Raycast 或终端调用。
4. **自定义快捷键**：支持使用 `bindHotkeys` 绑定任意快捷键触发宏序列。

## 配置与使用

在 `~/.hammerspoon/init.lua` 中添加：

```lua
hs.loadSpoon("OptionSpaceFn")
spoon.OptionSpaceFn:start()
```

### 自定义配置示例

```lua
hs.loadSpoon("OptionSpaceFn")

-- 可选：覆盖默认配置
spoon.OptionSpaceFn.config.delay = 0.1               -- 停留时间（秒）
spoon.OptionSpaceFn.config.fnHoldDuration = 0.05      -- Fn 按下保持时间（秒）
spoon.OptionSpaceFn.config.fnPressCount = 1           -- 按下 Fn 次数（若系统听写需双击 Fn 可设为 2）
spoon.OptionSpaceFn.config.listenOptionSpace = true   -- 是否监听物理 Option + 空格
spoon.OptionSpaceFn.config.enableUrlEvent = true      -- 是否启用 URL Scheme 触发
spoon.OptionSpaceFn.config.showNotification = false   -- 是否弹窗提示

-- 可选：绑定自定义快捷键触发整个宏序列
spoon.OptionSpaceFn:bindHotkeys({
    trigger = {{"ctrl", "alt"}, "space"}
})

spoon.OptionSpaceFn:start()
```

### 外部调用方式

- 终端 / 脚本调用：
  ```bash
  open "hammerspoon://option-space-fn"
  # 或者通过 hs 命令行
  hs -c "spoon.OptionSpaceFn:triggerSequence()"
  ```
- 硬件宏按键（如 Ulanzi Deck）：
  - 配置为打开 URL：`hammerspoon://option-space-fn`
  - 或配置为执行 Shell 命令：`open "hammerspoon://option-space-fn"`
