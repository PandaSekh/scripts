#!/bin/bash
#
# docker-reaper.sh - Periodically cleans up Docker containers, images, volumes, and networks.
#
# Author: Alessio Franceschi
# License: MIT
#
# Description:
# This script runs indefinitely, cleaning up all Docker containers, images, volumes, and networks
# every 4 hours. It is designed for development environments where frequent resets are needed.
#
# Usage:
# 1. Place the script in /usr/local/bin/ (or ~/bin/ for personal use).
# 2. Make it executable: chmod +x /usr/local/bin/docker-attila
# 3. To run in the background: nohup docker-attila > /dev/null 2>&1 &
# 4. Stop it anytime with CTRL+C
#
# ⚠️ WARNING:
# This script will permanently delete all Docker containers, images, volumes, and networks.
# Use with caution, especially on production machines!
#
# Dependencies:
# - Docker (ensure it is installed and running)
#

# Infinite loop to clean up Docker every 4 hours
while true; do
    echo "🔄 Docker cleanup started... [CTRL+C to stop]"

    # Get a list of all container IDs
    CONTAINERS=$(docker ps -aq)

    # Stop and remove containers if any exist
    if [[ -n "$CONTAINERS" ]]; then
        echo "🛑 Stopping all containers..."
        docker stop $CONTAINERS
        echo "🗑️ Removing all containers..."
        docker rm $CONTAINERS
    else
        echo "✅ No running or stopped containers found."
    fi

    # Remove unused images, volumes, and networks
    echo "📦 Pruning unused Docker images..."
    docker image prune -a -f
    echo "🗄️ Pruning unused Docker volumes..."
    docker volume prune -f
    echo "🌐 Pruning unused Docker networks..."
    docker network prune -f

    echo "✅ Cleanup complete. Next run in 4 hours..."
    sleep 14400  # Wait 4 hours before repeating
done
