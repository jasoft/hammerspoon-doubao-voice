# DoubaoVoice Spoon

右Option长按触发豆包语音输入，松开自动关闭并切回微信输入法。

## 功能

- 长按右Option（超过0.25秒）激活豆包语音输入
- 松开右Option自动关闭语音输入
- 自动切回微信输入法
- 短按不触发，避免误触

## 安装

```bash
cd ~/.hammerspoon
git clone https://github.com/jasoft/hammerspoon-doubao-voice.git
```

## 使用

在 `~/.hammerspoon/init.lua` 中添加：

```lua
hs.loadSpoon("DoubaoVoice")
spoon.DoubaoVoice:start()
```

## 自定义配置

```lua
hs.loadSpoon("DoubaoVoice")

-- 可选：覆盖默认配置
spoon.DoubaoVoice.config.targetInputSource = "其他输入法"
spoon.DoubaoVoice.config.defaultInputSource = "英文"
spoon.DoubaoVoice.config.longPressThreshold = 0.3

spoon.DoubaoVoice:start()
```

## 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| targetInputSource | 豆包输入法 | 语音输入使用的输入法 |
| defaultInputSource | 微信输入法 | 默认输入法 |
| longPressThreshold | 0.25 | 触发长按的最小时间（秒） |
| optionDoubleTapInterval | 0.18 | 双击间隔（秒） |
| imeReadyDelay | 0.2 | 切换输入法后等待时间（秒） |
| restoreImeDelay | 0.3 | 松开后切回默认输入法的延迟（秒） |
| activateSound | Funk | 激活时的音效 |
