#!/bin/sh
# Usage from Target run ontape to STDIO piping to this script via ssh
# Example:
# ontape -s -L 0 -t STDIO -F | ssh targetHostname /home/informix/informix-restore.sh
#
# ls -l 
#
# Must have set up and tested ssh trust first
#

. /etc/profile.d/informix.environment.sh
ontape -p -t STDIO > /home/informix/backup.log 2>&1

