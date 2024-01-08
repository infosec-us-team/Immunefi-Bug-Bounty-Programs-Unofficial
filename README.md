# Immunefi Bug Bounty Programs (Unofficial)
Every time a Bug Bounty Program in Immunefi modifies its **policy**, **assets-in-scope**, or **bounties-table**, a bot will commit those changes to this repo.

To get a before/after diff of a project go to `./project/{project-name}.json` and check it's latest commit.

## If a program is removed from Immunefi, will it be removed from here as well?
No, the information and history of changes will stay here forever.

## Can I use this as a public API to get a list of programs and assets in scope?
Yes.

To get **a list of programs** call this endpoint:

> `https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/projects.json`

For example, open your console and type:
```
wget -qO- https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/projects.json
```

To get a list of **assets in scope** and **program details** call this endpoint (replacing {PROJECT_ID} with the project's id):

> `https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/project/{PROJECT_ID}.json`

For example, open your console and type:
```
wget -qO- https://raw.githubusercontent.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial/main/project/2pi.json
```
