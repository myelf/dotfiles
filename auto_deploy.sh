#!/bin/bash

# 檢查是否為 root 權限
if [[ $EUID -ne 0 ]]; then
   echo "請使用 sudo 執行此腳本"
   exit 1
fi

echo ">>> 開始佈署 LDAP 認證 (家目錄設為本地端 /home/\$USER) <<<"

# 1. 安裝必要套件與清理舊環境
# 移除 nfs-common，因為不再需要掛載遠端磁碟
echo "1/4 安裝軟體包並清理舊環境..."
apt update -qq
apt install -y sssd sssd-tools libnss-sss libpam-sss > /dev/null

# 停止並移除可能干擾的 autofs
systemctl stop autofs 2>/dev/null
systemctl disable autofs 2>/dev/null
systemctl mask autofs 2>/dev/null

# 2. 配置 SSSD (身份認證與 Shell/Home 覆蓋)
# 將 override_homedir 設定為本地端的 /home/%u
echo "2/4 設定 SSSD 與 LDAP 參數..."
cat <<EOF > /etc/sssd/sssd.conf
[sssd]
services = nss, pam
config_file_version = 2
domains = default

[nss]

[pam]

[domain/default]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldap://192.168.50.250
ldap_search_base = dc=taluhome,dc=tw
ldap_id_use_start_tls = false
ldap_tls_reqcert = never
cache_credentials = true
enumerate = true

# 強制使用 Bash 並將家目錄設為本地 /home/%u
override_shell = /bin/bash
override_homedir = /home/%u
EOF

# 強制 SSSD 權限規範
chmod 600 /etc/sssd/sssd.conf
chown root:root /etc/sssd/sssd.conf

# 3. 啟用自動建立本地家目錄 (PAM)
# 這是本地端存儲模式最重要的部分，確保登入時自動 mkdir
echo "3/4 配置 PAM 自動建立家目錄..."
if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
    echo "session required    pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session
fi

# 4. 清理舊資料並重啟服務
echo "4/4 重新載入系統設定並重啟 SSSD..."
systemctl stop sssd
# 徹底刪除舊的 LDAP 帳號快取資料庫
rm -f /var/lib/sss/db/*
rm -f /var/lib/sss/mc/*

systemctl daemon-reload
systemctl restart sssd
systemctl enable sssd

echo "--------------------------------------------------"
echo "佈署完成！"
echo "所有 LDAP 帳號將使用本地儲存空間：/home/$USER"
echo "測試方式：輸入 'getent passwd [LDAP帳號]' 確認路徑正確"
echo "測試登入：'su - [LDAP帳號]'，系統應會自動建立本地資料夾"
echo "--------------------------------------------------"
