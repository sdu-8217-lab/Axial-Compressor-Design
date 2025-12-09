function result = multistage_storage( ...
    Tf_list, mdot_list, Nstage, ...
    cp_f, Tenv, U, A, M_stage, cp_s, ...
    Ts0_list, t_end, ...
    varargin)
% MULTISTAGE_PARALLEL  并行多级换热/储热模拟（调用 thermal_storage_simulation)
%
% 输入:
%   Tf_list   : 1xNstage 各级载热流体入口温度 (°C)
%   mdot_list : 1xNstage 各级质量流量 (kg/s)
%   Nstage    : 级数 (应等于上面两个向量长度)
%   cp_f      : 工质比热 (J/(kg·°C))
%   Tenv      : 环境温度 (°C)
%   U, A      : 换热系数与面积 (W/(m^2·°C), m^2)
%   M_stage   : 若为标量，则每级储热体质量相同；若为向量，长度为 Nstage (kg)
%   cp_s      : 储热介质比热 (J/(kg·°C))
%   Ts0_list  : 1xNstage 每级储热初始温度 (°C)
%   t_end     : 模拟时间 (s)
%
% 可选参数（按顺序）:
%   M_main, cp_main, T_main0
%   如果提供主罐 M_main 和 cp_main 以及主罐初始温度 T_main0，
%   则会计算主罐与各级贮能体混合后的最终温度。
%
% 返回 result 结构，包括:
%   result.Ts_end_each   : 每级最终储热温度 (°C)
%   result.Qnet_each     : 每级累计净换热量 (J)
%   result.Q_total       : 所有级累计净换热量之和 (J)
%   result.mdot_total    : 总质量流量 (kg/s)
%   result.T_final_combined : 若无主罐，按各级储热质量加权平均温度 (°C)
%   result.T_final_with_main: 如果提供主罐参数，则为混合后的温度 (°C)
%
% 备注: 该函数内部调用你已有的 thermal_storage_simulation。
%

% ------------------- 入参检查 -------------------
if length(Tf_list) ~= Nstage || length(mdot_list) ~= Nstage
    error('Tf_list 和 mdot_list 长度必须等于 Nstage');
end
if length(Ts0_list) ~= Nstage
    error('Ts0_list 必须与 Nstage 等长');
end
if isscalar(M_stage)
    M_stage = M_stage * ones(1,Nstage);
elseif length(M_stage) ~= Nstage
    error('M_stage 必须为标量或长度等于 Nstage 的向量');
end

% 可选主罐参数解析
has_main = false;
if length(varargin) >= 3
    M_main   = varargin{1};
    cp_main  = varargin{2};
    T_main0  = varargin{3};
    has_main = true;
end

% 预分配
Ts_end_each = zeros(1, Nstage);
Qnet_each   = zeros(1, Nstage);

% ------------------- 并行逐级独立仿真 -------------------
fprintf('\n开始对 %d 个并行换热单元逐级仿真 ...\n', Nstage);
for i = 1:Nstage
    fprintf('  -> 第 %d 级: Tf=%.3f °C, mdot=%.6f kg/s, Ts0=%.3f °C\n', ...
        i, Tf_list(i), mdot_list(i), Ts0_list(i));

    % 调用单级仿真函数（你提供）
    [t, Ts, Qin, Qloss] = thermal_storage_simulation( ...
        Tf_list(i), mdot_list(i), cp_f, Tenv, U, A, M_stage(i), cp_s, ...
        Ts0_list(i), t_end);

    % 计算该级最终温度与累计净换热量（使用 trapz 做时间积分）
    Ts_end_each(i) = Ts(end);
    dt = t(2) - t(1);
    % 使用 trapz 对 (Qin-Qloss) 进行积分，得到能量单位为 J （W·s）
    Qnet_each(i) = trapz(t, (Qin - Qloss));

    fprintf('      -> 本级最终 Ts = %.4f °C, 累计净换热 = %.3f kJ\n', ...
        Ts_end_each(i), Qnet_each(i)/1000);
end

% ------------------- 汇总结果 -------------------
Q_total = sum(Qnet_each);           % J
mdot_total = sum(mdot_list);        % kg/s

% 各级储能体合并（按质量*比热加权平均）
sum_MC = sum(M_stage .* cp_s);
T_combined = sum( M_stage .* cp_s .* Ts_end_each ) / sum_MC;

% 如果提供主罐参数，计算主罐与这些级合并后的温度
if has_main
    T_final_with_main = ( M_main*cp_main*T_main0 + sum( M_stage .* cp_s .* Ts_end_each ) ) ...
                        / ( M_main*cp_main + sum_MC );
else
    T_final_with_main = NaN;
end

% 打印汇总
fprintf('\n============= 多级并行汇总 =============\n');
fprintf('总质量流量 mdot_total = %.6f kg/s\n', mdot_total);
fprintf('总累计净换热量 Q_total = %.3f kJ\n', Q_total/1000);
fprintf('各级最终 Ts: '); fprintf('%.3f ', Ts_end_each); fprintf(' °C\n');
fprintf('按各级储热质量加权合并温度 = %.4f °C\n', T_combined);
if has_main
    fprintf('与主罐混合后温度 = %.4f °C (主罐 M=%.3f kg, cp=%.1f J/kg·°C, T0=%.3f °C)\n', ...
        T_final_with_main, M_main, cp_main, T_main0);
end
fprintf('=========================================\n\n');

% 返回结构
result.Ts_end_each = Ts_end_each;
result.Qnet_each = Qnet_each;
result.Q_total = Q_total;
result.mdot_total = mdot_total;
result.T_final_combined = T_combined;
result.T_final_with_main = T_final_with_main;
result.M_stage = M_stage;

end
