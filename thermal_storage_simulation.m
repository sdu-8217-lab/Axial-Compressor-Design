function [t, Ts, Qin, Qloss] = thermal_storage_simulation( ...
        Tf, mdot, cp_f, Tenv, U, A, M, cp_s, ...
        Ts0, t_end)

%--------------------------------------------------------------
% 储热系统一阶能量平衡模型（带稳态文字输出）
% dTs/dt = (Q_in - Q_loss) / (M * cp_s)
%--------------------------------------------------------------

if nargin < 10
    error('参数不足，需要：Tf, mdot, cp_f, Tenv, U, A, M, cp_s, Ts0, t_end');
end

dt = 1;                 
t = 0:dt:t_end;         
N = length(t);

Ts    = zeros(1, N);
Qin   = zeros(1, N);
Qloss = zeros(1, N);

Ts(1) = Ts0;

for k = 1:N-1

    %（1）输入热量
    Qin(k) = mdot * cp_f * (Tf - Ts(k));

    %（2）环境热损失
    Qloss(k) = U * A * (Ts(k) - Tenv);

    %（3）能量平衡
    dTs = (Qin(k) - Qloss(k)) / (M * cp_s);

    %（4）积分
    Ts(k+1) = Ts(k) + dTs * dt;

end

% 最后一时刻计算
Qin(end)   = mdot * cp_f * (Tf - Ts(end));
Qloss(end) = U * A * (Ts(end) - Tenv);

%--------------------------------------------------------------
% 稳态判定（可根据需要调整阈值）
%--------------------------------------------------------------
tol = 1e-4;  % 稳态允许温度变化阈值（°C/s）
dTs_last = (Ts(end) - Ts(end-1)) / dt;

is_steady = abs(dTs_last) < tol;

%--------------------------------------------------------------
% 输出稳态参数到命令行
%--------------------------------------------------------------
fprintf("\n================= 稳态输出参数 =================\n");
fprintf("稳态储热温度 Ts_ss           = %.4f °C\n", Ts(end));
fprintf("稳态输入热量 Qin_ss          = %.4f W\n", Qin(end));
fprintf("稳态散热量 Qloss_ss          = %.4f W\n", Qloss(end));
fprintf("净热量（应接近0）Qnet_ss     = %.4f W\n", Qin(end) - Qloss(end));
fprintf("最后时刻温度变化率 dTs/dt    = %.6f °C/s\n", dTs_last);

if is_steady
    fprintf("稳态判定：系统已达到稳态 √\n");
else
    fprintf("稳态判定：尚未完全达到稳态 ×（可增加模拟时间）\n");
end
fprintf("=================================================\n\n");

%--------------------------------------------------------------
% 绘图
%--------------------------------------------------------------
figure;
subplot(3,1,1)
plot(t, Ts, 'LineWidth', 2);
xlabel('时间 (s)');
ylabel('Ts (°C)');
title('储热介质温度');

subplot(3,1,2)
plot(t, Qin, 'LineWidth', 2);
xlabel('时间 (s)');
ylabel('Q_{in} (W)');
title('从流体获得的热量');

subplot(3,1,3)
plot(t, Qloss, 'LineWidth', 2);
xlabel('时间 (s)');
ylabel('Q_{loss} (W)');
title('向环境的热损失');

end
