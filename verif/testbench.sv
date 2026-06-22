//`timescale 1ns/1ps

module tb_top;

  import bird_pkg::*;
  logic clk = 1'b0;
  always #5 clk = ~clk;
  bird_if bus_if (clk);

  bird dut (
    .clk (clk),
    .rst_n (bus_if.rst_n),

    .in_vld (bus_if.in_vld),
    .in_rdy (bus_if.in_rdy),
    .data_in (bus_if.data_in),
    .cfg (bus_if.cfg),

    .drop_cnt (bus_if.drop_cnt),

    .local_vld (bus_if.local_vld),
    .local_rdy (bus_if.local_rdy),
    .data_local (bus_if.data_local),

    .remote_vld (bus_if.remote_vld),
    .remote_rdy (bus_if.remote_rdy),
    .data_remote (bus_if.data_remote)
  );

  function automatic bird_test_base create_test(string name, virtual bird_if vif);
    case (name)
      "test_local_basic": begin
        test_local_basic t = new(vif);
        return t;
      end
      "test_local_seqnum_variation": begin
        test_local_seqnum_variation t = new(vif);
        return t;
      end
      "test_local_invalid": begin
        test_local_invalid t = new(vif);
        return t;
      end
      "test_remote_single_frag": begin
        test_remote_single_frag t = new(vif);
        return t;
      end
      "test_remote_multi_inorder": begin
        test_remote_multi_inorder t = new(vif);
        return t;
      end
      "test_remote_out_of_order": begin
        test_remote_out_of_order t = new(vif);
        return t;
      end
      "test_remote_mismatched_seq": begin
        test_remote_mismatched_seq t = new(vif);
        return t;
      end
      "test_remote_missing_fragment": begin
        test_remote_missing_fragment t = new(vif);
        return t;
      end
      "test_reserved_bits_invalid": begin
        test_reserved_bits_invalid t = new(vif);
        return t;
      end
      "test_zero_fields_invalid": begin
        test_zero_fields_invalid t = new(vif);
        return t;
      end
      "test_payload_len_boundary": begin
        test_payload_len_boundary t = new(vif);
        return t;
      end
      "test_back_to_back_mixed": begin
        test_back_to_back_mixed t = new(vif);
        return t;
      end
      "test_drop_cnt_wrap": begin
        test_drop_cnt_wrap t = new(vif);
        return t;
      end
      "test_reset_midpacket": begin
        test_reset_midpacket t = new(vif);
        return t;
      end
      "test_backpressure_local": begin
        test_backpressure_local t = new(vif);
        return t;
      end
      "test_backpressure_remote": begin
        test_backpressure_remote t = new(vif);
        return t;
      end
      "test_coverage_full": begin
       test_coverage_full t = new(vif);
       return t;
       end
      default: begin
        $fatal(1, "[TB_TOP] Unknown TEST_NAME '%s'", name);
      end
    endcase
  endfunction

  // Run selected test
  bird_test_base test_h;

  initial begin
    string test_name;

    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);

    if (!$value$plusargs("TEST_NAME=%s", test_name))
      test_name = "test_local_seqnum_variation";

    $display("[TB_TOP] Running %s", test_name);
    test_h = create_test(test_name, bus_if);
    test_h.main();

    $display("[TB_TOP] Test %s finished", test_name);
    $finish;
  end

endmodule
