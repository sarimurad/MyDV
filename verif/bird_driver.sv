
class bird_driver;
  virtual bird_if vif;
  mailbox #(bird_fragment) seq2drv;

  int unsigned handshake_violations;
  int unsigned bytes_driven;
  int unsigned fragments_driven;

  bit busy;

  function new(virtual bird_if vif, mailbox #(bird_fragment) seq2drv);
    this.vif = vif;
    this.seq2drv = seq2drv;
    handshake_violations = 0;
    bytes_driven = 0;
    fragments_driven = 0;
    busy = 1'b0;
  endfunction

  task run();
    bird_fragment frag;

    forever begin
      seq2drv.get(frag);
      drive_fragment(frag);
    end
  endtask

  task automatic drive_one_byte(bit [31:0] cfg_word, u8_t b);

    @(negedge vif.clk);
    vif.cfg     = cfg_word;
    vif.data_in = b;
    vif.in_vld  = 1'b1;

    do begin
      @(posedge vif.clk);

      if (!vif.in_rdy) begin
        handshake_violations++;
      end

    end while (!vif.in_rdy);

    bytes_driven++;
  endtask

  task drive_fragment(bird_fragment frag);
    u8_t bytes_q[$];
    bit [31:0] cfg_word;

    busy = 1'b1;

    // Idle gap before fragment.
    if (frag.gap_cycles > 0) begin
      @(negedge vif.clk);
      vif.in_vld  = 1'b0;
      vif.cfg     = '0;
      vif.data_in = '0;

      repeat (frag.gap_cycles) @(posedge vif.clk);
    end

    cfg_word = frag.cfg();

    bytes_q.delete();

    foreach (frag.payload[i]) begin
      bytes_q.push_back(frag.payload[i]);
    end

    bytes_q.push_back(frag.crc[15:8]);
    bytes_q.push_back(frag.crc[7:0]);

    $display("[DRIVER] Driving fragment: type=%0s plen=%0d frag=%0d seq=%0d total_bytes=%0d crc=%04h",
             frag.traffic_type ? "REMOTE" : "LOCAL",
             frag.payload_len,
             frag.frag_num,
             frag.seq_num,
             bytes_q.size(),
             frag.crc);

    foreach (bytes_q[i]) begin
      drive_one_byte(cfg_word, bytes_q[i]);
    end

    fragments_driven++;

    @(negedge vif.clk);
    vif.in_vld  = 1'b0;
    vif.cfg     = '0;
    vif.data_in = '0;

    @(posedge vif.clk);

    busy = 1'b0;
  endtask

endclass