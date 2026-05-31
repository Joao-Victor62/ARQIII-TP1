import cache_def::*;

module dm_cache_fsm(
    input bit clk, input bit rst,
    input cpu_req_type cpu_req,
    input mem_data_type mem_data,
    output mem_req_type mem_req,
    output cpu_result_type cpu_res
);
    timeunit 1ns; timeprecision 1ps;
    import cache_def::*;

    typedef enum {idle, compare_tag, allocate, write_back} cache_state_type;

    cache_state_type vstate, rstate;

    // Sinais da Via 0 (Way 0)
    cache_tag_type tag_read_w0, tag_write_w0;
    cache_req_type tag_req_w0;
    cache_data_type data_read_w0, data_write_w0;
    cache_req_type data_req_w0;

    // Sinais da Via 1 (Way 1)
    cache_tag_type tag_read_w1, tag_write_w1;
    cache_req_type tag_req_w1;
    cache_data_type data_read_w1, data_write_w1;
    cache_req_type data_req_w1;

    // Memória LRU (1 bit por conjunto para rastrear a via mais antiga)
    logic lru_mem [0:1023];
    logic lru_we;     
    logic lru_din;
          
    logic victim_way, v_victim_way;

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
        for (int i=0; i<1024; i++) lru_mem[i] = 1'b0;
    end

    always @(*) begin
        vstate = rstate;
        v_victim_way = victim_way;
        
        v_cpu_res.data = '0; 
        v_cpu_res.ready = '0;
        
        v_mem_req.addr = '0; 
        v_mem_req.data = '0; 
        v_mem_req.rw = '0; 
        v_mem_req.valid = '0;
        
        tag_write_w0.valid = '0; 
        tag_write_w0.dirty = '0; 
        tag_write_w0.TAG = '0;
        
        tag_write_w1.valid = '0; 
        tag_write_w1.dirty = '0; 
        tag_write_w1.TAG = '0;
        tag_req_w0.we = '0; tag_req_w1.we = '0;
        tag_req_w0.index = idx; tag_req_w1.index = idx;
        
        data_req_w0.we = '0;
        data_req_w1.we = '0;
        data_req_w0.index = idx; data_req_w1.index = idx;
        
        data_write_w0 = data_read_w0; 
        data_write_w1 = data_read_w1;

        lru_we = 1'b0;
        lru_din = 1'b0;

        v_mem_req.addr  = cpu_req.addr;
        v_mem_req.data  = '0;
        v_mem_req.rw    = '0;
        v_mem_req.valid = '0;

        case(rstate)
            idle : begin
                if (cpu_req.valid) vstate = compare_tag;
            end
            
            compare_tag : begin
                if (hit_w0 || hit_w1) begin
                    v_cpu_res.ready = '1;
                    if (hit_w0) begin
                        lru_we = 1'b1;
                        lru_din = 1'b1; // Acessou a Via 0, então a Via 1 se torna a mais antiga (LRU)

                        case(cpu_req.addr[3:2])
                            2'b00: begin v_cpu_res.data = data_read_w0[31:0];   data_write_w0[31:0]   = cpu_req.data; end
                            2'b01: begin v_cpu_res.data = data_read_w0[63:32];  data_write_w0[63:32]  = cpu_req.data; end
                            2'b10: begin v_cpu_res.data = data_read_w0[95:64];  data_write_w0[95:64]  = cpu_req.data; end
                            2'b11: begin v_cpu_res.data = data_read_w0[127:96]; data_write_w0[127:96] = cpu_req.data; end
                        endcase

                        if (cpu_req.rw) begin 
                            tag_req_w0.we = '1;
                            data_req_w0.we = '1;
                            tag_write_w0.TAG = tag_read_w0.TAG;
                            tag_write_w0.valid = '1;
                            tag_write_w0.dirty = '1;
                        end
                    end 
                    else begin
                        lru_we = 1'b1;
                        lru_din = 1'b0; // Acessou a Via 1, então a Via 0 se torna a mais antiga (LRU)

                        case(cpu_req.addr[3:2])
                            2'b00: begin v_cpu_res.data = data_read_w1[31:0];   data_write_w1[31:0]   = cpu_req.data; end
                            2'b01: begin v_cpu_res.data = data_read_w1[63:32];  data_write_w1[63:32]  = cpu_req.data; end
                            2'b10: begin v_cpu_res.data = data_read_w1[95:64];  data_write_w1[95:64]  = cpu_req.data; end
                            2'b11: begin v_cpu_res.data = data_read_w1[127:96]; data_write_w1[127:96] = cpu_req.data; end
                        endcase

                        if (cpu_req.rw) begin
                            tag_req_w1.we = '1;
                            data_req_w1.we = '1;
                            tag_write_w1.TAG = tag_read_w1.TAG;
                            tag_write_w1.valid = '1;
                            tag_write_w1.dirty = '1;
                        end
                    end
                    vstate = idle;
                end
                else begin
                    v_victim_way = lru_mem[idx];
                    
                    if (v_victim_way == 1'b0) begin
                        if (tag_read_w0.valid == 1'b0 || tag_read_w0.dirty == 1'b0) begin
                            vstate = allocate;
                        end else begin
                            vstate = write_back;
                        end
                    end 
                    else begin
                        if (tag_read_w1.valid == 1'b0 || tag_read_w1.dirty == 1'b0) begin
                            vstate = allocate;
                        end else begin
                            vstate = write_back;
                        end
                    end
                end
            end

            write_back : begin
                v_mem_req.valid = '1;
                v_mem_req.rw = '1;
                if (victim_way == 1'b0) begin
                    v_mem_req.addr = {tag_read_w0.TAG, cpu_req.addr[TAGLSB-1:0]};
                    v_mem_req.data = data_read_w0;
                end else begin
                    v_mem_req.addr = {tag_read_w1.TAG, cpu_req.addr[TAGLSB-1:0]};
                    v_mem_req.data = data_read_w1;
                end

                if (mem_data.ready) begin
                    vstate = allocate;
                end
            end
            
            allocate: begin
                v_mem_req.valid = '1;
                v_mem_req.rw = '0;
                v_mem_req.addr = cpu_req.addr;

                if (mem_data.ready) begin 
                    vstate = compare_tag;
                    
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