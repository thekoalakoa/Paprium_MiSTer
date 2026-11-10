// Paprium port-2 return pipeline. No request, SDRAM command, or port-0/1 timing
// changes here. Both sides use clk_ram; clk_sys consumes the paired word/toggle
// on its first edge after this stage. The initial ack matches the FPGA's raw
// SDRAM ack2 power-up level. Data has no meaning until a transaction completes.
module paprium_p2_return (
    input clk_ram,
    input [15:0] data_in,
    input ack_in,
    (* preserve *) output reg [15:0] data_out,
    (* preserve *) output reg ack_out = 1'b0
);
    // Keep a real fabric stage between the I/O capture and clk_sys consumers.
    // This also prevents physical retiming from moving ack independently.
    // synthesis translate_off
    // Simulation checks live in tests/timing_closure_030; no simulation delays.
    // synthesis translate_on
    always @(posedge clk_ram) begin
        data_out <= data_in;
        ack_out <= ack_in;
    end
endmodule
