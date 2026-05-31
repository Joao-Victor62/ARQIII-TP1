package cache_def;
  parameter TAGMSB = 31;
  parameter TAGLSB = 14;

  typedef struct packed {
    logic valid;
    logic dirty;
    logic [31:14] TAG; 
  } cache_tag_type;

  typedef struct packed {
    logic [9:0] index;
    logic we;
  } cache_req_type;

  typedef logic [127:0] cache_data_type;

  typedef struct packed {
    logic [31:0] addr;
    logic [31:0] data;
    logic rw;
    logic valid;
  } cpu_req_type;

  typedef struct packed {
    logic [31:0] data;
    logic ready;
  } cpu_result_type;

  typedef struct packed {
    logic [31:0] addr;
    logic [127:0] data;
    logic rw;
    logic valid;
  } mem_req_type;

  typedef struct packed {
    logic [127:0] data; 
    logic ready;
  } mem_data_type;

endpackage