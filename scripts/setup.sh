#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

target=""
target_dir=""
no_system_tools=1

usage() {
  cat <<'USAGE'
用法:
  bash scripts/setup.sh --target codex
  bash scripts/setup.sh --target claude
  bash scripts/setup.sh --target agents
  bash scripts/setup.sh --target-dir "$HOME/.codex/skills"

参数:
  --target codex        安装到 ~/.codex/skills
  --target claude       安装到 ~/.claude/skills
  --target agents       安装到 ~/.agents/skills
  --target-dir DIR      安装到指定 skills 根目录
  --no-system-tools     不安装 Homebrew、Command Line Tools 或系统工具（默认）
  -h, --help            显示帮助

说明:
  这个脚本面向非技术同事，只安装 skill 本身。
  它会检查环境并运行验证，但不会自动安装系统级 Office/PDF/OCR 工具。
USAGE
}

log() {
  echo "$*"
}

fail() {
  echo ""
  echo "安装中断：$*" >&2
  echo ""
  echo "请把上面的完整输出发给 Vance 或技术同事处理。" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        fail "--target 后需要指定 codex、claude 或 agents。"
      fi
      target="${2:-}"
      shift 2
      ;;
    --target-dir)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        fail "--target-dir 后需要指定目录路径。"
      fi
      target_dir="${2:-}"
      shift 2
      ;;
    --no-system-tools)
      no_system_tools=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "未知参数: $1"
      ;;
  esac
done

if [[ -z "$target" && -z "$target_dir" ]]; then
  usage
  fail "缺少安装目标。请指定 --target 或 --target-dir。"
fi

if [[ -n "$target" && -n "$target_dir" ]]; then
  fail "--target 和 --target-dir 只能选择一个。"
fi

log "== KOL Content Review Skill 一键安装 =="
log "当前目录: $REPO_ROOT"
log "安装模式: 不安装系统工具"

case "$(uname -s)" in
  Darwin)
    log "系统: macOS"
    ;;
  Linux)
    log "系统: Linux"
    ;;
  *)
    fail "当前系统暂未支持。请在 macOS 或 Linux 上运行。"
    ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  fail "缺少 python3。请先安装 Python 3.9+，macOS 可从 https://www.python.org/downloads/macos/ 下载。"
fi

python3 - <<'PY' || fail "Python 版本过低，需要 Python 3.9+。"
import sys

version = sys.version_info
print(f"Python: {version.major}.{version.minor}.{version.micro}")
if version < (3, 9):
    raise SystemExit(1)
PY

if [[ "$no_system_tools" -eq 1 ]]; then
  log "提示: 本脚本不会安装 Homebrew、Xcode Command Line Tools、LibreOffice、PDF/OCR 工具。"
  log "      PDF/PPT/扫描件能力取决于当前 agent 或你之后手动安装的工具。"
fi

log ""
log "== 运行验证 =="
bash "$REPO_ROOT/scripts/validate.sh" || fail "验证失败。"

log ""
log "== 安装 skill =="
if [[ -n "$target_dir" ]]; then
  bash "$REPO_ROOT/scripts/install.sh" --target-dir "$target_dir" || fail "安装失败。"
else
  bash "$REPO_ROOT/scripts/install.sh" --target "$target" || fail "安装失败。"
fi

log ""
log "安装完成。请重启 Codex / Claude Code / agent，让新 skill 生效。"
