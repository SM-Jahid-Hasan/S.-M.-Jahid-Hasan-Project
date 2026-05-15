#!/bin/bash


max_score=${1:-100}
max_student_id=${2:-5}

output_file="output.csv"
base_student_id=1805120

# Create a secure temporary directory to store student outputs
temp_dir=$(mktemp -d)

# Arrays and Hash Maps to track state
declare -a valid_students
declare -A scores
declare -A copied

# Initialize the CSV file with headers
echo "student_id,score" > "$output_file"


# 2-5. Execution and Grading Loop
for (( i=1; i<=max_student_id; i++ )); do
    student_id=$((base_student_id + i))
    student_dir="Submissions/${student_id}"
    student_script="${student_dir}/${student_id}.sh"

    if [[ -d "$student_dir" && -f "$student_script" ]]; then
        valid_students+=("$student_id")

        cd "$student_dir" || exit

        bash "${student_id}.sh" > "${temp_dir}/${student_id}_out.txt" 2>/dev/null
        cd - > /dev/null || exit

        mismatches=$(diff -w AcceptedOutput.txt "${temp_dir}/${student_id}_out.txt" | grep -E '^[<>]' | wc -l)

        # Calculate score (deduct 5 points per mismatch)
        penalty=$(( mismatches * 5 ))
        score=$(( max_score - penalty ))

        # Ensure the score does not drop below 0
        if (( score < 0 )); then
            score=0
        fi

        scores["$student_id"]=$score
    else
        # Missing directory or script means 0 points
        scores["$student_id"]=0
    fi
done

# Copy-Checker (Plagiarism Detection)
# Compare every valid script against every other valid script
num_valid=${#valid_students[@]}

for (( i=0; i<num_valid; i++ )); do
    id1=${valid_students[$i]}
    for (( j=i+1; j<num_valid; j++ )); do
        id2=${valid_students[$j]}

        # Compare ignoring trailing whitespaces (-Z) and blank lines (-B)
        # If diff is completely silent (exit code 0), they are identical
        if diff -Z -B "Submissions/${id1}/${id1}.sh" "Submissions/${id2}/${id2}.sh" > /dev/null 2>&1; then
            copied["$id1"]=1
            copied["$id2"]=1
        fi
    done
done

# Final Output Generation
for (( i=1; i<=max_student_id; i++ )); do
    student_id=$((base_student_id + i))
    final_score=${scores["$student_id"]}

    # If caught in the copy-checker, the score becomes negative
    if [[ "${copied["$student_id"]}" == "1" && "$final_score" -gt 0 ]]; then
        final_score=$(( -final_score ))
    fi

    # Append to CSV
    echo "${student_id},${final_score}" >> "$output_file"
done

# 7. Cleanup
# Remove the temporary directory and all files inside it
rm -rf "$temp_dir"

echo "Evaluation complete! Results saved to $output_file"
