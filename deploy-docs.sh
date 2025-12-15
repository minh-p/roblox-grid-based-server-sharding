#!/usr/bin/env sh

# Make sure to include this line in visudo (server)
# user ALL=(ALL) NOPASSWD: /path/to/rsync
rsync -avz --delete --rsync-path="sudo rsync" ./build user@ip:/var/www/docs/roblox-grid-based-server-sharding
