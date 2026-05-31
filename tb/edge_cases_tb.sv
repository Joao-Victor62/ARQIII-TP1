import cache_def::*;

module tb_edge_cases_tb();
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

    logic [31:0] dado_capturado;

    initial begin
        $dumpfile("edge_cases_test.vcd");
        $dumpvars(0, tb_edge_cases_tb);

        clk = 0; rst = 1;
        
        cpu_req.addr  = 32'h0;
        cpu_req.data  = 32'h0;
        cpu_req.rw    = 1'b0;
        cpu_req.valid = 1'b0;
        
        #20 rst = 0; #10;

        $display("--------------------------------------------------");
        $display(" INICIANDO TESTES DE CASOS LIMITE (EDGE CASES)");
        $display("--------------------------------------------------");

        // ====================================================================
        // CENÁRIO 1: Comportamento com Cache Completamente Inválida
        // ====================================================================
        $display("\n[Ciclo %0t] -> Tentando ler Endereco 0x0000_0100 em Cache Vazia/Invalida...", $time);
        cpu_req.addr  = 32'h0000_0100;
        cpu_req.rw    = 1'b0;
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        
        dado_capturado = cpu_res.data;
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        if (dado_capturado === 32'h0) begin
            $display("[SUCESSO] Cache invalidada gerou Miss corretamente e carregou da RAM. Dado: %h", dado_capturado);
        end else begin
            $display("[ERRO] Falha ao tratar cache invalida. Lido: %h", dado_capturado);
        end

        #30;

        // ====================================================================
        // CENÁRIO 2: Acesso a Endereço Extremo Inferior (0x0000_0000)
        // ====================================================================
        $display("\n[Ciclo %0t] -> Escrevendo no Endereco Extremo Inferior (0x0000_0000)...", $time);
        cpu_req.addr  = 32'h0000_0000;
        cpu_req.data  = 32'h1A2B_3C4D;
        cpu_req.rw    = 1'b1;
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        $display("[Ciclo %0t] -> Lendo do Endereco Extremo Inferior...", $time);
        cpu_req.rw    = 1'b0;
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        
        dado_capturado = cpu_res.data;
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        if (dado_capturado === 32'h1A2B_3C4D) begin
            $display("[SUCESSO] Limite inferior (Indice 0, Tag 0) acessado e coerente.");
        end else begin
            $display("[ERRO] Falha no limite inferior. Lido: %h", dado_capturado);
        end

        #30;

        // ====================================================================
        // CENÁRIO 3: Acesso a Endereço Extremo Superior (0xFFFF_FFFC)
        // ====================================================================
        $display("\n[Ciclo %0t] -> Escrevendo no Endereco Extremo Superior (0xFFFF_FFFC)...", $time);
        cpu_req.addr  = 32'hFFFF_FFFC;
        cpu_req.data  = 32'h9988_7766;
        cpu_req.rw    = 1'b1;
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        $display("[Ciclo %0t] -> Lendo do Endereco Extremo Superior...", $time);
        cpu_req.rw    = 1'b0;
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        
        dado_capturado = cpu_res.data;
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        if (dado_capturado === 32'h9988_7766) begin
            $display("[SUCESSO] Limite superior (Max Index, Max Tag) suportado sem estouro de memoria!");
        end else begin
            $display("[ERRO] Falha no limite superior. Lido: %h", dado_capturado);
        end

        $display("\n--------------------------------------------------");
        $display(" TESTES DE CASOS LIMITE CONCLUIDOS");
        $display("--------------------------------------------------");
        $finish;
    end
endmodule