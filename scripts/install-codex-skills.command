#!/usr/bin/env bash
# 双击安装/更新本地仓库 .github/skills 中的 Codex 技能。
# 用法：install-codex-skills.command [仓库路径] [--whatif|--uninstall]
# 默认仓库为脚本所在目录的上级；目标为 ${CODEX_HOME:-$HOME/.codex}/skills。
# 更新仓库请先自行 git pull；本脚本不改动仓库的 Git 状态。
if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi
set -eo pipefail
if [[ -t 1 && "${TERM_PROGRAM:-}" == "Apple_Terminal" && -z "${TMUX:-}" ]]; then
  trap 'if [[ $? -ne 0 ]]; then read -r -p "按回车键关闭窗口…"; fi' EXIT
fi
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
execArgs=("$scriptDir/.." "${CODEX_HOME:-$HOME/.codex}/skills")
/usr/bin/python3 - "${execArgs[@]}" "$@" <<'PY'
import argparse
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

parser = argparse.ArgumentParser(description='安装/更新 NewLife Codex 技能（仅同步 skills）')
default_repo, destination = sys.argv[1:3]
parser.add_argument('repo', nargs='?', default=default_repo, help='本地 NewLife.Skills 仓库路径')
parser.add_argument('--whatif', action='store_true', help='仅预览，不写入文件')
parser.add_argument('--uninstall', action='store_true', help='仅卸载本脚本记录的技能')
args = parser.parse_args(sys.argv[3:])

def fail(message):
    raise RuntimeError(message)

def safe_name(name):
    return isinstance(name, str) and bool(re.fullmatch(r'[a-z0-9][a-z0-9-]*', name))

def run():
    repo = Path(args.repo).expanduser().resolve()
    target = Path(destination).expanduser()
    if target.is_symlink():
        fail('目标 skills 目录是符号链接，请先检查：' + str(target))
    target = target.resolve()
    manifest = target / '.newlife-skills-manifest.json'
    if manifest.is_symlink():
        fail('安装记录不能是符号链接')
    previous = []
    if manifest.exists():
        record = json.loads(manifest.read_text(encoding='utf-8'))
        if record.get('version') != 1 or not isinstance(record.get('skills'), list):
            fail('安装记录格式错误，已停止')
        previous = record['skills']
        if not all(safe_name(name) for name in previous) or len(set(previous)) != len(previous):
            fail('安装记录含不安全或重复的技能名称，已停止')

    sources = {}
    if not args.uninstall:
        source = repo / '.github' / 'skills'
        if not source.is_dir():
            fail('未找到技能源目录：' + str(source))
        if source == target or source in target.parents or target in source.parents:
            fail('源目录与目标目录不能重叠')
        for folder in sorted(source.iterdir()):
            if folder.name.startswith('.'):
                continue
            if not folder.is_dir() or folder.is_symlink() or not safe_name(folder.name):
                fail('技能目录无效：' + str(folder))
            if not (folder / 'SKILL.md').is_file():
                fail('缺少 SKILL.md：' + str(folder))
            if any(p.is_symlink() for p in folder.rglob('*')):
                fail('技能包含符号链接，请先检查：' + str(folder))
            sources[folder.name] = folder
        if not sources:
            fail('源目录没有技能，已停止，避免误清理现有安装')

    # 先完整检查冲突，再执行任何写入；不接管其他来源的同名技能。
    for name in set(previous) | set(sources):
        dest = target / name
        if dest.is_symlink() or (dest.exists() and not dest.is_dir()):
            fail('目标技能不是普通目录：' + str(dest))
        if name in sources and dest.exists() and name not in previous:
            fail('同名技能已存在且不属于本脚本，请先备份或改名：' + str(dest))

    removed = sorted(set(previous) - set(sources))
    print('仓库：', repo)
    print('目标：', target)
    if args.whatif:
        print('模式：预览，不写入文件')
    for name in sources:
        print('[更新]' if name in previous else '[安装]', name)
    for name in removed:
        print('[移除]', name)
    if args.whatif:
        return
    if args.uninstall and not manifest.exists():
        print('无安装记录，无需卸载。')
        return
    target.mkdir(parents=True, exist_ok=True)
    # 完整复制成功后才替换目标；保留备份，替换失败则回滚。
    with tempfile.TemporaryDirectory(prefix='.newlife-stage-', dir=target) as temporary:
        stage = Path(temporary)
        fresh, backup = stage / 'fresh', stage / 'backup'
        fresh.mkdir()
        backup.mkdir()
        for name, folder in sources.items():
            shutil.copytree(folder, fresh / name)
        staged_manifest = stage / 'manifest.json'
        staged_manifest.write_text(json.dumps({
            'version': 1, 'repoRoot': str(repo), 'skills': sorted(sources)
        }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        saved, installed = [], []
        try:
            for name in sorted(set(previous) | set(sources)):
                dest = target / name
                if dest.exists():
                    dest.rename(backup / name)
                    saved.append(name)
                if name in sources:
                    (fresh / name).rename(dest)
                    installed.append(name)
            if args.uninstall:
                manifest.unlink()
            else:
                os.replace(staged_manifest, manifest)
        except Exception:
            for name in reversed(installed):
                shutil.rmtree(target / name)
            for name in saved:
                (backup / name).rename(target / name)
            raise
    print('完成：安装/更新 %d 个，移除 %d 个。' % (len(sources), len(removed)))
    if not args.uninstall:
        print('请在下一轮对话查看技能是否已加载；若未出现，重启 Codex。')

try:
    run()
except Exception as error:
    print('错误：' + str(error), file=sys.stderr)
    sys.exit(1)
PY
