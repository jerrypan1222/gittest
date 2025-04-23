#!/bin/bash
source ./live_functions.sh

# 設定區域，避免亂碼
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ✅ 選擇 "tc account"
declare -A seen
options=()
while IFS=, read -r table account damain icpdomain; do
    # 如果該欄位值尚未出現過，則加入選項
    if [[ -z "${seen[$account]}" ]]; then
        options+=("$account" "" OFF)
        seen["$account"]=1
    fi
done < table_account.csv

# 顯示 whiptail 選單
account=$(whiptail --title "選擇騰訊帳號" --radiolist "請選擇帳號：" 30 60 15 \
"${options[@]}" 3>&1 1>&2 2>&3)

if [ -z "$account" ]; then
  echo "🚫 未選擇帳號，退出..."
  exit 1
fi

# ✅  從 table_account.csv 找出對應域名
mapping_file="./table_account.csv"
main_domain=""

if [[ -f "$mapping_file" ]]; then
    main_domain=$(grep ",$account," "$mapping_file" | cut -d',' -f3 | uniq)
fi

if [[ -z "$main_domain" ]]; then
    echo "❌  找不到對應帳號，請檢查 $mapping_file 中是否有 $account 設定"
    exit 1
fi

# ✅   從 table_account.csv 找出對應備案域名
mapping_file="./table_account.csv"
icp_domain1=""

if [[ -f "$mapping_file" ]]; then
    icp_domain=$(grep ",$account," "$mapping_file" | cut -d',' -f4 | uniq)
fi

if [[ -z "$icp_domain" ]]; then
    echo "❌   找不到對應帳號，請檢查 $mapping_file 中是否有 $account 設定"
    exit 1
fi

  # ✅ 顯示選擇結果
  whiptail --title "✅ 設定完成" --msgbox \
  "🔹 對應帳號為：$account\n🔹 主域名: $main_domain\n🔹 備案域名種類: $icp_domain\n" 15 60


  # ✅ 顯示選擇結果
  echo "✅ 選擇結果"
  echo "🔹 帳號為：$account"
  echo "🔹 主域名: $main_domain"
  echo "🔹 備案域名: $icp_domain"
  # ✅ 可以在這裡執行 `tccli` 指令，例如：
  # tccli live AddLiveDomain --DomainName "$table.example.com" --DomainType "$domain_type" --AccelerateArea "$accelerate_area"


# ✅ 呼叫 live_functions.sh 裡的函數
echo "🚀 執行自動化域名設定中..."

echo "1️⃣  檢查 HTTPS 憑證是否存在 / 是否過期"
echo "一般視頻域名"
echo "check_ssl_certificate '$main_domain' '$account'"
check_ssl_certificate "$main_domain" "$account"
chk=no
read -p "是否更新憑證($main_domain)(y / n):" txt
    if [ "$txt" == "y" ]; then
        chk=yes
	echo "upload_certificate '$domain_name' '$account' '$main_domain'"
	new_cert_id=$(upload_certificate "$domain_name" "$account" "$main_domain")
	if [[ -z "$new_cert_id" || "$new_cert_id" == "null" ]]; then
                echo "❌  上傳失敗，結束此流程"
                exit 1
        fi
	echo "$new_cert_id"

	echo "🔍 搜尋播流域名 for $main_domain ..."

	mapfile -t domains < <(tccli live DescribeLiveDomains --cli-unfold-argument --profile "$account" | jq -r --arg icp "$main_domain" '.DomainList[] | select(.Type == 1 and (.Name | endswith($icp))) | .Name')
	if [[ ${#domains[@]} -eq 0 ]]; then
	    echo "⚠️ 未找到任何播流域名！"
   	    exit 1
	fi

	echo "✅ 找到 ${#domains[@]} 個播流域名："
	printf ' - %s\n' "${domains[@]}"
	
	# 綁定憑證
        for domain_name in "${domains[@]}"; do
                echo "🔐  綁定 $domain_name"
                echo "bind_ssl_certificate '$domain_name' '$account' '$main_domain' '1'"
                bind_ssl_certificate "$domain_name" "$account" "$main_domain" "1"
        done

	# 清除舊憑證
	echo "remove_old_ssl_certificate '$main_domain' '$account' '$new_cert_id'"
	remove_old_ssl_certificate "$main_domain" "$account" "$new_cert_id"
    fi

echo "----------------------------------------------"
echo "備案域名"
echo "check_ssl_certificate '$icp_domain' '$account'"
check_ssl_certificate "$icp_domain" "$account"
read -p "是否更新憑證($icp_domain)(y / n):" txt
    if [ "$txt" == "y" ]; then
        chk=yes
	echo "upload_certificate '$domain_name' '$account' '$icp_domain'"
#	new_cert_id=$(upload_certificate "$domain_name" "$account" "$icp_domain")
	if [[ -z "$new_cert_id" || "$new_cert_id" == "null" ]]; then
        	echo "❌ 上傳失敗，結束此流程"
        	exit 1
    	fi

        echo "🔍  搜尋播流域名 for $icp_domain ..."

        mapfile -t domains < <(tccli live DescribeLiveDomains --cli-unfold-argument --profile "$account" | jq -r --arg icp "$icp_domain" '.DomainList[] | select(.Type == 1 and (.Name | endswith($icp))) | .Name')
	if [[ ${#domains[@]} -eq 0 ]]; then
            echo "⚠️ 未找到任何播流域名！"
            exit 1
        fi

        echo "✅{ 找到 ${#domains[@]} 個播流域名："
        printf ' - %s\n' "${domains[@]}"

	# 綁定憑證
        for domain_name in "${domains[@]}"; do
		echo "🔐 綁定 $d"
		echo "bind_ssl_certificate '$domain_name' '$account' '$icp_domain' '1'"
		bind_ssl_certificate "$domain_name" "$account" "$icp_domain" "$domain_type_value"
	done
        # 清除舊憑證
        echo "🧹  移除舊憑證（保留 $new_cert_id）..."
        tccli ssl DescribeCertificates --profile "$account" \
        | jq -r --arg alias "$main_domain" --arg keep "$new_cert_id" \
        '.Certificates[] | select(.Alias == $alias and .CertificateId != $keep) | .CertificateId' \
        | while read old_id; do
        echo "❌  刪除舊憑證：$old_id"
        tccli ssl DeleteCertificate --cli-unfold-argument --CertificateId "$old_id" --profile "$account"
        done
    fi
#cert_check_result=$?

#case $cert_check_result in
#  0)
#    echo "⚠️ 憑證已過期，執行上傳並綁定"
#    upload_certificate "$domain_name" "$account" "$main_domain"
#    bind_ssl_certificate "$domain_name" "$account" "$main_domain" "$domain_type_value"
#    ;;
#  1)
#    echo "✅  憑證存在且有效，直接綁定"
#    bind_ssl_certificate "$domain_name" "$account" "$main_domain" "$domain_type_value"
#    ;;
#  2)
#    echo "📤  憑證不存在，執行上傳並綁定"
#    upload_certificate "$domain_name" "$account" "$main_domain"
#    bind_ssl_certificate "$domain_name" "$account" "$main_domain" "$domain_type_value"
#    ;;
#esac

echo "7️⃣ 查詢 CNAME 設定"
echo "get_cname_info '$domain_name' '$account'"
#get_cname_info "$domain_name" "$account"

echo "✅ 所有操作已完成 ✅"

