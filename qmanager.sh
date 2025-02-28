#!/bin/bash
BIRed='\033[1;91m'
On_Black='\033[40m'
Red='\033[0;31m'
Color_Off='\033[0m'

set cursor=1
toggleCursor()
{
	if [[ cursor -eq 1 ]]
	then
		printf '\e[?25h'
		cursor=0
	else
		printf '\e[?25l'
		cursor=1
	fi
}

createVM()
{
  ISO=$(ls iso/ || mkdir iso && ls iso/ | slmenu -l 15 -t -p "Select an ISO: ")
}

operationSelection()
{
  OPTION=$(echo -e "Create a VM\nStart a VM\nExit" | slmenu -l 5 -t -p "Select an option: ")
  if [[ "$OPTION" == "Create a VM" ]]; then
    createVM
  fi
}

toggleCursor
clear
echo -e "${BIRed}${On_Black}Welcome to QManager${Color_Off}"
operationSelection
toggleCursor
