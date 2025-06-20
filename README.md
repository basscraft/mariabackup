### mariabackup.sh 순서도
![image](https://github.com/user-attachments/assets/82b2b31b-465d-4650-a1eb-3bf952c643e6)



### crontab

0 3 * * * /data/backup/deletebackup.sh >> /data/backup/logs/mariabackup.log 2>&1
0 4 * * * /data/backup/mariabackup.sh >> /data/backup/logs/mariabackup.log 2>&1
