#!/bin/bash
source ./live_functions.sh

# 設定區域，避免亂碼
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ✅ 第一層選單：選擇功能
action=$(whiptail --title "域名管理系統" --radiolist "請選擇一個操作：" 30 60 15 \
   "create_videostreaming_domain" "創建視頻直播域名" ON \
   "update_ssl" "更新 SSL 憑證" OFF 3>&1 1>&2 2>&3)

# 如果用戶取消或沒選擇
if [ -z "$action" ]; then
  echo "🚫 未選擇任何操作，退出..."
  exit 1
fi

# ✅ 如果選擇 "create_videostreaming_domain"，則進入第二層選單
if [ "$action" == "create_videostreaming_domain" ]; then
	./create_videostreaming_domain.sh
elif [ "$action" == "update_ssl" ]; then
	./update_ssl.sh 
fi

