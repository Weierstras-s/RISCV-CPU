`timescale 1ns / 1ps


module VGA (
    input rawClk,
    input rst,
    
    output bit [3:0] R,
    output bit [3:0] G,
    output bit [3:0] B,
    
    output bit HS,
    output bit VS,
    
    output int x,
    output int y,
    input int color
);

    localparam HPW = 112;
    localparam HFP = 48;
    localparam Width = 1280;
    localparam HMax = 1688;
    
    localparam VPW = 3;
    localparam Height = 1024;
    localparam VFP = 1;
    localparam VMax = 1066;
    
    localparam Boarder = 3;
    
    
    int RGB;
    assign {R, G, B} = RGB;
    
    // Horizontal counter
    always @(posedge rawClk) begin
        if (rst) x <= 0;
        else begin
            if (x < HMax - 1) x <= x + 1;
            else x <= 0;
        end
    end
    
    always @(posedge rawClk) begin
        if (rst) HS <= 1;
        else begin
		    if (x >= HFP + Width - 1 && x < HFP + Width + HPW - 1) HS <= 0;
		    else HS <= 1;
		end
    end
    
    // Vertical counter
    always @(posedge rawClk) begin
        if (rst) y <= 0;
        else begin
            if (x == HMax - 1) begin
                if (y < VMax - 1) y <= y + 1;
                else y <= 0;
            end
            else y <= y;
        end
    end
    
    always @(posedge rawClk) begin
        if (rst) VS <= 1;
        else begin
            if (y >= VFP + Height - 1 && y < VFP + Height + VPW - 1) VS <= 0;
            else VS <= 1;
        end
    end
    
    always @(posedge rawClk) begin
        if (rst) RGB <= 0;
        else begin
            if (y < Height - Boarder && y >= Boarder
                && x < Width - Boarder && x >= Boarder)
                RGB <= color;
            else if (x < Width && y < Height) RGB <= 'h111;
            else RGB <= 0;
        end
    end
endmodule


module Color (
    input bit [3:0] colorID,
    output int color
);
    always @* case (colorID)
        1: color <= 'hfff;
        2: color <= 'hccc;
        3: color <= 'h0f0;
        4: color <= 'h0c0;
        5: color <= 'hff0;
        6: color <= 'hdd0;
        7: color <= 'hf00;
        8: color <= 'hd00;
        default: color <= 'h111;
    endcase
endmodule


module Screen (
    input int x,
    input int y,
    output int color,
    
    input bit clk,
    input int info
);
    bit [159:0][127:0][3:0] current, done;
    
    int rx, ry;
    bit [3:0] colorID;
    Color colorCvt (colorID, color);
    always @* begin
        rx = x >> 3;
        ry = (1023 - y) >> 3;
        colorID = done[rx][ry];
    end
    
    always @(posedge clk) begin
        if (info[31]) begin
            done <= current;
            current <= 0;
        end
        else begin
//            current[info[20:4]] <= info[3:0];
            current[info[18:11]][info[10:4]] <= info[3:0];
//            for (int i = 0; i < 8; ++i) begin
//                if (current[info[21 + i]]) begin
//                    current[info[20:12] + i][info[11:4]] <= info[3:0];
//                end
//            end
        end
    end
endmodule

