#!/bin/bash

BIRed='\033[1;91m'
On_Black='\033[40m'
Color_Off='\033[0m'

set cursor=1
toggleCursor() {
	if [[ cursor -eq 1 ]]; then
		printf '\e[?25h'
		cursor=0
	else
		printf '\e[?25l'
		cursor=1
	fi
}

operationSelection() {
	OPTION=$(echo -e "Create a VM\nStart a VM\nEdit a VM\nDelete a VM\nExit" | slmenu -l 5 -t -p "Select an option: ")
	case "$OPTION" in
		"Create a VM") createVM ;;
		"Start a VM") startVM ;;
		"Edit a VM") editVM ;;
		"Delete a VM") deleteVM ;;
		"Exit") toggleCursor; clear; exit 0 ;;
	esac
}

createVM() {
	mkdir -p iso runnable images
	ISO=$(ls iso/ | slmenu -l 15 -t -p "Select an ISO: ")
	[[ -z "$ISO" ]] && { echo "No ISO selected, aborting."; return; }

	ARCH=$(echo -e "x86_64\naarch64\nriscv64\narm" | slmenu -l 5 -t -p "Architecture: ")
	[[ -z "$ARCH" ]] && return

	CORES=$(seq 1 $(nproc) | slmenu -l 15 -t -p "Number of CPU cores: ")
	[[ -z "$CORES" ]] && return

	TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
	RAM=$(seq 512 512 $TOTAL_RAM | tac | slmenu -l 15 -t -p "RAM (MB): ")
	[[ -z "$RAM" ]] && return

  clear
	read -p "Disk size (1T, 1G, 1M, 1K): " DISK_SIZE
	[[ -z "$DISK_SIZE" ]] && return

	VM_NAME=$(echo "" | slmenu -t -p "Name for the VM: ")
	[[ -z "$VM_NAME" ]] && return

	KVM=$(echo -e "Yes\nNo" | slmenu -l 2 -t -p "Enable KVM?")
	DISPLAY_TYPE=$(echo -e "sdl\ngtk\ncurses\nnone" | slmenu -l 5 -t -p "Display type: ")

	DISK_PATH="images/${VM_NAME}.qcow2"
	qemu-img create -f qcow2 "$DISK_PATH" "${DISK_SIZE}"

	cat > "runnable/${VM_NAME}" <<EOF
#!/bin/bash
qemu-system-$ARCH \\
	$( [[ "$KVM" == "Yes" ]] && echo "-enable-kvm" ) \\
	-m $RAM \\
	-smp $CORES \\
	-drive file="$DISK_PATH",format=qcow2 \\
	-cdrom "iso/$ISO" \\
	-boot order=d \\
	-net nic -net user \\
	-display $DISPLAY_TYPE
EOF
	chmod +x "runnable/${VM_NAME}"

	cat > "runnable/${VM_NAME}.conf" <<EOF
PREV_ARCH="$ARCH"
PREV_CORES="$CORES"
PREV_RAM="$RAM"
PREV_DISK_SIZE="$DISK_SIZE"
PREV_KVM="$KVM"
PREV_DISPLAY_TYPE="$DISPLAY_TYPE"
ISO="$ISO"
EXTRA_DISK=()
EOF

	echo "VM '$VM_NAME' created."
	operationSelection
}

startVM() {
	VM=$(ls runnable/ | grep -v '\.conf$' | slmenu -l 15 -t -p "Start VM: ")
	[[ -n "$VM" ]] && ./runnable/$VM &
	operationSelection
}

editVM() {
	VM=$(ls runnable/ | grep -v '\.conf$' | slmenu -l 15 -t -p "Edit VM: ")
	[[ -z "$VM" ]] && return

	source "runnable/${VM}.conf"
	CHANGES=()

	while true; do
		OPTION=$(echo -e "CPU cores\nRAM\nDisplay type\nKVM toggle\nBoot ISO/CDROM\nAdd extra disk\nRemove extra disk\nAccept changes\nCancel" | slmenu -l 10 -t -p "Edit $VM:")

		case "$OPTION" in
			"CPU cores") CORES=$(seq 1 $(nproc) | slmenu -l 15 -t -p "Cores (current: $PREV_CORES): "); CHANGES+=("CORES=$CORES") ;;
			"RAM") RAM=$(seq 512 512 $(free -m | awk '/^Mem:/{print $2}') | tac | slmenu -l 15 -t -p "RAM (current: $PREV_RAM): "); CHANGES+=("RAM=$RAM") ;;
			"Display type") DISPLAY_TYPE=$(echo -e "sdl\ngtk\ncurses\nnone" | slmenu -l 5 -t -p "Display (current: $PREV_DISPLAY_TYPE): "); CHANGES+=("DISPLAY_TYPE=$DISPLAY_TYPE") ;;
			"KVM toggle") KVM=$(echo -e "Yes\nNo" | slmenu -l 2 -t -p "KVM (current: $PREV_KVM): "); CHANGES+=("KVM=$KVM") ;;
			"Boot ISO/CDROM") ISO=$(ls iso/ | slmenu -l 15 -t -p "ISO (current: ${ISO:-none}): "); [[ "$ISO" == "none" ]] && ISO=""; CHANGES+=("ISO=$ISO") ;;
			"Add extra disk")
        clear
				read -p "New disk name: " NEW_DISK
				read -p "New disk size (1T, 1G, 1M, 1K): " NEW_DISK_SIZE
				qemu-img create -f qcow2 "images/$NEW_DISK.qcow2" "${NEW_DISK_SIZE}"
				EXTRA_DISK+=("images/$NEW_DISK.qcow2")
				;;
			"Remove extra disk")
				SELECTED=$(printf "%s\n" "${EXTRA_DISK[@]}" | slmenu -l 10 -t -p "Remove disk:")
				EXTRA_DISK=("${EXTRA_DISK[@]/$SELECTED}")
				;;
			"Accept changes") applyVMChanges "$VM"; return ;;
			"Cancel") return ;;
		esac
	done
}

applyVMChanges() {
	VM=$1
	source "runnable/${VM}.conf"
	for change in "${CHANGES[@]}"; do eval "$change"; done
	cat > "runnable/${VM}" <<EOF
#!/bin/bash
qemu-system-$PREV_ARCH \\
	$( [[ "$KVM" == "Yes" ]] && echo "-enable-kvm" ) \\
	-m $RAM \\
	-smp $CORES \\
	-drive file="images/${VM}.qcow2",format=qcow2 \\
	$( [[ -n "$ISO" ]] && echo "-cdrom iso/$ISO" ) \\
	$(for disk in "${EXTRA_DISK[@]}"; do echo "-drive file=\"$disk\",format=qcow2 \\"; done) \
	-boot order=d \\
	-net nic -net user \\
	-display $DISPLAY_TYPE
EOF
	chmod +x "runnable/${VM}"

	cat > "runnable/${VM}.conf" <<EOF
PREV_ARCH="$PREV_ARCH"
PREV_CORES="$CORES"
PREV_RAM="$RAM"
PREV_DISK_SIZE="$PREV_DISK_SIZE"
PREV_KVM="$KVM"
PREV_DISPLAY_TYPE="$DISPLAY_TYPE"
ISO="$ISO"
EXTRA_DISK=(${EXTRA_DISK[*]})
EOF
	operationSelection
}

deleteVM() {
	VM=$(ls runnable/ | grep -v '\.conf$' | slmenu -l 15 -t -p "Select a VM to delete: ")
	[[ -z "$VM" ]] && return

	CONF_FILE="runnable/${VM}.conf"
	DISK_FILE="images/${VM}.qcow2"
	EXTRA_DISK=()

	if [[ -f "$CONF_FILE" ]]; then
		source "$CONF_FILE"
	fi

	echo "Deleting VM: $VM"

	DELETE_RUNNABLE=$(echo -e "Yes\nNo" | slmenu -l 2 -t -p "Delete runnable script?")
	[[ "$DELETE_RUNNABLE" == "Yes" ]] && rm -f "runnable/$VM"

	DELETE_CONFIG=$(echo -e "Yes\nNo" | slmenu -l 2 -t -p "Delete config file?")
	[[ "$DELETE_CONFIG" == "Yes" ]] && rm -f "$CONF_FILE"

	DELETE_DISK=$(echo -e "Yes\nNo" | slmenu -l 2 -t -p "Delete main disk?")
	[[ "$DELETE_DISK" == "Yes" ]] && rm -f "$DISK_FILE"

	if [[ ${#EXTRA_DISK[@]} -gt 0 ]]; then
		for disk in "${EXTRA_DISK[@]}"; do
			DELETE_EXTRA=$(echo -e "Yes\nNo" | slmenu -l 2 -t -p "Delete extra disk: $(basename "$disk")?")
			[[ "$DELETE_EXTRA" == "Yes" ]] && rm -f "$disk"
		done
	fi

	echo "Deletion process complete."
	sleep 1
	operationSelection
}

toggleCursor
clear
echo -e "${BIRed}${On_Black}Welcome to QManager${Color_Off}"
operationSelection
