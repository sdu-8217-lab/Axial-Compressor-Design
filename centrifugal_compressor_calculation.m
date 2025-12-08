function compressor_output = centrifugal_compressor_calculation(input_parameters)
% 单级离心式压缩机性能计算
% 输入参数结构体包含以下字段：
%   T1: 入口温度 (K)
%   P1: 入口压力 (Pa)
%   m_dot: 质量流量 (kg/s)
%   V1: 入口速度 (m/s)
%   pressure_ratio: 压比 (P2/P1)
%   eta_isentropic: 等熵效率
%   gamma: 比热比 (cp/cv)
%   R: 气体常数 (J/kg·K)
%   cp: 定压比热容 (J/kg·K)

    % 提取输入参数
    T1 = input_parameters.T1;
    P1 = input_parameters.P1;
    m_dot = input_parameters.m_dot;
    V1 = input_parameters.V1;
    pressure_ratio = input_parameters.pressure_ratio;
    eta_isentropic = input_parameters.eta_isentropic;
    gamma = input_parameters.gamma;
    R = input_parameters.R;
    cp = input_parameters.cp;

    % 定义单位转换系数 [6,7](@ref)
    kPa_per_Pa = 1e-3;      % 1 kPa = 1000 Pa
    kW_per_W = 1e-3;        % 1 kW = 1000 W
    kJ_per_J = 1e-3;        % 1 kJ = 1000 J

    % 计算入口滞止参数（考虑速度头）
    T01 = T1 + V1^2 / (2 * cp);  % 滞止温度
    P01 = P1 * (T01 / T1)^(gamma / (gamma - 1));  % 滞止压力

    % 等熵压缩过程计算
    P02_isentropic = P01 * pressure_ratio;  % 等熵出口滞止压力
    T02_isentropic = T01 * (P02_isentropic / P01)^((gamma - 1) / gamma);  % 等熵出口滞止温度

    % 考虑效率的实际过程
    T02 = T01 + (T02_isentropic - T01) / eta_isentropic;  % 实际出口滞止温度
    P02 = P01 * pressure_ratio;  % 实际出口滞止压力（压比由输入确定）

    % 计算温升
    delta_T = T02 - T01;  % 滞止温升
    delta_T_static = (T02 - T1) - (T01 - T1);  % 静温升

    % 计算消耗功率
    W_isentropic = cp * (T02_isentropic - T01);  % 等熵压缩功 (J/kg)
    W_actual = W_isentropic / eta_isentropic;  % 实际压缩功 (J/kg)
    power_consumption = m_dot * W_actual;  % 总功率消耗 (W)

    % 计算出口静压和静温（假设出口速度与入口速度相同）
    T2 = T02 - V1^2 / (2 * cp);  % 出口静温
    P2 = P02 / (T02 / T2)^(gamma / (gamma - 1));  % 出口静压

    % 单位转换 [6,7](@ref)
    P1_kPa = P1 * kPa_per_Pa;
    P2_kPa = P2 * kPa_per_Pa;
    P01_kPa = P01 * kPa_per_Pa;
    P02_kPa = P02 * kPa_per_Pa;
    power_consumption_kW = power_consumption * kW_per_W;
    W_actual_kJ_kg = W_actual * kJ_per_J;
    W_isentropic_kJ_kg = W_isentropic * kJ_per_J;

    % 输出结果结构体（包含原始单位和工程单位）
    compressor_output.T2 = T2;  % 出口静温 (K)
    compressor_output.P2 = P2;  % 出口静压 (Pa)
    compressor_output.T02 = T02;  % 出口总温 (K)
    compressor_output.P02 = P02;  % 出口总压 (Pa)
    compressor_output.delta_T = delta_T;  % 总温升 (K)
    compressor_output.delta_T_static = delta_T_static;  % 静温升 (K)
    compressor_output.power_consumption = power_consumption;  % 消耗功率 (W)
    compressor_output.W_actual = W_actual;  % 比功 (J/kg)
    
    % 工程单位输出
    compressor_output.P1_kPa = P1_kPa;  % 入口压力 (kPa)
    compressor_output.P2_kPa = P2_kPa;  % 出口静压 (kPa)
    compressor_output.P01_kPa = P01_kPa;  % 入口总压 (kPa)
    compressor_output.P02_kPa = P02_kPa;  % 出口总压 (kPa)
    compressor_output.power_consumption_kW = power_consumption_kW;  % 消耗功率 (kW)
    compressor_output.W_actual_kJ_kg = W_actual_kJ_kg;  % 比功 (kJ/kg)
    compressor_output.W_isentropic_kJ_kg = W_isentropic_kJ_kg;  % 等熵比功 (kJ/kg)

    % 显示计算结果（使用工程单位）
    fprintf('单级离心式压缩机计算结果：\n');
    fprintf('=== 压力参数 ===\n');
    fprintf('入口静压: %.2f kPa (%.2f Pa)\n', P1_kPa, P1);
    fprintf('入口总压: %.2f kPa\n', P01_kPa);
    fprintf('出口静压: %.2f kPa (%.2f Pa)\n', P2_kPa, P2);
    fprintf('出口总压: %.2f kPa\n', P02_kPa);
    fprintf('压比: %.3f\n', pressure_ratio);
    
    fprintf('\n=== 温度参数 ===\n');
    fprintf('入口静温: %.2f K\n', T1);
    fprintf('入口总温: %.2f K\n', T01);
    fprintf('出口静温: %.2f K\n', T2);
    fprintf('出口总温: %.2f K\n', T02);
    fprintf('总温升: %.2f K\n', delta_T);
    fprintf('静温升: %.2f K\n', delta_T_static);
    
    fprintf('\n=== 功率参数 ===\n');
    fprintf('等熵比功: %.2f kJ/kg\n', W_isentropic_kJ_kg);
    fprintf('实际比功: %.2f kJ/kg\n', W_actual_kJ_kg);
    fprintf('消耗功率: %.2f kW (%.2f W)\n', power_consumption_kW, power_consumption);
    
    fprintf('\n=== 效率参数 ===\n');
    fprintf('等熵效率: %.3f\n', eta_isentropic);
    fprintf('质量流量: %.3f kg/s\n', m_dot);
    
    fprintf('\n=== 气体物性 ===\n');
    fprintf('比热比 (γ): %.3f\n', gamma);
    fprintf('气体常数 (R): %.2f J/kg·K\n', R);
    fprintf('定压比热 (cp): %.2f J/kg·K\n', cp);
end