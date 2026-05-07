%% Number to be reduced
num = 8380417^2;
%% Kyber Mod Reduction
    
x = dec2bin(num,24);
Output=char(num2cell(x));
Output=reshape(str2num(Output),1,[]);
y = mod_red(flip(Output),1)
%% Dilithium Mod Reduction

x = dec2bin(num,46);
Output=char(num2cell(x));
Output=reshape(str2num(Output),1,[]);
z = mod_red(flip(Output),0)
%% Function definitions

%Modular Reduction overall module%
%Generates the block, sends it to the adder,
%selects the output within its range

function red = mod_red(x,d_k)
    if d_k
        c = kyber_block(x(1:24));
    else
        c = dilithium_block(x);
    end
    temp = adder(c);
    q_d = 8380417;
    q_k = 3329;
    if d_k
        q = q_k;
    else
        q = q_d;
    end
    arr = [temp-2*q,temp-q,temp+q,temp];
    res1 = arr<=q-1;
    res2 = 1<=arr;
    res = int32(res1 & res2);
    red = sum(arr.*res);
end

%Adder for the blocks generated, in hardware this is a CSA->CPA%

function sum = adder(block)
    sum = 0;
    n = size(block,2);
    for i = 1:size(block,1)
        s = num2str(block(i,1:n));
        s = s(find(~isspace(s)));
        o = n*ones(1,32-n);
        b = flip([s s(o)]);
        k = typecast(uint32(bin2dec(b)),'int32');
        sum = sum + k;
    end
end

%Kyber Bit selection function%

function block = kyber_block(x)
    neg_x = ~x;
    block = zeros(8,15);
    block(1,1:12) = x(1:12);
    block(2,9:11) = [x(13),x(13),x(14)];
    block(2,1:8) = neg_x(13:20);
    block(3,9:11) = [x(18),x(14),x(18)];
    block(3,1:8) = [neg_x(15:17),neg_x(19:23)];
    block(4,1:3) = [neg_x(18),neg_x(18),neg_x(18)];
    block(4,4:8) = neg_x(20:24);
    block(4,9:11) = [x(20),x(16),x(20)];
    block(5,1:3) = [neg_x(19),neg_x(19),neg_x(19)];
    block(5,4:7) = neg_x(21:24);
    block(5,9:11) = [neg_x(24),x(20),neg_x(19)];
    block(6,1:5) = [neg_x(20),neg_x(21),neg_x(20),neg_x(23),neg_x(24)];
    block(6,9:11) = [neg_x(19),x(19),neg_x(17)];
    block(7,1:4) = [neg_x(21),neg_x(22),neg_x(22),neg_x(24)];
    block(7,9:11) = [neg_x(15),0,neg_x(16)];
    block(8,2:15) = [1,neg_x(23),0,1,0,1,0,1,0,1,1,0,1,1];
end

%Dilithium bit selection function%

function block = dilithium_block(x)
    neg_x = ~x;
    block = zeros(6,26);
    block(1,1:23) = x(1:23);
    block(2,1:23) = neg_x(24:46);
    block(3,1:13) = neg_x(34:46);
    block(3,14:23) = x(24:33);
    block(4,1:3) = neg_x(44:46);
    block(4,14:23) = x(34:43);
    block(5,14:16) = x(44:46);
    block(6,1:26) = [1,1,0,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,0,1,1];
end