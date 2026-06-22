// ============================================================
// bird_coverage.sv
// Functional coverage for the BIRD verification environment.
//  - cg_cfg     : cfg field value coverage (traffic type,
//                 PAYLOAD_LEN/FRAG_NUM/SEQ_NUM ranges)
//  - cg_drop    : each of the spec section 8.1 drop reasons
//  - cg_remote  : reassembled remote packet fragment counts and
//                 in-order vs out-of-order arrival
//  - cg_bp      : backpressure on local/remote output interfaces
//  - cg_reset   : reset asserted while idle / mid-fragment /
//                 mid remote-accumulation
// `included inside package bird_pkg
// ============================================================

class bird_coverage;

  // sampled value holders
  bit          s_traffic_type;
  int unsigned s_payload_len;
  int unsigned s_frag_num;
  int unsigned s_seq_num;

  drop_reason_e s_drop_reason;

  int unsigned s_remote_frag_count;
  bit          s_remote_out_of_order;

  bit          s_local_bp;
  bit          s_remote_bp;

  int unsigned s_reset_phase; // 0=idle, 1=mid-fragment, 2=mid-remote-accum

  covergroup cg_cfg_cg;
    cp_ttype: coverpoint s_traffic_type;
    cp_plen: coverpoint s_payload_len {
      bins b_zero  = {0};
      bins b_one   = {1};
      bins b_small = {[2:7]};
      bins b_mid   = {[8:127]};
      bins b_large = {[128:254]};
      bins b_max   = {255};
    }
    cp_frag: coverpoint s_frag_num {
      bins f_zero = {0};
      bins f_one  = {1};
      bins f_mid  = {[2:30]};
      bins f_31   = {31};
    }
    cp_seq: coverpoint s_seq_num {
      bins s_zero = {0};
      bins s_one  = {1};
      bins s_mid  = {[2:30]};
      bins s_31   = {31};
    }
    cx_ttype_plen: cross cp_ttype, cp_plen;
  endgroup

  covergroup cg_drop_cg;
    cp_reason: coverpoint s_drop_reason {
      bins reserved_bits = {DROP_RESERVED_BITS};
      bins plen_range    = {DROP_PAYLOAD_LEN_RANGE};
      bins seq_zero      = {DROP_SEQ_NUM_ZERO};
      bins frag_zero     = {DROP_FRAG_NUM_ZERO};
      bins local_bad_frag= {DROP_LOCAL_BAD_FRAG};
      bins mismatch_seq  = {DROP_MISMATCH_SEQ};
    }
  endgroup

  covergroup cg_remote_cg;
    cp_fragcnt: coverpoint s_remote_frag_count {
      bins one  = {1};
      bins two  = {2};
      bins few  = {[3:5]};
      bins many = {[6:10]};
      bins lots = {[11:31]};
    }
    cp_order: coverpoint s_remote_out_of_order;
  endgroup

  covergroup cg_bp_cg;
    cp_local_bp:  coverpoint s_local_bp;
    cp_remote_bp: coverpoint s_remote_bp;
  endgroup

  covergroup cg_reset_cg;
    cp_phase: coverpoint s_reset_phase {
      bins idle       = {0};
      bins mid_frag   = {1};
      bins mid_remote = {2};
    }
  endgroup

  function new();
    cg_cfg_cg    = new();
    cg_drop_cg   = new();
    cg_remote_cg = new();
    cg_bp_cg     = new();
    cg_reset_cg  = new();
  endfunction

  function void sample_cfg(bird_fragment f);
    s_traffic_type = f.traffic_type;
    s_payload_len  = f.payload_len;
    s_frag_num     = f.frag_num;
    s_seq_num      = f.seq_num;
    cg_cfg_cg.sample();
  endfunction

  function void sample_drop(drop_reason_e reason);
    s_drop_reason = reason;
    cg_drop_cg.sample();
  endfunction

  function void sample_remote_complete(int unsigned frag_count, bit out_of_order);
    s_remote_frag_count   = frag_count;
    s_remote_out_of_order = out_of_order;
    cg_remote_cg.sample();
  endfunction

  function void sample_backpressure(bit local_bp, bit remote_bp);
    s_local_bp  = local_bp;
    s_remote_bp = remote_bp;
    cg_bp_cg.sample();
  endfunction

  function void sample_reset(int unsigned phase);
    s_reset_phase = phase;
    cg_reset_cg.sample();
  endfunction

  function void report();
    $display("---------------------------------------------------------");
    $display("FUNCTIONAL COVERAGE SUMMARY");
    $display("  cfg fields        : %0.2f %%", cg_cfg_cg.get_coverage());
    $display("  drop reasons      : %0.2f %%", cg_drop_cg.get_coverage());
    $display("  remote reassembly : %0.2f %%", cg_remote_cg.get_coverage());
    $display("  backpressure      : %0.2f %%", cg_bp_cg.get_coverage());
    $display("  reset scenarios   : %0.2f %%", cg_reset_cg.get_coverage());
    $display("---------------------------------------------------------");
  endfunction

endclass
