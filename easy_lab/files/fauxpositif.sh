#!/bin/bash
TARGET_IP=10.0.30.16
USER=testuser
LOGFILE=/var/log/fauxpositif.log

echo "Faux positif lancé à $(date)" >> $LOGFILE

# 2 tentatives échouées (mauvais mot de passe)
sshpass -p "wrongpass" ssh $USER@$TARGET_IP -p 22 \
  -o StrictHostKeyChecking=no -o ConnectTimeout=5 exit >> $LOGFILE 2>&1

sshpass -p "wrongpass" ssh $USER@$TARGET_IP -p 22 \
  -o StrictHostKeyChecking=no -o ConnectTimeout=5 exit >> $LOGFILE 2>&1

# 3ème tentative réussie (mot de passe correct)
sshpass -p "123456" ssh $USER@$TARGET_IP -p 22 \
  -o StrictHostKeyChecking=no -o ConnectTimeout=5 exit >> $LOGFILE 2>&1
