import cache_def::*;

module tb_cache_read();
    timeunit 1ns; timeprecision 1ps;

    // Sinais de controle e barramentos
    bit clk;
    bit rst;
    cpu_req_type cpu_req;
    cpu_result_type cpu_res;

    mem_req_type mem_req;
    mem_data_type mem_data;

    // Instanciação do Controlador de Cache (UUT - Unit Under Test)
    dm_cache_fsm uut_cache (
        .clk(clk),
        .rst(rst),
        .cpu_req(cpu_req),
        .mem_data(mem_data),
        .mem_req(mem_req),
        .cpu_res(cpu_res)
    );

    // Instanciação da Memória Principal
    main_memory uut_mem (
        .clk(clk),
        .rst(rst),
        .mem_req(mem_req),
        .mem_data(mem_data)
    );

    // Geração do Clock (Período de 10ns)
    always #5 clk = ~clk;

    // Lógica do Teste
    initial begin
        // 0. Preparação e injeção de dados (Backdoor)
        // O endereço 32'h0000_01A0 mapeia para o índice de RAM 12'h01A
        uut_mem.ram[12'h01A] = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_1111_2222;
        
        // 1. Inicialização e Reset
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

        // Aguarda a cache levantar o sinal de ready (vai demorar devido ao acesso à RAM)
        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        $display("[Ciclo %0t] -> Cache MISS resolvido! Dado entregue: %h", $time, cpu_res.data);
        
        // CPU abaixa a requisição após receber o dado
        cpu_req.valid = 1'b0;
        #30; // Espera alguns ciclos de respiro

        // ====================================================================
        // CENÁRIO 2: Acesso com Cache HIT (Dados já na cache)
        // ====================================================================
        $display("\n[Ciclo %0t] -> CPU Solicita Leitura no MESMO Endereco 0x01A0", $time);
        cpu_req.addr = 32'h0000_01A0;
        cpu_req.rw = 1'b0;
        cpu_req.valid = 1'b1;

        // Aguarda a resposta (deve ser praticamente imediata)
        wait(cpu_res.ready == 1'b1);
        @(posedge clk);
        $display("[Ciclo %0t] -> Cache HIT imediato! Dado entregue: %h", $time, cpu_res.data);
        
        cpu_req.valid = 1'b0;
        #20;

        // ====================================================================
        // CENÁRIO 3: Verificação da atualização dos bits de controle
        // ====================================================================
        $display("\n--- Verificando os Bits de Controle ---");
        
        // Contorno para o bug do Icarus: em vez de acessar tag_mem[índice] diretamente,
        // lemos o fio tag_read_w0 da FSM, que já está extraindo os dados desse índice.
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