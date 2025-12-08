function system_result = multi_stage_compressor_system(...
    N_stage, ...                     % 级数
    T_in1, P_in1, m, c_in1, ...      % 第一级压缩机入口参数
    epsilon_list, eta_ad_list, ...   % 各级压缩机压比和效率
    T_cold_in_list, m_dot_cold_list, cp_cold_list, P_cold_list, ... % 各级换热器冷流体参数
    U_list, A_list, HX_type_list, ... % 各级换热器参数
    R, k, Cp, ...                    % 气体常数
    pressure_drop_ratio)             % 级间压力损失比例

%% 参数验证
if length(epsilon_list) ~= N_stage || length(eta_ad_list) ~= N_stage || ...
   length(T_cold_in_list) ~= N_stage || length(m_dot_cold_list) ~= N_stage || ...
   length(cp_cold_list) ~= N_stage || length(P_cold_list) ~= N_stage || ...
   length(U_list) ~= N_stage || length(A_list) ~= N_stage || ...
   length(HX_type_list) ~= N_stage
    error('所有级数相关参数列表长度必须等于N_stage');
end

%% 初始化变量
comp_results = cell(1, N_stage);    % 存储各级压缩机结果
hx_T_hot_out = zeros(1, N_stage);   % 各级换热器热流体出口温度
hx_T_cold_out = zeros(1, N_stage);  % 各级换热器冷流体出口温度
hx_Q = zeros(1, N_stage);           % 各级换热量
hx_effectiveness = zeros(1, N_stage); % 各级换热器效能
total_power = 0;                    % 总功耗
total_heat_exchange = 0;            % 总换热量
compressor_efficiency = zeros(1, N_stage); % 压缩机效率
interstage_pressure_drop = zeros(1, N_stage-1); % 级间压力损失

% 第一级压缩机入口参数
T_in = T_in1;
P_in = P_in1;
c_in = c_in1;

%% 多级系统计算
for i = 1:N_stage
    fprintf('\n--- 第 %d 级计算开始 ---\n', i);
    
    % 1. 压缩机计算
    fprintf('压缩机%d计算: 入口温度=%.2fK, 入口压力=%.2fPa\n', i, T_in, P_in);
    comp_results{i} = axial_compressor_design(...
        T_in, P_in, m, c_in, ...
        epsilon_list(i), eta_ad_list(i), R, k, Cp);
    
    total_power = total_power + comp_results{i}.power;
    compressor_efficiency(i) = eta_ad_list(i);
    
    % 2. 换热器计算
    % 换热器热流体入口参数 = 压缩机出口参数
    T_hot_in = comp_results{i}.T_out;
    P_hot = comp_results{i}.P_out;
    fprintf('压缩机%d输出: 出口温度=%.2fK, 出口压力=%.2fPa\n', i, T_hot_in, P_hot);
    
    % 考虑级间压力损失
    if i < N_stage
        P_hot = P_hot * (1 - pressure_drop_ratio);
        interstage_pressure_drop(i) = comp_results{i}.P_out * pressure_drop_ratio;
        fprintf('级间压力损失: %.2fPa\n', interstage_pressure_drop(i));
    end
    
    % 计算换热器
    fprintf('换热器%d计算: 热流体入口=%.2fK, 冷流体入口=%.2fK\n', i, T_hot_in, T_cold_in_list(i));
    
    % 注意：GasLiquidHXDesign 返回多个值，不是结构体
    [T_hot_out, T_cold_out, Q, effectiveness] = GasLiquidHXDesign(...
        m, Cp, T_hot_in, P_hot, ...          % 热流体参数
        m_dot_cold_list(i), cp_cold_list(i), T_cold_in_list(i), P_cold_list(i), ... % 冷流体参数
        U_list(i), A_list(i), HX_type_list{i}); % 换热器参数
    
    % 保存换热器结果
    hx_T_hot_out(i) = T_hot_out;
    hx_T_cold_out(i) = T_cold_out;
    hx_Q(i) = Q;
    hx_effectiveness(i) = effectiveness;
    
    total_heat_exchange = total_heat_exchange + Q;
    
    fprintf('换热器%d输出: 热流体出口=%.2fK, 换热量=%.2fkW\n', i, T_hot_out, Q/1000);
    
    % 3. 为下一级准备输入参数
    if i < N_stage
        T_in = T_hot_out;  % 下一级压缩机入口温度
        P_in = P_hot;      % 下一级压缩机入口压力（已考虑级间损失）
        c_in = c_in1;      % 保持入口速度不变
        fprintf('下一级压缩机入口: 温度=%.2fK, 压力=%.2fPa\n', T_in, P_in);
    end
end

%% 计算系统性能指标
% 总压比
total_compression_ratio = comp_results{end}.P_out / P_in1;

% 总温升
total_temperature_rise = hx_T_hot_out(end) - T_in1;

% 压缩机平均效率
avg_compressor_efficiency = mean(compressor_efficiency);

% 换热器平均效能
avg_hx_effectiveness = mean(hx_effectiveness);

%% 整理输出结果
system_result = struct(...
    'total_power', total_power, ...
    'total_heat_exchange', total_heat_exchange, ...
    'final_temperature', hx_T_hot_out(end), ...
    'final_pressure', comp_results{end}.P_out, ...
    'total_compression_ratio', total_compression_ratio, ...
    'total_temperature_rise', total_temperature_rise, ...
    'avg_compressor_efficiency', avg_compressor_efficiency, ...
    'avg_hx_effectiveness', avg_hx_effectiveness, ...
    'number_of_stages', N_stage, ...
    'interstage_pressure_drop', interstage_pressure_drop, ...
    'compressor_results', {comp_results}, ...
    'heat_exchanger_results', struct(...
        'T_hot_out', hx_T_hot_out, ...
        'T_cold_out', hx_T_cold_out, ...
        'Q', hx_Q, ...
        'effectiveness', hx_effectiveness), ...
    'pressure_drop_ratio', pressure_drop_ratio, ...
    'compressor_efficiency', compressor_efficiency, ...
    'hx_effectiveness', hx_effectiveness, ...
    'initial_conditions', struct('T_in1', T_in1, 'P_in1', P_in1, 'm', m, 'c_in1', c_in1));

%% 输出系统性能摘要
fprintf('\n========== 多级轴流压缩机系统性能摘要 ==========\n');
fprintf('系统级数: %d\n', N_stage);
fprintf('总功耗: %.2f kW\n', total_power/1000);
fprintf('总换热量: %.2f kW\n', total_heat_exchange/1000);
fprintf('总压比: %.4f\n', total_compression_ratio);
fprintf('总温升: %.2f K\n', total_temperature_rise);
fprintf('最终出口温度: %.2f K\n', system_result.final_temperature);
fprintf('最终出口压力: %.2f MPa\n', system_result.final_pressure/1e6);
fprintf('压缩机平均效率: %.4f\n', avg_compressor_efficiency);
fprintf('换热器平均效能: %.4f\n', avg_hx_effectiveness);
fprintf('级间压力损失比例: %.2f%%\n', pressure_drop_ratio*100);
fprintf('================================================\n');

%% 生成详细性能表格
fprintf('\n----------- 各级详细性能 -----------\n');
fprintf('级数 | 压缩机功耗(kW) | 换热量(kW) | 压缩机效率 | 换热器效能\n');
fprintf('-----|---------------|------------|------------|------------\n');
for i = 1:N_stage
    fprintf('%3d  | %12.2f  | %10.2f |   %.4f   |   %.4f\n', ...
        i, comp_results{i}.power/1000, hx_Q(i)/1000, ...
        compressor_efficiency(i), hx_effectiveness(i));
end
fprintf('-------------------------------------\n');
end