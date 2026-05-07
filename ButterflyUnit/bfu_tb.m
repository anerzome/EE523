N = 1000;

xj  = randi([0 8380417-1], N, 1);
xjt = randi([0 8380417-1], N, 1);
w   = randi([0 8380417-1], N, 1);
%mode = randi([0 1], N, 1); 
mode = linspace(0,0,N);
inv  = randi([0 1], N, 1);

fin  = fopen('bfu_input.txt','w');
fout = fopen('bfu_expected.txt','w');

for i = 1:N
    [y0, y1] = bfu_model(xj(i), xjt(i), w(i), mode(i), inv(i));

    fprintf(fin, "%d %d %d %d %d\n", xj(i), xjt(i), w(i), mode(i), inv(i));
    fprintf(fout, "%d %d\n", y0, y1);
end

fclose(fin);
fclose(fout);