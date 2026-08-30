#!/usr/bin/env bash
# web/ klasöründeki değişiklikleri ../knight-lite-web reposuna senkronize edip push eder.
# Cleavr.io bu ayrı repoyu (knight-lite-web) izleyip otomatik deploy ediyor.
#
# Kullanım:
#   git clone git@github.com:batv45/knight-lite-web.git ../knight-lite-web   # (bir kere)
#   ./sync-web.sh "commit mesajı"

set -euo pipefail

SRC="$(cd "$(dirname "$0")/web" && pwd)"
DEST="$(cd "$(dirname "$0")" && pwd)/../knight-lite-web"

if [ ! -d "$DEST/.git" ]; then
	echo "Hata: $DEST bir git reposu değil."
	echo "Önce clone et: git clone git@github.com:batv45/knight-lite-web.git $DEST"
	exit 1
fi

rsync -a --delete \
	--exclude ".git" \
	--exclude "config.php" \
	--exclude "releases.json" \
	--exclude "downloads/*.apk" \
	"$SRC"/ "$DEST"/

cd "$DEST"
git add -A
if git diff --cached --quiet; then
	echo "Değişiklik yok, senkronize edilecek bir şey bulunamadı."
	exit 0
fi
git commit -m "${1:-web/ güncellemesi senkronize edildi}"
git push
