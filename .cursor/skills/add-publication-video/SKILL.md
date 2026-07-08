---
name: add-publication-video
description: >-
  给个人主页 index.html 的 Publications 列表添加/更新演示视频，确保在手机上稳定播放、
  不出现白框。使用时机：用户要求上传、添加、替换、压缩 publication/demo 视频，或
  提到视频白框、手机不播放、视频太大等问题时。
---

# 添加 Publication 演示视频

给 `index.html` 的 `publications` 数组添加演示视频。目标：**手机端稳定播放，绝不出现白框**。

## 背景（为什么会白框）

手机浏览器（iOS Safari、低电量/省流量模式）经常阻止或延迟 `autoplay`，且 iOS 限制同时播放的视频数量。此时若 `<video>` 没有 `poster`，就会显示成一片**白框**。

因此每个视频**必须满足三条铁律**：

1. **必须有 `poster` 封面图** —— 自动播放没触发时至少显示封面，而不是白框。
2. **必须同时提供 `webm` + `mp4` 两种格式** —— webm 体积小，mp4 兼容 iOS。
3. **必须压缩到移动端友好尺寸** —— 360p、去音轨、mp4 加 `+faststart`。

`index.html` 里已实现「进入视口才播放」的逻辑（`setupLazyVideoPlayback`）和 `.pub-gif-wrap video { background:#0f172a }` 兜底背景，无需重复添加。

## 工作流

复制此清单并逐项跟踪：

```
- [ ] 1. 拿到源视频路径，确定 slug（英文小写、下划线，如 uniprototype_iros26）
- [ ] 2. 运行脚本生成 mp4 + webm + poster
- [ ] 3. 把生成的条目加入 index.html 的 publications 数组
- [ ] 4. 校验产物有效、体积合理
```

### 步骤 1：确定 slug

slug 用作文件名前缀，产物为 `images/<slug>.mp4`、`images/<slug>.webm`、`images/<slug>-poster.jpg`。

### 步骤 2：运行脚本（会自动压缩 + 生成封面）

```bash
.cursor/skills/add-publication-video/scripts/add_video.sh <源视频路径> <slug>
```

脚本会：360p / 去音轨 / H.264 mp4(+faststart) + VP9 webm，并从第 1 秒抽一帧做 poster。已存在同名文件会先备份到 `images/_orig_backup/`。脚本结束会打印可直接粘贴的 `publications` 条目。

### 步骤 3：加入 publications 数组

在 `index.html` 的 `const publications = [ ... ]` 中新增（`webm`/`mp4`/`poster` 三项缺一不可）：

```js
{
  authors: '<b>Xiao Hu</b>, et al.',
  title: '论文标题.',
  venue: '会议/期刊',
  webm: './images/<slug>.webm',
  mp4: './images/<slug>.mp4',
  poster: './images/<slug>-poster.jpg',
  mp4Height: 180
},
```

有视频的条目会自动排到前面并显示 `▶ Demo` 徽章，无需其他改动。

### 步骤 4：校验

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height -of csv=p=0 images/<slug>.mp4
ls -la images/<slug>.mp4 images/<slug>.webm images/<slug>-poster.jpg
```

期望：编码 `h264` / `vp9`，高度 `360`，单文件通常 < 1.5 MB。

## 手动命令（脚本不可用时的兜底）

```bash
# mp4
ffmpeg -y -i INPUT -vf "scale=-2:360" -c:v libx264 -crf 28 -preset slow \
  -pix_fmt yuv420p -an -movflags +faststart images/<slug>.mp4
# webm
ffmpeg -y -i INPUT -vf "scale=-2:360" -c:v libvpx-vp9 -crf 36 -b:v 0 -an \
  -deadline good -cpu-used 2 -row-mt 1 images/<slug>.webm
# poster（必须）
ffmpeg -y -ss 00:00:01 -i images/<slug>.mp4 -frames:v 1 -q:v 3 images/<slug>-poster.jpg
```

## 常见错误

- ❌ 只填 `mp4` / 只填 `gif`，漏了 `poster` → 手机白框。poster 永远要有。
- ❌ 直接用几 MB 的原始 480p 视频 → 弱网加载慢、易白屏。务必先压到 360p。
- ❌ 忘记 `-movflags +faststart` → 移动端要等整段下载完才出首帧。
