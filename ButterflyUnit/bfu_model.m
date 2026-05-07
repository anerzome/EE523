function [y0, y1] = bfu_model(xj, xjt, w, mode, inv)

    if mode == 0
        % ==============================
        % Dilithium (24-bit)
        % ==============================
        q = 8380417;

        xj  = mod(xj, q);
        xjt = mod(xjt, q);
        w   = mod(w, q);

        add_val = xj + xjt;
        sub_val = mod(xj - xjt, q);

        if inv == 0
            mul_in = xjt;
        else
            mul_in = sub_val;
        end

        t = mod(w * mul_in, q);

        if inv == 0
            y0 = xj + t;
            y1 = xj - t;
        else
            y0 = floor(add_val / 2);
            y1 = floor(t / 2);
        end

    else
        % ==============================
        % Kyber (2 × 12-bit lanes)
        % ==============================
        q = 3329;
        mask = 2^12 - 1;

        % Split inputs
        xj_lo  = bitand(xj, mask);
        xj_hi  = bitshift(xj, -12);

        xjt_lo = bitand(xjt, mask);
        xjt_hi = bitshift(xjt, -12);

        w_lo   = bitand(w, mask);
        w_hi   = bitshift(w, -12);

        % -------- LOWER LANE --------
        [y0_lo, y1_lo] = bfu_lane(xj_lo, xjt_lo, w_lo, q, inv);

        % -------- UPPER LANE --------
        [y0_hi, y1_hi] = bfu_lane(xj_hi, xjt_hi, w_hi, q, inv);

        % Combine back
        mask = int32(2^12 - 1);  % 0xFFF

        y0 = bitor( bitshift( bitand(int32(y0_hi), mask), 12 ), bitand(int32(y0_lo), mask) );

        y1 = bitor( bitshift( bitand(int32(y1_hi), mask), 12 ), bitand(int32(y1_lo), mask) );
    end

end


% =========================================
% Single 12-bit BFU lane (Kyber core)
% =========================================
function [y0, y1] = bfu_lane(xj, xjt, w, q, inv)

    xj  = mod(xj, q);
    xjt = mod(xjt, q);
    w   = mod(w, q);

    add_val = xj + xjt;
    sub_val = mod(xj - xjt, q);

    if inv == 0
        mul_in = xjt;
    else
        mul_in = sub_val;
    end

    t = mod(w * mul_in, q);

    if inv == 0
        y0 = xj + t;
        y1 = xj - t;
    else
        y0 = floor(add_val / 2);
        y1 = floor(t / 2);
    end

end