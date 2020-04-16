#!/bin/bash

# edit config file

ADDRESS=$(ifconfig eth0 | grep -E -o "(25[0-4]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-4]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-4]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-4]|2[0-4][0-9]|[01]?[0-9][0-9]?)" | head -n 1)

sudo cat << EOF > /home/ubuntu/transit-app-example/backend/config.ini
[DEFAULT]
LogLevel = WARN

[DATABASE]
Address = $ADDRESS
Port = 3306
User = root
Password = root
Database = my_app

[VAULT]
Enabled = True
DynamicDBCreds = False
DynamicDBCredsPath = lob_a/workshop/database/creds/workshop-app
ProtectRecords = True
Address = http://localhost:8200
Token = root
Namespace = root
KeyPath = lob_a/workshop/transit
KeyName = customer-key
Transform = True
TransformPath = lob_a/workshop/transform
SSNRole = ssn
EOF