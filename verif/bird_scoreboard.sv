class bird_scoreboard;

  virtual bird_if vif;

  mailbox #(bird_fragment) mon2sb_in;
  mailbox #(u8_t)          mon2sb_local;
  mailbox #(bit [31:0])    mon2sb_remote;

  bird_coverage cov;

  // ---------------- predicted output queues ----------------
  u8_t       expected_local[$];
  bit [31:0] expected_remote[$];
  bit [15:0] expected_drop_cnt;
  // ---------------- actual output queues ----------------
  u8_t       actual_local[$];
  bit [31:0] actual_remote[$];

  // ---------------- remote accumulation state ----------------
  bit          remote_active;
  int unsigned active_seq;
  int unsigned active_max_frag;
  int unsigned prev_frag_num;
  bit          out_of_order;
  bit          frag_seen   [1:31];
  u8_t         frag_payload[1:31][$];

  // ---------------- pass/fail bookkeeping ----------------
  int unsigned n_local_checked,  n_local_pass,  n_local_fail;
  int unsigned n_remote_checked, n_remote_pass, n_remote_fail;
  int unsigned n_local_unexpected, n_remote_unexpected;
  int unsigned n_packets_dropped_expected;
  int unsigned n_remote_packets_completed;

  function new(virtual bird_if vif,
                mailbox #(bird_fragment) mon2sb_in,
                mailbox #(u8_t)          mon2sb_local,
                mailbox #(bit [31:0])    mon2sb_remote,
                bird_coverage cov);
    this.vif           = vif;
    this.mon2sb_in     = mon2sb_in;
    this.mon2sb_local  = mon2sb_local;
    this.mon2sb_remote = mon2sb_remote;
    this.cov           = cov;
    expected_drop_cnt  = 16'd0;
    clear_remote_state();
  endfunction

  function void clear_remote_state();
    remote_active   = 0;
    active_seq      = 0;
    active_max_frag = 0;
    prev_frag_num   = 0;
    out_of_order    = 0;
    for (int f = 1; f <= 31; f++) begin
      frag_seen[f] = 0;
      frag_payload[f].delete();
    end
  endfunction

  task run();
    fork
      process_input();
      check_local();
      check_remote();
      monitor_reset();
      monitor_backpressure();
    join_none
  endtask

  // =========================================================
  // Input fragment -> reference model prediction
  // =========================================================
  task process_input();
    bird_fragment f;
    forever begin
      mon2sb_in.get(f);
      predict(f);
    end
  endtask

  task automatic predict(bird_fragment f);
    bit invalid;
    drop_reason_e reason;

    cov.sample_cfg(f);

    invalid = 1'b0;
    reason  = DROP_NONE;

    if (f.rsv_7_1 != 0 || f.rsv_23_21 != 0 || f.rsv_31_29 != 0) begin
      invalid = 1'b1; reason = DROP_RESERVED_BITS;
    end else if (f.payload_len < 1 || f.payload_len > 255) begin
      invalid = 1'b1; reason = DROP_PAYLOAD_LEN_RANGE;
    end else if (f.seq_num == 0) begin
      invalid = 1'b1; reason = DROP_SEQ_NUM_ZERO;
    end else if (f.frag_num == 0) begin
      invalid = 1'b1; reason = DROP_FRAG_NUM_ZERO;
    end

    if (invalid) begin
      drop_packet(reason);
      return;
    end

    if (f.traffic_type == 1'b0) begin
      // ---- LOCAL traffic ----
      if (f.frag_num != 1) begin
        drop_packet(DROP_LOCAL_BAD_FRAG);
      end else begin
        foreach (f.payload[i]) expected_local.push_back(f.payload[i]);
        expected_local.push_back(f.crc[15:8]);
        expected_local.push_back(f.crc[7:0]);
      end
    end else begin
      // ---- REMOTE traffic ----
      if (!remote_active) begin
        start_new_packet(f);
      end else if (f.seq_num == active_seq) begin
        add_fragment(f);
      end else begin
        // Packet boundary: a fragment with a different SEQ_NUM
        // arrives while another packet is being accumulated.
        if (is_active_ready()) begin
          complete_active();
        end else begin
          drop_packet(DROP_MISMATCH_SEQ);
          clear_remote_state();
        end
        if (f.frag_num == 1) start_new_packet(f);
        // else: fragment discarded silently (no separate drop_cnt inc)
      end
    end
  endtask

  function void drop_packet(drop_reason_e reason);
    expected_drop_cnt = expected_drop_cnt + 16'd1;
    n_packets_dropped_expected++;
    cov.sample_drop(reason);
  endfunction

  function void start_new_packet(bird_fragment f);
    clear_remote_state();
    remote_active   = 1;
    active_seq      = f.seq_num;
    active_max_frag = f.frag_num;
    prev_frag_num   = f.frag_num;
    frag_seen[f.frag_num] = 1;
    frag_payload[f.frag_num] = f.payload;
  endfunction

  function void add_fragment(bird_fragment f);
    if (f.frag_num < prev_frag_num) out_of_order = 1;
    prev_frag_num = f.frag_num;

    frag_seen[f.frag_num] = 1;
    frag_payload[f.frag_num] = f.payload;
    if (f.frag_num > active_max_frag) active_max_frag = f.frag_num;
  endfunction

  // True if every fragment 1..active_max_frag has been received, i.e.
  // the active accumulation could be reassembled right now.
  function bit is_active_ready();
    bit ready;
    ready = 1;
    for (int fnum = 1; fnum <= active_max_frag; fnum++) begin
      if (!frag_seen[fnum]) ready = 0;
    end
    return ready;
  endfunction

  // Reassemble the active accumulation (caller must ensure
  // is_active_ready() == 1) and push the expected remote output.
  function void complete_active();
    u8_t merged[$];
    logic [15:0] crc;
    int unsigned frag_count;

    merged.delete();
    frag_count = 0;
    for (int fnum = 1; fnum <= active_max_frag; fnum++) begin
      foreach (frag_payload[fnum][i]) merged.push_back(frag_payload[fnum][i]);
      frag_count++;
    end

    crc = bird_crc16_ccitt(merged);
    bird_pack_bytes_to_words(merged, expected_remote);
    expected_remote.push_back({16'h0000, crc});

    n_remote_packets_completed++;
    cov.sample_remote_complete(frag_count, out_of_order);

    clear_remote_state();
  endfunction

  // Called once at end-of-test (after the input stream has drained):
  // if a remote packet is still accumulating and is complete, flush
  // it as the final reassembled packet (it never saw a boundary
  // fragment to trigger completion).
  function void flush_remote();
    if (remote_active && is_active_ready()) complete_active();
  endfunction

  // =========================================================
  // Output checking
  // =========================================================
  task check_local();
    u8_t act_b;

    forever begin
      mon2sb_local.get(act_b);

      // Do not compare immediately.
      // Local output can appear before the input monitor finishes
      // reconstructing the full fragment and generating expected data.
      actual_local.push_back(act_b);
    end
  endtask

task check_remote();
  bit [31:0] act_w;

  forever begin
    mon2sb_remote.get(act_w);

    // Do not compare immediately.
    // The final remote packet may be predicted only during flush_remote()
    // at end-of-test.
    actual_remote.push_back(act_w);
  end
endtask

  // =========================================================
  // Reset handling (section 9): clear predictor + coverage tag
  // =========================================================
  task monitor_reset();
    bit prev_rst_n;
    prev_rst_n = 1'b1;
    forever begin
      @(vif.monitor_cb);
      if (prev_rst_n && !vif.rst_n) begin
        // rising-to-falling: reset just asserted
        int unsigned phase;
        if (remote_active) phase = 2;
        else if (vif.in_vld) phase = 1;
        else phase = 0;
        cov.sample_reset(phase);

        expected_local.delete();
        expected_remote.delete();
        actual_local.delete();
		actual_remote.delete();
        clear_remote_state();
        expected_drop_cnt = 16'd0;
      end
      prev_rst_n = vif.rst_n;
    end
  endtask

  // =========================================================
  // Backpressure coverage (local_rdy/remote_rdy deasserted while
  // *_vld==1)
  // =========================================================
  task monitor_backpressure();
    forever begin
      @(vif.monitor_cb);
      cov.sample_backpressure(
        vif.monitor_cb.local_vld  && !vif.monitor_cb.local_rdy,
        vif.monitor_cb.remote_vld && !vif.monitor_cb.remote_rdy
      );
    end
  endtask
  function void compare_local_streams();
  u8_t exp_b;
  u8_t act_b;

  while (expected_local.size() != 0 && actual_local.size() != 0) begin
    exp_b = expected_local.pop_front();
    act_b = actual_local.pop_front();

    n_local_checked++;

    if (exp_b !== act_b) begin
      n_local_fail++;
      $error("[SCOREBOARD] LOCAL byte mismatch: expected 0x%02h got 0x%02h",
             exp_b, act_b);
    end else begin
      n_local_pass++;
    end
  end

  while (actual_local.size() != 0) begin
    act_b = actual_local.pop_front();

    n_local_checked++;
    n_local_unexpected++;
    n_local_fail++;

    $error("[SCOREBOARD] Unexpected LOCAL byte 0x%02h (no data expected)",
           act_b);
  end

  while (expected_local.size() != 0) begin
    exp_b = expected_local.pop_front();

    n_local_fail++;

    $error("[SCOREBOARD] Missing LOCAL byte: expected 0x%02h but DUT did not output it",
           exp_b);
  end
endfunction


function void compare_remote_streams();
  bit [31:0] exp_w;
  bit [31:0] act_w;

  while (expected_remote.size() != 0 && actual_remote.size() != 0) begin
    exp_w = expected_remote.pop_front();
    act_w = actual_remote.pop_front();

    n_remote_checked++;

    if (exp_w !== act_w) begin
      n_remote_fail++;
      $error("[SCOREBOARD] REMOTE word mismatch: expected 0x%08h got 0x%08h",
             exp_w, act_w);
    end else begin
      n_remote_pass++;
    end
  end

  while (actual_remote.size() != 0) begin
    act_w = actual_remote.pop_front();

    n_remote_checked++;
    n_remote_unexpected++;
    n_remote_fail++;

    $error("[SCOREBOARD] Unexpected REMOTE word 0x%08h (no data expected)",
           act_w);
  end

  while (expected_remote.size() != 0) begin
    exp_w = expected_remote.pop_front();

    n_remote_fail++;

    $error("[SCOREBOARD] Missing REMOTE word: expected 0x%08h but DUT did not output it",
           exp_w);
  end
endfunction

  // =========================================================
  // End-of-test report
  // =========================================================
  function void report();
    compare_local_streams();
	compare_remote_streams();
    $display("===========================================================");
    $display("BIRD SCOREBOARD REPORT");
    $display("  LOCAL  : checked=%0d pass=%0d fail=%0d unexpected=%0d leftover_expected=%0d",
              n_local_checked, n_local_pass, n_local_fail, n_local_unexpected, expected_local.size());
    $display("  REMOTE : checked=%0d pass=%0d fail=%0d unexpected=%0d leftover_expected=%0d",
              n_remote_checked, n_remote_pass, n_remote_fail, n_remote_unexpected, expected_remote.size());
    $display("  Remote packets completed (predicted) : %0d", n_remote_packets_completed);
    $display("  Packets dropped (predicted)          : %0d", n_packets_dropped_expected);
    $display("  drop_cnt expected = %0d  (DUT) actual = %0d", expected_drop_cnt, vif.drop_cnt);
    if (expected_drop_cnt !== vif.drop_cnt)
      $error("[SCOREBOARD] drop_cnt mismatch: expected=%0d actual=%0d", expected_drop_cnt, vif.drop_cnt);

    if (n_local_fail == 0 && n_remote_fail == 0 &&
        expected_local.size() == 0 && expected_remote.size() == 0 &&
        expected_drop_cnt === vif.drop_cnt)
      $display("  RESULT: PASS");
    else
      $display("  RESULT: FAIL");
    $display("===========================================================");
  endfunction

endclass