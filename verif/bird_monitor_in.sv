class bird_mon_in;
  virtual bird_if vif;
  mailbox #(bird_fragment) mon2sb;

  typedef enum { ST_IDLE, ST_PAYLOAD, ST_CRC } mon_state_e;

  function new(virtual bird_if vif, mailbox #(bird_fragment) mon2sb);
    this.vif = vif;
    this.mon2sb = mon2sb;
  endfunction

  task run();
    mon_state_e  st;
    bird_fragment frag;
    int unsigned n_payload;
    int unsigned payload_left;
    int unsigned crc_left;

    st = ST_IDLE;

    forever begin
      @(vif.monitor_cb);
      if (!vif.rst_n) begin
        st = ST_IDLE;
      end else if (vif.monitor_cb.in_vld && vif.monitor_cb.in_rdy) begin
        unique case (st)
          ST_IDLE: begin
            frag = new();
            frag.traffic_type = vif.monitor_cb.cfg[0];
            frag.rsv_7_1      = vif.monitor_cb.cfg[7:1];
            frag.payload_len  = vif.monitor_cb.cfg[15:8];
            frag.frag_num     = vif.monitor_cb.cfg[20:16];
            frag.rsv_23_21    = vif.monitor_cb.cfg[23:21];
            frag.seq_num      = vif.monitor_cb.cfg[28:24];
            frag.rsv_31_29    = vif.monitor_cb.cfg[31:29];

            frag.payload.delete();
            frag.payload.push_back(vif.monitor_cb.data_in);

            n_payload    = (frag.payload_len == 0) ? 1 : frag.payload_len;
            payload_left = n_payload - 1;
            crc_left     = 2;

            st = (payload_left == 0) ? ST_CRC : ST_PAYLOAD;
          end

          ST_PAYLOAD: begin
            frag.payload.push_back(vif.monitor_cb.data_in);
            payload_left--;
            if (payload_left == 0) st = ST_CRC;
          end

          ST_CRC: begin
            if (crc_left == 2) frag.crc[15:8] = vif.monitor_cb.data_in;
            else                frag.crc[7:0]  = vif.monitor_cb.data_in;
            crc_left--;
            if (crc_left == 0) begin
              $display("[MON_IN] Completed fragment: type=%0s plen=%0d payload_size=%0d frag=%0d seq=%0d crc=%04h",
                     frag.traffic_type ? "REMOTE" : "LOCAL",
                     frag.payload_len,
                     frag.payload.size(),
                     frag.frag_num,
                     frag.seq_num,
                     frag.crc);
              mon2sb.put(frag);
              st = ST_IDLE;
            end
          end
        endcase
      end
    end
  endtask

endclass
