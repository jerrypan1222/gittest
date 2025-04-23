#!/bin/bash
source ./live_functions.sh

# 設定區域，避免亂碼
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ✅ 如果選擇 "create_videostreaming_domain"，則進入第二層選單
options=()
while IFS=, read -r table _; do
    options+=("$table" "" OFF)
done < table_account.csv

  # 顯示 whiptail 選單
table=$(whiptail --title "選擇桌台" --radiolist "請選擇桌台：" 30 60 15 \
"${options[@]}" 3>&1 1>&2 2>&3)

if [ -z "$table" ]; then
  echo "🚫 未選擇桌台，退出..."
  exit 1
fi

# ✅ 從 table_account.csv 找出對應帳號
mapping_file="./table_account.csv"
account=""

if [[ -f "$mapping_file" ]]; then
    account=$(grep "^$table," "$mapping_file" | cut -d',' -f2)
fi

if [[ -z "$account" ]]; then
    echo "❌ 找不到對應帳號，請檢查 $mapping_file 中是否有 $table 設定"
    exit 1
fi

# ✅  從 table_account.csv 找出對應域名
mapping_file="./table_account.csv"
main_domain1=""

if [[ -f "$mapping_file" ]]; then
    main_domain=$(grep "^$table," "$mapping_file" | cut -d',' -f3)
fi

if [[ -z "$main_domain" ]]; then
    echo "❌  找不到對應帳號，請檢查 $mapping_file 中是否有 $table 設定"
    exit 1
fi

  # ✅ 第三層選單：選擇域名種類
  domain_type=$(whiptail --title "選擇域名種類" --radiolist "請選擇域名種類：" 30 60 15 \
     "推流" "用於直播推流" ON \
     "播流" "用於直播播流" OFF 3>&1 1>&2 2>&3)

  if [ -z "$domain_type" ]; then
    echo "🚫 未選擇域名種類，退出..."
    exit 1
  fi

  if [[ "$domain_type" == "推流" ]]; then
    domain_type_value=0
  else
    domain_type_value=1
  fi

  # ✅ 第四層選單：選擇加速地區
  accelerate_area=$(whiptail --title "選擇加速地區" --radiolist "請選擇加速地區：" 30 60 15 \
  "境內加速" "中國內地加速" OFF \
  "國際加速" "國際加速" OFF \
  "港澳台加速" "港澳台加速" ON 3>&1 1>&2 2>&3)

  if [ -z "$accelerate_area" ]; then
    echo "🚫 未選擇加速地區，退出..."
    exit 1
  fi

  case "$accelerate_area" in
    "境內加速") accelerate_area_value=1 ;;
    "國際加速") accelerate_area_value=2 ;;
    "港澳台加速") accelerate_area_value=3 ;;
  esac

  # ✅ 第五層選單：輸入視頻域名
  domain_name=$(whiptail --title "🌐 輸入視頻域名" --inputbox  "請輸入視頻直播域名（如 live.example.com）：" 10 60 3>&1 1>&2 2>&3)

  if [ -z "$domain_name" ]; then
    echo "🚫 未輸入域名，退出..."
    exit 1
  fi

main_domain=$(echo "$domain_name" | awk -F '.' '{print $(NF-1)"."$NF}')

  # ✅ 顯示選擇結果
  whiptail --title "✅ 設定完成" --msgbox \
  "🔹 功能: $action\n🔹 桌台: $table\n🔹 對應帳號為：$account\n🔹 主域名: $main_domain\n🔹 域名種類: $domain_type\n🔹 加速地區: $accelerate_area\n🔹 視頻域名: $domain_name" 15 60


  # ✅ 顯示選擇結果
  echo "✅ 選擇結果"
  echo "🔹 功能: $action"
  echo "🔹 桌台: $table"
  echo "🔹 對應帳號為：$account"
  echo "🔹 主域名: $main_domain"
  echo "🔹 域名種類: $domain_type , $domain_type_value"
  echo "🔹 加速地區: $accelerate_area , $accelerate_area_value"
  echo "🔹 視頻域名: $domain_name"
  # ✅ 可以在這裡執行 `tccli` 指令，例如：
  # tccli live AddLiveDomain --DomainName "$table.example.com" --DomainType "$domain_type" --AccelerateArea "$accelerate_area"

# ✅ 呼叫 live_functions.sh 裡的函數
echo "🚀 執行自動化域名設定中..."

echo "1️⃣ 取得 TXT 驗證記錄"
echo "get_txt_verification '$main_domain' '$account'"
get_txt_verification "$main_domain" "$account"

echo "2️⃣ 創建直播域名"
echo "create_live_domain '$domain_name' '$domain_type_value' '$accelerate_area_value' '$account'"
create_live_domain "$domain_name" "$domain_type_value" "$accelerate_area_value" "$account"

echo "3️⃣ 關閉直播鑒權"
echo "set_authentication '$domain_name' '$account' '$domain_type_value'"
set_authentication "$domain_name" "$account" "$domain_type_value"

echo "4️⃣ 設定 Referer 防盜鏈"
echo "先略過"
echo "set_referer '$domain_name' '$account'"
#set_referer "$domain_name" "$account"

echo "5️⃣ 設置直播延遲"
echo "set_stream_delay '$domain_name' '$account'"
set_stream_delay "$domain_name" "$account"

echo "6️⃣ 檢查 HTTPS 憑證是否存在 / 是否過期"
check_ssl_certificate "$main_domain" "$account"
cert_check_result=$?

case $cert_check_result in
  0)
    echo "⚠️ 憑證已過期，執行上傳並綁定"
    upload_certificate "$domain_name" "$account" "$main_domain"
    bind_ssl_certificate "$domain_name" "$account" "$main_domain" "$domain_type_value"
    ;;
  1)
    echo "✅ 憑證存在且有效，直接綁定"
    bind_ssl_certificate "$domain_name" "$account" "$main_domain" "$domain_type_value"
    ;;
  2)
    echo "📤 憑證不存在，執行上傳並綁定"
    upload_certificate "$domain_name" "$account" "$main_domain"
    bind_ssl_certificate "$domain_name" "$account" "$main_domain" "$domain_type_value"
    ;;
esac

echo "7️⃣ 查詢 CNAME 設定"
echo "get_cname_info '$domain_name' '$account'"
get_cname_info "$domain_name" "$account"

echo "✅ 所有操作已完成 ✅"

