#!/bin/bash

useradd --home-dir /cerebro/dbup --shell /bin/bash dbup
chown -R dbup /cerebro/dbup
chmod 700 /cerebro/dbup

cp ./update.sh.example ./update.sh
chown root.dbup ./update.sh
chmod 750 ./update.sh

mkdir /cerebro/dbup/.ssh
echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDIclBaczEQC7kfRAE4sFO4IdyLg1LeqDRgPqYw/WOsT+Uyi2XxODY6b0iPRklmHBdoV3+MQ7PZmkAaoWOZeKYt8BDH2MjN7DKNRxeUXDZgW3iblg5Z9S0dgmGu195Sc1r9Wnc+iO8H3DkRvRBTgKax00F34Pv+3B8Iiycgn05+h5PjVc7f1g2cUJZnulvPy2rwtLsmtbVDfafbdi7B8VyRaGO+6AG/sFi3HtsLDCdM8l7wzz9HOfgSjIloo+QKAw4t0ygzDLqxK34cpBFZqa60INsnQ29RIJHtKvA2PBwUCIb/EH3mpxrWVC70SXNPyxhxkG2kwg3lmwOB5T/6H+71 root@ss.cerebrohq.com >/cerebro/dbup/.ssh/authorized_keys
chown -R dbup.dbup /cerebro/dbup/.ssh
chmod og+rx /cerebro

echo "dbup ALL=(ALL) NOPASSWD: /usr/bin/svn" >/etc/sudoers.d/dbup-svn

sudo -u dbup svn up --username virtual
