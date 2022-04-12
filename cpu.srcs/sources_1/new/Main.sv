`timescale 1ns / 1ps

`include "include.vh"


module Clock #(
    parameter T = 27
) (
    input rawClk,
    output clk
);
    int cnt;
    assign clk = cnt[T];
    always @(posedge rawClk) cnt <= cnt + 1;
endmodule

module SegDecoder (
    input [3:0] digit,
    output bit [7:0] seg
);
    always @* begin
        case (digit)
            4'b0000 : seg[7:0] <= 8'b11000000;
            4'b0001 : seg[7:0] <= 8'b11111001;
            4'b0010 : seg[7:0] <= 8'b10100100;
            4'b0011 : seg[7:0] <= 8'b10110000;
            4'b0100 : seg[7:0] <= 8'b10011001;
            4'b0101 : seg[7:0] <= 8'b10010010;
            4'b0110 : seg[7:0] <= 8'b10000010;
            4'b0111 : seg[7:0] <= 8'b11111000;
            4'b1000 : seg[7:0] <= 8'b10000000;
            4'b1001 : seg[7:0] <= 8'b10011000;
            4'b1010 : seg[7:0] <= 8'b10001000;
            4'b1011 : seg[7:0] <= 8'b10000011;
            4'b1100 : seg[7:0] <= 8'b11000110;
            4'b1101 : seg[7:0] <= 8'b10100001;
            4'b1110 : seg[7:0] <= 8'b10000110;
            default : seg[7:0] <= 8'b10001110;
        endcase
    end
endmodule

module HexDisplay #(
    parameter T = 16
) (
    input rawClk,
    input int num,
    output bit [7:0] an,
    output [7:0] seg
);
    bit clk;
    Clock #(.T(T)) clkDiv (rawClk, clk);
    
    int pos;
    bit [3:0] digit;
    SegDecoder decoder (digit, seg);
    
    always @(posedge clk) begin
        pos <= pos == 7? 0 : pos + 1;
        an <= ~(1 << pos);
        digit <= num >> (pos << 2);
    end
endmodule


/*
2: L
3: R
4: M
*/
module MouseRecv (
    inout ioClk,
    inout ioData,
    output bit intReq,
    output int info
);
    
    bit clk, data;
    always @* begin
        clk <= ioClk == 1'bz ? 1 : ioClk;
        data <= ioData == 1'bz ? 1 : ioData;
    end
    
    bit [43:0] buffer;
    initial buffer <= {1'd1, 43'd0};
    always @(negedge clk) begin
        if (buffer[0]) begin
            intReq <= 1;
            buffer <= {1'd1, 43'd0};
            // status, dx, dy, dm
            info <= {buffer[9:2], buffer[20:13], buffer[31:24], buffer[42:35]};
        end
        else begin
            intReq <= 0;
            buffer <= {data, buffer[43:1]};
        end
    end
endmodule

/*
D: 23
F: 2b
J: 3b
K: 42
*/
module KeyboardRecv (
    inout ioClk,
    inout ioData,
    output bit intDown,
    output bit intUp,
    output int info
);
    
    assign ioClk = 1'bz;
    assign ioData = 1'bz;
    bit clk, data;
    always @* begin
        clk <= ioClk == 1'bz ? 1 : ioClk;
        data <= ioData == 1'bz ? 1 : ioData;
    end
    
    bit [10:0] buffer;
    bit keyUp;
    
    initial buffer <= {1'd1, 10'd0};
    
    always @(negedge clk) begin
        if (buffer[0]) begin
            if (buffer[9:2] == 'hf0) begin
                keyUp <= 1;
            end
            else begin
                if (!buffer[9]) begin
                    if (keyUp) intUp <= 1;
                    else intDown <= 1;
                    info <= buffer[9:2];
                end
                keyUp <= 0;
            end
            
            buffer <= {1'd1, 10'd0};
        end
        else begin
            intDown <= 0;
            intUp <= 0;
            buffer <= {data, buffer[10:1]};
        end
    end
endmodule



/*
pipeline: 1
basic: 2
1e-6s: 7
1e-5s: 10
1s: 27
*/


module Main(
    input bit CLK100MHZ,
    input RESETN,
    input [15:0] SW,
    input [4:0] BTN,
    
    inout PS2_CLK,
    inout PS2_DATA,
    
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,
    output VGA_HS,
    output VGA_VS,
    
    output [7:0] AN,
    output [7:0] SEG,
    output [15:0] LED
);

    int intReq;
    
    
    // CLOCK INT (0)
    bit clockInt;
    assign intReq[0] = clockInt;
    int cnt;
    always @(posedge CLK100MHZ) begin
        if (cnt < 50_000) cnt <= cnt + 1;
        else begin
            cnt <= 0;
            clockInt <= !clockInt;
        end
    end
    
    
    // KEYBOARD INT (1: DOWN, 2: UP)
    bit keyDownInt, keyUpInt;
    assign intReq[1] = keyDownInt;
    assign intReq[2] = keyUpInt;
    int keyInfo;
    KeyboardRecv keyboard (PS2_CLK, PS2_DATA, keyDownInt, keyUpInt, keyInfo);

    
    
    // LED
    int ledData;
    HexDisplay #(.T(16)) display (CLK100MHZ, ledData, AN, SEG);
    
    
    // VGA
    bit dispClk;
    int vgaX, vgaY, color, dispInfo;
    VGA vga (
        CLK100MHZ, !RESETN,
        VGA_R, VGA_G, VGA_B,
        VGA_HS, VGA_VS,
        vgaX, vgaY, color
    );
    Screen screen (vgaX, vgaY, color, dispClk, dispInfo);
    
    
    
    
    // CPU
    bit clk, rst, nHalt;
    assign rst = !RESETN;
    Clock #(.T(2)) clkDiv (CLK100MHZ, clk);
    CPUPipeline #(.PATH(`PROG_PATH(test/main)), .SIZE_RAM(8)) cpu (
        clk, rst, intReq,
        keyInfo,
        ledData, nHalt,
        dispClk, dispInfo,
        LED[15:1]
    );
    
    assign LED[0] = nHalt;
endmodule
