import cache_def::*;

module tb_consistency_tb();
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
        $dumpfile("consistency_test.vcd");
        $dumpvars(0, tb_consistency_tb);

        clk = 0; rst = 1;
        cpu_req.addr  = 32'h0;
        cpu_req.data  = 32'h0;
        cpu_req.rw    = 1'b0;
        cpu_req.valid = 1'b0;
        #20 rst = 0; #10;

        $display("--------------------------------------------------");
        $display(" INICIANDO TESTES DE CONSISTENCIA (COERENCIA DE DADOS)");
        $display("--------------------------------------------------");

        // ====================================================================
        // CENÁRIO 1: Coerência Básica (Write seguido de Read)
        // ====================================================================
        $display("\n[Ciclo %0t] -> Escrevendo 0xAAAA_BBBB no Endereco 0x0000_0100...", $time);
        cpu_req.addr  = 32'h0000_0100;
        cpu_req.data  = 32'hAAAA_BBBB;
        cpu_req.rw    = 1'b1;
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        $display("[Ciclo %0t] -> Lendo imediatamente do Endereco 0x0000_0100...", $time);
        cpu_req.rw    = 1'b0; 
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        
        dado_capturado = cpu_res.data; 
        
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        if (dado_capturado === 32'hAAAA_BBBB)
            $display("[SUCESSO] Coerencia basica validada. Dado lido corresponde ao escrito.");
        else
            $display("[ERRO] Corrupcao de dados! Lido: %h", dado_capturado);

        #30;

        // ====================================================================
        // CENÁRIO 2: Acessos Repetidos (Atualizações sucessivas com HIT)
        // ====================================================================
        $display("\n[Ciclo %0t] -> Atualizando MESMO Endereco 0x0000_0100 para 0xCCCC_DDDD...", $time);
        cpu_req.data  = 32'hCCCC_DDDD;
        cpu_req.rw    = 1'b1;
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        $display("[Ciclo %0t] -> Lendo Endereco 0x0000_0100 novamente...", $time);
        cpu_req.rw    = 1'b0;
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        
        dado_capturado = cpu_res.data; 
        
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        if (dado_capturado === 32'hCCCC_DDDD)
            $display("[SUCESSO] Acesso repetido validado. Dado atualizado sem problemas no HIT.");
        else
            $display("[ERRO] Falha no acesso repetido! Lido: %h", dado_capturado);

        #30;

        // ====================================================================
        // CENÁRIO 3: Conflitos e Recuperação da Memória
        // ====================================================================
        $display("\n[Ciclo %0t] -> Criando Conflito 1: Escrevendo 0x1111_1111 no Endereco 0x0000_4100 (Via 1)", $time);
        cpu_req.addr  = 32'h0000_4100;
        cpu_req.data  = 32'h1111_1111;
        cpu_req.rw    = 1'b1;
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        $display("[Ciclo %0t] -> Criando Conflito 2: Escrevendo 0x2222_2222 no Endereco 0x0000_8100 (Expulsa Via 0)", $time);
        cpu_req.addr  = 32'h0000_8100;
        cpu_req.data  = 32'h2222_2222;
        cpu_req.rw    = 1'b1;
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        $display("[Ciclo %0t] -> Recuperando dado expulso: Lendo Endereco 0x0000_0100...", $time);
        cpu_req.addr  = 32'h0000_0100;
        cpu_req.rw    = 1'b0;
        cpu_req.valid = 1'b1;
        wait(cpu_res.ready == 1'b1);
        
        dado_capturado = cpu_res.data; 
        
        @(posedge clk);
        cpu_req.valid = 1'b0;
        #5;

        if (dado_capturado === 32'hCCCC_DDDD) begin
            $display("[SUCESSO] Consistencia TOTAL garantida! O dado expulso foi recuperado da RAM com sucesso.");
        end else begin
            $display("[ERRO] Perda de coerencia! O dado recuperado esta incorreto. Lido: %h (Esperado: ccccdddd)", dado_capturado);
        end

        $display("\n--------------------------------------------------");
        $display(" TESTES DE CONSISTENCIA CONCLUIDOS");
        $display("--------------------------------------------------");
        $finish;
    end
endmodule