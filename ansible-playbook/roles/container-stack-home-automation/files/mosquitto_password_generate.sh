#!/bin/bash

docker run --rm  eclipse-mosquitto sh -c "mosquitto_passwd -b -c /tmp/password.txt '$1' '$2' 2>/dev/null && cat /tmp/password.txt"