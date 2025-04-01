1. Install wg-easy, run the following:
```
bash <(wget -qO- https://raw.githubusercontent.com/kinhsman/vps-setup/master/vps-setup.sh)`
```

2. Get NordVPN wireguard config:
   
   2.1. Create access token and copy it:

   https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/


   2.2. The run the following script:
```   
bash <(wget -qO- https://raw.githubusercontent.com/kinhsman/vps-setup/master/get-nordvpn-wireguard-config.sh)
```
3. Create user kinhsman
```
sudo bash <(wget -qO- https://raw.githubusercontent.com/kinhsman/vps-setup/master/creating-kinhsman.sh)
```
