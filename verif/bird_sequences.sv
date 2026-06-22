class seq_local_basic extends bird_sequence_base;
  function new(string name = "seq_local_basic");
    super.new(name);
  endfunction

  task body(bird_sequencer sqr);
    int plens[$] = {1, 7, 16, 128, 255};
    foreach (plens[i]) begin
      bird_fragment f = new();
      void'(f.randomize());
      f.traffic_type = 1'b0;
      f.frag_num      = 1;
      f.seq_num       = 1;
      f.payload_len   = plens[i];
      f.gap_cycles    = i % 2;
      f.build_payload(8'h10 + i[7:0]);
      send(sqr, f);
    end
  endtask
endclass


// ------------------------------------------------------------
// Local traffic with SEQ_NUM != 1 (FRAG_NUM still 1, cfg
// otherwise legal). Per spec section 6, SEQ_NUM has no
// functional impact on local routing -> these should be
// forwarded. The DUT additionally requires SEQ_NUM==1 for
// local traffic, so this sequence is expected to surface a
// DUT-vs-spec deviation (see docs/README.md).
// ------------------------------------------------------------
class seq_local_seqnum_variation extends bird_sequence_base;
  function new(string name = "seq_local_seqnum_variation");
    super.new(name);
  endfunction

  task body(bird_sequencer sqr);
    int seqs[$]  = {2, 3, 5, 31};
    int plens[$] = {4, 8, 12, 20};
    foreach (seqs[i]) begin
      bird_fragment f = new();
      void'(f.randomize());
      f.traffic_type = 1'b0;
      f.frag_num      = 1;
      f.seq_num       = seqs[i];
      f.payload_len   = plens[i];
      f.gap_cycles    = 1;
      f.build_payload(8'h40 + i[7:0]);
      send(sqr, f);
    end
  endtask
endclass


// ------------------------------------------------------------
// Local traffic that violates the silent-drop rules:
//  1) FRAG_NUM != 1               (section 6 + 8.1)
//  2) Non-zero reserved bits      (section 8.1)
//  3) PAYLOAD_LEN == 0             (section 8.1)
// All three are expected to be silently dropped (drop_cnt++).
// ------------------------------------------------------------
class seq_local_invalid extends bird_sequence_base;
  function new(string name = "seq_local_invalid");
    super.new(name);
  endfunction

  task body(bird_sequencer sqr);
    bird_fragment f;

    // 1) FRAG_NUM != 1
    f = new();
    void'(f.randomize());
    f.traffic_type = 1'b0;
    f.frag_num      = 2;
    f.seq_num       = 1;
    f.payload_len   = 10;
    f.gap_cycles    = 1;
    f.build_payload(8'h60);
    send(sqr, f);

    // 2) Reserved bits non-zero
    f = new();
    void'(f.randomize());
    f.traffic_type = 1'b0;
    f.frag_num      = 1;
    f.seq_num       = 1;
    f.payload_len   = 6;
    f.rsv_7_1       = 7'b0000001;
    f.gap_cycles    = 1;
    f.build_payload(8'h70);
    send(sqr, f);

    // 3) PAYLOAD_LEN == 0
    f = new();
    void'(f.randomize());
    f.traffic_type = 1'b0;
    f.frag_num      = 1;
    f.seq_num       = 1;
    f.payload_len   = 0;
    f.gap_cycles    = 1;
    f.build_payload(8'h80);
    send(sqr, f);
  endtask
endclass


// ------------------------------------------------------------
// Remote traffic, single-fragment packet (N=1). Completes and
// is reassembled (trivially) immediately.
// ------------------------------------------------------------
class seq_remote_single_frag extends bird_sequence_base;
  int unsigned seq_num;
  int unsigned payload_len;

  function new(string name = "seq_remote_single_frag",
                int unsigned seq_num = 1, int unsigned payload_len = 10);
    super.new(name);
    this.seq_num     = seq_num;
    this.payload_len = payload_len;
  endfunction

  task body(bird_sequencer sqr);
    bird_fragment f = new();
    void'(f.randomize());
    f.traffic_type = 1'b1;
    f.frag_num      = 1;
    f.seq_num       = seq_num;
    f.payload_len   = payload_len;
    f.gap_cycles    = 1;
    f.build_payload(8'hA0);
    send(sqr, f);
  endtask
endclass


// ------------------------------------------------------------
// Remote traffic, N fragments sent in order (FRAG_NUM 1..N),
// all sharing the same SEQ_NUM. Verifies accumulation,
// reassembly and CRC16 regeneration.
// ------------------------------------------------------------
class seq_remote_multi_inorder extends bird_sequence_base;
  int unsigned seq_num;
  int unsigned num_frags;

  function new(string name = "seq_remote_multi_inorder",
                int unsigned seq_num = 1, int unsigned num_frags = 4);
    super.new(name);
    this.seq_num   = seq_num;
    this.num_frags = num_frags;
  endfunction

  task body(bird_sequencer sqr);
    for (int n = 1; n <= num_frags; n++) begin
      bird_fragment f = new();
      void'(f.randomize());
      f.traffic_type = 1'b1;
      f.frag_num      = n;
      f.seq_num       = seq_num;
      f.payload_len   = 2 + n;
      f.gap_cycles    = (n == 1) ? 1 : 0;
      f.build_payload(8'hB0 + n);
      send(sqr, f);
    end
  endtask
endclass


// ------------------------------------------------------------
// Same as above but fragments arrive out of order. Verifies
// reordering based on FRAG_NUM before reassembly.
// ------------------------------------------------------------
class seq_remote_out_of_order extends bird_sequence_base;
  int unsigned seq_num;
  int unsigned num_frags;

  function new(string name = "seq_remote_out_of_order",
                int unsigned seq_num = 2, int unsigned num_frags = 4);
    super.new(name);
    this.seq_num   = seq_num;
    this.num_frags = num_frags;
  endfunction

  task body(bird_sequencer sqr);
    // simple deterministic shuffle: N, 1, N-1, 2, N-2, 3, ...
    int order[$];
    int lo, hi;
    lo = 1; hi = num_frags;
    while (lo <= hi) begin
      order.push_back(hi);
      if (lo != hi) order.push_back(lo);
      lo++; hi--;
    end

    foreach (order[idx]) begin
      int n = order[idx];
      bird_fragment f = new();
      void'(f.randomize());
      f.traffic_type = 1'b1;
      f.frag_num      = n;
      f.seq_num       = seq_num;
      f.payload_len   = 2 + n;
      f.gap_cycles    = (idx == 0) ? 1 : 0;
      f.build_payload(8'hC0 + n);
      send(sqr, f);
    end
  endtask
endclass


// ------------------------------------------------------------
// Mismatched SEQ_NUM while a packet is being accumulated:
//  - seq=1: frag=1, frag=3 (frag 2 missing -> stays incomplete)
//  - seq=2: frag=1 arrives -> seq=1 (incomplete) is dropped,
//           FRAG_NUM==1 starts a new accumulation for seq=2
//  - seq=2: frag=2 completes the packet -> remote output produced
// Expected: 1 drop (seq=1) + 1 remote packet (seq=2, 2 frags).
// ------------------------------------------------------------
class seq_remote_mismatched_seq extends bird_sequence_base;
  function new(string name = "seq_remote_mismatched_seq");
    super.new(name);
  endfunction

  task body(bird_sequencer sqr);
    bird_fragment f;

    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 1; f.frag_num = 1; f.payload_len = 4;
    f.gap_cycles = 1; f.build_payload(8'hD1);
    send(sqr, f);

    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 1; f.frag_num = 3; f.payload_len = 4;
    f.gap_cycles = 0; f.build_payload(8'hD3);
    send(sqr, f);

    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 2; f.frag_num = 1; f.payload_len = 4;
    f.gap_cycles = 0; f.build_payload(8'hE1);
    send(sqr, f);

    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 2; f.frag_num = 2; f.payload_len = 4;
    f.gap_cycles = 0; f.build_payload(8'hE2);
    send(sqr, f);
  endtask
endclass


// ------------------------------------------------------------
// Missing fragment scenario:
//  - seq=5: frag=1, frag=2, frag=4 (frag 3 missing -> incomplete)
//  - seq=7: frag=1 arrives (FRAG_NUM==1 while seq=5 incomplete)
//           -> seq=5 dropped, seq=7 starts and immediately
//           completes (single-fragment packet, N=1)
// Expected: 1 drop (seq=5) + 1 remote packet (seq=7, 1 frag).
// ------------------------------------------------------------
class seq_remote_missing_fragment extends bird_sequence_base;
  function new(string name = "seq_remote_missing_fragment");
    super.new(name);
  endfunction

  task body(bird_sequencer sqr);
    bird_fragment f;

    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 5; f.frag_num = 1; f.payload_len = 4;
    f.gap_cycles = 1; f.build_payload(8'hF1);
    send(sqr, f);

    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 5; f.frag_num = 2; f.payload_len = 4;
    f.gap_cycles = 0; f.build_payload(8'hF2);
    send(sqr, f);

    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 5; f.frag_num = 4; f.payload_len = 4;
    f.gap_cycles = 0; f.build_payload(8'hF4);
    send(sqr, f);

    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 7; f.frag_num = 1; f.payload_len = 5;
    f.gap_cycles = 0; f.build_payload(8'h11);
    send(sqr, f);
  endtask
endclass


// ------------------------------------------------------------
// Reserved-bit groups non-zero, on both traffic types.
// All three fragments are expected to be silently dropped.
// ------------------------------------------------------------
class seq_reserved_bits_invalid extends bird_sequence_base;
  function new(string name = "seq_reserved_bits_invalid");
    super.new(name);
  endfunction

  task body(bird_sequencer sqr);
    bird_fragment f;

    // remote, cfg[23:21] != 0
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 1; f.frag_num = 1; f.payload_len = 5;
    f.rsv_23_21 = 3'b010;
    f.gap_cycles = 1; f.build_payload(8'h21);
    send(sqr, f);

    // remote, cfg[31:29] != 0
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 2; f.frag_num = 1; f.payload_len = 5;
    f.rsv_31_29 = 3'b100;
    f.gap_cycles = 1; f.build_payload(8'h22);
    send(sqr, f);

    // local, cfg[7:1] != 0
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b0; f.seq_num = 1; f.frag_num = 1; f.payload_len = 5;
    f.rsv_7_1 = 7'b1000000;
    f.gap_cycles = 1; f.build_payload(8'h23);
    send(sqr, f);
  endtask
endclass


// ------------------------------------------------------------
// PAYLOAD_LEN boundary values:
//  - 0   -> illegal (outside 1..255) -> drop
//  - 255 -> legal maximum, single remote fragment, completes
// ------------------------------------------------------------
class seq_payload_len_boundary extends bird_sequence_base;
  function new(string name = "seq_payload_len_boundary");
    super.new(name);
  endfunction

  task body(bird_sequencer sqr);
    bird_fragment f;

    // PAYLOAD_LEN == 0 (remote, otherwise legal)
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 1; f.frag_num = 1;
    f.payload_len = 0;
    f.gap_cycles = 1; f.build_payload(8'h30);
    send(sqr, f);

    // PAYLOAD_LEN == 255 (remote, single fragment, max size)
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 2; f.frag_num = 1;
    f.payload_len = 255;
    f.gap_cycles = 1; f.build_payload(8'h31);
    send(sqr, f);
  endtask
endclass


// ------------------------------------------------------------
// SEQ_NUM == 0 and FRAG_NUM == 0 (section 8.1: both "0 is
// invalid" regardless of traffic type) -> dropped.
// ------------------------------------------------------------
class seq_zero_fields_invalid extends bird_sequence_base;
  function new(string name = "seq_zero_fields_invalid");
    super.new(name);
  endfunction

  task body(bird_sequencer sqr);
    bird_fragment f;

    // SEQ_NUM == 0 (remote, otherwise legal)
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 0; f.frag_num = 5; f.payload_len = 4;
    f.gap_cycles = 1; f.build_payload(8'h90);
    send(sqr, f);

    // FRAG_NUM == 0 (remote, otherwise legal)
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 5; f.frag_num = 0; f.payload_len = 4;
    f.gap_cycles = 1; f.build_payload(8'h91);
    send(sqr, f);
  endtask
endclass


// ------------------------------------------------------------
// Interleaved local/remote traffic stress sequence.
// ------------------------------------------------------------
class seq_back_to_back_mixed extends bird_sequence_base;
  function new(string name = "seq_back_to_back_mixed");
    super.new(name);
  endfunction

  task body(bird_sequencer sqr);
    bird_fragment f;

    // local
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b0; f.seq_num = 1; f.frag_num = 1; f.payload_len = 4;
    f.gap_cycles = 0; f.build_payload(8'h50);
    send(sqr, f);

    // remote single-frag (completes immediately)
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 10; f.frag_num = 1; f.payload_len = 6;
    f.gap_cycles = 0; f.build_payload(8'h51);
    send(sqr, f);

    // local
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b0; f.seq_num = 1; f.frag_num = 1; f.payload_len = 3;
    f.gap_cycles = 0; f.build_payload(8'h52);
    send(sqr, f);

    // remote 2-fragment packet
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 11; f.frag_num = 1; f.payload_len = 4;
    f.gap_cycles = 0; f.build_payload(8'h53);
    send(sqr, f);

    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = 11; f.frag_num = 2; f.payload_len = 4;
    f.gap_cycles = 0; f.build_payload(8'h54);
    send(sqr, f);

    // local
    f = new(); void'(f.randomize());
    f.traffic_type = 1'b0; f.seq_num = 1; f.frag_num = 1; f.payload_len = 8;
    f.gap_cycles = 0; f.build_payload(8'h55);
    send(sqr, f);
  endtask
endclass


// ------------------------------------------------------------
// Repeated invalid local fragments (FRAG_NUM!=1, PAYLOAD_LEN=1
// -> minimal 3-byte fragments) to exercise drop_cnt incrementing
// and wrapping around modulo 2^16 (section 8.2).
// ------------------------------------------------------------
class seq_drop_cnt_wrap extends bird_sequence_base;
  int unsigned num_iters;

  function new(string name = "seq_drop_cnt_wrap", int unsigned num_iters = 65540);
    super.new(name);
    this.num_iters = num_iters;
  endfunction

  task body(bird_sequencer sqr);
    for (int unsigned i = 0; i < num_iters; i++) begin
      bird_fragment f = new();
      void'(f.randomize());
      f.traffic_type = 1'b0;
      f.frag_num      = 2;   // invalid for local -> drop
      f.seq_num       = 1;
      f.payload_len   = 1;
      f.gap_cycles    = 0;
      f.build_payload(8'hAA);
      send(sqr, f);
    end
  endtask
endclass


// ------------------------------------------------------------
// Sends two fragments of a remote packet (incomplete) so a test
// can assert reset mid-accumulation. Followed by a clean valid
// remote packet to verify normal operation resumes.
// ------------------------------------------------------------
class seq_remote_partial extends bird_sequence_base;
  int unsigned seq_num;

  function new(string name = "seq_remote_partial", int unsigned seq_num = 9);
    super.new(name);
    this.seq_num = seq_num;
  endfunction

  task body(bird_sequencer sqr);
    bird_fragment f;

    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = seq_num; f.frag_num = 1; f.payload_len = 4;
    f.gap_cycles = 1; f.build_payload(8'h60);
    send(sqr, f);

    f = new(); void'(f.randomize());
    f.traffic_type = 1'b1; f.seq_num = seq_num; f.frag_num = 3; f.payload_len = 4;
    f.gap_cycles = 0; f.build_payload(8'h63);
    send(sqr, f);
  endtask
endclass
