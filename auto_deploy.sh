#!/bin/bash

# 檢查是否為 root 權限
if [[ $EUID -ne 0 ]]; then
   echo "請使用 sudo 執行此腳本"
   exit 1
fi

echo ">>> 開始佈署 LDAP 認證與 NFS 漫遊家目錄 (Path: /NFS) <<<"

# 1. 安裝必要套件
echo "1/5 安裝軟體包..."
apt update -qq
apt install -y nfs-common autofs sssd sssd-tools libnss-sss libpam-sss > /dev/null

# 2. 配置 SSSD (身份認證與 Shell 覆蓋)
echo "2/5 設定 SSSD 與 LDAP 參數..."
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
cache_credentials = true
enumerate = true

# 關鍵：強制使用 Bash 並指定家目錄格式
override_shell = /bin/bash
fallback_homedir = /home/%u
EOF

# 強制 SSSD 權限規範
chmod 600 /etc/sssd/sssd.conf
chown root:root /etc/sssd/sssd.conf

# 3. 配置 AutoFS (NFS 自動掛載至 /home)
echo "3/5 設定 AutoFS 自動掛載規則..."
# 確保 auto.master 包含 /home 的對應
if ! grep -q "/home /etc/auto.home" /etc/auto.master; then
    echo "/home /etc/auto.home" >> /etc/auto.master
fi

# 建立 auto.home 規則：將 /home/$USER 對應到 NAS 的 /NFS/$USER
# & 是 AutoFS 的萬用字元，代表請求的使用者名稱
cat <<EOF > /etc/auto.home
* -fstype=nfs,rw,soft,intr,rsize=8192,wsize=8192 192.168.50.250:/NFS/&
EOF

# 4. 啟用自動建立家目錄掛載點 (PAM)
echo "4/5 修正 PAM 階段設定..."
if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
    echo "session required    pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session
fi

# 5. 清理舊資料並重新啟動
echo "5/5 清除快取並重新啟動服務..."
systemctl stop sssd
rm -f /var/lib/sss/db/*
rm -f /var/lib/sss/mc/*
systemctl daemon-reload
systemctl restart sssd
systemctl restart autofs
systemctl enable sssd autofs

echo "--------------------------------------------------"
echo "佈署完成！"
echo "測試方式：輸入 'getent passwd [LDAP帳號]' 確認 Shell 為 /bin/bash"
echo "然後嘗試切換使用者：'su - [LDAP帳號]'"
echo "--------------------------------------------------"
