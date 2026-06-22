class bird_env;

  virtual bird_if vif;

  bird_sequencer  sqr;
  bird_driver     drv;
  bird_mon_in     mon_in;
  bird_mon_local  mon_local;
  bird_mon_remote mon_remote;
  bird_scoreboard sb;
  bird_coverage   cov;

  mailbox #(bird_fragment) mon2sb_in;
  mailbox #(u8_t)          mon2sb_local;
  mailbox #(bit [31:0])    mon2sb_remote;

  function new(virtual bird_if vif);
    this.vif = vif;

    sqr = new();

    mon2sb_in     = new();
    mon2sb_local  = new();
    mon2sb_remote = new();

    cov = new();
    sb  = new(vif, mon2sb_in, mon2sb_local, mon2sb_remote, cov);

    drv        = new(vif, sqr.seq2drv);
    mon_in     = new(vif, mon2sb_in);
    mon_local  = new(vif, mon2sb_local);
    mon_remote = new(vif, mon2sb_remote);
  endfunction

  task run();
    fork
      drv.run();
      mon_in.run();
      mon_local.run();
      mon_remote.run();
      sb.run();
    join_none
  endtask

  task run_seq(bird_sequence_base seq);
    seq.body(sqr);
  endtask


task wait_idle(int unsigned quiet_cycles = 50);
  int unsigned quiet_count;

  quiet_count = 0;

  forever begin
    @(posedge vif.clk);

    if ((sqr.seq2drv.num() == 0) &&
        (!drv.busy) &&
        (!vif.in_vld) &&
        (!vif.local_vld) &&
        (!vif.remote_vld) &&
        (mon2sb_in.num() == 0) &&
        (mon2sb_local.num() == 0) &&
        (mon2sb_remote.num() == 0)) begin

      quiet_count++;

      if (quiet_count >= quiet_cycles)
        break;

    end else begin
      quiet_count = 0;
    end
  end
endtask

  function void report();
    sb.flush_remote();
    sb.report();
    cov.report();
  endfunction

endclass
