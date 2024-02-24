
PAGE_SIZE=32
TOTAL_MEMORY=1024
NUM_FRAMES=$((TOTAL_MEMORY / PAGE_SIZE))
NUM_BLOCKS=4  # Assuming four blocks

# Initialize Frames
declare -a frames
declare -A process_frames  # Associative array for mapping processes to frames
declare -a block_sizes     # Array for storing the size of each block
declare -a block_usage     # Array for tracking usage of each block

for ((i=0; i<NUM_FRAMES; i++)); do
    frames[$i]=0
done

process_counter=1

# Function to Set Block Sizes
set_block_sizes() {
    echo "Choose block type (fixed, variable):"
    read block_type
    if [ "$block_type" == "fixed" ]; then
        block_size=$((TOTAL_MEMORY / NUM_BLOCKS))
        for ((i=0; i<NUM_BLOCKS; i++)); do
            block_sizes[$i]=$block_size
            block_usage[$i]=0  # Ensure block_usage is initialized
        done
    elif [ "$block_type" == "variable" ]; then
        total_size=0
        for ((i=0; i<NUM_BLOCKS; i++)); do
            echo "Enter size for Block $i:"
            read size
            block_sizes[$i]=$size
            block_usage[$i]=0  # Ensure block_usage is initialized
            total_size=$((total_size + size))
            if [ $total_size -gt $TOTAL_MEMORY ]; then
                echo "Total size exceeds $TOTAL_MEMORY bytes. Please reconfigure."
                return
            fi
        done
    else
        echo "Invalid block type. Please choose 'fixed' or 'variable'."
        return
    fi
}


allocate_within_block() {
    local block_index=$1
    local pages_needed=$2
    local start_frame=$((block_index * (TOTAL_MEMORY / NUM_BLOCKS / PAGE_SIZE)))
    local frame_count=$((block_sizes[block_index] / PAGE_SIZE))
    local allocated_frames=""
    local pages_allocated=0

    for ((i=start_frame; i<start_frame + frame_count && pages_needed > 0; i++)); do
        if [ "${frames[$i]}" -eq 0 ]; then
            frames[$i]=$process_counter
            allocated_frames="$allocated_frames $i"
            ((pages_needed--))
            ((pages_allocated++))
            block_usage[$block_index]=$((block_usage[$block_index] + 1))
        fi
    done

    if [ $pages_allocated -gt 0 ]; then
        process_frames["P$process_counter"]=$allocated_frames
        ((process_counter++))
        return 0
    else
        return $pages_needed
    fi
}


# Function to Allocate Frames
allocate_frames() {
    num_pages=$1
    allocation_strategy=$2

    # Initialization of block_space to avoid unassigned errors
    for ((b=0; b<NUM_BLOCKS; b++)); do
        if [ -z "${block_usage[b]}" ]; then
            block_usage[b]=0
        fi
    done
    
    case $allocation_strategy in
        "first")
            for ((b=0; b<NUM_BLOCKS; b++)); do
                block_space=$((block_sizes[b] / PAGE_SIZE - block_usage[b]))
                if [ $block_space -ge $num_pages ]; then
                    allocate_within_block $b $num_pages
                    echo "Process P$process_counter allocated in Block $b using First Fit"
                    return
                fi
            done
            ;;

        "best")
            best_block=-1
            min_space=-1  # Initialize with -1 to indicate no block found yet

            for ((b=0; b<NUM_BLOCKS; b++)); do
                block_space=$((block_sizes[b] / PAGE_SIZE - block_usage[b]))
                if [ $block_space -ge $num_pages ]; then
                    if [ $min_space -eq -1 ] || [ $block_space -lt $min_space ]; then
                        best_block=$b
                        min_space=$block_space
                    fi
                fi
            done

            if [ $best_block -ne -1 ]; then
                allocate_within_block $best_block $num_pages
                return
            fi
            ;;

        "worst")
            worst_block=-1
            max_space=-1

            for ((b=0; b<NUM_BLOCKS; b++)); do
                block_space=$((block_sizes[b] / PAGE_SIZE - block_usage[b]))
                if [ $block_space -ge $num_pages ] && [ $block_space -gt $max_space ]; then
                    worst_block=$b
                    max_space=$block_space
                fi
            done

            if [ $worst_block -ne -1 ]; then
                allocate_within_block $worst_block $num_pages
                return
            fi
            ;;
    esac
if [ $num_pages -eq 0 ]; then
        echo "Process P$((process_counter - 1)) successfully allocated using $allocation_strategy Fit"
    else
        echo "No suitable memory block found for Process P$process_counter using $allocation_strategy Fit"
    fi
}


#Function to Create Process
#Function to Create Process
# Function to Create Process
create_process() {
    echo "Enter the memory size of the process:"
    read process_size

    echo "Choose the allocation algorithm (first, best, worst):"
    read allocation_algorithm

    # Calculate the number of pages needed
    num_pages=$(( (process_size + PAGE_SIZE - 1) / PAGE_SIZE ))

    echo "Creating Process P$process_counter with $num_pages pages using $allocation_algorithm Fit algorithm..."

    # Allocate frames based on selected algorithm
    allocate_frames $num_pages $allocation_algorithm
    # Note: process_counter is incremented within allocate_within_block function
}


release_memory() {
    echo "Enter the process number to release:"
    read process_number

    for frame in ${process_frames["P$process_number"]}; do
        frames[$frame]=0
        echo "Released frame $frame from Process P$process_number"

        # Update block usage
        block_num=$((frame / (TOTAL_MEMORY / (NUM_BLOCKS * PAGE_SIZE))))
        block_usage[$block_num]=$((block_usage[$block_num] - 1))
    done

    unset process_frames["P$process_number"]  # Remove the process from the tracking array
}

# Function to Display Memory State
display_memory_state() {
    echo "Memory State:"
    for ((i=0; i<NUM_FRAMES; i++)); do
        if [ "${frames[$i]}" -eq 0 ]; then
            frame_state="free"
        else
            frame_state="occupied by P${frames[$i]}"
        fi
        echo "Frame $i: $frame_state"
    done
}

while true; do
    echo "1. Set Block Sizes"
    echo "2. Create Process"
    echo "3. Display Memory State"
    echo "4. Release Memory"
    echo "5. Exit"
    read -p "Choose an option: " option

    case $option in
        1) set_block_sizes ;;
        2) create_process ;;
        3) display_memory_state ;;
        4) release_memory ;;
        5) exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done
