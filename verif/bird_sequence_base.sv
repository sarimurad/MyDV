class bird_sequencer;
  mailbox #(bird_fragment) seq2drv;

  function new();
    seq2drv = new();
  endfunction
endclass


virtual class bird_sequence_base;
  string name;

  function new(string name = "seq");
    this.name = name;
  endfunction

  pure virtual task body(bird_sequencer sqr);

  task send(bird_sequencer sqr, bird_fragment f);
    sqr.seq2drv.put(f);
  endtask
endclass
