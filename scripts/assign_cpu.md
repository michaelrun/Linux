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

# Assign CPU

```
#!/bin/bash

# Function to check if Hyper-Threading is enabled
is_hyperthreading_enabled() {
    if [[ $(lscpu | grep "Thread(s) per core" | awk '{print $4}') -gt 1 ]]; then
        return 0  # Hyper-Threading is enabled
    else
        return 1  # Hyper-Threading is disabled
    fi
}

# Function to check if SNC is enabled
is_snc_enabled() {
    local numa_distances
    numa_distances=$(numactl --hardware | grep "node distances:" -A 10 | tail -n +2)

    # Check if there are multiple NUMA nodes with the same smallest distance
    local smallest_distance
    smallest_distance=$(echo "$numa_distances" | awk '{print $2}' | sort -n | head -1)

    local count_smallest_distance
    count_smallest_distance=$(echo "$numa_distances" | grep -o "$smallest_distance" | wc -l)

    # If there are more than 2 NUMA nodes with the smallest distance, SNC is likely enabled
    if [[ $count_smallest_distance -gt 2 ]]; then
        return 0  # SNC is enabled
    else
        return 1  # SNC is disabled
    fi
}

# Function to get the list of CPU cores on a specified NUMA node
get_cores_on_numa_node() {
    local numa_node=$1
    local cores
    cores=$(numactl --hardware | grep "node $numa_node cpus" | awk -F': ' '{print $2}')
    echo "$cores"
}

# Function to assign CPU cores based on policy 1
assign_cores_policy1() {
    local numa_node=$1
    local num_cores=$2
    local cores
    cores=$(get_cores_on_numa_node "$numa_node")

    if is_hyperthreading_enabled; then
        # Hyper-Threading is enabled
        local physical_cores=($(echo "$cores" | tr ' ' '\n' | awk -F',' '{print $1}' | sort -u))
        local logical_cores=($(echo "$cores" | tr ' ' '\n' | grep -vxF "${physical_cores[@]}" | sort -u))

        local half_cores=$((num_cores / 2))
        local selected_cores=()

        # Assign physical cores
        selected_cores+=("${physical_cores[@]:0:$half_cores}")

        # Assign logical cores
        selected_cores+=("${logical_cores[@]:0:$half_cores}")

        echo "${selected_cores[@]}"
    else
        # Hyper-Threading is disabled
        local selected_cores=($(echo "$cores" | tr ' ' '\n' | head -n "$num_cores"))
        echo "${selected_cores[@]}"
    fi
}

# Function to assign CPU cores based on policy 2 (SNC enabled)
assign_cores_policy2() {
    local numa_nodes=($1)
    local num_cores=$2
    local distribute=$3  # 0: assign to specified NUMA node, 1: distribute across NUMA nodes
    local selected_cores=()

    if [[ $distribute -eq 0 ]]; then
        # Assign to specified NUMA node
        selected_cores=($(assign_cores_policy1 "${numa_nodes[0]}" "$num_cores"))
    else
        # Distribute across specified NUMA nodes
        local cores_per_node=$((num_cores / ${#numa_nodes[@]}))
        local remainder=$((num_cores % ${#numa_nodes[@]}))

        for node in "${numa_nodes[@]}"; do
            local cores
            cores=$(get_cores_on_numa_node "$node")
            local num_cores_to_assign=$cores_per_node

            if [[ $remainder -gt 0 ]]; then
                num_cores_to_assign=$((num_cores_to_assign + 1))
                remainder=$((remainder - 1))
            fi

            selected_cores+=($(echo "$cores" | tr ' ' '\n' | head -n "$num_cores_to_assign"))
        done
    fi

    echo "${selected_cores[@]}"
}

# Main script
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <policy> <numa_node(s)> <num_cores> [distribute]"
    echo "  policy: 1 (assign to specified NUMA node), 2 (SNC enabled)"
    echo "  numa_node(s): Comma-separated list of NUMA nodes (e.g., 0 or 0,1)"
    echo "  num_cores: Even number of CPU cores to assign"
    echo "  distribute: Optional, only for policy 2. 0: assign to specified NUMA node, 1: distribute across NUMA nodes"
    exit 1
fi

policy=$1
numa_nodes=($(echo "$2" | tr ',' ' '))
num_cores=$3
distribute=${4:-0}  # Default to 0 (assign to specified NUMA node)

if [[ $((num_cores % 2)) -ne 0 ]]; then
    echo "Error: Number of CPU cores must be even."
    exit 1
fi

# Check SNC status for Policy 2
if [[ $policy -eq 2 ]]; then
    if is_snc_enabled; then
        echo "SNC is enabled."
    else
        echo "SNC is disabled."
    fi
fi

case $policy in
    1)
        if [[ ${#numa_nodes[@]} -ne 1 ]]; then
            echo "Error: Policy 1 requires exactly one NUMA node."
            exit 1
        fi
        selected_cores=($(assign_cores_policy1 "${numa_nodes[0]}" "$num_cores"))
        ;;
    2)
        if [[ ${#numa_nodes[@]} -lt 1 ]]; then
            echo "Error: Policy 2 requires at least one NUMA node."
            exit 1
        fi
        selected_cores=($(assign_cores_policy2 "${numa_nodes[*]}" "$num_cores" "$distribute"))
        ;;
    *)
        echo "Error: Invalid policy. Use 1 or 2."
        exit 1
        ;;
esac

echo "Selected CPU cores: ${selected_cores[*]}"
```

nic_name=$1
cpu_list=($(echo "$2" | tr ',' ' '))

bind_nic_interrupts "$nic_name" "${cpu_list[*]}"
```
