#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
REPO="albret181-stack/-"
echo '=== Скульптор речи · публикация в подключённый репозиторий ==='
command -v git >/dev/null || { echo 'Не найден git. Установи Command Line Tools.'; exit 1; }
if ! command -v gh >/dev/null; then
  if command -v brew >/dev/null; then brew install gh; else echo 'Нужен GitHub CLI (https://cli.github.com/)'; exit 1; fi
fi
if ! gh auth status >/dev/null 2>&1; then gh auth login -h github.com -p https -w; fi
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
gh repo clone "$REPO" "$WORKDIR/repo"
# Don't copy .git or local build output. Preserve any future remote-only files.
rsync -a --exclude='.git' --exclude='build/' --exclude='dist/' --exclude='*.xcodeproj/' ./ "$WORKDIR/repo/"
cd "$WORKDIR/repo"
git add .
if ! git diff --cached --quiet; then
  git -c user.name="Speech Sculptor setup" -c user.email="albret181-stack@users.noreply.github.com" commit -m 'feat: add Speech Sculptor macOS source and tests'
  git push origin HEAD:main
fi
echo 'Исходники опубликованы. GitHub Actions запускаются при push.'
echo "https://github.com/$REPO/actions"
read -r -p 'Нажми Enter для выхода…' _
