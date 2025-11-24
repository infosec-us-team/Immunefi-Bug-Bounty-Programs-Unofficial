#!/bin/bash

# Pull the latest program directory from Immunefi's new public API endpoint.
bounty_directory_json=$(curl -s https://immunefi.com/public-api/bounties.json | jq)

# Compare current program slugs against what we already have tracked locally.
echo "$bounty_directory_json" | jq '.[].slug' | tr -d '"' | sort >./current_slugs.txt
cat ./projects.json | jq -r '.[].slug' | sort >./previous_slugs.txt

# Programs that disappeared from the directory (paused or removed).
paused_or_removed_programs=$(comm -23 ./previous_slugs.txt ./current_slugs.txt | sed 's/^/#/' | sed -r 's/\s+//g' | xargs)
# Programs that appeared in the directory (added or unpaused).
added_or_unpaused_programs=$(comm -13 ./previous_slugs.txt ./current_slugs.txt | sed 's/^/#/' | sed -r 's/\s+//g' | xargs)

# Clean up temporary lists.
rm ./previous_slugs.txt
rm ./current_slugs.txt

# Overwrite the tracked directory snapshot with the latest data, duplicating slug into id for compatibility.
echo "$bounty_directory_json" | jq 'map(. + {id: .slug})' >projects.json

# Determine how many entries we need to fetch individually.
bounty_count=$(echo "$bounty_directory_json" | jq length)

for ((index = 0; index <= bounty_count - 1; index++)); do

  # Each element includes the program slug that identifies its detailed record.
  bounty_slug=$(echo "$bounty_directory_json" | jq -r .[$index].slug)
  echo "Scanning: $bounty_slug [$index/$bounty_count]"

  # Pull the full program details for this slug.
  bounty_details_json=$(curl -s "https://immunefi.com/public-api/bounty/$bounty_slug.json")
  echo "Calling: https://immunefi.com/public-api/bounty/$bounty_slug.json"
  echo "$bounty_details_json"

  # Basic sanity check: confirm the API returned the slug we requested.
  response_slug=$(echo "$bounty_details_json" | jq -r '.slug' | tr -d '"')
  echo "Name received: $response_slug [$index/$bounty_count]"

  if [ "$response_slug" = "$bounty_slug" ]; then

    # Happy path: format and store the program snapshot.
    echo "$bounty_details_json" | jq '. + {id: .slug}' >./project/$bounty_slug.json
    echo "Scanned: $bounty_slug [$index/$bounty_count]"
    sleep .5

  else
    # Bail out early to avoid writing bad data.
    echo "PANIC ERROR!!! [$index/$bounty_count]"
    break
  fi

done

# If there are any changes, commit them.
if [[ -z $(git status -s | grep -o -P 'project/.*') ]]; then
  echo "Nothing changed"
else

  projects_changed=$(git status -s | grep -o -P '(?<=M project\/).*(?=\.json)' | sed 's/^/#/' | xargs)

  # Commit message
  echo -e "\n\n"
  mg=$(echo -e "Projects added or unpaused:\n$added_or_unpaused_programs\n\nProjects removed or paused:\n$paused_or_removed_programs\n\nProjects with updates:\n$projects_changed")
  echo -e "$mg"

  # Push to github
  git add --all
  git commit -m "$mg"
  git push

fi

date
exit
