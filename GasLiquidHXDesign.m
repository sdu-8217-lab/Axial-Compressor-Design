function [T_hot_out, T_cold_out, Q, effectiveness] = GasLiquidHXDesign(...
    m_dot_hot, cp_hot, T_hot_in, P_hot, ...    % 气体侧参数 (热流体)
    m_dot_cold, cp_cold, T_cold_in, P_cold, ... % 液体侧参数 (冷流体)
    U, A, HX_type, varargin)
% 气液换热器设计函数
% 输入参数:
%   m_dot_hot/cold: 热/冷流体质量流量 [kg/s]
%   cp_hot/cold: 热/冷流体定压比热容 [J/(kg·K)]
%   T_hot_in/cold_in: 热/冷流体入口温度 [°C]
%   P_hot/cold: 热/冷流体入口压力 [Pa] (预留压力参数用于后续扩展)
%   U: 总传热系数 [W/(m²·K)]
%   A: 传热面积 [m²]
%   HX_type: 换热器类型字符串 ('counterflow'-逆流, 'parallel'-顺流等)
% 输出参数:
%   T_hot_out: 气体出口温度 [°C]
%   T_cold_out: 液体出口温度 [°C]  
%   Q: 换热量 [W]
%   effectiveness: 换热器效能

%% 参数有效性检查
if nargin < 9
    error('至少需要9个输入参数。');
end
if any([m_dot_hot, m_dot_cold, U, A] <= 0)
    error('质量流量、传热系数和传热面积必须为正数。');
end

%% 计算热容流率 (Capacity Rates)
C_hot = m_dot_hot * cp_hot;  % 热流体热容流率 [W/K]
C_cold = m_dot_cold * cp_cold; % 冷流体热容流率 [W/K]

C_min = min(C_hot, C_cold);  % 最小热容流率
C_max = max(C_hot, C_cold);  % 最大热容流率
C_ratio = C_min / C_max;     % 热容流率比 (C_r)

%% 计算NTU (传热单元数)
NTU = U * A / C_min;

%% 根据换热器类型计算效能 (Epsilon, ε)
% 效能ε定义：实际传热量与最大可能传热量之比
switch HX_type
    case 'counterflow' % 逆流换热器
        if C_ratio < 1
            effectiveness = (1 - exp(-NTU * (1 - C_ratio))) / ...
                           (1 - C_ratio * exp(-NTU * (1 - C_ratio)));
        else % C_ratio == 1
            effectiveness = NTU / (1 + NTU);
        end
        
    case 'parallel' % 顺流换热器
        effectiveness = (1 - exp(-NTU * (1 + C_ratio))) / ...
                       (1 + C_ratio);
        
    otherwise
        error(['不支持的换热器类型。当前支持: ', ...
               'counterflow (逆流), parallel (顺流)']);
end

%% 计算实际传热量 Q
Q_max = C_min * (T_hot_in - T_cold_in); % 最大可能传热量
Q = effectiveness * Q_max;               % 实际传热量 [W]

%% 计算出口温度
T_hot_out = T_hot_in - Q / C_hot;   % 热流体出口温度
T_cold_out = T_cold_in + Q / C_cold; % 冷流体出口温度


end