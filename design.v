`timescale 1ns / 1ps

module MIPS32(clk1, clk2);

input clk1, clk2;

// here we are defining variable required for the 5 stage of execution
/*
Stage - 1: IF , instruction fetching stage
Stage - 2: ID , instruction decoding stage
Stage - 3: EX , Instruction execution stage
Stage - 4: MEM , Memory stage
Stage - 5: WB , Writting stage
*/

/* Instruction register format
    - Total 32 bits
    - 31:26 -> opcode
    - 25:21 -> rs
    - 20:16 -> rt
    - 15:11 -> rd
*/ 


// For stage - 1
// All are 32 bit values
reg [31:0] PC, IF_ID_IR, IF_ID_NPC;
reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm;

// After fetching the instruction it will be storing inside the IF_ID_IR memory
// from their we will decode the first 6 bit which is the opcode
// The type means after decoding the first 6 bit we can know that the instruction is add/sub/mul etc...
reg [2:0] ID_EX_type, EX_MEM_type, MEM_WB_type;
reg [31:0] EX_MEM_IR, EX_MEM_ALUout, EX_MEM_B;

// This is used for JUMP or BRANCH condition
reg EX_MEM_cond;
reg [31:0] MEM_WB_IR, MEM_WB_ALUout, MEM_WB_LMD;

// Register Bank
reg [31:0] Reg [0:31];

// 1024 X 32 memory
reg [31:0] Mem [0:1023];

// Declaring the ALU parameter.
parameter ADD=6'b000000, SUB=6'b000001, AND=6'b000100, OR=6'b000011, SLT=6'b000100, MUL=6'b000101, HLT=6'b111111,
          LW=6'b001000, SW=6'b001001, ADDI=6'b001010, SUBI=6'b001011, SLTI=6'b001100, BNEQZ=6'b001101, BEQZ=6'b001110;
          
 // Types
 parameter RR_ALU=3'b000, RM_ALU=3'b001, LOAD=3'b010, STORE=3'b011, BRANCH=3'b100, HALT=3'b101;

// HALT flag
//  set after the halt instruction is completed (in WB stage)
reg HALTED;

// Branch checking flag;
// required to disable instruction after branch when it is set
reg TAKEN_BRANCH;

// ------------------- Stage - 1 IF stage -------------------------------
always @ (posedge clk1)
    begin
        if(HALTED)
            begin
                if(((EX_MEM_IR[31:26] == BEQZ) && EX_MEM_cond == 1)||((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond == 0)))
                    begin
                        IF_ID_IR <= #2 Mem[EX_MEM_ALUout];
                        TAKEN_BRANCH <= #2 1'b1;
                        IF_ID_NPC <= #2 EX_MEM_ALUout + 1;
                        PC <= #2 EX_MEM_ALUout + 1; 
                    end
                else 
                    begin
                        IF_ID_IR <= #2 Mem[PC];
                        IF_ID_NPC <= #2 PC + 1;
                        PC <= #2 PC + 1;
                    end
            end
    end
    
// ------------------- Stage - 2 ID stage -------------------------------
/* 
- In ID stage their are mainly three operation are happening
    - Decoding the instruction 
    - prefetching the two source register
    - sign extending the 16 bit offset. 
*/

always @ (posedge clk2)
    begin
        if(HALTED)
            begin
            // checking whether the RS data is Zero or not, if 0 A will be 0;
                if(IF_ID_IR[25:21] == 5'b00000)
                    begin
                        ID_EX_A <= 0;
                    end
           // If not zero we will input the RS data to A         
                else
                    begin
                        ID_EX_A <= #2 Reg[IF_ID_IR[25:21]]; 
                    end
            // checking whether the RT data is Zero or not, if 0: B will be 0;
                if(IF_ID_IR[20:16] == 5'b00000)
                    begin
                        ID_EX_B <= 0;
                    end
           // If not zero we will input the RT data to B         
                else
                    begin
                        ID_EX_B <= #2 Reg[IF_ID_IR[20:16]]; 
                    end
          ID_EX_NPC <= #2 IF_ID_NPC;
          ID_EX_IR <= #2 IF_ID_IR;
          // Sign extension process
          ID_EX_Imm <= #2 {{16{IF_ID_IR[15]}}, {IF_ID_IR[15:0]}};
            end
       case(IF_ID_IR[31:26])
            ADD, SUB, AND, OR, SLT, MUL: ID_EX_type <= #2 RR_ALU;
            ADDI, SUBI, SLTI: ID_EX_type <= #2 RM_ALU;
            LW: ID_EX_type <= #2 LOAD;
            SW: ID_EX_type <= #2 STORE;
            BNEQZ, BEQZ: ID_EX_type <= #2 BRANCH;
            HLT: ID_EX_type <= #2 HALT;
            default: ID_EX_type <= #2 HALT;
       endcase
       
    end


// ------------------- Stage - 3 EX stage -------------------------------
always @ (posedge clk1)
    begin
        if(HALTED)
            begin
                EX_MEM_type <= #2 ID_EX_type;
                EX_MEM_IR <= #2 ID_EX_IR;
                TAKEN_BRANCH <= #2 0;
                
                case(ID_EX_type)
                    RR_ALU: begin
                                case(ID_EX_IR[31:26])
                                    ADD: EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_B;
                                    SUB: EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_B;
                                    AND: EX_MEM_ALUout <= #2 ID_EX_A & ID_EX_B;
                                    OR: EX_MEM_ALUout <= #2 ID_EX_A | ID_EX_B;
                                    SLT: EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_B;
                                    MUL: EX_MEM_ALUout <= #2 ID_EX_A * ID_EX_B;
                                    default: EX_MEM_ALUout <= 32'hxxxxxxxx;
                                endcase
                            end
                    RM_ALU: begin
                                case(ID_EX_IR[31:26])
                                    ADDI: EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_B;
                                    SUBI: EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_B;
                                    SLTI: EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_B;
                                    default: EX_MEM_ALUout <= #2 32'hxxxxxxxx;
                                endcase
                            end
                    LOAD, STORE: begin
                                    EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_B;
                                    EX_MEM_B <= #2 ID_EX_B;
                                 end
                    BRANCH: begin
                                EX_MEM_ALUout <= #2 ID_EX_NPC + ID_EX_Imm;
                                EX_MEM_cond <= #2 (ID_EX_A == 0);
                            end
                
                endcase
            end
    end

// ------------------- Stage - 4 MEM stage -------------------------------
always @ (posedge clk2)
    begin
        if(HALTED == 0)
            begin
                MEM_WB_type <= #2 EX_MEM_type;
                MEM_WB_IR <= #2 EX_MEM_IR;
            end
            
            case(EX_MEM_type)
                RR_ALU, RM_ALU: 
                            MEM_WB_ALUout <= #2 EX_MEM_ALUout;
                LOAD:
                    MEM_WB_LMD <= #2 Mem[EX_MEM_ALUout];
                STORE: if(TAKEN_BRANCH == 0)
                            begin
                                Mem[EX_MEM_ALUout] <= EX_MEM_B;
                            end
            endcase
    end
    
// ------------------- Stage - 5 WB stage -------------------------------
always @ (posedge clk1)
    begin
        if(TAKEN_BRANCH == 0)
            begin
                case(MEM_WB_type)
                    RR_ALU: Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUout;
                    RM_ALU: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUout;
                    LOAD: Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_LMD;
                    HLT: HALTED <= 1'b1;
                endcase
            end
    end

endmodule

