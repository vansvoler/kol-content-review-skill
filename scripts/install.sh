#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 安装 KOL 审稿 skill 到本机 agent skill 目录
# ============================================================

SKILL_NAME="kol-content-review"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

target_dir=""

usage() {
  cat <<'USAGE'
用法:
  bash scripts/install.sh --target claude
  bash scripts/install.sh --target agents
  bash scripts/install.sh --target-dir "$HOME/.claude/skills"

参数:
  --target claude    安装到 ~/.claude/skills
  --target agents    安装到 ~/.agents/skills
  --target-dir DIR   安装到指定 skills 根目录
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      case "${2:-}" in
        claude) target_dir="$HOME/.claude/skills" ;;
        agents|codex) target_dir="$HOME/.agents/skills" ;;
        *)
          echo "未知 target: ${2:-}" >&2
          usage
          exit 2
          ;;
      esac
      shift 2
      ;;
    --target-dir)
      target_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$target_dir" ]]; then
  echo "缺少安装目标。请指定 --target 或 --target-dir。" >&2
  usage
  exit 2
fi

mkdir -p "$target_dir"

destination="$target_dir/$SKILL_NAME"
if [[ -e "$destination" ]]; then
  backup="$destination.backup-$(date +%Y%m%d%H%M%S)"
  mv "$destination" "$backup"
  echo "已备份旧版本: $backup"
fi

mkdir -p "$destination"
cp -R \
  "$REPO_ROOT/SKILL.md" \
  "$REPO_ROOT/assets" \
  "$REPO_ROOT/references" \
  "$REPO_ROOT/scripts" \
  "$destination/"

echo "安装完成: $destination"
echo "建议验证: test -f \"$destination/SKILL.md\""

