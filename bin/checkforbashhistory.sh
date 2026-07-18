find . -type d -name .git -print0 |
while IFS= read -r -d '' g; do
  repo=$(dirname "$g")
  if git -C "$repo" ls-files | grep -qF '.bash_history'; then
    echo "FOUND in $repo"
  fi
done
