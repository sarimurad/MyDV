class test_local_basic extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_local_basic"; endfunction
  task run_test();
    seq_local_basic seq = new();
    env.run_seq(seq);
  endtask
endclass

class test_local_seqnum_variation extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_local_seqnum_variation"; endfunction
  task run_test();
    seq_local_seqnum_variation seq = new();
    env.run_seq(seq);
  endtask
endclass


// TC: local traffic drop conditions (bad FRAG_NUM, reserved bits, PAYLOAD_LEN==0)
class test_local_invalid extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_local_invalid"; endfunction
  task run_test();
    seq_local_invalid seq = new();
    env.run_seq(seq);
  endtask
endclass


// TC: remote traffic, single-fragment packet (N=1)
class test_remote_single_frag extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_remote_single_frag"; endfunction
  task run_test();
    seq_remote_single_frag seq = new("seq_remote_single_frag", 3, 12);
    env.run_seq(seq);
  endtask
endclass


// TC: remote traffic, multi-fragment packet sent in order
class test_remote_multi_inorder extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_remote_multi_inorder"; endfunction
  task run_test();
    seq_remote_multi_inorder seq = new("seq_remote_multi_inorder", 4, 5);
    env.run_seq(seq);
  endtask
endclass


// TC: remote traffic, fragments arrive out of order
class test_remote_out_of_order extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_remote_out_of_order"; endfunction
  task run_test();
    seq_remote_out_of_order seq = new("seq_remote_out_of_order", 6, 4);
    env.run_seq(seq);
  endtask
endclass


// TC: mismatched SEQ_NUM while a packet is being accumulated
class test_remote_mismatched_seq extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_remote_mismatched_seq"; endfunction
  task run_test();
    seq_remote_mismatched_seq seq = new();
    env.run_seq(seq);
  endtask
endclass


// TC: required fragment missing -> packet dropped when superseded
class test_remote_missing_fragment extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_remote_missing_fragment"; endfunction
  task run_test();
    seq_remote_missing_fragment seq = new();
    env.run_seq(seq);
  endtask
endclass


// TC: reserved cfg bits non-zero (local and remote)
class test_reserved_bits_invalid extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_reserved_bits_invalid"; endfunction
  task run_test();
    seq_reserved_bits_invalid seq = new();
    env.run_seq(seq);
  endtask
endclass


// TC: SEQ_NUM==0 and FRAG_NUM==0 (both "0 is invalid" per section 8.1)
class test_zero_fields_invalid extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_zero_fields_invalid"; endfunction
  task run_test();
    seq_zero_fields_invalid seq = new();
    env.run_seq(seq);
  endtask
endclass


// TC: PAYLOAD_LEN boundary values (0 = illegal, 255 = max legal)
class test_payload_len_boundary extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_payload_len_boundary"; endfunction
  task run_test();
    seq_payload_len_boundary seq = new();
    env.run_seq(seq);
  endtask
endclass


// TC: interleaved local/remote traffic
class test_back_to_back_mixed extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_back_to_back_mixed"; endfunction
  task run_test();
    seq_back_to_back_mixed seq = new();
    env.run_seq(seq);
  endtask
endclass


// TC: drop_cnt increments and wraps around modulo 2^16
// NOTE: default 65540 iterations exercises the full wrap. For quick
// smoke runs, construct seq_drop_cnt_wrap with a smaller num_iters.
class test_drop_cnt_wrap extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_drop_cnt_wrap"; endfunction
  task run_test();
    seq_drop_cnt_wrap seq = new("seq_drop_cnt_wrap", 65540);
    env.run_seq(seq);
  endtask
endclass


// TC: reset asserted mid remote-accumulation, then normal operation resumes
class test_reset_midpacket extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_reset_midpacket"; endfunction
  task run_test();
    seq_remote_partial      seq1 = new("seq_remote_partial", 9);
    seq_remote_single_frag  seq2 = new("seq_remote_single_frag", 1, 8);

    env.run_seq(seq1);
    env.wait_idle(2);

    // Reset asserted while a remote packet (seq=9) is incomplete.
    do_reset();

    env.run_seq(seq2);
  endtask
endclass


// TC: backpressure on the local output interface (local_rdy toggling)
class test_backpressure_local extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_backpressure_local"; endfunction

  task toggle_local_rdy();
  forever begin
    @(negedge vif.clk);
    vif.local_rdy = 1'b0;
    repeat (2) @(posedge vif.clk);

    @(negedge vif.clk);
    vif.local_rdy = 1'b1;
    repeat (2) @(posedge vif.clk);
  end
endtask

  task run_test();
    seq_local_basic seq = new();
    fork
      toggle_local_rdy();
      begin
        env.run_seq(seq);
        env.wait_idle();
      end
    join_any
    disable fork;
    vif.driver_cb.local_rdy <= 1'b1;
  endtask
endclass


// TC: backpressure on the remote output interface (remote_rdy toggling)
class test_backpressure_remote extends bird_test_base;
  function new(virtual bird_if vif); super.new(vif); endfunction
  virtual function string get_name(); return "test_backpressure_remote"; endfunction

task toggle_remote_rdy();
  forever begin
    @(negedge vif.clk);
    vif.remote_rdy = 1'b0;
    repeat (2) @(posedge vif.clk);

    @(negedge vif.clk);
    vif.remote_rdy = 1'b1;
    repeat (2) @(posedge vif.clk);
  end
endtask

  task run_test();
    seq_remote_multi_inorder seq = new("seq_remote_multi_inorder", 8, 4);
    fork
      toggle_remote_rdy();
      begin
        env.run_seq(seq);
        env.wait_idle();
      end
    join_any
    disable fork;
    vif.driver_cb.remote_rdy <= 1'b1;
  endtask
endclass


class test_coverage_full extends bird_test_base;

  function new(virtual bird_if vif);
    super.new(vif);
  endfunction

  virtual function string get_name();
    return "test_coverage_full";
  endfunction

  task toggle_local_rdy();
    forever begin
      @(negedge vif.clk);
      vif.local_rdy = 1'b0;
      repeat (2) @(posedge vif.clk);

      @(negedge vif.clk);
      vif.local_rdy = 1'b1;
      repeat (2) @(posedge vif.clk);
    end
  endtask

  task toggle_remote_rdy();
    forever begin
      @(negedge vif.clk);
      vif.remote_rdy = 1'b0;
      repeat (2) @(posedge vif.clk);

      @(negedge vif.clk);
      vif.remote_rdy = 1'b1;
      repeat (2) @(posedge vif.clk);
    end
  endtask

  task run_test();

    fork
      toggle_local_rdy();
      toggle_remote_rdy();

      begin
        // -------------------------
        // Reset coverage
        // -------------------------

        // Reset while idle
        do_reset();

        // Reset during local/input activity
        begin
          seq_local_basic seq = new();
          env.run_seq(seq);
          repeat (5) @(posedge vif.clk);
          do_reset_during_activity();
          env.wait_idle(20);
        end

        // Reset during remote accumulation
        begin
          seq_remote_partial seq = new("seq_remote_partial", 9);
          env.run_seq(seq);
          env.wait_idle(5);
          do_reset_during_activity();
          env.wait_idle(20);
        end

        // -------------------------
        // CFG field coverage
        // -------------------------
        begin
          seq_local_basic seq = new();
          env.run_seq(seq);
          env.wait_idle(20);
        end

        begin
          seq_local_seqnum_variation seq = new();
          env.run_seq(seq);
          env.wait_idle(20);
        end

        begin
          seq_payload_len_boundary seq = new();
          env.run_seq(seq);
          env.wait_idle(20);
        end

        // -------------------------
        // Drop reason coverage
        // -------------------------
        begin
          seq_local_invalid seq = new();
          env.run_seq(seq);
          env.wait_idle(20);
        end

        begin
          seq_reserved_bits_invalid seq = new();
          env.run_seq(seq);
          env.wait_idle(20);
        end

        begin
          seq_zero_fields_invalid seq = new();
          env.run_seq(seq);
          env.wait_idle(20);
        end

        begin
          seq_remote_mismatched_seq seq = new();
          env.run_seq(seq);
          env.wait_idle(20);
        end

        begin
          seq_remote_missing_fragment seq = new();
          env.run_seq(seq);
          env.wait_idle(20);
        end

        // -------------------------
        // Remote reassembly coverage
        // -------------------------

        // 1 fragment
        begin
          seq_remote_single_frag seq = new("remote_1frag", 3, 12);
          env.run_seq(seq);
          env.wait_idle(20);
        end

        // 2 fragments
        begin
          seq_remote_multi_inorder seq = new("remote_2frag", 4, 2);
          env.run_seq(seq);
          env.wait_idle(20);
        end

        // 4 fragments: hits few bin
        begin
          seq_remote_multi_inorder seq = new("remote_4frag", 5, 4);
          env.run_seq(seq);
          env.wait_idle(20);
        end

        // 8 fragments: hits many bin
        begin
          seq_remote_multi_inorder seq = new("remote_8frag", 6, 8);
          env.run_seq(seq);
          env.wait_idle(20);
        end

        // 12 fragments: hits lots bin
        begin
          seq_remote_multi_inorder seq = new("remote_12frag", 7, 12);
          env.run_seq(seq);
          env.wait_idle(20);
        end

        // Out-of-order fragments
        begin
          seq_remote_out_of_order seq = new("remote_ooo", 8, 4);
          env.run_seq(seq);
          env.wait_idle(20);
        end

        // Mixed local and remote
        begin
          seq_back_to_back_mixed seq = new();
          env.run_seq(seq);
          env.wait_idle(20);
        end
      end

    join_any

    disable fork;

    @(negedge vif.clk);
    vif.local_rdy  = 1'b1;
    vif.remote_rdy = 1'b1;

  endtask

endclass
