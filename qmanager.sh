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
	mkdir -p iso runnable images

	if [[ -n "$1" ]]
	then
		VM_NAME="$1"
		source "runnable/${VM_NAME}.conf"
	else
		ISO=$(ls iso/ | slmenu -l 15 -t -p "Select an ISO: ")
		if [[ -z "$ISO" ]]
		then
			echo "No ISO selected, aborting."
			return
		fi
	fi

	ARCH=$(echo -e "x86_64\naarch64\nriscv64\narm" | slmenu -l 5 -t -p "Select architecture: ")
	if [[ -z "$ARCH" ]]
	then
		echo "No architecture selected, aborting."
		return
	fi

	CORES=$(nproc)
	CORES=$(seq 1 $CORES | slmenu -l $CORES -t -p "Number of CPU cores: ")
	if [[ -z "$CORES" ]]
	then
		echo "No core count selected, aborting."
		return
	fi

	TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
	RAM_OPTIONS=$(seq 512 512 $TOTAL_RAM | tac)
	RAM=$(echo "$RAM_OPTIONS" | slmenu -l 15 -t -p "How much RAM (MB): ")
	if [[ -z "$RAM" ]]
	then
		echo "No RAM selected, aborting."
		return
	fi

	clear
	read -p "Disk size in GB (current: ${PREV_DISK_SIZE:-unset}): " DISK_SIZE
	DISK_SIZE=${DISK_SIZE:-$PREV_DISK_SIZE}
	if [[ -z "$DISK_SIZE" ]]
	then
		echo "No disk size set, aborting."
		return
	fi

	if [[ -z "$VM_NAME" ]]
	then
		VM_NAME=$(echo "" | slmenu -t -p "Name for the VM: ")
		if [[ -z "$VM_NAME" ]]
		then
			echo "No name provided, aborting."
			return
		fi
	fi

	KVM=$(echo -e "Yes\nNo" | slmenu -l 2 -t -p "Enable KVM?")
	if [[ "$KVM" == "Yes" ]]
	then
		KVM_FLAG="-enable-kvm"
	else
		KVM_FLAG=""
	fi

	DISPLAY_TYPE=$(echo -e "sdl\ngtk\ncurses\nnone" | slmenu -l 5 -t -p "Select display type: ")
	if [[ -z "$DISPLAY_TYPE" ]]
	then
		echo "No display type selected, aborting."
		return
	fi

	ISO_PATH="iso/$ISO"
	DISK_PATH="images/${VM_NAME}.qcow2"
	RUNNABLE_PATH="runnable/${VM_NAME}"

	if [[ ! -f "$DISK_PATH" ]]
	then
		qemu-img create -f qcow2 "$DISK_PATH" "${DISK_SIZE}G"
	else
		echo "Disk image already exists at $DISK_PATH, reusing it."
	fi

	cat > "$RUNNABLE_PATH" <<EOF
#!/bin/bash
qemu-system-$ARCH \\
	$KVM_FLAG \\
	-m $RAM \\
	-smp $CORES \\
	-drive file="$DISK_PATH",format=qcow2 \\
	-cdrom "$ISO_PATH" \\
	-boot order=d \\
	-net nic -net user \\
	-display $DISPLAY_TYPE
EOF
	chmod +x "$RUNNABLE_PATH"

	# Save VM configuration for future editing
	cat > "runnable/${VM_NAME}.conf" <<EOF
PREV_ARCH="$ARCH"
PREV_CORES="$CORES"
PREV_RAM="$RAM"
PREV_DISK_SIZE="$DISK_SIZE"
PREV_KVM="$KVM"
PREV_DISPLAY_TYPE="$DISPLAY_TYPE"
ISO="$ISO"
EOF

	echo "VM configuration saved for '$VM_NAME'."
	operationSelection
}

startVM()
{
	VM=$(ls runnable/ | grep -v '\.conf$' | slmenu -l 15 -t -p "Select a VM: ")
	if [[ -n "$VM" ]]
	then
		sh "./runnable/$VM" &
	fi
	operationSelection
}

editVM()
{
	VM=$(ls runnable/ | grep -v '\.conf$' | slmenu -l 15 -t -p "Select a VM to edit: ")
	if [[ -n "$VM" ]]
	then
		if [[ -f "runnable/${VM}.conf" ]]
		then
			source "runnable/${VM}.conf"
			createVM "$VM"
		else
			echo "No configuration file found for '$VM', cannot edit."
			sleep 2
		fi
	fi
	operationSelection
}

operationSelection()
{
	OPTION=$(echo -e "Create a VM\nStart a VM\nEdit a VM\nExit" | slmenu -l 5 -t -p "Select an option: ")
	if [[ "$OPTION" == "Create a VM" ]]
	then
		createVM
	elif [[ "$OPTION" == "Start a VM" ]]
	then
		startVM
	elif [[ "$OPTION" == "Edit a VM" ]]
	then
		editVM
	elif [[ "$OPTION" == "Exit" ]]
	then
		toggleCursor
		clear
		exit 0
	fi
}

toggleCursor
clear
echo -e "${BIRed}${On_Black}Welcome to QManager${Color_Off}"
operationSelection
