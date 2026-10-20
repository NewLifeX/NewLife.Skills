#!/usr/bin/env bash
#
# verify-assets.command — macOS 双击运行版
# 对应 Windows 的 verify-assets.ps1
#
# 扫描 .github/{instructions,skills,agents,prompts} 与全局指令文件，校验：
#   1. 每个资产都有合法的 YAML frontmatter 且含必填字段（name/description）。
#   2. 每个 skill 文件夹名与其 name 字段一致。
#   3. README.md 资产表与磁盘双向一致：
#        - 磁盘上的资产都在 README 中登记（无遗漏）；
#        - README 中登记的资产都在磁盘上存在（无陈旧/幽灵条目）。
#
# 所有文件以 UTF-8（无 BOM）读取，避免中文内容损坏。本脚本只读，不修改任何文件。
# 发现问题时退出码为 1（适配 CI），否则为 0。
#
# 用法：
#   双击本文件                      完整一致性检查并打印报告
#   ./verify-assets.command         同上
#   ./verify-assets.command /path/to/repo   显式指定仓库根目录
#
# 双击说明：本脚本可能在 zsh 下被启动，首行会强制用 bash 重新执行；
# 在 Terminal.app 中双击运行时，仅当校验失败（退出码非 0）才暂停以便查看错误，
# 成功（OK）则直接由 Terminal 关闭窗口。

# 若不是 bash，重新用 bash 执行（双击 .command 可能由 zsh 启动）
if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi
set -eo pipefail
shopt -s nullglob

# 双击在 Terminal.app 中运行时，仅当退出码非 0（校验失败）才暂停以便查看错误；
# 成功（退出码 0）不暂停，配合 Terminal “shell 退出即关闭”偏好可自动关窗。
if [[ -t 1 && "${TERM_PROGRAM:-}" == "Apple_Terminal" && -z "${TMUX:-}" ]]; then
  trap 'if [[ $? -ne 0 ]]; then echo ""; read -r -p "按回车键关闭窗口…"; fi' EXIT
fi

REPO_ROOT="${1:-}"
if [[ -z "$REPO_ROOT" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

if [[ -t 1 ]]; then
  C_CYAN=$'\033[0;36m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'; C_RESET=$'\033[0m'
else
  C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RESET=''
fi

githubDir="$REPO_ROOT/.github"
readmePath="$REPO_ROOT/README.md"
skillsDir="$githubDir/skills"
instrDir="$githubDir/instructions"
agentsDir="$githubDir/agents"
promptsDir="$githubDir/prompts"

# 提取 frontmatter 中某个 key 的值（去引号、去首尾空白）；无 frontmatter 或无该字段则输出空
get_field() {
  /usr/bin/python3 - "$1" "$2" <<'PY'
import sys, re
path, key = sys.argv[1], sys.argv[2]
try:
    txt = open(path, encoding='utf-8').read()
except Exception:
    print(''); sys.exit(0)
m = re.match(r'^\uFEFF?---\s*\n(.*?)\n---', txt, re.S)
if not m:
    print(''); sys.exit(0)
for line in m.group(1).split('\n'):
    t = line.lstrip()
    if t.startswith(key + ':'):
        val = t[len(key) + 1:].strip().strip('"').strip("'").strip()
        print(val)
        break
PY
}

# 是否存在合法 frontmatter
has_frontmatter() {
  /usr/bin/python3 - "$1" <<'PY'
import sys, re
try:
    txt = open(sys.argv[1], encoding='utf-8').read()
except Exception:
    sys.exit(1)
sys.exit(0 if re.match(r'^\uFEFF?---\s*\n.*?\n---', txt, re.S) else 1)
PY
}

problems=()
diskIds=""
mustList=""

# ── Skills ─────────────────────────────────────────────────
for d in "$skillsDir"/*/; do
  name="$(basename "$d")"
  diskIds+="$name"$'\n'
  mustList+="$name"$'\n'
  skillMd="$d/SKILL.md"
  if [[ ! -f "$skillMd" ]]; then problems+=("Skill missing SKILL.md: $name"); continue; fi
  if ! has_frontmatter "$skillMd"; then problems+=("Skill missing frontmatter: $name"); continue; fi
  sname="$(get_field "$skillMd" name)"
  sdesc="$(get_field "$skillMd" description)"
  [[ -z "$sname" ]] && problems+=("Skill missing 'name': $name")
  [[ -n "$sname" && "$sname" != "$name" ]] && problems+=("Skill name/folder mismatch: folder=$name name=$sname")
  [[ -z "$sdesc" ]] && problems+=("Skill missing 'description': $name")
done

# ── Instructions ───────────────────────────────────────────
for f in "$instrDir"/*.instructions.md; do
  b="$(basename "$f")"
  diskIds+="$b"$'\n'
  mustList+="$b"$'\n'
  if ! has_frontmatter "$f"; then problems+=("Instruction missing frontmatter: $b"); continue; fi
  desc="$(get_field "$f" description)"
  [[ -z "$desc" ]] && problems+=("Instruction missing 'description': $b")
done

# ── Agents ─────────────────────────────────────────────────
for f in "$agentsDir"/*.agent.md; do
  b="$(basename "$f")"
  short="${b%.agent.md}"
  diskIds+="$b"$'\n'
  diskIds+="$short"$'\n'
  mustList+="$short"$'\n'
  if ! has_frontmatter "$f"; then problems+=("Agent missing frontmatter: $b"); continue; fi
  desc="$(get_field "$f" description)"
  [[ -z "$desc" ]] && problems+=("Agent missing 'description': $b")
done

# ── Prompts ────────────────────────────────────────────────
promptCount=0
for f in "$promptsDir"/*.prompt.md; do
  promptCount=$((promptCount + 1))
  b="$(basename "$f")"
  short="${b%.prompt.md}"
  diskIds+="$b"$'\n'
  diskIds+="$short"$'\n'
  mustList+="$b"$'\n'
  if ! has_frontmatter "$f"; then problems+=("Prompt missing frontmatter: $b"); continue; fi
  desc="$(get_field "$f" description)"
  [[ -z "$desc" ]] && problems+=("Prompt missing 'description': $b")
done

# ── README 交叉校验 ────────────────────────────────────────
readmeNames="$(/usr/bin/python3 - "$readmePath" <<'PY'
import sys, re
try:
    txt = open(sys.argv[1], encoding='utf-8').read()
except Exception:
    print(''); sys.exit(0)
for m in re.finditer(r'(?m)^\|\s*`([^`]+)`\s*\|', txt):
    print(m.group(1))
PY
)"

while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  if ! printf '%s' "$readmeNames" | grep -qxF "$id"; then
    problems+=("Disk asset not listed in README: $id")
  fi
done < <(printf '%s' "$mustList")

while IFS= read -r n; do
  [[ -z "$n" ]] && continue
  if ! printf '%s' "$diskIds" | grep -qxF "$n"; then
    problems+=("README lists non-existent asset: $n")
  fi
done < <(printf '%s' "$readmeNames")

# ── 报告 ───────────────────────────────────────────────────
skillCount=$(find "$skillsDir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
instrCount=$(find "$instrDir" -maxdepth 1 -name '*.instructions.md' -type f 2>/dev/null | wc -l | tr -d ' ')
agentCount=$(find "$agentsDir" -maxdepth 1 -name '*.agent.md' -type f 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo -e "${C_CYAN}NewLife.Skills asset verification${C_RESET}"
echo "  skills=$skillCount  instructions=$instrCount  agents=$agentCount  prompts=$promptCount"

if [[ ${#problems[@]} -eq 0 ]]; then
  echo -e "${C_GREEN}  OK: all assets consistent.${C_RESET}"
  exit 0
fi

echo -e "${C_YELLOW}  ${#problems[@]} problem(s) found:${C_RESET}"
for p in "${problems[@]}"; do
  echo -e "${C_YELLOW}    - $p${C_RESET}"
done
exit 1
