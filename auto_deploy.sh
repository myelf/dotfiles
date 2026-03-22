#!/bin/bash

# 檢查是否為 root 權限
if [[ $EUID -ne 0 ]]; then
   echo "請使用 sudo 執行此腳本"
   exit 1
fi

NAS_IP="192.168.50.250"
NAS_PATH="/volume1/NFS"  # 請確認 Synology 的實際路徑
LOCAL_MOUNT="/rhome"

echo ">>> 開始佈署 LDAP 認證與 FSTAB 靜態掛載 (Path: $LOCAL_MOUNT) <<<"

# 1. 安裝必要套件與移除 autofs
echo "1/5 安裝軟體包並清理舊環境..."
apt update -qq
apt install -y nfs-common sssd sssd-tools libnss-sss libpam-sss > /dev/null
systemctl stop autofs 2>/dev/null
systemctl disable autofs 2>/dev/null
# 徹底封印 autofs 以免干擾
systemctl mask autofs 2>/dev/null

# 2. 配置 SSSD (身份認證與 Shell/Home 覆蓋)
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
ldap_tls_reqcert = never
cache_credentials = true
enumerate = true

# 強制使用 Bash 並指定掛載點路徑
override_shell = /bin/bash
override_homedir = $LOCAL_MOUNT/%u
EOF

# 強制 SSSD 權限規範
chmod 600 /etc/sssd/sssd.conf
chown root:root /etc/sssd/sssd.conf

# 3. 配置 /etc/fstab (取代 AutoFS)
echo "3/5 配置 /etc/fstab 掛載規則..."
# 建立本地掛載點目錄
mkdir -p $LOCAL_MOUNT

# 檢查是否已存在相同的掛載規則，若無則加入
FSTAB_ENTRY="$NAS_IP:$NAS_PATH $LOCAL_MOUNT nfs _netdev,rw,soft,intr,x-systemd.automount,x-systemd.idle-timeout=600 0 0"
if ! grep -q "$LOCAL_MOUNT" /etc/fstab; then
    echo "$FSTAB_ENTRY" >> /etc/fstab
    echo "已成功加入 fstab。"
else
    echo "fstab 中已存在 $LOCAL_MOUNT 的規則，跳過修改。"
fi

# 4. 啟用自動建立家目錄 (PAM)
# 雖然我們建議手動預建，但保留此功能作為後援
echo "4/5 修正 PAM 階段設定..."
if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
    echo "session required    pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session
fi

# 5. 清理舊資料並重啟服務
echo "5/5 重新載入系統設定並重啟 SSSD..."
systemctl stop sssd
rm -f /var/lib/sss/db/*
rm -f /var/lib/sss/mc/*

# 重新載入 systemd 以識別新的 fstab 選項
systemctl daemon-reload
systemctl restart sssd
systemctl enable sssd

# 觸發掛載
mount -a

echo "--------------------------------------------------"
echo "佈署完成！"
echo "本地掛載點：$LOCAL_MOUNT"
echo "測試方式：輸入 'getent passwd [LDAP帳號]' 確認 Home 路徑為 $
