1. Install wg-easy, run the following:
```
bash <(wget -qO- https://raw.githubusercontent.com/kinhsman/vps-setup/master/vps-setup2.sh)
```

2. Get NordVPN wireguard config:
   
   2.1. Create access token and copy it:

   https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/
   https://nord-configs.onrender.com/

   2.2. The run the following script:
```
apt update && apt install jq -y   
bash <(wget -qO- https://raw.githubusercontent.com/kinhsman/vps-setup/master/get-nordvpn-wireguard-config.sh)
```
3. Create user kinhsman

```
sudo -i
```

```
bash <(wget -qO- https://raw.githubusercontent.com/kinhsman/vps-setup/master/creating-kinhsman.sh)
```
