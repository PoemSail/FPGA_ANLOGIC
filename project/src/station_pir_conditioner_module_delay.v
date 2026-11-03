// Fresh post-warmup low/high qualification; HOLD_MS>0 is event-based inactivity timeout.
// 1ms clock-enable; OUT is motion, not a stationary-person detector.
module station_pir_conditioner #(
    parameter integer WARMUP_MS = 60000,
    parameter integer HIGH_MS = 50,
    parameter integer LOW_MS = 100,
    parameter integer HOLD_MS = 0,
    parameter integer EVENT_REQUEST = 0
)(
    input wire clk, input wire rst_n, input wire tick_ms,
    input wire pir_async,
    output reg warmup_done, output reg motion_level,
    output wire service_request
);
    reg pir_meta, pir_sync;
    reg service_level;
    reg armed;
    // Inclusive-limit width; minimum one bit for disabled timers.
    function integer count_width;
        input integer limit;
        integer n;
        begin
            n=limit; count_width=0;
            while(n>0) begin count_width=count_width+1; n=n>>1; end
            if(count_width==0) count_width=1;
        end
    endfunction
    reg [count_width(WARMUP_MS)-1:0] warm_count;
    reg [count_width(HIGH_MS)-1:0] high_count;
    reg [count_width(LOW_MS)-1:0] low_count;
    reg [count_width(HOLD_MS)-1:0] hold_count;
    wire high_ok = pir_sync && (high_count >= HIGH_MS-1);
    wire low_ok = !pir_sync && (low_count >= LOW_MS-1);
    wire next_motion = high_ok ? 1'b1 : low_ok ? 1'b0 : motion_level;
    // Qualified event is consumed on the same bus edge that raises motion.
    // This uses existing motion state and adds no event/output register.
    assign service_request = EVENT_REQUEST ?
        (rst_n && tick_ms && warmup_done && armed && next_motion && !motion_level) : service_level;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin pir_meta <= 0; pir_sync <= 0; end
        else begin pir_meta <= pir_async; pir_sync <= pir_meta; end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            warm_count <= 0; high_count <= 0; low_count <= 0; hold_count <= 0;
            warmup_done <= (WARMUP_MS == 0); motion_level <= 0; service_level <= 0; armed <= 0;
        end else if (tick_ms) begin
            if (!warmup_done) begin
                // Never qualify motion or carry high history through warmup.
                high_count <= 0; low_count <= 0; motion_level <= 0;
                service_level <= 0; hold_count <= 0; armed <= 0;
                if (warm_count >= WARMUP_MS-1) warmup_done <= 1;
                else warm_count <= warm_count + 1'b1;
            end else if (!armed) begin
                // A sensor held high across startup is not a fresh trigger.
                high_count <= 0; motion_level <= 0; service_level <= 0; hold_count <= 0;
                if (!pir_sync) begin
                    if (low_count >= LOW_MS-1) begin armed <= 1; low_count <= 0; end
                    else low_count <= low_count + 1'b1;
                end else low_count <= 0;
            end else begin
                if (pir_sync) begin
                    low_count <= 0;
                    if (high_count < HIGH_MS) high_count <= high_count + 1'b1;
                end else begin
                    high_count <= 0;
                    if (low_count < LOW_MS) low_count <= low_count + 1'b1;
                end
                motion_level <= next_motion;
                if (HOLD_MS == 0) begin
                    service_level <= next_motion; hold_count <= 0;
                end else if (next_motion && !motion_level) begin
                    service_level <= 1; hold_count <= HOLD_MS;
                end else if (service_level) begin
                    if (hold_count <= 1) begin service_level <= 0; hold_count <= 0; end
                    else hold_count <= hold_count - 1'b1;
                end
            end
        end
    end
endmodule
