#!/bin/bash
# Подключение купленного домена к сайту LAD на GitHub Pages (репозиторий alfasnew/lad).
# Запуск:  ./connect-domain.sh lad.co.ua
set -e
DOM="$1"
[ -z "$DOM" ] && { echo "Использование: $0 <домен>   например: $0 lad.co.ua"; exit 1; }
cd "$(dirname "$0")"

echo "== 1. Проверяю DNS =========================================="
GH_IPS="185.199.108.153 185.199.109.153 185.199.110.153 185.199.111.153"
GOT=$(dig +short "$DOM" A @8.8.8.8 | sort | tr '\n' ' ')
echo "   A-записи $DOM: [${GOT:-нет}]"
OK=0
for ip in $GH_IPS; do case " $GOT " in *" $ip "*) OK=$((OK+1));; esac; done
if [ "$OK" -lt 1 ]; then
  echo "   !! DNS ещё не указывает на GitHub Pages."
  echo "      В панели NIC.UA для зоны $DOM должно быть:"
  for ip in $GH_IPS; do echo "         A    @    $ip"; done
  echo "         CNAME www  alfasnew.github.io."
  echo "      Прописать и подождать 10-30 минут, потом запустить скрипт снова."
  exit 2
fi
echo "   DNS в порядке ($OK из 4 адресов GitHub)."

echo "== 2. Кладу CNAME в репозиторий ============================="
echo "$DOM" > CNAME
git add CNAME
git commit -m "Власний домен $DOM" || echo "   (нечего коммитить)"
git push

echo "== 3. Прописываю домен в настройках GitHub Pages ============"
gh api -X PUT repos/alfasnew/lad/pages -f cname="$DOM" -F https_enforced=false || true
sleep 5
gh api repos/alfasnew/lad/pages --jq '"   cname=\(.cname)  status=\(.status)  https=\(.https_enforced)"'

echo "== 4. Жду сертификат Let's Encrypt (до 20 минут) ============"
for i in $(seq 1 40); do
  ST=$(gh api repos/alfasnew/lad/pages --jq '.https_certificate.state // "—"' 2>/dev/null || echo "—")
  echo "   [$i/40] сертификат: $ST"
  [ "$ST" = "approved" ] && break
  sleep 30
done
gh api -X PUT repos/alfasnew/lad/pages -F https_enforced=true || true

echo "== 5. Проверка ============================================="
for u in "https://$DOM/" "https://$DOM/shots/hero-full.jpg" "https://www.$DOM/"; do
  printf "   %-45s %s\n" "$u" "$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 20 "$u")"
done
echo "Готово: https://$DOM"
