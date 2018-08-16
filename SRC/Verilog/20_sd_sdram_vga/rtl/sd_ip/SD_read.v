`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name:    SD_read 
//////////////////////////////////////////////////////////////////////////////////
module SD_read(
						input sdram_init_done,
						input SD_clk,
						output reg SD_cs,
						output reg SD_datain,
						input  SD_dataout,
						
						output reg [15:0]mydata_o,
						output myvalid_o,
						
						output [3:0] mystate_o,
						
						output data_come_o,
						
						input init,
						
						output reg [7:0] rx,
						
						output reg picture_store
    );
	 

reg en;
reg rx_valid;
reg [5:0] aa;	 
reg [21:0] cnt;

reg data_come;

reg myen;
reg [31:0] sec;                //SD��sec��ַ

assign data_come_o=data_come;

assign mystate_o=mystate;
assign myvalid_o=myvalid;
//assign mydata_o=mydata;

reg myvalid;
reg [15:0] mydata;

reg [11:0] sec_size;

reg [3:0] mystate;



parameter idle=4'd0;
parameter write=4'd1;
parameter write_wait=4'd2;
parameter read=4'd3;
parameter read_wait=4'd4;
parameter read_data=4'd5;
parameter read_done=4'd6;

parameter sec_length=12'd3072;    //total sector size of one picture : 1024 * 768 * 2 /512

parameter SADDR=32'd16448;        //��һ��ͼƬ��SD������ʼsector��ַ

	 
always @(posedge SD_clk)
begin
	rx[0]<=SD_dataout;
	rx[7:1]<=rx[6:0];
end

//����һ��block�������Ӧ������
always @(posedge SD_clk)
begin
	if(!SD_dataout&&!en)begin rx_valid<=1'b0; aa<=1;en<=1'b1;end      //�ȴ�SD_dataoutΪ��,SD_dataoutΪ��,��ʼ��������
   else if(en)	begin 
		if(aa<7) begin
			aa<=aa+1'b1; 
			rx_valid<=1'b0;
		end
		else begin
			aa<=0;
			en<=1'b0;
			rx_valid<=1'b1;            //�������8bit��,rx_valid�źſ�ʼ��Ч
		end
	end
	else begin en<=1'b0;aa<=0;rx_valid<=1'b0;end
end

reg [47:0] CMD17; //CMD17���ֽ�����

//reg [47:0] CMD24={8'h58,8'h00,8'h00,8'h00,8'h00,8'hff};

reg [7:0] CMDX;
reg [7:0] CMDY=8'hff;
reg [3:0] cnta;
                

always @(posedge SD_clk)
if(!init)
	begin
		mystate<=idle;
		CMD17<={8'h51,8'h00,8'h00,8'h00,8'h00,8'hff};
		data_come<=1'b0;
		picture_store<=1'b0;
		sec<=SADDR;
		mydata<=0;
		SD_cs<=1'b1;
		SD_datain<=1'b1;		
	end
else
	begin
	case(mystate)
		idle:	begin
				data_come<=1'b0;
				SD_cs<=1'b1;
				SD_datain<=1'b1;
				cnt<=22'd0;	
		      mydata<=0;		
				if((picture_store==1'b0) && (sdram_init_done==1'b1))       //���SD����ͼƬ��δд�뵽SDRAM��
					begin
						mystate<=read;
						CMD17<={8'h51,sec[31:24],sec[23:16],sec[15:8],sec[7:0],8'hff};
					end
				else
				   mystate<=idle;			
		end
		read: begin                    //����CMD17���� (single Block Read)			
			   data_come<=1'b0;
			   if(CMD17!=48'd0) begin
					SD_cs<=1'b0;
					SD_datain<=CMD17[47];
					CMD17<={CMD17[46:0],1'b0};     //��λ���
					myen<=1'b0;
					cnt<=22'd0;									
				end
				else begin 
				   if(rx_valid) begin          //�ȴ�Ӧ���ź�		
						cnt<=0;
						mystate<=read_wait;
					end
				end
		end
		read_wait: begin             //�ȴ��������ݵ���ʼλ,�͵�ƽ
			    myvalid<=1'b0;
			    if(!SD_dataout) begin 
				     mystate<=read_data;
					  cnta<=0;
					  data_come<=1'b1;
				 end
				 else data_come<=1'b0;
			end
		read_data: begin             //��ȡһ��Block��SD����ͼ��
			   data_come<=1'b0;
				if(cnt<256)	begin                         //����512��bytes, 256��16bit
			     if(cnta<15)	begin                      //����bit15
					   myvalid<=1'b0;
						mydata<={mydata[14:0],SD_dataout};
						cnta<=cnta+1'b1;
				  end
				  else begin
						myvalid<=1'b1;                       //����bit0~bit14
						mydata_o<={mydata[14:0],SD_dataout};
						cnta<=0;
						cnt<=cnt+1'b1;
				  end
				end
				else begin 
				   cnt<=0;
					mystate<=read_done;
					myvalid<=1'b0;
				end
		end
		read_done: begin               //һ��Block SD�������
			   data_come<=1'b0;
				if(cnt<22'd15) begin
					 SD_cs<=1'b1;
					 SD_datain<=1'b1;
					 cnt<=cnt+1'b1;
				 end
				 else begin 
				    cnt<=0;
					 mystate<=idle;
					 if (sec_size<sec_length) begin     //���ͼ��δ���� 
 					    picture_store<=1'b0;
                   sec <= sec + 1'b1;
						 sec_size <= sec_size +1'b1;
					 end	 
					 else	begin	 
					    picture_store<=1'b1;
					 end	 
				 end
			end
		default:mystate<=0;
		endcase		
	end					
	

endmodule