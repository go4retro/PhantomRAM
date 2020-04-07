`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:          RETRO Innovations
// Engineer:         Jim Brain
// 
// Create Date:      18:30:27 02/25/2020 
// Design Name: 
// Module Name:      PhantomRAM
// Project Name:     PhantomRAM
// Target Devices:   XC95288XL
// Tool versions:    14.7
// Description:      DMA-based RAM Expansion unit for the TANDY Color Computer
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module PhantomRAM(
                  input clock,
                  input _reset_cpu,
                  input e_cpu, 
                  input q_cpu,
                  inout r_w_cpu, 
                  input _scs,
                  input _cts,
                  output _slenb,
                  output _cart,
                  output _halt,
                  output _nmi,
                  inout [15:0]address_cpu, 
                  inout [7:0]data_cpu,
                  output _enbus,
                  output [18:0]address_mem,
                  inout [7:0]data_mem,
                  output _we_mem,
                  output _ce_flash,
                  output _ce_ram,
                  output led,
                  output [7:0]test
                 );

`define TEST 1

`ifdef TEST
wire ce_test;
`endif
wire ce_reg;
reg [15:0]address_cpu_out;
reg [7:0]data_cpu_out;
reg [7:0]data_mem_out;
reg flag_halt;
reg flag_dma;
reg flag_knock;
reg flag_cc3;
reg r_w_cpu_out;
reg [23:0]address_mem_out;
reg [15:0]address_sys;
reg [15:0]len;
reg e_qual;
reg q_qual;

reg flag_write;
reg flag_active;
reg flag_mem_hold;
reg flag_sys_hold;
wire ce_knock;
wire ce_knock2;
reg flag_run;
wire mode_cc3;

assign test[0] = 0;
assign test[1] = _halt;
assign test[2] = 0;
assign test[3] = 0;
assign test[4] = 0;
assign test[5] = 0;
assign test[6] = 0;
assign test[7] = 0;

assign _cart =                         'bz;
assign _nmi =                          'bz;
assign _ce_flash =                     1;
assign _enbus =                        1;

assign _halt =                         (flag_active & flag_halt ? 0 : 'bz);
`ifdef TEST
assign _ce_ram =                       !(ce_test | flag_dma);
assign _we_mem =                       !((ce_test & !r_w_cpu) | (flag_dma & !flag_write));
`else
assign _ce_ram =                       !flag_dma;
assign _we_mem =                       !(flag_dma & !flag_write); 
`endif
assign led =                           flag_dma;

assign ce_reg =                        (address_cpu[15:4] == 12'hff6);
assign ce_addre =                      ce_reg & (address_cpu[3:0] == 0);
assign ce_addrh =                      ce_reg & (address_cpu[3:0] == 1);
assign ce_addrl =                      ce_reg & (address_cpu[3:0] == 2);
//assign ce_adde_sys =                   ce_reg & (address_cpu[3:0] == 3);
assign ce_addrh_sys =                  ce_reg & (address_cpu[3:0] == 4);
assign ce_addrl_sys =                  ce_reg & (address_cpu[3:0] == 5);
//assign ce_lene =                       ce_reg & (address_cpu[3:0] == 6);
assign ce_lenh =                       ce_reg & (address_cpu[3:0] == 7);
assign ce_lenl =                       ce_reg & (address_cpu[3:0] == 8);
assign ce_ctrl =                       ce_reg & (address_cpu[3:0] == 9);
`ifdef TEST
assign ce_test =                       ce_reg & (address_cpu[3:0] == 10);
`endif

assign ce_knock =                      ce_lenh;
assign ce_knock2 =                     ce_lenl;

assign data_cpu =                      data_cpu_out;
assign r_w_cpu =                       r_w_cpu_out;
assign address_cpu =                   address_cpu_out;
assign data_mem =                      data_mem_out;
assign address_mem =                   address_mem_out;

assign _slenb =                        'bz;

assign mode_cc3 =                     (flag_cc3 & flag_dma & flag_write & !e_qual & !q_qual);

always @(posedge clock)
begin
   e_qual <= e_cpu;
   q_qual <= q_cpu;
end

/* 
 * Address is valid at start of Q, and start of E is 250nS before fall of Q,
 * so, let's just check address at start of E, bring HALT low then, and we'll
 * meet tPCS (200nS on 1MHz CPU)
 */
always @(posedge e_qual or negedge _reset_cpu)
begin
   if(!_reset_cpu)
      begin
         flag_halt <= 0;
         flag_knock <= 0;
         flag_run <= 0;
      end
   else if(!flag_dma & ce_knock)
      begin
         flag_halt <= 1;
         flag_knock <= 1;
      end
   else if(!flag_dma & ce_knock2 & flag_knock)
      begin
         flag_knock <= 0;
         flag_run <= 1;
      end
   else if(!flag_dma & !ce_knock2 && flag_knock)
      begin
         flag_knock <= 0;
         flag_halt <= 0;
      end
   else if(flag_dma & (!len))
      begin
         flag_halt <= 0;
         flag_knock <= 0;
         flag_run <= 0;
      end
end

always @(negedge e_qual)
begin
   flag_dma <= flag_active & flag_run;
end

always @(*)
begin
   if(e_qual & r_w_cpu & ce_addre)
      data_cpu_out = address_mem_out[23:16];
   else if(e_qual & r_w_cpu & ce_addrh)
      data_cpu_out = address_mem_out[15:8];
   else if(e_qual & r_w_cpu & ce_addrl)
      data_cpu_out = address_mem_out[7:0];
   else if(e_qual & r_w_cpu & ce_addrh_sys)
      data_cpu_out = address_sys[15:8];
   else if(e_qual & r_w_cpu & ce_addrl_sys)
      data_cpu_out = address_sys[7:0];
   else if(e_qual & r_w_cpu & ce_lenh)
      data_cpu_out = len[15:8];
   else if(e_qual & r_w_cpu & ce_lenl)
      data_cpu_out = len[7:0];
`ifdef TEST
   else if(e_qual & r_w_cpu & ce_test)
      data_cpu_out = data_mem;
`endif
   else if(mode_cc3 | (flag_dma & flag_write & !flag_cc3))
      data_cpu_out = data_mem;
   else
      data_cpu_out = 8'bz;
end

always @(*)
begin
   if(!flag_write & flag_dma)
      data_mem_out = data_cpu;
`ifdef TEST
   else if(ce_test & !r_w_cpu) // write to memory slow
      data_mem_out = data_cpu;
`endif      
   else
      data_mem_out = 8'bz;
end

always @(negedge e_qual or negedge _reset_cpu)
begin
   if(!_reset_cpu)
   begin
      flag_write <= 0;
      flag_mem_hold <= 0;
      flag_sys_hold <= 0;
      flag_active <= 0;
   end
   else if(ce_ctrl & !r_w_cpu)
   begin
      flag_write <= data_cpu[0];
      flag_mem_hold <= data_cpu[4];
      flag_sys_hold <= data_cpu[5];
      flag_cc3 <= data_cpu[6];
      flag_active <= data_cpu[7];
   end   
      
end

always @(negedge e_qual or negedge _reset_cpu)
begin
   if(!_reset_cpu)
      address_mem_out <= 0;
   else if(ce_addre & !r_w_cpu)
      address_mem_out[23:16] <= data_cpu;
   else if(ce_addrh & !r_w_cpu)
      address_mem_out[15:8] <= data_cpu;
   else if(ce_addrl & !r_w_cpu)
      address_mem_out[7:0] <= data_cpu;
   else if(flag_dma & !flag_mem_hold)
      address_mem_out <= address_mem_out + 1;
end

always @(negedge e_qual or negedge _reset_cpu)
begin
   if(!_reset_cpu)
      address_sys <= 0;
   else if(ce_addrh_sys & !r_w_cpu)
      address_sys[15:8] <= data_cpu;
   else if(ce_addrl_sys & !r_w_cpu)
      address_sys[7:0] <= data_cpu;
   else if(flag_dma & !flag_sys_hold)
      address_sys <= address_sys + 1;
end

always @(negedge e_qual or negedge _reset_cpu)
begin
   if(!_reset_cpu)
      len <= 0;
   else if(ce_lenh & !r_w_cpu)
      len[15:8] <= data_cpu;
   else if(ce_lenl & !r_w_cpu)
      len[7:0] <= data_cpu;
   else if(flag_run)
      len <= len - 1;
end

always @(*)
begin
   if(mode_cc3)
      address_cpu_out = 16'hffff;
   else if(flag_dma)
      address_cpu_out = address_sys;
   else
      address_cpu_out = 16'bz;
end

always @(*)
begin
   if(mode_cc3)
      r_w_cpu_out = 1; // read for a bit
   else if(flag_dma)
      r_w_cpu_out = !flag_write;
   else
      r_w_cpu_out = 'bz;
end


endmodule
