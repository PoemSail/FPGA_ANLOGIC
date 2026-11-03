`timescale 1ns/1ps
module tb;
reg clk=0,rst=0,pir=1,commit=1,kvalid=0,eset=0,eclear=0,fault=0;
reg[3:0] code=0;reg[2:0] short_key=0,long_key=0;
always #5 clk=~clk;
wire enter,leave,selected,playing,normal_playing,alert,tick,warm,motion,service;
wire[1:0] scene,request,media;wire[2:0] menu;
integer checks=0;
station_user_control_scheduled users(.clk(clk),.rst_n(rst),.frame_commit(commit),.short_press(short_key),.long_press(long_key),.keypad_valid(kvalid),.keypad_code(code),.emergency_active(alert),.active_scene(scene),.music_fault(1'b0),.photo_load_error(1'b0),.manual_service_pulse(enter),.manual_return_pulse(leave),.music_selected(selected),.music_playing(playing),.normal_playing(normal_playing),.normal_media(media),.menu(menu));
station_control_unit_recovery #(.CLOCKS_PER_MS(2),.ENABLE_MANUAL_HOLD(1),.PIR_HOLD_MS(20000)) control(.clk(clk),.reset_n_async(rst),.pir_async(pir),.light_async(1'b0),.frame_commit(commit),.manual_service_pulse(enter),.manual_return_pulse(leave),.service_hold(selected),.emergency_set(eset),.emergency_clear(eclear),.media_fault(fault),.user_playing(normal_playing),.auto_brightness_enable(1'b0),.manual_brightness(8'sd0),.pir_warmup_done(warm),.pir_motion(motion),.pir_service(service),.active_scene(scene),.requested_scene(request),.alert_enable(alert),.tick_ms(tick));
task ms(input integer n);begin repeat(n)@(posedge tick);@(negedge clk);end endtask
task expect_scene(input[1:0] n);begin repeat(8)@(negedge clk);checks=checks+1;if(scene!==n||request!==n)$fatal(1,"scene check%0d got%0d/%0d expected%0d",checks,scene,request,n);end endtask
task key(input[3:0] n);begin @(negedge clk);code=n;kvalid=1;@(negedge clk);kvalid=0;repeat(8)@(negedge clk);end endtask
initial begin
 repeat(5)@(negedge clk);rst=1;
 ms(60050);if(!warm||motion||service)$fatal(1,"warmup high generated phantom");expect_scene(0);
 pir=0;ms(110);pir=1;ms(20);pir=0;ms(110);expect_scene(0);
 commit=0;pir=1;ms(60);if(scene!=0||request!=1)$fatal(1,"frame commit violated");commit=1;expect_scene(1);
 ms(20100);expect_scene(0); // held high is one event, never an endless refresh
 pir=0;ms(110);pir=1;ms(60);expect_scene(1);
 pir=0;ms(110);ms(10000);pir=1;ms(60);ms(19000);expect_scene(1);
 ms(1100);expect_scene(0); // second rising edge renewed the complete timeout
 pir=0;ms(110);pir=1;ms(60);expect_scene(1);
 key(3);expect_scene(0);ms(2000);expect_scene(0); // no immediate PIR pullback
 pir=0;ms(110);pir=1;ms(60);expect_scene(1); // fresh event overrides manual suppression
 key(3);expect_scene(0);key(3);expect_scene(1); // manual bidirectional key
 ms(20100);expect_scene(0);
 key(3);expect_scene(1);@(negedge clk);short_key=2;@(negedge clk);short_key=0;expect_scene(0);
 key(3);expect_scene(1);@(negedge clk);long_key=1;@(negedge clk);long_key=0;expect_scene(0);
 // Matrix wins against simultaneous board-key entry and no playback pause remains.
 @(negedge clk);code=3;kvalid=1;short_key=1;@(negedge clk);kvalid=0;short_key=0;expect_scene(1);
 key(3);expect_scene(0);if(selected||!normal_playing)$fatal(1,"return did not resume promo");
 // Existing explicit music-service hold is also cleared by the return key.
 @(negedge clk);short_key=1;@(negedge clk);short_key=0;expect_scene(1);
 if(!selected)$fatal(1,"manual music selection missing");
 ms(20100);expect_scene(1);
 key(3);expect_scene(0);if(selected)$fatal(1,"manual hold not cleared");
 @(negedge clk);fault=1;expect_scene(2);eset=1;expect_scene(3);eset=0;key(3);expect_scene(3);
 eclear=1;expect_scene(2);eclear=0;fault=0;expect_scene(0);
 // Common reset again suppresses high at the warmup boundary.
 @(negedge clk);rst=0;repeat(5)@(negedge clk);rst=1;ms(60050);expect_scene(0);
 $display("TEST_PASS PIR_SCENES checks=%0d warmup=60000 hold=20000 startup_high glitch retrigger timeout manual_return frame_commit emergency fault reset",checks);$finish;
end
initial begin #10000000;$fatal(1,"watchdog");end
endmodule
