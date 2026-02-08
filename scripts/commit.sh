#!/bin/bash

# Git commit script for Deepu Jain
# Usage: ./scripts/commit.sh "your commit message"

if [ -z "$1" ]; then
  echo "Error: Commit message required"
  echo "Usage: ./scripts/commit.sh \"your commit message\""
  exit 1
fi

git add -A
git -c user.name="deepujain" -c user.email="deepujain@gmail.com" commit -m "$1"
git push

echo "✓ Changes committed and pushed"
