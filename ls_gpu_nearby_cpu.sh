#!/bin/bash

# This script:
# 1) Lists all GPUs PCI addresses using nvidia-smi or rocm-smi fallback
# 2) Maps each GPU PCI to NUMA node (via /sys or lstopo)
# 3) Lists CPU cores associated with the NUMA node (via lscpu)

# Get GPU PCI bus IDs from nvidia-smi or rocm-smi
if command -v nvidia-smi &>/dev/null; then
  GPUS=$(nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader | tr '[:upper:]' '[:lower:]' | sed 's/^0000//')
elif command -v rocm-smi &>/dev/null; then
  GPUS=$(rocm-smi --showhw | awk '/^GPU/ {found=1; next} found && NF>=10 {print $10}' | tr '[:upper:]' '[:lower:]')
else
  echo "Neither nvidia-smi nor rocm-smi found. Trying lspci for GPUs..."
  GPUS=$(lspci -Dn | grep -i 'vga\|3d\|display' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
fi

# Function to get NUMA node of a PCI device
get_numa_node() {
  local pci=$1
  # Convert 0000:07:00.0 or 07:00.0 to sysfs path pci0000:07/0000:07:00.0
  local pci_path=""
  if [[ $pci =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
    pci_path="/sys/bus/pci/devices/$pci"
  elif [[ $pci =~ ^[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
    pci_path=$(find /sys/bus/pci/devices/ -name "*$pci" | head -1)
  fi
  if [[ -z "$pci_path" ]]; then
    echo "unknown"
    return
  fi
  if [[ -f "$pci_path/numa_node" ]]; then
    numa_node=$(cat "$pci_path/numa_node")
    if [[ "$numa_node" -lt 0 ]]; then
      # -1 means no NUMA node info
      echo "0"
    else
      echo "$numa_node"
    fi
  else
    echo "unknown"
  fi
}

# Function to list CPUs of a NUMA node
list_cpus_in_numa_node() {
  local node=$1
  if [[ "$node" == "unknown" ]]; then
    echo "unknown"
    return
  fi
  cpus=$(lscpu -p=CPU,NODE | grep -v '^#' | awk -F, -v node="$node" '$2 == node {printf "%s ", $1}')

  echo "$cpus"
}

echo "GPU to NUMA node and CPU cores mapping:"
echo "---------------------------------------"

for pci in $GPUS; do
  # Normalize PCI format: add domain if missing
  if [[ ! $pci =~ ^[0-9a-f]{4}: ]]; then
    pci="0000:$pci"
  fi
  numa_node=$(get_numa_node "$pci")
  cpus=$(list_cpus_in_numa_node "$numa_node")

  # Print GPU info from lspci for nicer name
  gpu_name=$(lspci -s ${pci:5} | cut -d: -f3-)

  echo "GPU PCI: $pci"
  echo "  Model: $gpu_name"
  echo "  NUMA node: $numa_node"
  echo "  CPU cores near this GPU: $cpus"
  echo
done
