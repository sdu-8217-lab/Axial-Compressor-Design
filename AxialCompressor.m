classdef AxialCompressor
    properties
        % 输入参数（全部由用户定义）
        gas = struct();          % 工质物性
        inlet = struct();        % 进口参数
        outlet_pressure = [];    % 出口压力 (Pa)
        mass_flow = [];          % 质量流量 (kg/s)
        stages = [];             % 级数
        efficiency = struct();   % 效率参数（需包含ad和pol）
        geometry = struct();     % 几何参数
        u = [];                  % 圆周速度 (m/s)
        reaction_coeff = [];     % 反动度系数
        interstage_loss = struct(); % 级间损失参数
    end
    
    methods
        function obj = AxialCompressor(inputs)
            if nargin > 0
                obj = obj.set_inputs(inputs);
            end
        end
        
        function obj = set_inputs(obj, inputs)
            % 简化参数设置：直接赋值所有字段
            fields = fieldnames(inputs);
            for i = 1:length(fields)
                field_name = fields{i};
                % 直接赋值，覆盖原有值
                obj.(field_name) = inputs.(field_name);
            end
            
            % 设置级间损失默认值
            if ~isfield(obj.interstage_loss, 'K_eta') 
                % 效率修正系数默认值
                if ~isempty(obj.outlet_pressure) && ~isempty(obj.inlet) && isfield(obj.inlet, 'p')
                    if obj.outlet_pressure/obj.inlet.p < 10
                        obj.interstage_loss.K_eta = 0.95 * ones(1, obj.stages);
                    else
                        obj.interstage_loss.K_eta = 0.93 * ones(1, obj.stages);
                    end
                end
            end
            
            if ~isfield(obj.interstage_loss, 'K_h') 
                % 能量头修正系数默认值
                if ~isempty(obj.outlet_pressure) && ~isempty(obj.inlet) && isfield(obj.inlet, 'p')
                    if obj.outlet_pressure/obj.inlet.p < 10
                        obj.interstage_loss.K_h = 0.98 * ones(1, obj.stages);
                    else
                        obj.interstage_loss.K_h = 0.96 * ones(1, obj.stages);
                    end
                end
            end
        end
        
        function results = calculate(obj)
            % 检查必要参数是否已设置
            if ~isfield(obj.gas, 'k') || isempty(obj.gas.k)
                error('缺少必要参数: gas.k');
            end
            if ~isfield(obj.gas, 'R') || isempty(obj.gas.R)
                error('缺少必要参数: gas.R');
            end
            if ~isfield(obj.inlet, 'T') || isempty(obj.inlet.T)
                error('缺少必要参数: inlet.T');
            end
            if ~isfield(obj.inlet, 'p') || isempty(obj.inlet.p)
                error('缺少必要参数: inlet.p');
            end
            if ~isfield(obj.inlet, 'c') || isempty(obj.inlet.c)
                error('缺少必要参数: inlet.c');
            end
            if isempty(obj.outlet_pressure)
                error('缺少必要参数: outlet_pressure');
            end
            if isempty(obj.mass_flow)
                error('缺少必要参数: mass_flow');
            end
            if isempty(obj.stages)
                error('缺少必要参数: stages');
            end
            if ~isfield(obj.efficiency, 'ad') || isempty(obj.efficiency.ad)
                error('缺少必要参数: efficiency.ad');
            end
            if ~isfield(obj.efficiency, 'mech') || isempty(obj.efficiency.mech)
                error('缺少必要参数: efficiency.mech');
            end
            if ~isfield(obj.efficiency, 'leak') || isempty(obj.efficiency.leak)
                error('缺少必要参数: efficiency.leak');
            end
            if isempty(obj.u)
                error('缺少必要参数: u');
            end
            
            % 新增：检查级间损失参数
            if ~isfield(obj.interstage_loss, 'K_eta') || isempty(obj.interstage_loss.K_eta)
                error('缺少级间损失参数: interstage_loss.K_eta');
            end
            if ~isfield(obj.interstage_loss, 'K_h') || isempty(obj.interstage_loss.K_h)
                error('缺少级间损失参数: interstage_loss.K_h');
            end
            
            % 计算Cp
            k = obj.gas.k;
            R = obj.gas.R;
            Cp = k * R / (k - 1);
            
            % 1. 计算总绝热能量头
            p_ratio = obj.outlet_pressure / obj.inlet.p;
            H_ad_total = (k/(k-1)) * R * obj.inlet.T * (p_ratio^((k-1)/k) - 1);
            
            % 2. 计算重热系数（修正后的公式）
            % 根据[15](@ref)：a = 1 + (η_pol/η_ad - 1)(1 - 1/Z)
            if isfield(obj.efficiency, 'pol') && ~isempty(obj.efficiency.pol)
                % 如果用户提供了多变效率
                a = 1 + (obj.efficiency.pol/obj.efficiency.ad - 1) * (1 - 1/obj.stages);
            else
                % 默认情况下假设η_pol/η_ad ≈ 1.05（典型值）
                a = 1 + (1.05 - 1) * (1 - 1/obj.stages);
            end
            
            % 3. 分配各级能量头（应用级间损失修正）
            H_ad_stage = a * H_ad_total / obj.stages;
            H_ad_stage = H_ad_stage .* obj.interstage_loss.K_h; % 能量头修正
            
            % 初始化级参数
            T_in = obj.inlet.T;
            p_in = obj.inlet.p;
            c_in = obj.inlet.c;
            rho_in = p_in / (R * T_in);
            
            % 计算初始通流面积
            A_flow = obj.mass_flow / (rho_in * c_in);
            
            stage_results = cell(obj.stages, 1);
            total_power = 0;
            
            % 使用局部变量避免重复访问属性
            num_stages = obj.stages;
            for i = 1:num_stages
                % 4. 计算反动度
                if ~isempty(obj.reaction_coeff) && length(obj.reaction_coeff) >= i
                    Omega = obj.reaction_coeff(i);
                else
                    if num_stages > 1
                        Omega = 0.5 + 0.1*(i-1)/(num_stages-1);
                    else
                        Omega = 0.5;
                    end
                end
                
                % 5. 计算级绝热温升（应用级间损失修正）
                Delta_T_ad = H_ad_stage(i) / Cp;
                
                % 6. 计算实际温升（应用效率修正）
                stage_efficiency = obj.efficiency.ad * obj.interstage_loss.K_eta(i);
                total_efficiency = stage_efficiency * obj.efficiency.mech * obj.efficiency.leak;
                Delta_T = Delta_T_ad / total_efficiency;
                
                % 7. 计算出口温度
                T_out = T_in + Delta_T;
                
                % 8. 计算出口压力
                n = k / (k - stage_efficiency * (k - 1));
                p_out = p_in * (T_out/T_in)^(n/(n-1));
                
                % 9. 计算出口密度
                rho_out = p_out / (R * T_out);
                
                % 10. 计算出口速度
                K_L = 0.97 - 0.01*(i-1); % 减功系数随级数递减
                c_out = obj.mass_flow / (rho_out * A_flow) * K_L;
                
                % 11. 计算级功率
                power_stage = obj.mass_flow * Cp * Delta_T;
                total_power = total_power + power_stage;
                
                % 12. 存储级结果
                stage_results{i} = struct(...
                    'stage', i, ...
                    'inlet_T', T_in, ...
                    'outlet_T', T_out, ...
                    'inlet_p', p_in/1000, ...
                    'outlet_p', p_out/1000, ...
                    'inlet_velocity', c_in, ...
                    'outlet_velocity', c_out, ...
                    'density', rho_out, ...
                    'power', power_stage, ...
                    'reaction', Omega, ...
                    'pressure_ratio', p_out/p_in, ...
                    'temperature_rise', Delta_T, ...
                    'loss_correction', struct(...
                        'K_eta', obj.interstage_loss.K_eta(i), ...
                        'K_h', obj.interstage_loss.K_h(i), ...
                        'K_L', K_L));
                
                % 更新下一级进口参数
                T_in = T_out;
                p_in = p_out;
                c_in = c_out * 0.98; % 轴向速度衰减
                rho_in = rho_out;
                
                % 更新通流面积
                A_flow = obj.mass_flow / (rho_in * c_in);
            end
            
            % 13. 计算总效率
            total_efficiency = H_ad_total / (total_power / obj.mass_flow);
            
            % 14. 汇总结果
            results = struct(...
                'stages', num_stages, ...
                'total_power', total_power, ...
                'total_efficiency', total_efficiency, ...
                'outlet_T', T_out, ...
                'outlet_p', p_out/1000, ...
                'outlet_velocity', c_out, ...
                'stage_results', {stage_results}, ...
                'interstage_loss_params', obj.interstage_loss);
        end
        
        function display_stage_results(obj, results)
            % 显示各级详细结果
            fprintf('\n=== 轴流压缩机逐级计算结果 ===\n');
            fprintf('级数: %d\n', obj.stages);
            fprintf('总压比: %.2f\n', results.outlet_p * 1000 / obj.inlet.p);
            fprintf('总温升: %.2f K\n', results.outlet_T - obj.inlet.T);
            fprintf('总耗功: %.2f kW\n\n', results.total_power/1000);
            
            stages = results.stage_results;
            for i = 1:length(stages)
                s = stages{i};
                fprintf('--- 第%d级 ---\n', s.stage);
                fprintf('  效率修正系数 K_η: %.4f\n', s.loss_correction.K_eta);
                fprintf('  能量头修正系数 K_h: %.4f\n', s.loss_correction.K_h);
                fprintf('  减功系数 K_L: %.4f\n', s.loss_correction.K_L);
                fprintf('  进口温度: %.2f K\n', s.inlet_T);
                fprintf('  出口温度: %.2f K\n', s.outlet_T);
                fprintf('  进口压力: %.2f kPa\n', s.inlet_p);
                fprintf('  出口压力: %.2f kPa\n', s.outlet_p);
                fprintf('  压比: %.3f\n', s.pressure_ratio);
                fprintf('  温升: %.2f K\n', s.temperature_rise);
                fprintf('  进口速度: %.2f m/s\n', s.inlet_velocity);
                fprintf('  出口速度: %.2f m/s\n', s.outlet_velocity);
                fprintf('  反动度: %.3f\n', s.reaction);
                fprintf('  级功率: %.2f kW\n\n', s.power/1000);
            end
        end
        
        function plot_performance(obj, results)
            % 绘制压缩机性能曲线
            stages = [results.stage_results{:}];
            T_out = [stages.outlet_T];
            p_out = [stages.outlet_p];
            v_out = [stages.outlet_velocity];
            power = [stages.power];
            reaction = [stages.reaction];
            pressure_ratio = [stages.pressure_ratio];
            
            % 使用局部变量避免重复访问属性
            num_stages = obj.stages;
            
            figure('Position', [100, 100, 1200, 800])
            
            % 温度压力曲线
            subplot(2,2,1)
            yyaxis left
            plot(1:num_stages, T_out, '-o', 'LineWidth', 2)
            ylabel('温度 (K)')
            yyaxis right
            plot(1:num_stages, p_out, '-s', 'LineWidth', 2)
            ylabel('压力 (kPa)')
            title('各级出口温度和压力')
            xlabel('级数')
            grid on
            legend('温度', '压力', 'Location', 'best')
            
            % 速度曲线
            subplot(2,2,2)
            plot(1:num_stages, v_out, '-^', 'LineWidth', 2)
            ylabel('速度 (m/s)')
            title('各级出口速度')
            xlabel('级数')
            grid on
            
            % 功率曲线
            subplot(2,2,3)
            plot(1:num_stages, power/1000, '-d', 'LineWidth', 2)
            ylabel('功率 (kW)')
            title('各级耗功')
            xlabel('级数')
            grid on
            
            % 反动度和压比曲线
            subplot(2,2,4)
            yyaxis left
            plot(1:num_stages, reaction, '-*', 'LineWidth', 2)
            ylabel('反动度')
            yyaxis right
            plot(1:num_stages, pressure_ratio, '-+', 'LineWidth', 2)
            ylabel('压比')
            title('反动度与压比变化')
            xlabel('级数')
            grid on
            legend('反动度', '压比', 'Location', 'best')
        end
        
        function plot_loss_effects(obj, results)
            % 绘制级间损失影响曲线
            stages = [results.stage_results{:}];
            
            % 修正：分两步提取嵌套结构体字段
            loss_corrections = [stages.loss_correction];  % 提取所有loss_correction结构体
            loss_K_eta = [loss_corrections.K_eta];        % 提取K_eta值
            loss_K_h = [loss_corrections.K_h];            % 提取K_h值
            loss_K_L = [loss_corrections.K_L];            % 提取K_L值
            
            efficiency = [stages.pressure_ratio]./[stages.temperature_rise];
            
            % 使用局部变量避免重复访问属性
            num_stages = obj.stages;
            
            figure('Position', [100, 100, 1000, 700])
            
            % 损失系数变化
            subplot(2,2,1)
            plot(1:num_stages, loss_K_eta, '-o', 1:num_stages, loss_K_h, '-s', 1:num_stages, loss_K_L, '-d', 'LineWidth', 2)
            title('级间损失修正系数沿级变化')
            xlabel('级数')
            ylabel('修正系数')
            legend('K_η (效率)', 'K_h (能量头)', 'K_L (减功)', 'Location', 'best')
            grid on
            
            % 损失对效率的影响
            subplot(2,2,2)
            yyaxis left
            plot(1:num_stages, efficiency, '-^', 'LineWidth', 2)
            ylabel('级效率')
            yyaxis right
            plot(1:num_stages, 1-loss_K_eta, '-o', 'LineWidth', 2)
            ylabel('效率损失比例')
            title('级效率与损失关系')
            xlabel('级数')
            grid on
            legend('级效率', '效率损失', 'Location', 'best')
            
            % 损失对压比的影响
            subplot(2,2,3)
            pressure_ratio = [stages.pressure_ratio];
            yyaxis left
            plot(1:num_stages, pressure_ratio, '-*', 'LineWidth', 2)
            ylabel('级压比')
            yyaxis right
            plot(1:num_stages, 1-loss_K_h, '-s', 'LineWidth', 2)
            ylabel('能量头损失比例')
            title('压比与能量头损失')
            xlabel('级数')
            grid on
            legend('级压比', '能量头损失', 'Location', 'best')
            
            % 损失对轴向速度的影响
            subplot(2,2,4)
            velocity_ratio = [stages.outlet_velocity]./[stages.inlet_velocity];
            plot(1:num_stages, velocity_ratio, '-+', 1:num_stages, loss_K_L, '-d', 'LineWidth', 2)
            title('轴向速度变化与减功系数')
            xlabel('级数')
            ylabel('速度比/减功系数')
            legend('出口/进口速度比', '减功系数K_L', 'Location', 'best')
            grid on
        end
    end
end
