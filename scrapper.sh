#!/bin/bash

# Get NEXT_DATA in JSON format
NEXT_DATA=$(curl -s https://immunefi.com/explore/ | grep -o "<script id=\"__NEXT_DATA__\" type=\"application/json\">.*</script>" | grep -o "{.*}" | jq)

# Get bounties in a variable
projects=$(echo "$NEXT_DATA" | jq '.props.pageProps.bounties')

# Let's see if new projects were added or paused
cat ./projects.json | jq -r '.[].project' | sort > prev_projects_name.txt
echo "$projects" | jq -r '.[].project' | sort > current_projects_name.txt

# Paused or Removed
paused_programs=$(comm -23 ./prev_projects_name.txt ./current_projects_name.txt | xargs)
# Added or Unpaused
added_programs=$(comm -13 ./prev_projects_name.txt ./current_projects_name.txt | xargs)

# Clean temporal files
rm ./prev_projects_name.txt
rm ./current_projects_name.txt

# Save current bounties
echo "$projects" > projects.json

# Get buildId
buildId=$(echo "$NEXT_DATA" | jq -r '.buildId')

# Get how many bounties are
bounties_length=$(echo "$projects" | jq length)

for (( c=0; c<=$bounties_length-1; c++))
do

   # Get project's name
   name=$(echo "$projects" | jq -r .[$c].id)
   # Get project's data
   PROJECT_DATA=$(curl -s "https://immunefi.com/_next/data/$buildId/bounty/$name.json")

   # There's no try/catch in batch, so this is our way to double check everything went right:
   # Get name from JSON response
   name_received=$(echo "$PROJECT_DATA" | jq -r '.pageProps.bounty.id')
   # Compare it with stored name
   if [ "$name_received" = "$name" ]; then

     # All good!
     echo "$PROJECT_DATA" | jq > ./project/$name.json
     #Print DONE
     echo "$name updated!"
     sleep .2

   else
     # PANIC!
     break;
   fi

done

# If there are any changes, commit them.
if [[ -z $(git status -s | grep -o -P '(?<=M project\/).*(?=\.json)') ]]
then
  echo "Nothing changed"
else

  added_qty=$(echo "$added_programs" | sed '/^\s*$/d' | wc -l)
  paused_qty=$(echo "$paused_programs" | sed '/^\s*$/d' | wc -l)
  projects_changed=$(git status -s | grep -o -P '(?<=M project\/).*(?=\.json)')
  updated_qty=$(echo "$projects_changed" | sed '/^\s*$/d' | wc -l)

  # Commit message
  echo -e "\n"
  mg=$(echo -e "Update\n\nProjects added or unpaused: $added_qty\n$added_programs\nProjects removed or paused: $paused_qty\n$paused_programs\nProjects updated their program: $updated_qty\n$projects_changed")
  echo -e "$mg"

  # Push to github
  git add --all
  git commit -m "$mg"
  git push

  # Tweet about it
  tweet="🤖 Bip bop! "
  if [ "$added_qty" -ne "0" ]; then
    tweet="${tweet}New projects: $added_qty [$added_programs] | "
  fi

  if [ "$paused_qty" -ne "0" ]; then
    tweet="${tweet}Paused projects: $paused_qty [$paused_programs] | "
  fi

  if [ "$updated_qty" -ne "0" ]; then
    tweet="${tweet}Projects that updated their program: $updated_qty [$projects_changed] | "
  fi

  tweet="${tweet}Changes committed to the repo, link in the description. #Immunefi #Infosec #Bugbounty"

  python3 ./tweet.py "${tweet}"

  exit
fi

