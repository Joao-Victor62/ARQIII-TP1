module dm_cache_fsm(
    input bit clk, input bit rst,
    input cache_def::cpu_req_type cpu_req,
    input cache_def::mem_data_type mem_data,
    output cache_def::mem_req_type mem_req,
    output cache_def::cpu_result_type cpu_res
);
    timeunit 1ns; timeprecision 1ps;
    import cache_def::*;

    typedef enum {idle, compare_tag, allocate, write_back} cache_state_type;

    cache_state_type vstate, rstate;

    //way 0
    cache_tag_type tag_read_w0, tag_write_w0;
    cache_req_type tag_req_w0;
    cache_data_type data_read_w0, data_write_w0;
    cache_req_type data_req_w0;

    //way 1
    cache_tag_type tag_read_w1, tag_write_w1;
    cache_req_type tag_req_w1;
    cache_data_type data_read_w1, data_write_w1;
    cache_req_type data_req_w1;

    // mapeamento de velho. considerar "2 caches" de 1024 blocos
    // o bloco lru_mem é um dicionario que diz, de acordo com o valor, qual caminho é o MAIS VELHO
    // por exemplo: se o addr apompta para os blocos de endereço 5, lru_mem[5] dirá qual dos dois será ejetado
    logic lru_mem [0:1023];      
    logic lru_we; // quando um dos blocos for substituido, deve-se atualizar o velho (miss)     
    logic lru_din; // o valor que será escrito na lru_mem           
    logic victim_way, v_victim_way; // quem sai em caso de miss

    cpu_result_type v_cpu_res;
    mem_req_type v_mem_req;

    assign mem_req = v_mem_req;
    assign cpu_res = v_cpu_res;

    logic [9:0] idx;
    assign idx = cpu_req.addr[13:4];
    logic hit_w0, hit_w1;
    assign hit_w0 = (cpu_req.addr[TAGMSB:TAGLSB] == tag_read_w0.TAG) && tag_read_w0.valid;
    assign hit_w1 = (cpu_req.addr[TAGMSB:TAGLSB] == tag_read_w1.TAG) && tag_read_w1.valid;

    initial begin
        for (int i=0; i<1024; i++) lru_mem[i] = 1'b0; // Começa sempre elegendo a Way 0
    end

    always_comb begin
        vstate = rstate;
        v_victim_way = victim_way;
        v_cpu_res = '{0, 0}; 
        v_mem_req = '{0, 0, 0, 0};
        
        tag_write_w0 = '{0, 0, 0}; tag_write_w1 = '{0, 0, 0};
        tag_req_w0.we = '0; tag_req_w1.we = '0;
        tag_req_w0.index = idx; tag_req_w1.index = idx;
        
        data_req_w0.we = '0; data_req_w1.we = '0;
        data_req_w0.index = idx; data_req_w1.index = idx;
        
        data_write_w0 = data_read_w0; 
        data_write_w1 = data_read_w1;

        lru_we = 1'b0;
        lru_din = 1'b0;

        case(cpu_req.addr[3:2])
            2'b00: data_write[31:0]   = cpu_req.data;
            2'b01: data_write[63:32]  = cpu_req.data;
            2'b10: data_write[95:64]  = cpu_req.data;
            2'b11: data_write[127:96] = cpu_req.data;
        endcase

        case(cpu_req.addr[3:2])
            2'b00: v_cpu_res.data = data_read[31:0];
            2'b01: v_cpu_res.data = data_read[63:32];
            2'b10: v_cpu_res.data = data_read[95:64];
            2'b11: v_cpu_res.data = data_read[127:96];
        endcase

        v_mem_req.addr = cpu_req.addr;
        v_mem_req.data = data_read;
        v_mem_req.rw = '0;

        case(rstate)
            idle : begin
                if (cpu_req.valid) vstate = compare_tag;
            end
            
            compare_tag : begin

                if (hit_w0 || hit_w1) begin
                    v_cpu_res.ready = '1; 
                    if (hit_w0) begin
                        lru_we = 1'b1; lru_din = 1'b1; // acesso em 0, 1 vira o mais velho

                        case(cpu_req.addr[3:2])
                            2'b00: begin v_cpu_res.data = data_read_w0[31:0];   data_write_w0[31:0]   = cpu_req.data; end
                            2'b01: begin v_cpu_res.data = data_read_w0[63:32];  data_write_w0[63:32]  = cpu_req.data; end
                            2'b10: begin v_cpu_res.data = data_read_w0[95:64];  data_write_w0[95:64]  = cpu_req.data; end
                            2'b11: begin v_cpu_res.data = data_read_w0[127:96]; data_write_w0[127:96] = cpu_req.data; end
                        endcase

                        if (cpu_req.rw) begin 
                            tag_req_w0.we = '1; data_req_w0.we = '1;
                            tag_write_w0.TAG = tag_read_w0.TAG;
                            tag_write_w0.valid = '1;
                            tag_write_w0.dirty = '1; 
                        end
                    end 
                    else begin

                        lru_we = 1'b1; lru_din = 1'b0; // acesso em 1, 0 vira o mais velho 

                        case(cpu_req.addr[3:2])
                            2'b00: begin v_cpu_res.data = data_read_w1[31:0];   data_write_w1[31:0]   = cpu_req.data; end
                            2'b01: begin v_cpu_res.data = data_read_w1[63:32];  data_write_w1[63:32]  = cpu_req.data; end
                            2'b10: begin v_cpu_res.data = data_read_w1[95:64];  data_write_w1[95:64]  = cpu_req.data; end
                            2'b11: begin v_cpu_res.data = data_read_w1[127:96]; data_write_w1[127:96] = cpu_req.data; end
                        endcase

                        if (cpu_req.rw) begin
                            tag_req_w1.we = '1; data_req_w1.we = '1;
                            tag_write_w1.TAG = tag_read_w1.TAG;
                            tag_write_w1.valid = '1;
                            tag_write_w1.dirty = '1; 
                        end
                    end
                    vstate = idle;
                end


                else begin
                    v_victim_way = lru_mem[idx]; // Consulta o dicionario da LRU para ver quem sai

                    v_mem_req.valid = '1; //libera busca para memoria
                    
                    if (v_victim_way == 1'b0) begin
                        // se lixo ou limpo, pode sobrescrever sem write-back
                        if (tag_read_w0.valid == 1'b0 || tag_read_w0.dirty == 1'b0) begin
                            vstate = allocate;
                        //envia para guardar na memória se sujo ou valido
                        end else begin
                            v_mem_req.addr = {tag_read_w0.TAG, cpu_req.addr[TAGLSB-1:0]};
                            v_mem_req.data = data_read_w0;
                            v_mem_req.rw = '1; //libera para guardar neste momento exato
                            vstate = write_back;
                        end
                    end 
                    else begin
                        if (tag_read_w1.valid == 1'b0 || tag_read_w1.dirty == 1'b0) begin
                            vstate = allocate;
                        end else begin
                            v_mem_req.addr = {tag_read_w1.TAG, cpu_req.addr[TAGLSB-1:0]};
                            v_mem_req.data = data_read_w1;
                            v_mem_req.rw = '1;
                            vstate = write_back;
                        end
                    end
                end
            end

            write_back : begin
                if (mem_data.ready) begin
                    v_mem_req.valid = '1;
                    v_mem_req.rw = '0;
                    vstate = allocate;
                end
            end
            
            allocate: begin
                // espera a memória terminar a busca
                if (mem_data.ready) begin 
                    vstate = compare_tag;
                    
                    //salva no rsepectivo bloco de cache
                    if (victim_way == 1'b0) begin
                        data_write_w0 = mem_data.data;
                        data_req_w0.we = '1;
                        tag_write_w0.TAG = cpu_req.addr[TAGMSB:TAGLSB];
                        tag_write_w0.valid = '1;
                        tag_write_w0.dirty = '0;
                        tag_req_w0.we = '1;
                    end else begin
                        data_write_w1 = mem_data.data;
                        data_req_w1.we = '1;
                        tag_write_w1.TAG = cpu_req.addr[TAGMSB:TAGLSB];
                        tag_write_w1.valid = '1;
                        tag_write_w1.dirty = '0;
                        tag_req_w1.we = '1;
                    end
                end
            end
            
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            rstate <= idle;
            victim_way <= 1'b0;
        end else begin
            rstate <= vstate;
            victim_way <= v_victim_way;

            if (lru_we) begin
                lru_mem[idx] <= lru_din;
            end
        end
    end

    dm_cache_tag  ctag_w0  (.clk(clk), .tag_req(tag_req_w0), .tag_write(tag_write_w0), .tag_read(tag_read_w0));
    dm_cache_data cdata_w0 (.clk(clk), .data_req(data_req_w0), .data_write(data_write_w0), .data_read(data_read_w0));

    dm_cache_tag  ctag_w1  (.clk(clk), .tag_req(tag_req_w1), .tag_write(tag_write_w1), .tag_read(tag_read_w1));
    dm_cache_data cdata_w1 (.clk(clk), .data_req(data_req_w1), .data_write(data_write_w1), .data_read(data_read_w1));

endmodule