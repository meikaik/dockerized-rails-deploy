#### Staging Server (Direct VM) Instructions:
  REQUIRES: Debian 9.x
  1. Configure a static IP address directly on the VM

     `su`

     enter password

     `vi /etc/network/interfaces`

     [change the last line to look like this, remember to set the correct
      gateway for your router's IP address if it's not 192.168.0.1]

```
iface eth0 inet static
  address 192.168.0.1
  netmask 255.255.255.0
  gateway 192.168.0.1
```
  2. Reboot the VM and ensure the Debian CD is mounted

  3. Install sudo

     `apt-get update && apt-get install -y -q sudo`

  4. Add the user to the sudo group

     `adduser ${SSH_USER} sudo`

  5. Ensure SSH is installed

     `ps aux | grep sshd`

     If there is no ssh process:

     `apt-get update && apt-get install -y -q openssh-server && sudo systemctl enable ssh`

  6. Run `deploy.sh`

     Example:
       `./deploy.sh -a`