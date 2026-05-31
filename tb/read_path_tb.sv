import cache_def::*;

module tb_cache_read();
    timeunit 1ns; timeprecision 1ps;

    bit clk;
    bit rst;
    cpu_req_type cpu_req;
    cpu_result_type cpu_res;

    mem_req_type mem_req;
    mem_data_type mem_data;

    dm_cache_fsm uut_cache (
        .clk(clk),
        .rst(rst),
        .cpu_req(cpu_req),
        .mem_data(mem_data),
        .mem_req(mem_req),
        .cpu_res(cpu_res)
    );

    main_memory uut_mem (
        .clk(clk),
        .rst(rst),
        .mem_req(mem_req),
        .mem_data(mem_data)
    );

    always #5 clk = ~clk;

    initial begin
        uut_mem.ram[12'h01A] = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_1111_2222;
        
        clk = 0;
        rst = 1;
        cpu_req.valid = 1'b0;
        cpu_req.rw = 1'b0;
        cpu_req.addr = 32'h0;
        cpu_req.data = 32'h0;
        #20;
        rst = 0;
        #10;

        $display("--------------------------------------------------");
        $display(" INICIANDO TESTES DE LEITURA (READ PATH)");
        $display("--------------------------------------------------");

        // ====================================================================
        // CENÁRIO 1: Acesso com Cache MISS seguido de carregamento
        // ====================================================================
        $display("\n[Ciclo %0t] -> CPU Solicita Leitura no Endereco 0x01A0", $time);
        cpu_req.addr = 32'h0000_01A0;
        cpu_req.rw = 1'b0; // rw = 0 significa leitura
        cpu_req.valid = 1'b1;

        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        $display("[Ciclo %0t] -> Cache MISS resolvido! Dado entregue: %h", $time, cpu_res.data);
        
        cpu_req.valid = 1'b0;
        #30;

        // ====================================================================
        // CENÁRIO 2: Acesso com Cache HIT (Dados já na cache)
        // ====================================================================
        $display("\n[Ciclo %0t] -> CPU Solicita Leitura no MESMO Endereco 0x01A0", $time);
        cpu_req.addr = 32'h0000_01A0;
        cpu_req.rw = 1'b0;
        cpu_req.valid = 1'b1;

        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        $display("[Ciclo %0t] -> Cache HIT imediato! Dado entregue: %h", $time, cpu_res.data);
        
        cpu_req.valid = 1'b0;
        #20;

        // ====================================================================
        // CENÁRIO 3: Verificação da atualização dos bits de controle
        // ====================================================================
        $display("\n--- Verificando os Bits de Controle ---");
        
        if (uut_cache.tag_read_w0.valid === 1'b1) begin
            $display("[SUCESSO] O Bit VALID da Via 0 foi preenchido corretamente.");
        end else begin
            $display("[ERRO] O Bit VALID nao foi levantado na memoria de tags!");
        end

        $display("TAG armazenada na Via 0: %18h", uut_cache.tag_read_w0.TAG);
        
        $display("\n--------------------------------------------------");
        $display(" TESTES CONCLUIDOS");
        $display("--------------------------------------------------");
        $finish;
    end
endmodule