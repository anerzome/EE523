N = 1000;

mode = randi([0 1], N, 1); 

if mode == 0
    xj  = randi([0 8380417-1], N, 1);
    xjt = randi([0 8380417-1], N, 1);
    w   = randi([0 8380417-1], N, 1);
    %mode = randi([0 1], N, 1);
    inv  = randi([0 1], N, 1);
else
    xj_lo  = randi([0 q-1], N, 1);
    xj_hi  = randi([0 q-1], N, 1);

    xjt_lo = randi([0 q-1], N, 1);
    xjt_hi = randi([0 q-1], N, 1);

    w_lo   = randi([0 q-1], N, 1);
    w_hi   = randi([0 q-1], N, 1);
    inv  = randi([0 1], N, 1);

    for i = 1:N
        xj(i)  = pack_kyber(xj_hi(i),  xj_lo(i));
        xjt(i) = pack_kyber(xjt_hi(i), xjt_lo(i));
        w(i)   = pack_kyber(w_hi(i),   w_lo(i));
    end
end

fin  = fopen('bfu_input.txt','w');
fout = fopen('bfu_expected.txt','w');

for i = 1:N
    [y0, y1] = bfu_model(xj(i), xjt(i), w(i), mode(i), inv(i));

    fprintf(fin, "%d %d %d %d %d\n", xj(i), xjt(i), w(i), mode(i), inv(i));
    fprintf(fout, "%d %d\n", y0, y1);
end

fclose(fin);
fclose(fout);

function y = pack_kyber(hi, lo)
    mask = int32(2^12 - 1); % 12-bit
    y = bitor( ...
        bitshift(bitand(int32(hi), mask), 12), ...
        bitand(int32(lo), mask) ...
    );
end