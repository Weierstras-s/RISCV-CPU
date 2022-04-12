`timescale 1ns / 1ps

`include "include.vh"


module Syscall (
    input clk, input rst, input ecall,
    input int A, input int B,
    output int eret,
    // IN
    input int keyInfo,
    // OUT
    output int ledData, output bit nHalt,
    output bit dispClk, output int dispInfo
);
    int romData;
    ROM #(.PATH(`PROG_PATH(test/data)), .SIZE(12)) rom (B, romData);
    

    initial begin
        nHalt <= 1;
        dispClk <= 1;
    end
    always @(posedge clk) begin
        if (rst) begin
            ledData <= 0;
            nHalt <= 1;
            dispClk <= 1;
        end
        else if (ecall) begin
            case (A)
                'h0a: nHalt <= 0;
                'h22: begin
                    ledData <= B;
                    $display("%08x", B);
                end
                'h82: begin
                    dispClk <= 0;
                    dispInfo <= B;
                end
            endcase
        end
        else begin
            dispClk <= 1;
        end
    end
    always @* begin
        case (A)
            'h80: eret <= keyInfo;
            'h81: eret <= romData;
            default: eret <= 0;
        endcase
    end
endmodule

