N = 1000;
q = 1000;

% Generate two coefficients per input
xj_lo  = randi([0 q-1], N, 1);
xj_hi  = randi([0 q-1], N, 1);

xjt_lo = randi([0 q-1], N, 1);
xjt_hi = randi([0 q-1], N, 1);

w_lo   = randi([0 q-1], N, 1);
w_hi   = randi([0 q-1], N, 1);

% Pack into 24-bit
xj  = zeros(N,1);
xjt = zeros(N,1);
w   = zeros(N,1);

for i = 1:N
    xj(i)  = pack_kyber(xj_hi(i),  xj_lo(i));
    xjt(i) = pack_kyber(xjt_hi(i), xjt_lo(i));
    w(i)   = pack_kyber(w_hi(i),   w_lo(i));
end

% Kyber mode only
mode = ones(N,1);   % 1 = Kyber
inv  = randi([0 1], N, 1);

% Files
fin  = fopen('bfu_input_kyber.txt','w');
fout = fopen('bfu_expected_kyber.txt','w');

for i = 1:N
    
    % Use your Kyber-aware BFU model
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