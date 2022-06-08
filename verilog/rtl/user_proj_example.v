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

//`default_nettype none
`default_nettype wire
`timescale 1ns / 1ps
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
    output reg wbs_ack_o,
    output reg [31:0] wbs_dat_o,

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

    
wire clk;
wire rst;

wire ring_Osc_Output;
wire xor_out_sampledROs;
wire xor_out_analogROs;
wire rng_out_sampled_ROs;
wire rng_out_analog_ROs;
wire figaro_Osc_Output;
wire xor_out_sampledFIGAROs;
wire xor_out_analogFIGAROs;
wire rng_out_sampled_FIGAROs;
wire rng_out_analog_FIGAROs;

wire [11:0]probe ;
	
	//READ REGS WITH WISHBONE
	always @(posedge wb_clk_i) begin 
		if (wb_rst_i) begin
			wbs_dat_o <= 32'h0;
		end else if(wbs_stb_i && wbs_cyc_i && !wbs_we_i) begin
			case(wbs_adr_i[7:0])
				8'h04	: wbs_dat_o <= {20'b0,probe};
				default	: wbs_dat_o <= 32'h0;
			endcase
		end
	end
	
	// ACK WISHBONE
	always @(posedge wb_clk_i) begin 
		if (wb_rst_i) begin
			wbs_ack_o <= 1'b0;
		end else begin
			wbs_ack_o <= (wbs_stb_i && wbs_cyc_i);
		end
	end
 
    // IO
    assign irq = 3'b000;

    assign io_oeb = {(`MPRJ_IO_PADS-1){1'b1}};






    assign probe[0] = clk;
    assign probe[1] = ring_Osc_Output;
    assign probe[2] = xor_out_sampledROs;
    assign probe[3] = xor_out_analogROs;
    assign probe[4] = rng_out_sampled_ROs;
    assign probe[5] = rng_out_analog_ROs;
    assign probe[6] = clk;
    assign probe[7] = figaro_Osc_Output;
    assign probe[8] = xor_out_sampledFIGAROs;
    assign probe[9] = xor_out_analogFIGAROs;
    assign probe[10] = rng_out_sampled_FIGAROs;
    assign probe[11] = rng_out_analog_FIGAROs;

    assign io_out[11:0] = probe;
    assign io_out[19:12] = 8'b0;
    assign io_out[31:20] = probe;

    // LA
    assign la_data_out[11:0] = probe;
    assign la_data_out[31:12] = 20'b0;
    assign la_data_out[43:32] = probe;

    assign la_data_out[127:44] = 84'b0;

    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;

    
    entropy_RO entropy_RO(
        .clk_dff               (clk),
        .o_RO_out              (ring_Osc_Output),
        .o_xor_out_ROs_sampled (xor_out_sampledROs),
        .o_xor_out_ROs_analog  (xor_out_analogROs)
    );
        
    mydff dff_last_sampledRO(.clk(clk), .D(xor_out_sampledROs), .Q(rng_out_sampled_ROs));
    mydff dff_last_analogRO (.clk(clk), .D(xor_out_analogROs) , .Q(rng_out_analog_ROs));

    entropy_FIGARO entropy_FIGARO(
        .clk_dff               (clk),
        .o_FIGARO_out           (figaro_Osc_Output),
        .o_xor_out_FIGAROs_analog   (xor_out_sampledFIGAROs),
        .o_xor_out_FIGAROs_sampled   (xor_out_analogFIGAROs));  

    mydff dff_last_sampledFIGARO(.clk(clk), .D(xor_out_sampledFIGAROs), .Q(rng_out_sampled_FIGAROs));
    mydff dff_last_analogFIGARO (.clk(clk), .D(xor_out_analogFIGAROs) , .Q(rng_out_analog_FIGAROs));
   
    

endmodule


///////////////////////XORing 40 inverter ring oscillators with 15 inverters//////////////////////////////////////
module entropy_RO #(parameter nRO = 40 )(
    input clk_dff,
    output o_RO_out,
    output o_xor_out_ROs_sampled,
    output o_xor_out_ROs_analog    
    );
    
    wire [nRO:1] ro_out;
    wire [nRO:1] ro_out_sampled;
    wire xor_out_sampled;  
    wire xor_out_analog;

    assign o_RO_out = ro_out[1];
    assign o_xor_out_ROs_sampled = xor_out_sampled;
    assign o_xor_out_ROs_analog = xor_out_analog;

    genvar i;
    generate
    for (i=nRO; i>=1; i=i-1)begin
        ring_osc RO_gen(.osc_out(ro_out[i]));
        mydff dff_gen(.clk(clk_dff), .D(ro_out[i]), .Q(ro_out_sampled[i]));
    end
    endgenerate

    multi_xor #(
    .length(nRO)
    )xor_stage(
    .ros_i(ro_out_sampled),
    .rosx(xor_out_sampled)
    ); 
    
    multi_xor #(
    .length(nRO)
    )xor_stage_analog(
    .ros_i(ro_out),
    .rosx(xor_out_analog)
    );
endmodule
///////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////XORing 3 FIGAROs using poly3/////////////////////////////////////////////////////
module entropy_FIGARO #(parameter nFIGARO = 3 )(
    input clk_dff,
    output o_FIGARO_out,
    output o_xor_out_FIGAROs_analog,
    output o_xor_out_FIGAROs_sampled
    );
    
    wire [nFIGARO:1] o_figaro_outputs;
    wire xor_figaro_analog;
    wire [nFIGARO:1] figaro_outputs_sampled;    
    wire xor_figaro_sampled;

    assign o_xor_out_FIGAROs_sampled = xor_figaro_sampled;
    assign o_FIGARO_out = o_figaro_outputs[1];
    assign o_xor_out_FIGAROs_analog=xor_figaro_analog;
    
    genvar i;
    generate
    for (i=nFIGARO; i>=1; i=i-1)begin
       figaro_poly3 FIGARO_gen(.o_figaro(o_figaro_outputs[i]));
       mydff dff_gen(.clk(clk_dff), .D(o_figaro_outputs[i]), .Q(figaro_outputs_sampled [i]));
    end
    endgenerate
   
   multi_xor #(
     .length(nFIGARO)
     )xor_stage(
     .ros_i(figaro_outputs_sampled),
     .rosx(xor_figaro_sampled)
   ); 
    
   multi_xor #(
     .length(nFIGARO)
     )xor_stage_analog(
     .ros_i(o_figaro_outputs),
     .rosx(xor_figaro_analog)
   );

endmodule
//////////////////////////////////////////////////////////////////////////////////

////////////////Inverter ring oscillator with 15 inverters///////////////////////
module ring_osc(
    output osc_out
    );
  
   
   localparam [3:0] length = 4'd15;
   wire [length:0] del;
   assign del[0] = del[length]; 
    

    
   genvar i;
   generate 
   for (i=0; i<length; i=i+1)begin
      sky130_fd_sc_hd__inv_2 inverters (
        .A(del[i]),
        .Y(del[i+1])
      );
   end
   endgenerate
    
   assign osc_out = del[length];  
   
endmodule
///////////////////////////////////////////////////////////////////////////////////

/////////////D flip flop///////////////////////////////////////////////////////////
module mydff(
    input clk,
    input D,
    output Q
    );

reg Q_q;
assign Q = Q_q;
always @(posedge clk)                                                    
begin                                                                                               
    Q_q <= D;                                                                      
end
endmodule
/////////////////////////////////////////////////////////////////////////////////////

/////////////Multi input Xor /////////////////////////////////////////////
module multi_xor #(parameter length= 7)(
    input [length:1] ros_i,
    output rosx
    );
    
wire [length-1:1] Xor_out;
sky130_fd_sc_hd__xor2_4 xor_initial (
	.A(ros_i[1]),
	.B(ros_i[2]),
	.X(Xor_out[1])
);
genvar i;
generate 
   for (i=1; i<=length-2; i=i+1)begin
	sky130_fd_sc_hd__xor2_4 xors (
		.A(Xor_out[i]),
		.B(ros_i[i+2]),
		.X(Xor_out[i+1])
	);
   end
endgenerate

assign rosx = Xor_out[length-1];
endmodule
////////////////////////////////////////////////////////////////////////////


///////Figaro with polynomial poly3= x^15+x^14+x^7+x^6+x^5+x^4+^2+1////////////////
module figaro_poly3(
    output o_figaro
);

wire garoOut;
wire firoOut;

garo_poly3  garo(.o_garo(garoOut)); 
firo_poly3  firo(.o_firo(firoOut)); 

sky130_fd_sc_hd__xor2_4 xor_poly3 (
	.A(garoOut),
	.B(firoOut),
	.X(o_figaro)
);
endmodule
////////////////////////////////////////////////////////////////////////////


/////////Firo with polynomial x^15+x^14+x^7+x^6+x^5+x^4+^2+1////////////////
module firo_poly3(
    output o_firo
    );

localparam [7:0] length = 8'd15;
   
wire [length:0] f;
wire [5:1] fXor; 
assign o_firo = f[length];   

genvar i;
generate 
   for (i=0; i<length; i=i+1)begin
         sky130_fd_sc_hd__inv_2 inverters (
        .A(f[i]),
        .Y(f[i+1])
      );
   end
endgenerate

sky130_fd_sc_hd__xor2_4 xor_firo_1 (.A(f[15]), .B(f[14]), .X(fXor[5]));
sky130_fd_sc_hd__xor2_4 xor_firo_2 (.A(fXor[5]), .B(f[7]), .X(fXor[4]));
sky130_fd_sc_hd__xor2_4 xor_firo_3 (.A(fXor[4]), .B(f[6]), .X(fXor[3]));
sky130_fd_sc_hd__xor2_4 xor_firo_4 (.A(fXor[3]), .B(f[5]), .X(fXor[2]));
sky130_fd_sc_hd__xor2_4 xor_firo_5 (.A(fXor[2]), .B(f[4]), .X(fXor[1]));
sky130_fd_sc_hd__xor2_4 xor_firo_6 (.A(fXor[1]), .B(f[2]), .X(f[0]));


endmodule

/////////////////////////////////////////////////////////////////////////////////


/////garo with polynomial x^15+x^14+x^7+x^6+x^5+x^4+^2+1/////////////////////////
module garo_poly3(
    output o_garo
    );

localparam [7:0] length = 8'd20;
wire [length:0] f;
assign o_garo = f[0];     

sky130_fd_sc_hd__inv_2 inverter1 (.A(f[1]),.Y(f[0]));
sky130_fd_sc_hd__inv_2 inverter2 (.A(f[2]),.Y(f[1]));

sky130_fd_sc_hd__xor2_4 xor_garo_1 (.A(f[0]), .B(f[3]), .X(f[2]));

sky130_fd_sc_hd__inv_2 inverter3 (.A(f[4]),.Y(f[3]));
sky130_fd_sc_hd__inv_2 inverter4 (.A(f[5]),.Y(f[4]));

sky130_fd_sc_hd__xor2_4 xor_garo_2 (.A(f[0]), .B(f[6]), .X(f[5]));

sky130_fd_sc_hd__inv_2 inverter5 (.A(f[7]),.Y(f[6]));

sky130_fd_sc_hd__xor2_4 xor_garo_3 (.A(f[0]), .B(f[8]), .X(f[7]));

sky130_fd_sc_hd__inv_2 inverter6 (.A(f[9]),.Y(f[8]));

sky130_fd_sc_hd__xor2_4 xor_garo_4 (.A(f[0]), .B(f[10]), .X(f[9]));

sky130_fd_sc_hd__inv_2 inverter7 (.A(f[11]),.Y(f[10]));

sky130_fd_sc_hd__xor2_4 xor_garo_5 (.A(f[0]), .B(f[12]), .X(f[11]));

sky130_fd_sc_hd__inv_2 inverter8 (.A(f[13]),.Y(f[12]));
sky130_fd_sc_hd__inv_2 inverter9 (.A(f[14]),.Y(f[13]));
sky130_fd_sc_hd__inv_2 inverter10 (.A(f[15]),.Y(f[14]));                          
sky130_fd_sc_hd__inv_2 inverter11 (.A(f[16]),.Y(f[15]));
sky130_fd_sc_hd__inv_2 inverter12 (.A(f[17]),.Y(f[16]));
sky130_fd_sc_hd__inv_2 inverter13 (.A(f[18]),.Y(f[17]));
sky130_fd_sc_hd__inv_2 inverter14 (.A(f[19]),.Y(f[18]));

sky130_fd_sc_hd__xor2_4 xor_garo_6 (.A(f[0]), .B(f[20]), .X(f[19]));

sky130_fd_sc_hd__inv_2 inverter15 (.A(f[0]),.Y(f[20]));

endmodule
////////////////////////////////////////////////////////////////////////////////////





