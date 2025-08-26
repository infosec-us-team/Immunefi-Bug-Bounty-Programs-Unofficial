#!/bin/bash

# Get NEXT_DATA in JSON format
NEXT_DATA_BOUNTIES=$(curl -s https://immunefi.com/bug-bounty/ | grep -o "<script id=\"__NEXT_DATA__\" type=\"application/json\".*>.*</script>" | grep -o "{.*}" | jq)
NEXT_DATA_BOOSTS=$(curl -s https://immunefi.com/audit-competition/ | grep -o "<script id=\"__NEXT_DATA__\" type=\"application/json\".*>.*</script>" | grep -o "{.*}" | jq)

# Get bounties in a variable
projects=$(echo "$NEXT_DATA_BOUNTIES" | jq '.props.pageProps.bounties')
# Get boosts in a variable
boosts=$(echo "$NEXT_DATA_BOOSTS" | jq '.props.pageProps.bounties')

# Let's see if new projects were added or paused
cat ./projects.json | jq -r '.[].project' | sort >prev_projects_name.txt
echo "$projects" | jq -r '.[].project' | sort >current_projects_name.txt

# Let's see if new boosts were added or removed
cat ./boosts.json | jq -r '.[].project' | sort >prev_boosts_name.txt
echo "$boosts" | jq -r '.[].project' | sort >current_boosts_name.txt


# Paused or Removed
paused_programs=$(comm -23 ./prev_projects_name.txt ./current_projects_name.txt | sed 's/^/#/' | sed -r 's/\s+//g' | xargs)
# Added or Unpaused
added_programs=$(comm -13 ./prev_projects_name.txt ./current_projects_name.txt | sed 's/^/#/' | sed -r 's/\s+//g' | xargs)

# Paused or Removed
paused_boosts=$(comm -23 ./prev_boosts_name.txt ./current_boosts_name.txt | sed 's/^/#/' | sed -r 's/\s+//g' | xargs)
# Added or Unpaused
added_boosts=$(comm -13 ./prev_boosts_name.txt ./current_boosts_name.txt | sed 's/^/#/' | sed -r 's/\s+//g' | xargs)

# Clean temporal files
rm ./prev_projects_name.txt
rm ./current_projects_name.txt

# Clean temporal files
rm ./prev_boosts_name.txt
rm ./current_boosts_name.txt

# Save current bounties
echo "$boosts" >boosts.json

# Save current bounties
echo "$projects" >projects.json

# Get buildId
buildId=$(echo "$NEXT_DATA_BOUNTIES" | jq -r '.buildId')

# Get how many bounties are
bounties_length=$(echo "$projects" | jq length)

for ((c = 0; c <= $bounties_length - 1; c++)); do

	# Get project's name
	name=$(echo "$projects" | jq -r .[$c].id)
	echo "Scanning: $name [$c/$bounties_length]"
	# Get project's data
	PROJECT_DATA=$(curl -s "https://immunefi.com/_next/data/$buildId/bug-bounty/$name/scope.json")
	echo "Calling: https://immunefi.com/_next/data/$buildId/bug-bounty/$name/scope.json"
	echo "$PROJECT_DATA"
	# There's no try/catch in batch, so this is our way to double check everything went right:
	# Get name from JSON response
	name_received=$(echo "$PROJECT_DATA" | jq -r '.pageProps.bounty.id')
	echo "Name received: $name_received [$c/$bounties_length]"
	# Compare it with stored name
	if [ "$name_received" = "$name" ]; then

		# All good!
		echo "$PROJECT_DATA" | jq 'del(.pageProps.project.vault)' | jq 'del(.pageProps.flags)' >./project/$name.json
		#Print DONE
		echo "Scanned: $name [$c/$bounties_length]"
		sleep .5

	else
		# PANIC!
		echo "PANIC ERROR!!! [$c/$bounties_length]"
		break
	fi

done


# Get buildId
buildId=$(echo "$NEXT_DATA_BOOSTS" | jq -r '.buildId')

# Get how many boosts are
boosts_length=$(echo "$boosts" | jq length)

for ((c = 0; c <= $boosts_length - 1; c++)); do

	# Get project's name
	name=$(echo "$boosts" | jq -r .[$c].id)
	echo "Scanning: $name [$c/$boosts_length]"
	# Get project's data
	PROJECT_DATA=$(curl -s "https://immunefi.com/_next/data/$buildId/boost/$name/scope.json")
	echo "Calling: https://immunefi.com/_next/data/$buildId/boost/$name/scope.json"
	echo "$PROJECT_DATA"
	# There's no try/catch in batch, so this is our way to double check everything went right:
	# Get name from JSON response
	name_received=$(echo "$PROJECT_DATA" | jq -r '.pageProps.bounty.id')
	echo "Name received: $name_received [$c/$boosts_length]"
	# Compare it with stored name
	if [ "$name_received" = "$name" ]; then

		# All good!
		echo "$PROJECT_DATA" | jq 'del(.pageProps.project.vault)' | jq 'del(.pageProps.flags)' >./project/$name.json
		#Print DONE
		echo "Scanned: $name [$c/$boosts_length]"
		sleep .5

	else
		notFound=$(echo "$PROJECT_DATA" | jq -r '.notFound')

		if [ "$notFound" = "true" ]; then
			# All good!
			echo "$PROJECT_DATA" >./project/$name.json
			#Print DONE
			echo "Scanned: $name [$c/$boosts_length]"
			sleep .5
		else
			# PANIC!
			echo "PANIC ERROR!!! [$c/$boosts_length]"
			break
		fi
	fi

done

# If there are any changes, commit them.
if [[ -z $(git status -s | grep -o -P 'project/.*') ]]; then
	echo "Nothing changed"
else

	projects_changed=$(git status -s | grep -o -P '(?<=M project\/).*(?=\.json)' | sed 's/^/#/' | xargs)

	# Commit message
	echo -e "\n\n"
	mg=$(echo -e "Projects added or unpaused:\n$added_programs\n\nBoosts added:\n$added_boosts\n\nProjects removed or paused:\n$paused_programs\n\nBoosts removed:\n$paused_boosts\n\nProjects or Boosts with updates:\n$projects_changed")
	echo -e "$mg"

	# Push to github
	git add --all
	git commit -m "$mg"
	git push

fi

date
exit
