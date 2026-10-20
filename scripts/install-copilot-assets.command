#!/usr/bin/env bash
#
# install-copilot-assets.command — macOS 双击运行版
# 对应 Windows 的 install-copilot-assets.ps1
#
# 将 .github/ 下的 skills/instructions/prompts/agents 同步到 VS Code Copilot 用户目录：
#   Skills        → ~/.copilot/skills/<name>/
#   Instructions  → ~/Library/Application Support/Code/User/prompts/*.instructions.md
#   Prompts       → ~/Library/Application Support/Code/User/prompts/*.prompt.md
#   Agents        → ~/Library/Application Support/Code/User/prompts/*.agent.md
#   全局指令      → ~/Library/Application Support/Code/User/prompts/newlife-global.instructions.md
#
# 通过 manifest 文件 (newlife-skills-manifest.json) 跟踪本工具安装过的资产，
# 再次执行安装时会自动删除仓库中已不存在但上次安装过的资产（孤儿清理）。
# 不会触碰 manifest 之外的文件，保证用户自有资产安全。
#
# 用法：
#   双击本文件                     安装或更新（自动删除已废弃资产）
#   ./install-copilot-assets.command --whatif          预览将要安装/删除的内容，不实际执行
#   ./install-copilot-assets.command --uninstall       卸载本工具安装过的全部资产
#   ./install-copilot-assets.command --assume-all-orphans --whatif   首次从旧脚本迁移前先预览
#   ./install-copilot-assets.command /path/to/repo    显式指定仓库根目录
#
# 双击说明：本脚本可能在 zsh 下被启动，首行会强制用 bash 重新执行；
# 在 Terminal.app 中双击运行时，仅当失败（退出码非 0）才暂停以便查看错误，
# 成功则直接由 Terminal 关闭窗口。
#
# 若双击提示“无法打开”或“不明开发者”，在终端执行一次：
#   xattr -dr com.apple.quarantine /路径/install-copilot-assets.command
#
# 若实际安装到 ~/Library/Application Support/Code/User/prompts 与 ~/.copilot/skills，
# 属于系统写操作；首次使用建议先加 --whatif 预览。

# 若不是 bash，重新用 bash 执行（双击 .command 可能由 zsh 启动）
if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi
set -eo pipefail
shopt -s nullglob

# 双击在 Terminal.app 中运行时，仅当退出码非 0（安装失败）才暂停以便查看错误；
# 成功（退出码 0）不暂停，配合 Terminal “shell 退出即关闭”偏好可自动关窗。
if [[ -t 1 && "${TERM_PROGRAM:-}" == "Apple_Terminal" && -z "${TMUX:-}" ]]; then
  trap 'if [[ $? -ne 0 ]]; then echo ""; read -r -p "按回车键关闭窗口…"; fi' EXIT
fi

# ── 参数解析 ───────────────────────────────────────────────
REPO_ROOT=""
WHATIF=false
UNINSTALL=false
NO_ORPHAN_CLEANUP=false
ASSUME_ALL_ORPHANS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -WhatIf|--whatif) WHATIF=true ;;
    -Uninstall|--uninstall) UNINSTALL=true ;;
    -NoOrphanCleanup|--no-orphan-cleanup) NO_ORPHAN_CLEANUP=true ;;
    -AssumeAllOrphans|--assume-all-orphans) ASSUME_ALL_ORPHANS=true ;;
    -RepoRoot|--repotroot) REPO_ROOT="$2"; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^#\{1,2\} //'
      exit 0 ;;
    *)
      if [[ -z "$REPO_ROOT" ]]; then REPO_ROOT="$1"; fi ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# ── 颜色（仅交互终端启用）─────────────────────────────────
if [[ -t 1 ]]; then
  C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'; C_GRAY=$'\033[1;30m'
  C_CYAN=$'\033[0;36m'; C_RED=$'\033[0;31m'; C_RESET=$'\033[0m'
else
  C_GREEN=''; C_YELLOW=''; C_GRAY=''; C_CYAN=''; C_RED=''; C_RESET=''
fi

# ── 路径设置 ───────────────────────────────────────────────
githubDir="$REPO_ROOT/.github"
userDataDir="$HOME/Library/Application Support/Code/User"
promptsDst="$userDataDir/prompts"
# Copilot 官方用户技能路径：~/.copilot/skills/
skillsDst="$HOME/.copilot/skills"
# 旧版本错装在 prompts/skills/ 下，升级后自动清理
skillsDstOld="$promptsDst/skills"
manifestPath="$promptsDst/newlife-skills-manifest.json"

skillsSrc="$githubDir/skills"
instructionsSrc="$githubDir/instructions"
promptsSrc="$githubDir/prompts"
agentsSrc="$githubDir/agents"
globalInstrSrc="$githubDir/copilot-instructions.md"
globalInstrName="newlife-global.instructions.md"

# ── 辅助函数 ───────────────────────────────────────────────
ensure_dir() {
  [[ -d "$1" ]] || $WHATIF || mkdir -p "$1"
}

step() {
  local tag="$1"; local msg="$2"; local color="${3:-$C_CYAN}"
  printf "    [%-7s] %s%s%s\n" "$tag" "$color" "$msg" "$C_RESET"
}

read_manifest() {
  # 输出每行一个资产相对路径；文件不存在或损坏时输出为空
  [[ -f "$manifestPath" ]] || return 0
  /usr/bin/python3 - "$manifestPath" <<'PY'
import sys, json
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        obj = json.load(f)
    for a in (obj.get('assets') or []):
        print(a)
except Exception:
    pass
PY
}

write_manifest() {
  $WHATIF && return
  local p="$1"; shift
  local assets=("$@")
  /usr/bin/python3 - "$p" "$REPO_ROOT" "${assets[@]}" <<'PY'
import sys, json, datetime
p, repo = sys.argv[1], sys.argv[2]
assets = sys.argv[3:]
obj = {
    "version": 1,
    "installedAt": datetime.datetime.now().isoformat(),
    "repoRoot": repo,
    "assets": assets,
}
with open(p, 'w', encoding='utf-8') as f:
    json.dump(obj, f, ensure_ascii=False, indent=2)
PY
}

# 资产相对路径约定：
#   skills/<name>  → 新在 ~/.copilot/skills/，旧在 prompts/skills/
#   <filename>.ext → ~/Library/Application Support/Code/User/prompts/
remove_asset() {
  local rel="$1"
  if [[ "$rel" == skills/* ]]; then
    local name="${rel#skills/}"
    local removed=false
    for base in "$skillsDst" "$skillsDstOld"; do
      local full="$base/$name"
      if [[ -e "$full" ]]; then
        $WHATIF || rm -rf "$full"
        removed=true
      fi
    done
    $removed && return 0 || return 1
  fi
  local full="$promptsDst/$rel"
  [[ -e "$full" ]] || return 1
  $WHATIF || rm -rf "$full"
  return 0
}

copy_file_asset() {
  local src="$1" dstname="$2"
  $WHATIF || cp -f "$src" "$promptsDst/$dstname"
}

copy_skill_folder() {
  local src="$1" name dst
  name="$(basename "$src")"
  dst="$skillsDst/$name"
  $WHATIF && return
  rm -rf "$dst"
  mkdir -p "$dst"
  cp -R "$src/." "$dst/"
}

# ── Banner ─────────────────────────────────────────────────
echo ""
echo -e "${C_GREEN}=== NewLife Copilot 资产安装 (macOS) ===${C_RESET}"
echo "  仓库: $REPO_ROOT"
echo "  目标 (技能): $skillsDst"
echo "  目标 (指令等): $promptsDst"
$WHATIF    && echo -e "${C_YELLOW}  模式: 预览（WhatIf）${C_RESET}"
$UNINSTALL && echo -e "${C_YELLOW}  模式: 卸载（Uninstall）${C_RESET}"
echo ""

if ! $UNINSTALL && [[ ! -d "$githubDir" ]]; then
  echo -e "${C_RED}错误：未找到 .github 目录: $githubDir${C_RESET}" >&2
  exit 1
fi

ensure_dir "$promptsDst"
ensure_dir "$skillsDst"
[[ -d "$skillsDstOld" ]] && echo -e "${C_YELLOW}  ⚠ 检测到旧版技能路径，安装后将自动清理${C_RESET}"

# ── 卸载 ───────────────────────────────────────────────────
if $UNINSTALL; then
  oldAssets=()
  while IFS= read -r a; do [[ -n "$a" ]] && oldAssets+=("$a"); done < <(read_manifest)
  if [[ ${#oldAssets[@]} -eq 0 ]]; then
    echo -e "${C_GRAY}  未找到 manifest，无可卸载内容。${C_RESET}"
    exit 0
  fi
  echo -e "${C_YELLOW}[卸载] 移除 ${#oldAssets[@]} 项资产${C_RESET}"
  removed=0
  for a in "${oldAssets[@]}"; do
    if remove_asset "$a"; then
      step 'remove' "$a" "$C_GRAY"
      removed=$((removed + 1))
    fi
  done
  $WHATIF || rm -f "$manifestPath"
  echo ""
  echo -e "${C_GREEN}=== 卸载完成，移除 $removed 项 ===${C_RESET}"
  echo ""
  exit 0
fi

# ── 构建新 manifest（来自源）────────────────────────────
newAssets=()
skillFolders=()
for d in "$skillsSrc"/*/; do
  skillFolders+=("$d")
  newAssets+=("skills/$(basename "$d")")
done
instructionFiles=()
for f in "$instructionsSrc"/*.instructions.md; do
  instructionFiles+=("$f")
  newAssets+=("$(basename "$f")")
done
promptFiles=()
for f in "$promptsSrc"/*.prompt.md; do
  promptFiles+=("$f")
  newAssets+=("$(basename "$f")")
done
agentFiles=()
for f in "$agentsSrc"/*.agent.md; do
  agentFiles+=("$f")
  newAssets+=("$(basename "$f")")
done
if [[ -f "$globalInstrSrc" ]]; then
  newAssets+=("$globalInstrName")
fi

# ── 孤儿清理 ───────────────────────────────────────────────
oldAssets=()
if $ASSUME_ALL_ORPHANS; then
  echo -e "${C_YELLOW}[迁移扫描] 将磁盘上所有本工具命名规则的资产视为旧安装${C_RESET}"
  for d in "$skillsDst"/*/; do oldAssets+=("skills/$(basename "$d")"); done
  for d in "$skillsDstOld"/*/; do oldAssets+=("skills/$(basename "$d")"); done
  for f in "$promptsDst"/*.instructions.md; do oldAssets+=("$(basename "$f")"); done
  for f in "$promptsDst"/*.agent.md; do oldAssets+=("$(basename "$f")"); done
  for f in "$promptsDst"/*.prompt.md; do oldAssets+=("$(basename "$f")"); done
  echo -e "${C_GRAY}    发现 ${#oldAssets[@]} 项候选资产${C_RESET}"
else
  while IFS= read -r a; do [[ -n "$a" ]] && oldAssets+=("$a"); done < <(read_manifest)
fi

orphans=()
if [[ ${#oldAssets[@]} -gt 0 ]] && ! $NO_ORPHAN_CLEANUP; then
  newFile="$(mktemp)"; oldFile="$(mktemp)"
  newSorted="$(mktemp)"; oldSorted="$(mktemp)"; orphansFile="$(mktemp)"
  if [[ ${#newAssets[@]} -gt 0 ]]; then printf '%s\n' "${newAssets[@]}"; fi > "$newFile"
  if [[ ${#oldAssets[@]} -gt 0 ]]; then printf '%s\n' "${oldAssets[@]}"; fi > "$oldFile"
  sort -u "$newFile" > "$newSorted"
  sort -u "$oldFile" > "$oldSorted"
  comm -23 "$oldSorted" "$newSorted" > "$orphansFile"
  while IFS= read -r o; do
    [[ -z "$o" ]] && continue
    orphans+=("$o")
  done < "$orphansFile"
  rm -f "$newFile" "$oldFile" "$newSorted" "$oldSorted" "$orphansFile"
fi

if [[ ${#orphans[@]} -gt 0 ]]; then
  echo -e "${C_YELLOW}[孤儿清理] 仓库中已删除但上次安装过的 ${#orphans[@]} 项${C_RESET}"
  for o in "${orphans[@]}"; do
    if remove_asset "$o"; then
      step 'orphan' "$o" "$C_GRAY"
    fi
  done
fi

# ── 安装 / 更新 ────────────────────────────────────────────
installed=0

# 1. Skills
echo -e "${C_YELLOW}[1/5] Skills (${#skillFolders[@]})${C_RESET}"
for folder in "${skillFolders[@]}"; do
  copy_skill_folder "$folder"
  step 'skill' "$(basename "$folder")"
  installed=$((installed + 1))
done
[[ ${#skillFolders[@]} -eq 0 ]] && echo -e "${C_GRAY}    （空）${C_RESET}"

# 清理旧版技能路径（prompts/skills/ 下同名目录）
if [[ -d "$skillsDstOld" ]]; then
  cleanedOld=0
  for folder in "${skillFolders[@]}"; do
    oldPath="$skillsDstOld/$(basename "$folder")"
    if [[ -e "$oldPath" ]]; then
      $WHATIF || rm -rf "$oldPath"
      cleanedOld=$((cleanedOld + 1))
    fi
  done
  [[ $cleanedOld -gt 0 ]] && echo -e "${C_GRAY}    （旧路径清理 $cleanedOld 项）${C_RESET}"
  remaining=("$skillsDstOld"/*/)
  [[ ${#remaining[@]} -eq 0 ]] && $WHATIF || rm -rf "$skillsDstOld" 2>/dev/null || true
fi

# 2. Instructions
echo -e "${C_YELLOW}[2/5] Instructions (${#instructionFiles[@]})${C_RESET}"
for f in "${instructionFiles[@]}"; do
  copy_file_asset "$f" "$(basename "$f")"
  step 'instr' "$(basename "$f")"
  installed=$((installed + 1))
done
[[ ${#instructionFiles[@]} -eq 0 ]] && echo -e "${C_GRAY}    （空）${C_RESET}"

# 3. Prompts
echo -e "${C_YELLOW}[3/5] Prompts (${#promptFiles[@]})${C_RESET}"
for f in "${promptFiles[@]}"; do
  copy_file_asset "$f" "$(basename "$f")"
  step 'prompt' "$(basename "$f")"
  installed=$((installed + 1))
done
[[ ${#promptFiles[@]} -eq 0 ]] && echo -e "${C_GRAY}    （空）${C_RESET}"

# 4. Agents
echo -e "${C_YELLOW}[4/5] Agents (${#agentFiles[@]})${C_RESET}"
for f in "${agentFiles[@]}"; do
  copy_file_asset "$f" "$(basename "$f")"
  step 'agent' "$(basename "$f")"
  installed=$((installed + 1))
done
[[ ${#agentFiles[@]} -eq 0 ]] && echo -e "${C_GRAY}    （空）${C_RESET}"

# 5. 全局 Copilot 指令（注入 applyTo 头部）
echo -e "${C_YELLOW}[5/5] 全局 Copilot 指令${C_RESET}"
if [[ -f "$globalInstrSrc" ]]; then
  $WHATIF || { printf -- '---\napplyTo: "**"\n---\n'; cat "$globalInstrSrc"; } > "$promptsDst/$globalInstrName"
  step 'global' "$globalInstrName"
  installed=$((installed + 1))
else
  echo -e "${C_GRAY}    （跳过：$globalInstrSrc 不存在）${C_RESET}"
fi

# ── 写 manifest ────────────────────────────────────────────
write_manifest "$manifestPath" "${newAssets[@]}"

# ── 完成 ───────────────────────────────────────────────────
echo ""
echo -e "${C_GREEN}=== 安装完成 ===${C_RESET}"
echo "  安装/更新: $installed 项"
echo "  孤儿清理: ${#orphans[@]} 项"
echo "  Manifest : $manifestPath"
echo ""
echo "重启 VS Code 后即可在所有项目中使用。"
echo ""
