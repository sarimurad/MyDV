class bird_mon_remote;
  virtual bird_if vif;
  mailbox #(bit [31:0]) mon2sb;

  function new(virtual bird_if vif, mailbox #(bit [31:0]) mon2sb);
    this.vif = vif;
    this.mon2sb = mon2sb;
  endfunction

  task run();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.remote_vld && vif.monitor_cb.remote_rdy) begin
        mon2sb.put(vif.monitor_cb.data_remote);
      end
    end
  endtask

endclass
