module logistic(
        clk, //100M
        rst,
        readClk;
        readData,
        readEn,
        writeData,
        writeEn,
        writeClk,
        rate,
        done,
        batchNum
    );

localparam Idle = 0;
localparam getXAndH = 1;
localparam getSigmoidH = 2;
localparam getYMinusH = 3;
localparam getXDM = 4;
localparam getXDM_MUL_HMY = 5;
localparam getLRGRAD = 6;
localparam getNTheta = 7;
input clk; //100M
input rst; //high
input [31:0] readData;
input readClk;
input [3:0] batchNum;
output readEn;
output [31:0] writeData;
output writeEn;
output writeClk;
output done;
output [9:0] rate;
wire dataInReady;
reg dataOutReady;
//get data input ready
reg readEnable;
reg xReady;
reg yReady;
reg writeEnable;
reg [99:0][783:0] X;//image batch
reg [783:0][9:0] Theta;//weight 
reg [99:0][9:0] y;//label
reg [9:0] xI; //index for x
reg [9:0] xJ;
reg [9:0] yI;//index for y
reg [9:0] yJ;
reg [9:0] tI; //index for Theta
reg [9:0] tJ;
reg [9:0] trI;
reg [9:0] trJ;
reg [10:0] iterate;//iterate times
reg randomlized;
reg [31:0] randomNum;
assign dataInReady = xReady & yReady;
assign readEn = readEnable;
assign writeEn = writeEnable;
assign writeClk = clk;
assign done = dataOutReady & rateForSuccess;
//control read
always@(posedge clk)
begin
    if(rst)
    begin
        xReady <= 0;
        yReady <= 0;
        readEnable <= 0;
        writeEnable <= 0;
        i <= 0;
        j <= 0;
        state <= 0;
        randomlized <= 0;
        trI <= 0;
        trJ <= 0;
        if(batchNum != 0)
        begin
            randomlized <= 1;
        end 
    end
    else
    begin
        if(!dataInReady && randomlized)
            readEnable <= 1;
        else
        begin
            readEnable <= 0;
        end
        if(!randomlized)
        begin 
         if(trJ == 9)
         begin
            if(trI == 783)
            begin 
                randomlized <= 1;
            end 
            else
            begin 
                trJ <= 0;
                trI <= trI + 1;
            end 
         end
         else
         begin
            trJ <= trJ + 1;
         end
         Theta[trI][trJ] <= randomNum;
     end 
    end 
end

always@(posedge readClk)
begin
    if(readEn)
    begin
        if(!xReady)
        begin
            if(xJ == 783)
            begin
                if(xI == 99)
                    xReady <= 1;
                else
                    xI <= xI + 1;
            end
            else
                xJ <= xJ + 1;
            x[xI][xJ] <= readData;
        end
        else if(!yReady)
        begin
            if(yJ == 9)
            begin
                if(yI == 9)
                    yReady <= 1;
                else
                    yI <= yI + 1;
            end
            else
                yJ <= yJ + 1;
            y[yI][yJ] <= readData;
        end
    end
    else
    begin
        xI <= 0;
        xJ <= 0;
        yI <= 0;
        yJ <= 0;
        tI <= 0;
        tJ <= 0;
    end
end
//write Theta
always@(posedge clk)
begin
    if(writeEn)
    begin
        if(!dataOutReady)
        begin
            if(tJ == 9)
            begin
                if(tI == 783)
                    dataOutReady <= 1;
                else
                    tI <= tI + 1;
            end
            else
                tJ <= tJ + 1;
            writeData <= Theta[tI][tJ];
        end
    end
end 
reg [9:0] cnt;
reg [9:0] index;
reg rateForSuccess;
assign rate = cnt;
always@(posedge clk)
begin 
    if(rst)
        cnt <= 0;
        index <= 0;
        rateForSuccess <= 0;
    else
    begin
        if(dataOutReady == 1)
        begin
            if(index<100)
            begin
                 if(sigmoid_h[index] == y[index])
                     cnt <= cnt+1;
             end
             else
                 rateForSuccess <= 1;

        end
    end
end
//trainging
reg [783:0][99:0] xTrans;
reg [99:0][9:0] negY;
reg [99:0][9:0] h;
reg [99:0][9:0] h_buffer;
reg [99:0][9:0] sigmoid_h;
reg [99:0][9:0] sigmoid_h_buffer;
reg [99:0][9:0] h_minus_y;
reg [99:0][9:0] h_minus_y_buffer;
reg [783:0][99:0] xTransDivM;
reg [783:0][99:0] xTransDivM_buffer;
reg [783:0][9:0] grad;
reg [783:0][9:0] grad_buffer;
reg [31:0] oneDivM;
reg [31:0] lr;
reg [783:0][9:0] Theta_buffer;
reg [783:0][9:0] negLrGrad;
reg [783:0][9:0] lrGrad;
reg [783:0][9:0] lrGrad_buffer;


reg [3:0] state; //0 wait, 1 calculate x' h, 2. get sigmoid_h 3 get (h - y) ,4 get 1/m * x', 5 get (1/m) * x' * (h-y), 6 get lr*grad, 7 get new Theta
reg getH = 1;
reg input_Theta_Stable;
reg input_xTransDivM_stb;
reg input_HMY_stb;
reg getGrad;
reg input_ThetaR_stb;
reg input_grad_stb;
reg input_lr_stb;
reg input_lrGrad_stb;
reg getLrGrad;
reg getNewTheta;
reg input_sigmoid_h_stb;
reg getSigmoid;
wire input_sigmoid_h_stb;
wire output_sigmoid_h_stb;
wire input_ThetaR_ack;
wire input_lrGrad_ack;
wire input_grad_ack;
wire input_lr_ack;
wire output_lrGrad_stb;
wire output_newTheta_stb;
wire input_xTransDivM_ack;
wire input_HMY_ack;
wire output_Grad_stb;
wire input_x_ack;
wire input_Theta_ack;
wire output_h_stb;
reg input_h_stable;
reg getYMH;
reg input_oneDivM_stb;
reg input_xTrans_stb;
reg getXtransDivM;
wire input_y_ack;
wire input_h_ack;
wire output_YMH_stable;
wire input_oneDiveM_ack;
wire input_xTrans_ack;
wire output_xTransDivM_stable;
always@(posedge clk)
begin
    case(state)
    Idle:begin
        if(dataInReady || rst)
        begin 
            iterate <= iterate + 1;
            state <= 1;
            Theta <= 7840'b0;
            input_Theta_Stable <= 1;
            getH <= 0;
            input_h_stable <= 0;
            getYMH <= 0;
            oneDivM <= 32'b00111100001000111101011100001010;
            input_oneDivM_stb <= 1;
            getXtransDivM <= 0;
            input_xTrans_stb <= 1;
            input_xTransDivM_stb <= 0;
            input_HMY_stb <= 0;
            getGrad <= 0;
            input_grad_stb <= 0;
            input_lr_stb <= 1;
            lr <= 32'b00111000110100011011011100010111;
            getLrGrad <= 0;
            getNewTheta <= 0;
            input_ThetaR_stb <= 0;
            input_lrGrad_stb <= 0;
            input_sigmoid_h_stb <= 0;
            getSigmoid <= 0;
        end
        else
            iterate <= 0;

    end
    getXAndH:begin
        if(input_x_ack && input_Theta_ack && output_h_stb)
        begin
            h <= h_buffer;
            getH <= 1;
            input_Theta_Stable <= 0;
            state <= 2;
            input_sigmoid_h_stb <= 1;
        end
    end
    getSigmoidH:begin
        if(input_sigmoid_h_ack && output_sigmoid_h_stb)
        begin
            sigmoid_h <= sigmoid_h_buffer;
            input_h_stb <= 1;
            state <= 3;
        end
    end
    getYMinusH:begin
        if(input_y_ack && input_h_ack && output_YMH_stable)
        begin
            h_minus_y <= h_minus_y_buffer;
            getYMH <= 1;
            input_h_stable <= 0;
            state <= 4;
        end
    end
    getXtransDivM:begin
        if(input_oneDiveM_ack && input_xTrans_ack && output_xTransDivM_stable)
        begin
            xTransDivM <= xTransDivM_buffer;
            getXtransDivM <= 1;
            input_xTrans_stb <= 0;
            state <= 5;
            input_xTransDivM_stb <= 1;
            input_HMY_stb <= 1;
        end
    end
    getXDM_MUL_HMY:begin
        if(input_xTransDivM_ack && input_HMY_ack && output_Grad_stb)
        begin
            grad <= grad_buffer;
            state <= 6;
            input_grad_stb <= 1; 
        end
    end
    getLRGRAD:begin
        if(input_grad_ack && input_lr_ack && output_lrGrad_stb)
        begin
            lrGrad <= lrGrad_buffer;
            getLrGrad <= 1;
            state <= 7;
            input_lrGrad_stb <= 1;
            input_ThetaR_stb <= 1;
            getNewTheta <= 0;
        end 
    end
    getNTheta:begin
        if(input_lrGrad_ack && input_Theta_ack && output_newTheta_stb)
        begin
            if(iterate < 2001)
            begin
                state <= 0;
                Theta <= Theta_buffer;
            end
            else
                writeEnable <= 1;
        end
end
mat_transpose #(.M(100), .N(784)) get_xTrans(
    .input_a(x),
    .output_at(xTrans)
);

mat_opposite #(.M(100), .N(10)) get_OppoY(
    .input_a(y),
    .output_at(negY)
);

mat_opposite #(.M(784), .N(10)) negLrGrad(
    .input_a(lrGrad),
    .output_at(negLrGrad)
);
mat_product #(.M(100), .N(784), .P(10)) get_H(
    .clk(clk),
    .rst(rst),
    .input_a(x),
    .input_b(Theta),
    .input_a_stb(dataInReady),
    .input_b_stb(input_Theta_Stable),
    .output_z_ack(getH),
    .input_a_ack(input_x_ack),
    .input_b_ack(input_Theta_ack),
    .output_z(h_buffer),
    .output_z_stb(output_h_stb)
);
mat_sum #(.M(100),(10)) get_YMH(
    .clk(clk),
    .rst(rst),
    .input_a(negY),
    .input_b(sigmoid_h),
    .input_a_stb(dataInReady),
    .input_b_stb(input_h_stable),
    .output_z_ack(getYMH),
    .input_a_ack(input_y_ack),
    .input_b_ack(input_h_ack),
    .output_z(h_minus_y_buffer),
    ,output_z_stb(output_YMH_stable)
);
mat_mul_scalar #(.M(784), .N(100)) get_xT_D_M(
    .clk(clk),
    .rst(rst),
    .input_k(oneDivM),
    .input_mat(xTrans),
    .input_k_stb(input_oneDivM_stb),
    .input_mat_stb(input_xTrans_stb),
    .output_z_ack(getXtransDivM),
    .input_k_ack(input_oneDiveM_ack),
    .input_mat_stb(input_xTrans_ack),
    .output_z(xTransDivM_buffer),
    .output_z_stb(output_xTransDivM_stable)
);

mat_product #(.M(784),.N(100),.P(10)) get_grad(
    .clk(clk),
    .rst(rst),
    .input_a(xTransDivM),
    .input_b(h_minus_y),
    .input_a_stb(input_xTransDivM_stb),
    .input_b_stb(input_HMY_stb),
    .output_z_ack(getGrad),
    .input_a_ack(input_xTransDivM_ack),
    .input_b_ack(input_HMY_ack),
    .output_z(grad_buffer),
    .output_z_stb(output_Grad_stb)
);
mat_mul_scalar #(.M(784), .N(10)) getLrGrad(
    .clk(clk),
    .rst(rst),
    .input_k(lr),
    .input_mat(grad),
    .input_k_stb(input_lr_stb),
    .input_mat_stb(input_grad_stb),
    .output_z_ack(getLrGrad),
    .input_k_ack(input_lr_ack),
    .input_mat_ack(input_grad_ack),
    .output_z(lrGrad_buffer),
    .output_z_stb(output_lrGrad_stb)
);
mat_sum #(.M(784), .N(10)) getNewTheta(
    .clk(clk),
    .rst(rst),
    .input_a(Theta),
    .input_b(negLrGrad),
    .input_a_stb(input_ThetaR_stb),
    .input_b_stb(input_lrGrad_stb),
    .output_z_ack(getNewTheta),
    .input_a_ack(input_ThetaR_ack),
    .input_b_ack(input_lrGrad_ack),
    .output_z(Theta_buffer),
    .output_z_stb(output_newTheta_stb)
);
mat_sigmoid #(.M(784), .N(10)) get_sigmoidH(
    .clk(clk),
    .rst(rst),
    .input_mat(h),
    .input_mat_stb(input_sigmoid_h_stb),
    .output_z_ack(getSigmoid),
    .input_mat_ack(input_sigmoid_h_ack),
    ,output_z(sigmoid_h_buffer),
    .output_z_stb(output_sigmoid_h_stb)
);
rng rand(
    .clk(clk),
    .rst(rst),
    .seed(32'h0AFB3245),
    .rnd(randomNum)
);

