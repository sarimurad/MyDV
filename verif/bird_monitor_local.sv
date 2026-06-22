class bird_mon_local;
  virtual bird_if vif;
  mailbox #(u8_t) mon2sb;

  function new(virtual bird_if vif, mailbox #(u8_t) mon2sb);
    this.vif = vif;
    this.mon2sb = mon2sb;
  endfunction

  task run();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.local_vld && vif.monitor_cb.local_rdy) begin
        mon2sb.put(vif.monitor_cb.data_local);
      end
    end
  endtask

endclass
