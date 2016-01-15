#!/usr/bin/expect -f
set timeout 300
set date [timestamp -format "%a"]
set archive_path "/Users/serveradmin/Desktop"
set archive_password "test"
set archive_name "OpenDirectory_Day_"

spawn /usr/sbin/slapconfig -backupdb $archive_path/$archive_name$date
expect "Enter archive password"
send "$archive_password\r"
expect eof
