function result = tank_leak_sim(P0, T0, V, R, A, h, Tamb, leak_rate, t_end)
% tank_leak_sim —— 带泄漏与散热的密闭储气罐动态模型
%
% 输入：
%   P0         —— 初始压力 (kPa)
%   T0         —— 初始温度 (K)
%   V          —— 储气罐体积 (m^3)
%   R          —— 气体常数 (kJ/kg*K)
%   A          —— 换热面积 (m^2)
%   h          —— 换热系数
%   Tamb       —— 环境温度 (K)
%   leak_rate  —— 泄漏系数 (1/s)
%   t_end      —— 仿真时间 (s)
%
% 输出：
%   result.time —— 时间数组
%   result.T    —— 温度曲线
%   result.P    —— 压力曲线
%   result.m    —— 质量曲线

    % 根据状态方程由 P0, T0 求初始质量
    m0 = P0 * V / (R * T0);

    x0 = [T0; m0];          % 初始状态 [T; m]
    tspan = [0 t_end];

    [t, x] = ode45(@(t,x) ode_func(t,x,V,R,A,h,Tamb,leak_rate), tspan, x0);

    T = x(:,1);
    m = x(:,2);

    P = m .* R .* T ./ V;

    % 输出结构
    result.time = t;
    result.T = T;
    result.P = P;
    result.m = m;
end


%% ================= ODE 方程 ==================
function dx = ode_func(~, x, V, R, A, h, Tamb, leak_rate)

    T = x(1);   % 温度
    m = x(2);   % 质量

    % 空气定压比热 cp(T)
    cp = 0.9705 + 6.791e-5*T + 1.658e-7*T^2 - 6.788e-11*T^3;
    cv = cp - R;

    %% ——温度变化：能量守恒（无进气、仅散热）
    Qloss = h * A * (T - Tamb);
    dTdt = - Qloss / (m * cv);

    %% ——质量变化：泄漏（指数衰减）
    dmdt = - leak_rate * m;

    dx = [dTdt; dmdt];
end
