#!/bin/bash

# Get NEXT_DATA in JSON format
NEXT_DATA=$(curl -s https://immunefi.com/bug-bounty/ | grep -o "<script id=\"__NEXT_DATA__\" type=\"application/json\">.*</script>" | grep -o "{.*}" | jq)

# Get bounties in a variable
projects=$(echo "$NEXT_DATA" | jq '.props.pageProps.bounties')

# Let's see if new projects were added or paused
cat ./projects.json | jq -r '.[].project' | sort >prev_projects_name.txt
echo "$projects" | jq -r '.[].project' | sort >current_projects_name.txt

# Paused or Removed
paused_programs=$(comm -23 ./prev_projects_name.txt ./current_projects_name.txt | sed 's/^/#/' | sed -r 's/\s+//g' | xargs)
# Added or Unpaused
added_programs=$(comm -13 ./prev_projects_name.txt ./current_projects_name.txt | sed 's/^/#/' | sed -r 's/\s+//g' | xargs)

# Clean temporal files
rm ./prev_projects_name.txt
rm ./current_projects_name.txt

# Save current bounties
echo "$projects" >projects.json

# Get buildId
buildId=$(echo "$NEXT_DATA" | jq -r '.buildId')

# Get how many bounties are
bounties_length=$(echo "$projects" | jq length)

for ((c = 0; c <= $bounties_length - 1; c++)); do

	# Get project's name
	name=$(echo "$projects" | jq -r .[$c].id)
	echo "Scanning: $name [$c/$bounties_length]"
	# Get project's data
	PROJECT_DATA=$(curl -s "https://immunefi.com/_next/data/$buildId/bounty/$name.json")
	echo "Calling: https://immunefi.com/_next/data/$buildId/bounty/$name.json"
	echo "$PROJECT_DATA"
	# There's no try/catch in batch, so this is our way to double check everything went right:
	# Get name from JSON response
	name_received=$(echo "$PROJECT_DATA" | jq -r '.pageProps.bounty.id')
	echo "Name received: $name_received [$c/$bounties_length]"
	# Compare it with stored name
	if [ "$name_received" = "$name" ]; then

		# All good!
		echo "$PROJECT_DATA" | jq 'del(.pageProps.project.vault)' >./project/$name.json
		#Print DONE
		echo "Scanned: $name [$c/$bounties_length]"
		sleep .3

	else
		# PANIC!
		echo "PANIC ERROR!!! [$c/$bounties_length]"
		break
	fi

done

# If there are any changes, commit them.
if [[ -z $(git status -s | grep -o -P 'project/.*') ]]; then
	echo "Nothing changed"
else

	added_qty=$(echo "$added_programs" | sed '/^\s*$/d' | wc -l)
	paused_qty=$(echo "$paused_programs" | sed '/^\s*$/d' | wc -l)
	projects_changed=$(git status -s | grep -o -P '(?<=M project\/).*(?=\.json)' | sed 's/^/#/' | xargs)
	updated_qty=$(git status -s | grep -o -P '(?<=M project\/).*(?=\.json)' | sed '/^\s*$/d' | wc -l)

	# Commit message
	echo -e "\n"
	mg=$(echo -e "Update\n\nProjects added or unpaused:\n$added_programs\nProjects removed or paused:\n$paused_programs\nProjects updated their program:\n$projects_changed")
	echo -e "$mg"

	# Push to github
	git add --all
	git commit -m "$mg"
	git push

fi

date
exit
