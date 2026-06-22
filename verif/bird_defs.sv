typedef byte unsigned u8_t;

// cfg[31:0] field layout (see BIRD_spec.pdf section 5):
//  [0]      TRAFFIC_TYPE  (0=local, 1=remote)
//  [7:1]    Reserved      (must be 0)
//  [15:8]   PAYLOAD_LEN   (1-255 valid)
//  [20:16]  FRAG_NUM      (1-31 valid)
//  [23:21]  Reserved      (must be 0)
//  [28:24]  SEQ_NUM       (1-31 valid)
//  [31:29]  Reserved      (must be 0)

typedef enum {
  DROP_NONE,
  DROP_RESERVED_BITS,        // any reserved bit group non-zero
  DROP_PAYLOAD_LEN_RANGE,     // PAYLOAD_LEN outside 1..255
  DROP_SEQ_NUM_ZERO,          // SEQ_NUM == 0
  DROP_FRAG_NUM_ZERO,         // FRAG_NUM == 0
  DROP_LOCAL_BAD_FRAG,        // local traffic with FRAG_NUM != 1
  DROP_MISMATCH_SEQ           // active packet still incomplete when superseded
                              // by a fragment with a different SEQ_NUM
} drop_reason_e;

// Build a 32-bit cfg word from individual fields.
function automatic bit [31:0] bird_make_cfg(
    bit          traffic_type,
    int unsigned payload_len,
    int unsigned frag_num,
    int unsigned seq_num,
    bit [6:0]    rsv_7_1   = 7'd0,
    bit [2:0]    rsv_23_21 = 3'd0,
    bit [2:0]    rsv_31_29 = 3'd0
);
  bit [31:0] c;
  c = '0;
  c[0]     = traffic_type;
  c[7:1]   = rsv_7_1;
  c[15:8]  = payload_len[7:0];
  c[20:16] = frag_num[4:0];
  c[23:21] = rsv_23_21;
  c[28:24] = seq_num[4:0];
  c[31:29] = rsv_31_29;
  return c;
endfunction

function automatic logic [15:0] bird_crc16_ccitt(u8_t bytes_q[$]);
  logic [15:0] crc;
  crc = 16'hFFFF;
  foreach (bytes_q[i]) begin
    crc ^= {bytes_q[i], 8'h00};
    for (int b = 0; b < 8; b++) begin
      if (crc[15]) crc = (crc << 1) ^ 16'h1021;
      else         crc = (crc << 1);
    end
  end
  return crc;
endfunction

function automatic void bird_pack_bytes_to_words(u8_t bytes_q[$], ref bit [31:0] words_q[$]);
  int i;
  i = 0;
  while (i < bytes_q.size()) begin
    bit [31:0] w;
    w = 32'h0;
    for (int k = 0; k < 4; k++) begin
      if (i < bytes_q.size()) begin
        w[8*k +: 8] = bytes_q[i];
        i++;
      end
    end
    words_q.push_back(w);
  end
endfunction
