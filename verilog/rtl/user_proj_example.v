// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);

    wire ring_out;

    wire valid;
    wire [3:0] wstrb;
    wire [31:0] la_write;

    // IO
    assign io_out = ring_out;
    assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    // IRQ
    assign irq = 3'b000;	// Unused

    // LA
    assign la_data_out = {{(127-BITS){1'b0}}, ring_out};
    // Assuming LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:32] & ~{BITS{valid}};
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;

    ring_osc ring(
        .osc_out(ring_out)
    );

endmodule

module ring_osc(
    output osc_out
    );

    localparam NUM_INVERTERS = 155;
    assign osc_out = buffers_out[0];
    // http://svn.clairexen.net/handicraft/2015/ringosc/ringosc.v
    wire chain_in, chain_out;
    wire [NUM_INVERTERS-1:0] buffers_in, buffers_out;
    assign chain = chain_out;
    assign buffers_in = {buffers_out[NUM_INVERTERS-2:0], chain_in};
    assign chain_out = buffers_out[NUM_INVERTERS-1];
    assign chain_in = rst ? 0: !chain_out;

    sky130_fd_sc_hd__inv_2 buffers [NUM_INVERTERS-1:0] (
        .A(buffers_in),
        .Y(buffers_out)
    );
    //localparam [3:0] length = 4'd15;
   
     //wire [length:0] del;
    
     //assign del[0] = del[length];
    
     //genvar i;
     //generate 
     //    for (i=0; i<length; i=i+1)begin
     //      assign del[i+1] = ~del[i];
     //    end
     //endgenerate
    
     //assign osc_out = del[length];

endmodule

`default_nettype wire
