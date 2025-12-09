function result = Gas_storage_tank_input(Tin, mdot, R, V, A, h, Tamb, T0, m0, t_end)
%Gas_storage_tank_input —— 储气罐温度与压力变化模型
%
% 输入参数（全部由用户提供）：
%   Tin    —— 入口气体温度 (K)
%   mdot   —— 质量流量 (kg/s)
%   R      —— 空气气体常数 (kJ/kg*K)
%   V      —— 储气罐体积 (m^3)
%   A      —— 储气罐换热面积 (m^2)
%   h      —— 换热系数
%   Tamb   —— 环境温度 (K)
%   T0     —— 储气罐初始温度 (K)
%   m0     —— 储气罐初始质量 (kg)
%   t_end  —— 仿真时间 (s)
%
% 输出 result：
%   result.time  —— 时间序列
%   result.T     —— 温度序列
%   result.P     —— 压力序列
%   result.m     —— 质量序列

    tspan = [0 t_end];
    x0 = [T0; m0];       % 状态变量 [温度; 质量]

    % ODE 求解
    [t, x] = ode45(@(t,x) tank_ode(t, x, Tin, mdot, R, V, A, h, Tamb), tspan, x0);

    % 提取状态
    T = x(:,1);
    m = x(:,2);
    P = m .* R .* T ./ V;   % 状态方程 P = mRT/V

    % 输出结构体
    result.time = t;
    result.T = T;
    result.P = P;
    result.m = m;
end


%% ===================== 内部 ODE 函数 ===========================
function dx = tank_ode(~, x, Tin, mdot, R, V, A, h, Tamb)

    % 状态变量
    T = x(1);
    m = x(2);

    % 空气定压比热 cp(T)
    cp = 0.9705 + 0.00006791*T + 1.658e-7*T^2 - 6.788e-11*T^3;

    % 定容比热
    cv = cp - R;

    % 能量方程： m*cv*dT/dt = mdot*cp*(Tin - T) - h*A*(T - Tamb)
    Qin  = mdot * cp * (Tin - T);
    Qout = h * A * (T - Tamb);

    dTdt = (Qin - Qout) / (m * cv);

    % 质量方程
    dmdt = mdot;

    dx = [dTdt; dmdt];
end
