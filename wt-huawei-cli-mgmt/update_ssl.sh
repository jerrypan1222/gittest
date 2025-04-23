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

# 檢查與更新播流域名憑證（主域名 + 備案域名）
update_certificates_for_domain() {
    local target_domain=$1
    local desc=$2

    echo "📋 撈出播流域名（$desc）中..."

    mapfile -t pull_domains < <(
      hcloud Live ShowDomain --cli-region="ap-southeast-3" \
      | jq -r --arg md "$target_domain" '.domain_info[] | select(.domain_type == "pull" and (.domain | endswith($md))) | .domain'
    )

    if [[ ${#pull_domains[@]} -eq 0 ]]; then
      echo "⚠️  無播流域名找到 ($desc)"
      return
    fi

    echo "✅ 找到 ${#pull_domains[@]} 個播流域名："
    printf ' - %s\n' "${pull_domains[@]}"

    cert_path="certs/$target_domain"
    cert_file="$cert_path/fullchain.pem"
    key_file="$cert_path/privkey.pem"

    if [[ ! -f "$cert_file" || ! -f "$key_file" ]]; then
      echo "❌ 憑證或私鑰不存在：$cert_file / $key_file"
      return
    fi

    # 讀取 PEM 內容
    cert_content=$(<"$cert_file")
    key_content=$(<"$key_file")

    for domain in "${pull_domains[@]}"; do
      echo "🔒 更新憑證: $domain"

      hcloud Live UpdateDomainHttpsCert \
        --cli-region="ap-southeast-3" \
        --domain="$domain" \
        --certificate="$cert_content" \
        --certificate_key="$key_content" \
        --force_redirect=true
    done
}

# 主程序開始
update_certificates_for_domain "$main_domain" "主域名"
update_certificates_for_domain "$icp_domain" "備案域名"
