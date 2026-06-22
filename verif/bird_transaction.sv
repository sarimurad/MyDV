class bird_fragment;

  // cfg fields
  rand bit          traffic_type;   // cfg[0]
  rand int unsigned payload_len;    // cfg[15:8]
  rand int unsigned frag_num;       // cfg[20:16]
  rand int unsigned seq_num;        // cfg[28:24]
  rand bit [6:0]    rsv_7_1;        // cfg[7:1]
  rand bit [2:0]    rsv_23_21;      // cfg[23:21]
  rand bit [2:0]    rsv_31_29;      // cfg[31:29]

  // Number of idle (in_vld=0) cycles to insert before this fragment
  rand int unsigned gap_cycles;

  // Payload bytes (size == payload_len, or 1 if payload_len==0)
  u8_t payload[$];

  // CRC16 transmitted with this fragment (covers payload bytes only)
  logic [15:0] crc;

  constraint c_payload_len { payload_len inside {[1:255]}; }
  constraint c_frag_num    { frag_num    inside {[1:31]}; }
  constraint c_seq_num     { seq_num     inside {[1:31]}; }
  constraint c_reserved    { rsv_7_1 == 0; rsv_23_21 == 0; rsv_31_29 == 0; }
  constraint c_gap         { gap_cycles inside {[0:2]}; }

  function new(string name = "frag");
  endfunction

  // Fill payload with a deterministic, repeatable pattern and
  // compute the CRC16 over it. Call after setting payload_len
  // (and any direct field overrides for negative tests).
  function void build_payload(bit [7:0] base_tag = 8'h00);
    int n;
    n = (payload_len == 0) ? 1 : payload_len;
    payload.delete();
    for (int i = 0; i < n; i++) payload.push_back(base_tag + i[7:0]);
    crc = bird_crc16_ccitt(payload);
  endfunction

  function void post_randomize();
    build_payload(8'h00);
  endfunction

  // Pack fields into the 32-bit cfg word.
  function bit [31:0] cfg();
    return bird_make_cfg(traffic_type, payload_len, frag_num, seq_num,
                          rsv_7_1, rsv_23_21, rsv_31_29);
  endfunction

  function bird_fragment clone();
    bird_fragment c;
    c = new();
    c.traffic_type = traffic_type;
    c.payload_len  = payload_len;
    c.frag_num     = frag_num;
    c.seq_num      = seq_num;
    c.rsv_7_1      = rsv_7_1;
    c.rsv_23_21    = rsv_23_21;
    c.rsv_31_29    = rsv_31_29;
    c.gap_cycles   = gap_cycles;
    c.payload      = payload;
    c.crc          = crc;
    return c;
  endfunction

  function string convert2string();
    return $sformatf("type=%0s plen=%0d frag=%0d seq=%0d rsv=%0d/%0d/%0d crc=%04h",
                      traffic_type ? "REMOTE" : "LOCAL",
                      payload_len, frag_num, seq_num,
                      rsv_7_1, rsv_23_21, rsv_31_29, crc);
  endfunction

endclass
