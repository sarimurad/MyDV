
interface bird_if (input logic clk);

  logic        rst_n;
  logic        in_vld;
  logic        in_rdy;
  logic [7:0]  data_in;
  logic [31:0] cfg;

  logic [15:0] drop_cnt;
  logic        local_vld;
  logic        local_rdy;
  logic [7:0]  data_local;
  logic        remote_vld;
  logic        remote_rdy;
  logic [31:0] data_remote;

  clocking driver_cb @(posedge clk);
    default input #1step output #1step;
    output in_vld, data_in, cfg, local_rdy, remote_rdy;
    input  in_rdy;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1step;
    input in_vld, in_rdy, data_in, cfg, drop_cnt,
          local_vld, local_rdy, data_local,
          remote_vld, remote_rdy, data_remote;
  endclocking

  modport DRIVER  (clocking driver_cb);
  modport MONITOR (clocking monitor_cb);

endinterface
