accountpwd=./account.txt   #帳號資訊
accounts=$(awk -F ',' '{print $3}' "$accountpwd")  #將帳號txt檔案第三欄位當選單
options=($accounts)
choices=()

    #選單開始
menu() {
        echo "Available Options:"
        for i in "${!options[@]}"; do
        printf "%s %2d. %s\n" "${choices[i]:-}" $((i+1)) "${options[i]}"
        done
        [[ "$msg" ]] && echo "$msg"; :
       }


prompt="Check Your Choices (again to uncheck, ENTER when done): "

        while menu && read -rp "$prompt" num && [[ "$num" ]]; do
        [[ "$num" != *[![:digit:]]* ]] &&
        (( num > 0 && num <= ${#options[@]} )) ||
        { msg="Invalid Options: $num"; continue; }
        ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
        [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="*"
        done

selected_options=""
                 for i in "${!options[@]}"; do
                 if [[ "${choices[i]}" ]]; then
                 selected_options="${options[i]}"
                           break
                            fi
                           done

                 if [[ -z "$selected_options" ]]; then
                 echo "Your input is incorrect, please try again."
                           exit
                            fi

IFS=',' read -ra params <<< "$(awk -F ',' -v selected="$selected_options" '$3 == selected {print $1","$2}' "$accountpwd")"

Accesskey="${params[0]}"

Secretkey="${params[1]}"

echo "Accesskey='$Accesskey'"
echo "Secretkey='$Secretkey'"


LOGINCLI(){
           hcloud configure set --cli-region="ap-southeast-3" --cli-access-key="$Accesskey" --cli-secret-key="$Secretkey"
          }

LOGINCLI             #<<<登入


account_domain_csv="./account_domain.csv"
main_domain=$(awk -F',' -v acc="$selected_options" '$1 == acc {print $2}' "$account_domain_csv")
icp_domain=$(awk -F',' -v acc="$selected_options" '$1 == acc {print $3}' "$account_domain_csv")

echo "🔎 帳號: $selected_options"
echo "🔎 主域名: $main_domain"
echo "🔎 備案域名: $icp_domain"

# ✅ 查詢所有播流域名
mapfile -t pull_domains < <(
  hcloud Live ShowDomain --cli-region="ap-southeast-3" \
  | jq -r --arg md "$main_domain" '.domain_info[] | select(.domain_type == "push" and (.domain | endswith($md))) | .domain'
)

if [[ ${#pull_domains[@]} -eq 0 ]]; then
  echo "⚠️ 無播流域名找到"
  exit 1
fi

echo "📋 撈出 ${#pull_domains[@]} 個播流域名"

# ✅ 檢查每個播流域名是否已完成 CNAME 設定
echo "📤 未驗證播流域名 YAML："
for domain in "${pull_domains[@]}"; do
  actual_cname=$(dig +short "$domain" CNAME)

  if [[ -z "$actual_cname" || "$actual_cname" != *cdnhw* ]]; then
    expected_cname=$(hcloud Live ShowDomain --cli-region="ap-southeast-3" \
      | jq -r --arg d "$domain" '.domain_info[] | select(.domain == $d) | .domain_cname')

    host=$(echo "$domain" | cut -d'.' -f1)
    echo "- { host: \"$host\", type:\"CNAME\", data:\"$expected_cname\", aliyun_routing: \"default\" }"
  fi
done
