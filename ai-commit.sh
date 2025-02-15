#!/bin/bash
#
# ai-commit.sh - Generate Git commit messages using AI based on staged changes.
#
# Author: Alessio Franceschi
# License: MIT
#
# Description:
# This script uses an AI model to generate concise, conventional commit messages 
# based on the staged Git changes. It ensures commit messages follow the 
# Conventional Commits format (feat, fix, docs, style, refactor, etc.).
#
# Features:
# - Uses staged Git changes (`git diff --cached`) to generate a message.
# - Excludes common files (e.g., `package.json`, lock files, test files).
# - Integrates with a local AI API (running Ollama or similar).
# - Automatically copies the commit message to the clipboard.
# - Supports JIRA ticket extraction from branch names.
#
# Dependencies:
# - Git
# - jq (for JSON parsing)
# - curl (for API requests)
# - pbcopy/xclip/clip (for clipboard support)
#
# Usage:
# 1. Run the AI model locally (`ollama run qwen2.5-coder:7b` or similar).
# 2. Stage your changes: `git add .`
# 3. Execute the script: `./ai-commit.sh`
# 4. The commit message is generated, copied to clipboard, and displayed.
#

# Get only the diff of what has already been staged, excluding common unnecessary files.
git add .
git_diff_output=$(git diff --cached --diff-algorithm=minimal -- . \
  ":(exclude)package.json" ":(exclude)package-lock.json" \
  ":(exclude)*.lock" ":(exclude)*.test.*" ":(exclude).changeset/*")

# Check if there are any staged changes to commit
if git diff --cached --exit-code >/dev/null; then
  echo "⚠️ No staged changes detected. Aborting."
  exit 1
fi

# AI prompt setup
prompt=$(cat <<EOF
You are an AI assistant that generates high-quality Git commit messages.
Generate a concise Git commit message using the Conventional Commits format:
- First line: type: short description
  - Types: feat, fix, docs, style, refactor, perf, test, chore, etc.
  - Do not put any scope in parentheses.
- Optionally, bullet points for details **only if necessary**:
  - List only **actual code changes** from the diff.
  - Do NOT add assumptions, features, or anything that is not explicitly in the diff.
  - Keep bullets very short and relevant.
  - If the change is minor, do not use bullet points.

Do NOT include explanations, greetings, or formatting beyond the commit message.

Here’s the diff:

$git_diff_output
EOF
)

# Escape the prompt properly for JSON
json_escaped_prompt=$(jq -Rs '.' <<< "$prompt")

# Call the AI API (ensure your model is running locally)
response=$(curl -s -X POST http://127.0.0.1:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:7b",
    "prompt": '"$json_escaped_prompt"',
    "stream": false,
    "temperature": 0.1
  }')

# Extract AI-generated commit message
commit_message=$(echo "$response" | jq -r '.response' | sed 's/^ *//g')

# Validate AI response
if [ -z "$commit_message" ] || [[ "$commit_message" == "null" ]]; then
  echo "🚫 Failed to generate a commit message from AI."
  echo "⚠️ API Response: $response"
  exit 1
fi

# Keep only the first bullet points if there are more than two
commit_message=$(echo "$commit_message" | awk 'NR==1 || (NR<=3 && /^-/)')

# 🛠 Remove redundant bullet points
first_line=$(echo "$commit_message" | head -n 1)
filtered_message=$(echo "$commit_message" | awk -v title="$first_line" 'NR==1 || (NR==3 && $0 != "- " title)')

# Extract branch name and potential JIRA ticket
current_branch=$(git rev-parse --abbrev-ref HEAD)
jira_ticket=$(echo "$current_branch" | grep -oE '[A-Z]+-[0-9]+' || echo "")

# Ensure JIRA ticket is at the end of the first line of the commit message
if [ -n "$jira_ticket" ]; then
  filtered_message=$(echo "$filtered_message" | sed -E "s/^([^:]+): (.+)$/\1: \2 ($jira_ticket)/")
fi

# Copy commit message to clipboard (macOS, Linux, Windows support)
if command -v pbcopy &> /dev/null; then
  echo "$filtered_message" | pbcopy
  echo "✅ Commit message copied to clipboard (MacOS)."
elif command -v xclip &> /dev/null; then
  echo "$filtered_message" | xclip -selection clipboard
  echo "✅ Commit message copied to clipboard (Linux)."
elif command -v clip &> /dev/null; then
  echo "$filtered_message" | clip
  echo "✅ Commit message copied to clipboard (Windows)."
else
  echo "⚠️ Clipboard copy tool not found. Manually copy the commit message below:"
fi

# Output the commit message
echo "$filtered_message"

# Known Issue: The AI sometimes hallucinates on new or deleted files.
