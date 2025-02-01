# Bind NIC Interrupts to CPU Cores
```
#!/bin/bash

# Function to convert CPU list to bitmask
cpu_list_to_bitmask() {
    local cpu_list=($1)
    local bitmask=0
    for cpu in "${cpu_list[@]}"; do
        bitmask=$((bitmask | (1 << cpu)))
    done
    printf "%x" "$bitmask"
}

# Function to bind NIC interrupts to CPU cores
bind_nic_interrupts() {
    local nic_name=$1
    local cpu_list=($2)

    # Get the IRQ numbers for the NIC
    local irqs
    irqs=$(grep "$nic_name" /proc/interrupts | awk '{print $1}' | sed 's/://')

    if [[ -z "$irqs" ]]; then
        echo "Error: No interrupts found for NIC $nic_name."
        exit 1
    fi

    # Convert CPU list to bitmask
    local bitmask
    bitmask=$(cpu_list_to_bitmask "$(echo "${cpu_list[@]}")")

    # Bind each IRQ to the specified CPUs
    for irq in $irqs; do
        echo "Binding IRQ $irq to CPUs ${cpu_list[*]} (bitmask: $bitmask)"
        echo "$bitmask" > "/proc/irq/$irq/smp_affinity"
    done
}

# Main script
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <NIC_NAME> <CPU_LIST>"
    echo "  NIC_NAME: Name of the network interface (e.g., eth0)"
    echo "  CPU_LIST: Comma-separated list of CPU cores (e.g., 0,1,2,3)"
    exit 1
fi

nic_name=$1
cpu_list=($(echo "$2" | tr ',' ' '))

bind_nic_interrupts "$nic_name" "${cpu_list[*]}"
```
