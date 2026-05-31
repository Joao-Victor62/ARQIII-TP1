import cache_def::*;

module tb_substitution_tb();
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
        $dumpfile("substitution_test.vcd");
        $dumpvars(0, tb_substitution_tb);

        clk = 0; rst = 1;
        
        cpu_req.addr  = 32'h0;
        cpu_req.data  = 32'h0;
        cpu_req.rw    = 1'b0;
        cpu_req.valid = 1'b0;
        
        #20 rst = 0; #10;

        $display("--------------------------------------------------");
        $display(" INICIANDO TESTES DE SUBSTITUICAO E WRITE-BACK");
        $display("--------------------------------------------------");

        // ====================================================================
        // 1. Preencher a Via 0 (Tag 0)
        // ====================================================================
        $display("\n[Ciclo %0t] -> Escrita 1: Endereco 0x0000_0000 (Via 0)", $time);
        cpu_req.addr  = 32'h0000_0000;
        cpu_req.data  = 32'h1111_1111;
        cpu_req.rw    = 1'b1;
        cpu_req.valid = 1'b1;
        
        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        // ====================================================================
        // 2. Preencher a Via 1 (Tag 1) - Cache Set 0 fica CHEIO
        // ====================================================================
        $display("\n[Ciclo %0t] -> Escrita 2: Endereco 0x0000_4000 (Via 1)", $time);
        cpu_req.addr  = 32'h0000_4000;
        cpu_req.data  = 32'h2222_2222;
        cpu_req.rw    = 1'b1;
        cpu_req.valid = 1'b1;

        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        // ====================================================================
        // 3. Forçar a Substituição (Tag 2) - LRU expulsa a Via 0
        // ====================================================================
        $display("\n[Ciclo %0t] -> Escrita 3: Endereco 0x0000_8000 (Forca Substituicao)", $time);
        cpu_req.addr  = 32'h0000_8000;
        cpu_req.data  = 32'h3333_3333;
        cpu_req.rw    = 1'b1;
        cpu_req.valid = 1'b1;

        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        // ====================================================================
        // 4. Validações Finais (LRU e Write-Back)
        // ====================================================================
        $display("\n--- Validando Politicas de Cache ---");
        
        if (uut_cache.tag_read_w0.TAG === 18'h2 && uut_cache.tag_read_w1.TAG === 18'h1) begin
            $display("[SUCESSO] Politica LRU funcionou perfeitamente. A Via 0 foi ejetada e substituida.");
        end else begin
            $display("[ERRO] Falha no LRU! Tag0: %h (Esperado: 2), Tag1: %h (Esperado: 1)", 
                     uut_cache.tag_read_w0.TAG, uut_cache.tag_read_w1.TAG);
        end

        if (uut_mem.ram[0][31:0] === 32'h1111_1111) begin
            $display("[SUCESSO] Write-Back executado com sucesso! Dado transferido para a RAM.");
        end else begin
            $display("[ERRO] Falha de Write-Back! A memoria RAM nao recebeu o bloco sujo. RAM: %h", uut_mem.ram[0][31:0]);
        end

        $display("\n--------------------------------------------------");
        $display(" TESTES DE SUBSTITUICAO CONCLUIDOS");
        $display("--------------------------------------------------");
        $finish;
    end
endmodule