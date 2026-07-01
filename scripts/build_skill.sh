#!/usr/bin/env bash
# 把 qiq-grill2prd skill 必要文件打包成 zip。
#
# 用法：
#   ./scripts/build_skill.sh                  # 用默认版本（日期+短 sha）
#   ./scripts/build_skill.sh v1.2.0           # 自定义版本
#
# 产物：
#   dist/qiq-grill2prd-<version>.zip
#
# zip 内部结构（解压后即可作为一个 skill 目录使用）：
#   qiq-grill2prd/
#   ├── SKILL.md
#   ├── LICENSE
#   └── references/
#       ├── repo-scan-checklist.md
#       ├── question-tree.md
#       ├── grilling-rules.md
#       └── prd-template.md

set -euo pipefail

# 仓库根目录（脚本位于 scripts/ 下）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

SKILL_NAME="qiq-grill2prd"

# ---- 版本号 ----
if [[ $# -ge 1 && -n "$1" ]]; then
  VERSION="$1"
else
  # 优先从 SKILL.md 的 frontmatter 中提取 version 字段
  if [[ -f "$REPO_ROOT/SKILL.md" ]]; then
    FRONTMATTER_VERSION=$(sed -n '/^---$/,/^---$/p' "$REPO_ROOT/SKILL.md" | sed -n 's/^version: *//p' | head -1)
  fi
  if [[ -n "${FRONTMATTER_VERSION:-}" ]]; then
    VERSION="$FRONTMATTER_VERSION"
    echo "==> 从 SKILL.md frontmatter 读取版本: $VERSION"
  else
    DATE_TAG="$(date +%Y%m%d)"
    if git rev-parse --short HEAD >/dev/null 2>&1; then
      SHA_TAG="$(git rev-parse --short HEAD)"
      VERSION="${DATE_TAG}-${SHA_TAG}"
    else
      VERSION="${DATE_TAG}"
    fi
    echo "==> 自动生成版本: $VERSION"
  fi
fi

# ---- 必备文件清单（缺一个都视为打包失败）----
REQUIRED_FILES=(
  "SKILL.md"
  "references/repo-scan-checklist.md"
  "references/question-tree.md"
  "references/grilling-rules.md"
  "references/prd-template.md"
)

# 可选文件（存在则一并打入）
OPTIONAL_FILES=(
  "LICENSE"
  "README.md"
)

echo "==> 校验必备文件"
for f in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: 缺少必备文件: $f" >&2
    exit 1
  fi
  echo "    ok  $f"
done

# ---- 准备 staging 目录 ----
DIST_DIR="$REPO_ROOT/dist"
mkdir -p "$DIST_DIR"

STAGE_ROOT="$(mktemp -d)"
trap 'rm -rf "$STAGE_ROOT"' EXIT

STAGE_DIR="$STAGE_ROOT/$SKILL_NAME"
mkdir -p "$STAGE_DIR"

echo "==> 拷贝必备文件到 staging"
for f in "${REQUIRED_FILES[@]}"; do
  mkdir -p "$STAGE_DIR/$(dirname "$f")"
  cp "$f" "$STAGE_DIR/$f"
done

echo "==> 拷贝可选文件（若存在）"
for f in "${OPTIONAL_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    mkdir -p "$STAGE_DIR/$(dirname "$f")"
    cp "$f" "$STAGE_DIR/$f"
    echo "    +   $f"
  fi
done

# ---- 打包 ----
ZIP_NAME="${SKILL_NAME}-${VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

# 删除同名旧产物，避免 zip 追加模式带来的不一致
rm -f "$ZIP_PATH"

if ! command -v zip >/dev/null 2>&1; then
  echo "ERROR: 未找到 zip 命令，请先安装（如 apt install zip / brew install zip）" >&2
  exit 1
fi

echo "==> 生成 $ZIP_PATH"
( cd "$STAGE_ROOT" && zip -r -q "$ZIP_PATH" "$SKILL_NAME" )

# ---- 输出摘要 ----
SIZE_HUMAN="$(du -h "$ZIP_PATH" | awk '{print $1}')"
FILE_COUNT="$(unzip -Z1 "$ZIP_PATH" | wc -l | tr -d ' ')"

echo
echo "==> 打包完成"
echo "    路径: $ZIP_PATH"
echo "    版本: $VERSION"
echo "    大小: $SIZE_HUMAN"
echo "    文件数: $FILE_COUNT"
echo
echo "内部结构:"
unzip -Z1 "$ZIP_PATH" | sed 's/^/    /'
