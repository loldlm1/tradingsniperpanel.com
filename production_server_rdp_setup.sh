sudo ufw allow 2000:3000/tcp
sudo ufw allow from 82.86.115.138 to any port 3334 # Prevent DDoS 

sudo apt update
sudo apt install -y xrdp xorgxrdp lightdm
sudo apt-get install -y xfce4 xfce4-session xfce4-goodies

# sudo nano /etc/xrdp/xrdp.ini
port=3334 # Prevent DDoS to default Ports
use_vsock=false
h264=true

[Xorg]
name=Xorg
lib=libxup.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=20

# Unset potentially problematic environment variables
# nano /etc/xrdp/startwm.sh
# unset DBUS_SESSION_BUS_ADDRESS
# unset XDG_RUNTIME_DIR
# startxfce4

# nano ~/.xsession
# startxfce4

sudo systemctl restart xrdp

# AVOID WAYS TO SUSPEND LINUX/UBUNTU

sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

sudo nano /etc/systemd/logind.conf
[Login]
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitchExternalPower=ignore
sudo systemctl restart systemd-logind

sudo nano /etc/UPower/UPower.conf
[Sleep]
AllowSuspend=false
AllowHibernate=false
sudo systemctl restart upower

sudo nano /etc/acpi/events/powerbtn
event=button/power.*
action=/etc/acpi/powerbtn.sh

gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'

crontab -l
sudo systemctl list-timers

xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/inactivity-on-ac -s 0
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/inactivity-on-battery -s 0
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/logind-handle-lid-switch -s false
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/logind-handle-suspend-switch -s false
