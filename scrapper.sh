#!/bin/bash

# Get NEXT_DATA in JSON format
NEXT_DATA=$(curl -s https://immunefi.com/explore/ | grep -o "<script id=\"__NEXT_DATA__\" type=\"application/json\">.*</script>" | grep -o "{.*}" | jq)

# Get bounties in a variable
projects=$(echo "$NEXT_DATA" | jq '.props.pageProps.bounties')

# Check if bounties were added or removed, then do something about it
#prev_bounties=$(cat projects.json)
#if [ "$projects" = "$prev_projects" ]; then
    # No programs were removed or added - do something here
#else
    # Programs were removed or added - do something here
#fi

# Save current bounties
echo "$NEXT_DATA" | jq '.props.pageProps.bounties' > projects.json

# Get buildId
buildId=$(echo "$NEXT_DATA" | jq -r '.buildId')

# Get how many bounties are
bounties_length=$(echo "$projects" | jq length)

for (( c=0; c<=$bounties_length-1; c++))
do
   echo "$c"
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
