virtual class bird_test_base;

  virtual bird_if vif;
  bird_env        env;

  function new(virtual bird_if vif);
    this.vif = vif;
    env = new(vif);
  endfunction

  // Drives rst_n=0 for a few cycles with all inputs idle, then
  // releases reset (section 9: reset behavior).
task do_reset(int unsigned cycles = 3);

  vif.rst_n      = 1'b0;
  vif.in_vld     = 1'b0;
  vif.cfg        = '0;
  vif.data_in    = '0;
  vif.local_rdy  = 1'b1;
  vif.remote_rdy = 1'b1;

  repeat (cycles) @(posedge vif.clk);

  @(negedge vif.clk);
  vif.rst_n = 1'b1;

  repeat (2) @(posedge vif.clk);

endtask

task do_reset_during_activity(int unsigned cycles = 3);

  @(negedge vif.clk);
  vif.rst_n = 1'b0;

  repeat (cycles) @(posedge vif.clk);

  @(negedge vif.clk);
  vif.in_vld     = 1'b0;
  vif.cfg        = '0;
  vif.data_in    = '0;
  vif.local_rdy  = 1'b1;
  vif.remote_rdy = 1'b1;
  vif.rst_n      = 1'b1;

  repeat (2) @(posedge vif.clk);

endtask

  pure virtual task run_test();

  task main();
    $display("===========================================================");
    $display("STARTING TEST: %s", get_name());
    $display("===========================================================");
    do_reset();
    env.run();
    run_test();
    env.wait_idle();
    env.report();
  endtask

  virtual function string get_name();
    return "bird_test_base";
  endfunction

endclass
