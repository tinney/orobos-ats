#!/usr/bin/env bash

i = 0
while true; do
  start=$(date +%s)

  # Your commands
  echo "Running commands..."
  if [[ -n $(git status --porcelain) ]]; then
    echo "Changes detected"
    git add -A;
    git ci -m "Adding Ooroboros changes... Iteraetion $i"
    git git push

    # Commands to run when there are changes
    git status
  else
    # Do nothing
    :
  fi

  ((i++))

  end=$(date +%s)
  elapsed=$((end - start))

  sleep_time=$((60 - elapsed))
  if [ $sleep_time -gt 0 ]; then
    sleep $sleep_time
  fi
done
