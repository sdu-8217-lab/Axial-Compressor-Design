function comp_result = axial_compressor_design(T_in, P_in, m, c_in, epsilon, eta_ad, R, k, Cp)
% 单级轴流压缩机热力计算
% 输入参数：
%   T_in: 入口温度 (K)
%   P_in: 入口压力 (Pa)
%   m: 空气质量流量 (kg/s)
%   c_in: 入口速度 (m/s)
%   epsilon: 压比 (出口压力/入口压力)
%   eta_ad: 绝热效率
%   R: 气体常数 (J/kg·K)
%   k: 绝热指数
%   Cp: 定压比热容 (J/kg·K)
%
% 输出结构体 comp_result 包含：
%   T_out: 出口温度 (K)
%   P_out: 出口压力 (Pa)
%   deltaT: 温升 (K)
%   power: 消耗功率 (W)
%   T_in_stag: 入口滞止温度 (K)
%   P_in_stag: 入口滞止压力 (Pa)
%   H_ad: 绝热能量头 (J/kg)

% 1. 计算出口压力 [17,18](@ref)
P_out = epsilon * P_in;

% 2. 计算绝热压缩出口温度 (等熵过程) [21,26](@ref)
T_out_s = T_in * epsilon^((k-1)/k);

% 3. 计算实际出口温度 [21,23](@ref)
T_out = T_in + (T_out_s - T_in) / eta_ad;

% 4. 计算温升
deltaT = T_out - T_in;

% 5. 计算绝热能量头 [21](@ref)
H_ad = Cp * (T_out_s - T_in);

% 6. 计算消耗功率 [21,23](@ref)
power = m * H_ad / eta_ad;

% 7. 滞止参数修正 [20,29,30](@ref)
T_in_stag = T_in + c_in^2/(2*Cp);
P_in_stag = P_in * (T_in_stag/T_in)^(k/(k-1));

% 将结果保存到结构体
comp_result = struct(...
    'T_in', T_in, ...
    'P_in', P_in, ...
    'm', m, ...
    'c_in', c_in, ...
    'epsilon', epsilon, ...
    'eta_ad', eta_ad, ...
    'R', R, ...
    'k', k, ...
    'Cp', Cp, ...
    'T_out', T_out, ...
    'P_out', P_out, ...
    'deltaT', deltaT, ...
    'power', power, ...
    'T_in_stag', T_in_stag, ...
    'P_in_stag', P_in_stag, ...
    'H_ad', H_ad);


end