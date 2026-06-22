#!/bin/bash

tests=(
test_local_basic
test_local_seqnum_variation
test_local_invalid
test_remote_single_frag
test_remote_multi_inorder
test_remote_out_of_order
test_remote_mismatched_seq
test_remote_missing_fragment
test_reserved_bits_invalid
test_zero_fields_invalid
test_payload_len_boundary
test_back_to_back_mixed
test_drop_cnt_wrap
test_reset_midpacket
test_backpressure_local
test_backpressure_remote
test_coverage_full
)

for t in "${tests[@]}"
do
    echo "Running $t"

    ./simv \
        +TEST_NAME=$t \
        -cm line+cond+tgl+branch \
        -cm_name $t \
        -cm_dir coverage/$t
done

# ---- merge all test databases into ONE report ----
echo "Merging coverage..."
dirs=()
for t in "${tests[@]}"; do
    dirs+=(-dir coverage/$t)
done

urg -full64 "${dirs[@]}" \
    -report coverage/merged_report \
    -format both

echo "Done. Open coverage/merged_report/dashboard.html"
