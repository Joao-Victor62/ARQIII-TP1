import cache_def::*;

module tb_write_path_tb();
    timeunit 1ns; timeprecision 1ps;

    bit clk;
    bit rst;
    cpu_req_type cpu_req;
    cpu_result_type cpu_res;
    mem_req_type mem_req;
    mem_data_type mem_data;

    dm_cache_fsm uut_cache (.clk(clk), .rst(rst), .cpu_req(cpu_req), .mem_data(mem_data), .mem_req(mem_req), .cpu_res(cpu_res));
    main_memory uut_mem (.clk(clk), .rst(rst), .mem_req(mem_req), .mem_data(mem_data));

    always #5 clk = ~clk;

    initial begin
        $dumpfile("write_test.vcd");
        $dumpvars(0, tb_write_path_tb);

        clk = 0; rst = 1;
        
        cpu_req.addr  = 32'h0;
        cpu_req.data  = 32'h0;
        cpu_req.rw    = 1'b0;
        cpu_req.valid = 1'b0;
        
        #20 rst = 0; #10;

        $display("--------------------------------------------------");
        $display(" INICIANDO TESTES DE ESCRITA (WRITE PATH)");
        $display("--------------------------------------------------");

        $display("[Ciclo %0t] -> Escrita com MISS (Write-Allocate) no endereco 0x0000_0200", $time);
        cpu_req.addr  = 32'h0000_0200;
        cpu_req.data  = 32'hDEADBEEF;
        cpu_req.rw    = 1'b1;
        cpu_req.valid = 1'b1;
        
        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        cpu_req.valid = 1'b0;

        #5;
        
        $display("[Ciclo %0t] -> Verificando Bit Dirty na Via 0...", $time);
        if (uut_cache.tag_read_w0.dirty === 1'b1) 
            $display("[SUCESSO] Bit Dirty levantado apos escrita com miss.");
        else 
            $display("[ERRO] Bit Dirty nao foi levantado! Status: %b", uut_cache.tag_read_w0.dirty);

        #50;

        $display("[Ciclo %0t] -> Escrita com HIT no endereco 0x0000_0200", $time);
        cpu_req.addr  = 32'h0000_0200;
        cpu_req.data  = 32'hCAFEBABE;
        cpu_req.rw    = 1'b1;
        cpu_req.valid = 1'b1;

        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        cpu_req.valid = 1'b0;

        #5;

        $display("[Ciclo %0t] -> Validando escrita na cache...", $time);
        if (uut_cache.data_read_w0[31:0] === 32'hCAFEBABE)
            $display("[SUCESSO] Dado escrito com sucesso no Hit.");
        else
            $display("[ERRO] Dado incorreto apos escrita HIT: %h", uut_cache.data_read_w0[31:0]);

        $display("\n--------------------------------------------------");
        $display(" TESTES DE ESCRITA CONCLUIDOS");
        $display("--------------------------------------------------");
        $finish;
    end
endmodule