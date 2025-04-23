#!/bin/bash
# tccli 直播域名操作函數
REGION="ap-guangzhou"


# 取得 TXT 驗證內容
get_txt_verification() {
    local domain=$1
    local account=$2
    echo "🔍 取得 TXT 驗證內容: $domain , 帳號: $account"
    TXT_data=$(tccli live AuthenticateDomainOwner --cli-unfold-argument --DomainName "$domain" --VerifyType dnsCheck --profile "$account" | jq -r .Content)
    
    read -p  "請協助添加 TXT 內容 , 此操作是為了驗證域名是自己的
    	- { host: \"cssauth\", type: \"TXT\", data: \"$TXT_data\", aliyun_routing: \"default\"}
    #完成後請按 y : " y
    
    # 檢查驗證
    tccli live AuthenticateDomainOwner --cli-unfold-argument --DomainName $domain --VerifyType dnsCheck --profile $account | jq -r .Content 
}

# 創建直播域名
create_live_domain() {
    local domain=$1
    local domain_type=$2  # 推流 or 播流
    local accelerate_area=$3  # 境內加速 / 港澳台加速 / 國際加速
    local account=$4

    echo "🚀  創建直播域名: $domain（類型: $domain_type, 加速區域: $accelerate_area）, 帳號: $account"
    # DomainType 0：推流域名， 1：播放域名。 ### accelerate_area  1：國內， 2：全球， 3：境外。
    tccli live AddLiveDomain --cli-unfold-argument --DomainName "$domain" --DomainType "$domain_type" --PlayType "$accelerate_area" --IsDelayLive 0 --profile "$account"
}

# 取得 CNAME 設定
get_cname_info() {
    local domain=$1
    local account=$2
    sub_domain=$(echo "$domain" | awk -F '.' '{print $1}')
    echo "🔍 查詢 CNAME 設定: $domain , sub_domain: $sub_domain"
    CNAME_data=$(tccli live DescribeLiveDomain --cli-unfold-argument --DomainName "$domain" --profile "$account" | jq -r .DomainInfo.TargetDomain)

    read -p  "請協助添加 CNAME 內容 , 此操作是為了配置域名解析
        - { host: \"$sub_domain\", type: \"CNAME\", data: \"$CNAME_data\", aliyun_routing: \"default\"}
    #完成後請按 y : " y
}

# 關閉直播鑒權
set_authentication() {
    local domain=$1
    local account=$2
    local domain_type=$3
    echo "🔐 設定直播鑒權（開啟）: $domaina , 播放類型: $domain_type"

    if [[ "$domain_type" -eq 1 ]]; then
	echo "📺 播流域名 ➜ 使用 ModifyLivePlayAuthKey"
        tccli live ModifyLivePlayAuthKey --cli-unfold-argument --DomainName "$domain" --Enable 0 --profile "$account"
    elif [[ "$domain_type" -eq 0 ]]; then
        echo "📡 推流域名 ➜ 使用 ModifyLivePushAuthKey"
        tccli live ModifyLivePushAuthKey --cli-unfold-argument --DomainName "$domain" --Enable 0 --profile "$account"
    else
        echo "❌ 錯誤：未知的 domain_type 值：$domain_type，請確認輸入是否為 0 或 1"
        return 1
    fi
}

# 設定 Referer 防盜鏈
set_referer() {
    local domain=$1
    local account=$2
    echo "🔗 設定 Referer 防盜鏈: $domain"
    tccli live ModifyLiveDomainReferer --cli-unfold-argument --DomainName "$domain" --ReferType 1 --ReferDomains "example.com,another.com" --AllowEmpty 1 --profile "$account"
}

# 檢查 HTTPS 憑證
check_ssl_certificate() {
    local main_domain=$1
    local account=$2
    echo "🔍  檢查憑證是否已存在（Alias = $main_domain）..."
    local cert_id=$(tccli ssl DescribeCertificates --profile "$account" | jq -r --arg alias "$main_domain" '.Certificates[] | select(.Alias == $alias) | .CertificateId')

    if [[ -z "$cert_id" || "$cert_id" == "null" ]]; then
        echo "❌ 憑證不存在於雲端"
        return 2
    else
        echo "✅ 憑證已存在，ID: $cert_id"
    fi    

    local cert_path="certs/$main_domain"
    local fullchain_file="$cert_path/fullchain.pem"
    
    if [[ ! -f "$fullchain_file" ]]; then
        echo "❌ 找不到本地憑證檔案：$fullchain_file"
        return 2
    fi

    # 取得到期時間（格式：Apr 15 23:59:59 2025 GMT）
    end_date=$(openssl x509 -enddate -noout -in "$fullchain_file" | cut -d= -f2)

    # 將時間轉為 timestamp 進行比較
    end_ts=$(date -d "$end_date" +%s)
    now_ts=$(date +%s)

    if [[ "$now_ts" -ge "$end_ts" ]]; then
        echo "⚠️ 憑證已過期（到期日：$end_date）"
        return 0
    else
        days_left=$(( (end_ts - now_ts) / 86400 ))
        echo "✅ 憑證有效（剩餘 $days_left 天）（到期日：$end_date）"
        return 1
    fi
}

# 上傳/更新 HTTPS 憑證
upload_certificate() {
    local domain=$1
    local account=$2
    local main_domain=$3
    
    echo "📤  上傳新憑證中..." >&2
    local cert_path="certs/$main_domain"
    local fullchain_file="$cert_path/fullchain.pem"
    local privkey_file="$cert_path/privkey.pem"
    
    local CERTIFICATE=$(< "$fullchain_file")
    local PRIVATE=$(< "$privkey_file")
    #echo "tccli ssl UploadCertificate --cli-unfold-argument --CertificatePublicKey '$CERTIFICATE' --CertificatePrivateKey '$PRIVATE' --Alias '$main_domain' --profile $account |jq -r .CertificateId"
    cert_id=$(tccli ssl UploadCertificate --cli-unfold-argument --CertificatePublicKey "$CERTIFICATE" --CertificatePrivateKey "$PRIVATE" --Alias "$main_domain" --profile $account |jq -r .CertificateId)
    if [[ -z "$cert_id" || "$cert_id" == "null" ]]; then
            echo "❌  憑證上傳失敗，無法取得 CertificateId" >&2
            return 1
    fi
    echo "✅   憑證上傳成功，ID: $cert_id" >&2
    echo "$cert_id"
    
}

# 綁定 HTTPS 憑證
bind_ssl_certificate() {
    local domain=$1
    local account=$2
    local main_domain=$3
    local domain_type=$4
    local cert_id=$(tccli ssl DescribeCertificates --profile "$account" | jq -r --arg alias "$main_domain" '.Certificates[] | select(.Alias == $alias) | .CertificateId' | head -n 1)
    echo "🔒 綁定 SSL 憑證: $domain"
    
    if [[ "$domain_type" -ne 1 ]]; then
        echo "⚠️ 僅處理播流域名憑證，如需處理推流域名請擴充此函數"
        return 0
    fi
    echo "tccli live ModifyLiveDomainCertBindings --cli-unfold-argument --CloudCertId $cert_id --DomainInfos.0.DomainName '$domain' --DomainInfos.0.Status 1 --profile $account"
    tccli live ModifyLiveDomainCertBindings --cli-unfold-argument --CloudCertId $cert_id --DomainInfos.0.DomainName "$domain" --DomainInfos.0.Status 1 --profile $account
}

# 刪除舊 HTTPS 憑證
remove_old_ssl_certificate() {
    local main_domain=$1
    local account=$2
    local keep_cert_id=$3

    echo "🧹 清理舊憑證（保留 $keep_cert_id）"

    local all_cert_ids=$(tccli ssl DescribeCertificates --profile "$account" \
        | jq -r --arg alias "$main_domain" '.Certificates[] | select(.Alias == $alias) | .CertificateId')

    for cert_id in $all_cert_ids; do
        if [[ "$cert_id" != "$keep_cert_id" ]]; then
            echo "❌ 刪除憑證：$cert_id"
            tccli ssl DeleteCertificate --cli-unfold-argument --CertificateId "$cert_id" --profile "$account"
        fi
    done
}

# 設置直播延遲
set_delay() {
    local domain=$1
    local account=$2
    echo "⏳ 設置直播延遲（5 秒）: $domain"
    tccli live AddDelayLiveStream --cli-unfold-argument --DomainName "$domain" --AppName live --StreamName test123 --DelayTime 5 --profile "$account"
}

# 查詢視頻域名資訊
query_live_domain() {
    local domain=$1
    local account=$2
    echo "🔐  查詢視頻域名資訊: $domain"
    tccli live DescribeLiveDomain --cli-unfold-argument --DomainName "$domain" --profile "$account"
}

# 更新憑證
update_certificate() {
    local domain=$1
    local account=$2
    local domain_type=$3
    local main_domain=$4
    
    if [[ "$domain_type" -ne 1 ]]; then
        echo "⚠️ 僅處理播流域名憑證，如需處理推流域名請擴充此函數"
        return 0
    fi

    echo "📺 播流域名 ➜ 準備憑證處理 ($domain) ..."

    local cert_path="certs/$main_domain"
    local fullchain_file="$cert_path/fullchain.pem"
    local privkey_file="$cert_path/privkey.pem"

    if [[ ! -f "$fullchain_file" || ! -f "$privkey_file" ]]; then
        echo "❌ 憑證檔案不存在：$fullchain_file 或 $privkey_file"
        return 1
    fi

    # ✅ 檢查憑證是否已上傳過
    echo "🔍 檢查憑證是否已上傳..."
    local cert_id=$(tccli ssl DescribeCertificates --profile "$account" | jq -r --arg alias "$main_domain" '.Certificates[] | select(.Alias == $alias) | .CertificateId')

    if [[ -n "$cert_id" ]]; then
        echo "✅ 憑證已存在，ID: $ID，略過上傳"
    else
        echo "📤 上傳新憑證中..."
        local CERTIFICATE=$(< "$fullchain_file")
        local PRIVATE=$(< "$privkey_file")

        cert_id=$(tccli ssl UploadCertificate --cli-unfold-argument --CertificatePublicKey "$CERTIFICATE" --CertificatePrivateKey "$PRIVATE" --Alias "$main_domain" --profile $account |jq -r .CertificateId)

        if [[ -z "$cert_id" || "$cert_id" == "null" ]]; then
            echo "❌ 憑證上傳失敗，無法取得 CertificateId"
            return 1
        fi

        echo "✅ 憑證上傳成功，ID: $cert_id"
    fi

    echo "🔗 綁定憑證到域名：$domain"
    tccli live ModifyLiveDomainCertBindings --cli-unfold-argument --CloudCertId $cert_id --DomainInfos.0.DomainName "$domain" --DomainInfos.0.Status 1 --profile $account

#    if [[ "$domain_type" -eq 1 ]]; then
#        echo "📺  播流域名 ➜ 使用 UploadCertificate"
#        CERTIFICATE=$(cat certs/$main_domain/fullchain.pem)
#        PRIVATE=$(cat certs/$main_domain/privkey.pem)
        ## 上傳SSL證書
#        ID=$(tccli ssl UploadCertificate --cli-unfold-argument --CertificatePublicKey "$CERTIFICATE" --CertificatePrivateKey "$PRIVATE" --Alias "$main_domain" --profile $account |jq -r .CertificateId)
        ## 綁定證書
#        tccli live ModifyLiveDomainCertBindings --cli-unfold-argument --CloudCertId $ID --DomainInfos.0.DomainName "$domain" --DomainInfos.0.Status 1 --profile $account
#    fi                            
}
