#!/usr/bin/env bash
#
# 把一个源视频转成移动端稳定的 publication demo 资源：
#   - 360p、去音轨、H.264 mp4（+faststart）
#   - 360p、去音轨、VP9 webm
#   - 一张 poster 封面 jpg（关键：没有 poster 手机上会出现白框）
#
# 用法:
#   scripts/add_video.sh <输入视频路径> <slug>
# 例:
#   scripts/add_video.sh ~/Downloads/new_demo.mov uniprototype_iros26
#
# 产物（写入仓库 images/ 目录）:
#   images/<slug>.mp4
#   images/<slug>.webm
#   images/<slug>-poster.jpg
#
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "用法: $0 <输入视频路径> <slug>" >&2
  echo "例:   $0 ~/Downloads/new_demo.mov uniprototype_iros26" >&2
  exit 1
fi

INPUT="$1"
SLUG="$2"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "错误: 未找到 ffmpeg，请先安装 (brew install ffmpeg)" >&2
  exit 1
fi

if [ ! -f "$INPUT" ]; then
  echo "错误: 输入文件不存在: $INPUT" >&2
  exit 1
fi

# 定位仓库根目录
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
IMG_DIR="$REPO_ROOT/images"
mkdir -p "$IMG_DIR"

MP4="$IMG_DIR/$SLUG.mp4"
WEBM="$IMG_DIR/$SLUG.webm"
POSTER="$IMG_DIR/$SLUG-poster.jpg"

# 若已存在同名文件，先备份，避免误覆盖
BACKUP_DIR="$IMG_DIR/_orig_backup"
for f in "$MP4" "$WEBM" "$POSTER"; do
  if [ -f "$f" ]; then
    mkdir -p "$BACKUP_DIR"
    cp -n "$f" "$BACKUP_DIR/$(basename "$f")" 2>/dev/null || true
  fi
done

echo ">>> [1/3] 生成 360p mp4 (H.264, 去音轨, faststart)"
ffmpeg -y -i "$INPUT" \
  -vf "scale=-2:360" \
  -c:v libx264 -crf 28 -preset slow -pix_fmt yuv420p \
  -an -movflags +faststart \
  "$MP4" -loglevel error

echo ">>> [2/3] 生成 360p webm (VP9, 去音轨)"
ffmpeg -y -i "$INPUT" \
  -vf "scale=-2:360" \
  -c:v libvpx-vp9 -crf 36 -b:v 0 -an -deadline good -cpu-used 2 -row-mt 1 \
  "$WEBM" -loglevel error

echo ">>> [3/3] 生成 poster 封面 (取第 1 秒的一帧)"
ffmpeg -y -ss 00:00:01 -i "$MP4" -frames:v 1 -q:v 3 "$POSTER" -loglevel error

echo ""
echo "完成。产物大小:"
ls -la "$MP4" "$WEBM" "$POSTER" | awk '{printf "  %-45s %8.1f KB\n", $NF, $5/1024}'

echo ""
echo "把下面这段加入 index.html 的 publications 数组（webm/mp4/poster 三项都要有）:"
cat <<EOF

      {
        authors: '<b>Xiao Hu</b>, et al.',
        title: '在此填写论文标题.',
        venue: '在此填写会议/期刊',
        webm: './images/$SLUG.webm',
        mp4: './images/$SLUG.mp4',
        poster: './images/$SLUG-poster.jpg',
        mp4Height: 180
      },
EOF
