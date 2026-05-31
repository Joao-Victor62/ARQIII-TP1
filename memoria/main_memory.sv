module main_memory(
    input bit clk,
    input bit rst,
    input cache_def::mem_req_type mem_req,   // O pedido que vem do Controlador
    output cache_def::mem_data_type mem_data // A resposta que vai para o Controlador
);
    timeunit 1ns; timeprecision 1ps;
    import cache_def::*;

    //RAM de 64KB (4x maior que a cache)
    bit [127:0] ram [0:4095];

    logic [11:0] ram_index;
    assign ram_index = mem_req.addr[15:4]; 

    typedef enum {mem_idle, mem_busy} mem_state_type;
    mem_state_type state;
    logic [3:0] delay_count;

    initial begin
        for (int i=0; i<4096; i++)
            ram[i] = '0;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= mem_idle;
            delay_count <= '0;
            mem_data.ready <= '0;
            mem_data.data <= '0;
        end else begin
            case (state)
                mem_idle: begin
                    mem_data.ready <= '0; // Baixa o sinal de pronto
                    
                    if (mem_req.valid) begin
                        state <= mem_busy;
                        delay_count <= 4'd10; // Configura o atraso para 10 ciclos!
                    end
                end
                
                mem_busy: begin
                    if (delay_count > 0) begin
                        delay_count <= delay_count - 1; // Contagem decrescente
                    end 
                    else begin
                        mem_data.ready <= '1; // Avisa a Cache: "Terminei!"
                        
                        if (mem_req.rw == 1'b0) begin
                            mem_data.data <= ram[ram_index];
                        end 
                        else begin
                            ram[ram_index] <= mem_req.data;
                        end
                        
                        state <= mem_idle; // Volta a dormir no próximo ciclo
                    end
                end
            endcase
        end
    end
endmodule
