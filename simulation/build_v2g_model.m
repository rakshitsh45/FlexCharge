%% =========================================================================
% Project: FlexCharge - V2G & G2V Fast-Charging Station Optimization
% File: build_v2g_model.m
% Description: Programmatic Simulink Model Builder for flexcharge_v2g_g2v.slx
% Architecture: 3-Stage Power Topology with Zero-Feedthrough (D=0) State Space
% =========================================================================

function build_v2g_model()
    mdl = 'flexcharge_v2g_g2v';
    fprintf('Building professional Simulink model: %s.slx ...\n', mdl);

    % Close system if already open in memory
    if bdIsLoaded(mdl)
        close_system(mdl, 0);
    end

    % Create new blank system
    new_system(mdl);
    open_system(mdl);

    % Configure Model Solver & Simulation Settings
    set_param(mdl, 'SolverType', 'Fixed-step');
    set_param(mdl, 'Solver', 'FixedStepDiscrete');
    set_param(mdl, 'FixedStep', '1e-4');
    set_param(mdl, 'StartTime', '0.0');
    set_param(mdl, 'StopTime', '10.0');
    set_param(mdl, 'SaveOutput', 'on');
    set_param(mdl, 'OutputSaveName', 'yout');
    set_param(mdl, 'SaveTime', 'on');
    set_param(mdl, 'TimeSaveName', 'tout');
    set_param(mdl, 'PreLoadFcn', 'init_params;');

    % Set Clean Editor Canvas Appearance
    set_param(mdl, 'ScreenColor', 'white');

    %% --------------------------------------------------------------------
    % 1. TOP-LEVEL SUBSYSTEM INSTANTIATION
    % --------------------------------------------------------------------
    % Subsystem 1: Supervisory Grid & Demand Management
    add_block('simulink/Ports & Subsystems/Subsystem', [mdl, '/Supervisory_Grid_Manager'], ...
        'Position', [40, 140, 220, 250]);

    % Subsystem 2: Three-Phase AC Distribution Grid & Step-Down Transformer
    add_block('simulink/Ports & Subsystems/Subsystem', [mdl, '/Grid_and_Distribution_Transformer'], ...
        'Position', [280, 140, 480, 250]);

    % Subsystem 3: 3-Phase Active Front End (AFE) PWM Converter
    add_block('simulink/Ports & Subsystems/Subsystem', [mdl, '/Active_Front_End_AFE'], ...
        'Position', [540, 140, 740, 250]);

    % Subsystem 4: Common 800V DC Link Bus
    add_block('simulink/Ports & Subsystems/Subsystem', [mdl, '/Common_DC_Bus_800V'], ...
        'Position', [800, 140, 980, 250]);

    % Subsystem 5: Bidirectional DC-DC Buck-Boost Port
    add_block('simulink/Ports & Subsystems/Subsystem', [mdl, '/Bidirectional_DCDC_Port'], ...
        'Position', [800, 320, 980, 430]);

    % Subsystem 6: EV Lithium-Ion Battery Pack (60 kWh / 150 Ah)
    add_block('simulink/Ports & Subsystems/Subsystem', [mdl, '/EV_Lithium_Ion_Battery_Pack'], ...
        'Position', [540, 320, 740, 430]);

    % Subsystem 7: Dual-Loop Vector Controller (SRF d-q & CC-CV Logic)
    add_block('simulink/Ports & Subsystems/Subsystem', [mdl, '/Dual_Loop_Vector_Controller'], ...
        'Position', [280, 320, 480, 430]);

    % Subsystem 8: Scope & Performance Telemetry
    add_block('simulink/Ports & Subsystems/Subsystem', [mdl, '/Scopes_and_Performance_Metrics'], ...
        'Position', [40, 320, 220, 430]);

    sf = sfroot;

    %% --------------------------------------------------------------------
    % 2. SUPERVISORY GRID MANAGER
    % --------------------------------------------------------------------
    sub = [mdl, '/Supervisory_Grid_Manager'];
    clean_subsystem(sub);
    
    add_block('simulink/Sources/Clock', [sub, '/Clock'], 'Position', [30, 80, 60, 110]);
    
    fcn_blk = add_block('simulink/User-Defined Functions/MATLAB Function', [sub, '/Schedule_Logic'], ...
        'Position', [120, 60, 280, 130]);
    chart = sf.find('Path', [sub, '/Schedule_Logic'], '-isa', 'Stateflow.EMChart');
    if ~isempty(chart)
        chart.Script = sprintf(['function [v_scale, mode, i_bat_target, i_gq_target] = Schedule_Logic(t)\n', ...
                                '%% Interval 1: Normal G2V Fast Charging (0 - 3.5s)\n', ...
                                '%% Interval 2: 12%% Sag & Reactive Support (3.5 - 6.5s)\n', ...
                                '%% Interval 3: V2G Peak Shaving (-60A) (6.5 - 10.0s)\n', ...
                                'if t < 3.5\n', ...
                                '    v_scale = 1.0; mode = 1; i_bat_target = 75.0; i_gq_target = 0.0;\n', ...
                                'elseif t < 6.5\n', ...
                                '    v_scale = 0.88; mode = 2; i_bat_target = 0.0; i_gq_target = -40.0;\n', ...
                                'else\n', ...
                                '    v_scale = 1.0; mode = 3; i_bat_target = -60.0; i_gq_target = 0.0;\n', ...
                                'end\n']);
    end
    add_line(sub, 'Clock/1', 'Schedule_Logic/1');
    
    add_block('built-in/Outport', [sub, '/v_grid_scale'], 'Position', [340, 50, 370, 70]);
    add_block('built-in/Outport', [sub, '/operating_mode'], 'Position', [340, 80, 370, 100]);
    add_block('built-in/Outport', [sub, '/i_bat_target'], 'Position', [340, 110, 370, 130]);
    add_block('built-in/Outport', [sub, '/i_gq_target'], 'Position', [340, 140, 370, 160]);
    
    add_line(sub, 'Schedule_Logic/1', 'v_grid_scale/1');
    add_line(sub, 'Schedule_Logic/2', 'operating_mode/1');
    add_line(sub, 'Schedule_Logic/3', 'i_bat_target/1');
    add_line(sub, 'Schedule_Logic/4', 'i_gq_target/1');

    %% --------------------------------------------------------------------
    % 3. GRID AND DISTRIBUTION TRANSFORMER
    % --------------------------------------------------------------------
    sub = [mdl, '/Grid_and_Distribution_Transformer'];
    clean_subsystem(sub);
    
    add_block('built-in/Inport', [sub, '/v_scale'], 'Position', [30, 80, 60, 100]);
    add_block('simulink/Sources/Clock', [sub, '/Clock'], 'Position', [30, 140, 60, 170]);

    fcn_blk = add_block('simulink/User-Defined Functions/MATLAB Function', [sub, '/Grid_Voltage_Gen'], ...
        'Position', [120, 80, 260, 170]);
    chart = sf.find('Path', [sub, '/Grid_Voltage_Gen'], '-isa', 'Stateflow.EMChart');
    if ~isempty(chart)
        chart.Script = sprintf(['function [va, vb, vc, theta_grid] = Grid_Voltage_Gen(v_scale, t)\n', ...
                                'f_g = 50.0; omega = 2*pi*f_g;\n', ...
                                'V_LL = 415.0; V_pk = (V_LL / sqrt(3)) * sqrt(2) * v_scale;\n', ...
                                'theta_grid = mod(omega * t, 2*pi);\n', ...
                                'va = V_pk * cos(theta_grid);\n', ...
                                'vb = V_pk * cos(theta_grid - 2*pi/3);\n', ...
                                'vc = V_pk * cos(theta_grid + 2*pi/3);\n']);
    end
    add_line(sub, 'v_scale/1', 'Grid_Voltage_Gen/1');
    add_line(sub, 'Clock/1', 'Grid_Voltage_Gen/2');

    add_block('built-in/Outport', [sub, '/v_grid_a'], 'Position', [340, 75, 370, 95]);
    add_block('built-in/Outport', [sub, '/v_grid_b'], 'Position', [340, 105, 370, 125]);
    add_block('built-in/Outport', [sub, '/v_grid_c'], 'Position', [340, 135, 370, 155]);
    add_block('built-in/Outport', [sub, '/theta_grid'], 'Position', [340, 165, 370, 185]);

    add_line(sub, 'Grid_Voltage_Gen/1', 'v_grid_a/1');
    add_line(sub, 'Grid_Voltage_Gen/2', 'v_grid_b/1');
    add_line(sub, 'Grid_Voltage_Gen/3', 'v_grid_c/1');
    add_line(sub, 'Grid_Voltage_Gen/4', 'theta_grid/1');

    %% --------------------------------------------------------------------
    % 4. COMMON DC BUS SUBSYSTEM (800V)
    % --------------------------------------------------------------------
    sub = [mdl, '/Common_DC_Bus_800V'];
    clean_subsystem(sub);
    
    add_block('built-in/Inport', [sub, '/i_afe_dc'], 'Position', [30, 60, 60, 80]);
    add_block('built-in/Inport', [sub, '/i_dcdc_dc'], 'Position', [30, 120, 60, 140]);
    
    add_block('simulink/Math Operations/Sum', [sub, '/Sum'], 'Position', [110, 75, 135, 115], ...
        'Inputs', '+-');
    add_line(sub, 'i_afe_dc/1', 'Sum/1');
    add_line(sub, 'i_dcdc_dc/1', 'Sum/2');
    
    add_block('simulink/Math Operations/Gain', [sub, '/Gain_Cap'], 'Position', [170, 80, 230, 110], ...
        'Gain', '1e-4 / 4700e-6');
    add_line(sub, 'Sum/1', 'Gain_Cap/1');
    
    add_block('simulink/Discrete/Discrete-Time Integrator', [sub, '/Bus_Integrator'], ...
        'Position', [270, 75, 310, 115], ...
        'InitialCondition', '800.0', ...
        'SampleTime', '1e-4');
    add_line(sub, 'Gain_Cap/1', 'Bus_Integrator/1');
    
    add_block('built-in/Outport', [sub, '/V_dc'], 'Position', [360, 85, 390, 105]);
    add_line(sub, 'Bus_Integrator/1', 'V_dc/1');

    %% --------------------------------------------------------------------
    % 5. EV BATTERY PACK SUBSYSTEM (D=0 Strictly Causal Form)
    % --------------------------------------------------------------------
    sub = [mdl, '/EV_Lithium_Ion_Battery_Pack'];
    clean_subsystem(sub);
    
    add_block('built-in/Inport', [sub, '/i_bat'], 'Position', [30, 80, 60, 100]);
    
    add_block('built-in/UnitDelay', [sub, '/Delay_SoC'], 'Position', [100, 130, 130, 160], ...
        'X0', '25.0', 'SampleTime', '1e-4');
    
    fcn_blk = add_block('simulink/User-Defined Functions/MATLAB Function', [sub, '/Battery_Dynamics'], ...
        'Position', [180, 60, 320, 150]);
    chart = sf.find('Path', [sub, '/Battery_Dynamics'], '-isa', 'Stateflow.EMChart');
    if ~isempty(chart)
        chart.Script = sprintf(['function [v_bat, soc, next_soc] = Battery_Dynamics(i_bat, current_soc)\n', ...
                                'dt = 1e-4;\n', ...
                                'Q_Ah = 150.0; R_int = 0.035;\n', ...
                                'soc = current_soc;\n', ...
                                'V_oc = 370.0 + (420.0 - 370.0) * (soc / 100.0);\n', ...
                                'v_bat = V_oc + i_bat * R_int;\n', ...
                                'next_soc = current_soc + (i_bat / (Q_Ah * 3600)) * 100 * dt;\n']);
    end
    add_line(sub, 'i_bat/1', 'Battery_Dynamics/1');
    add_line(sub, 'Delay_SoC/1', 'Battery_Dynamics/2');
    add_line(sub, 'Battery_Dynamics/3', 'Delay_SoC/1');

    add_block('built-in/Outport', [sub, '/v_bat'], 'Position', [380, 75, 410, 95]);
    add_block('built-in/Outport', [sub, '/soc'], 'Position', [380, 115, 410, 135]);
    add_line(sub, 'Battery_Dynamics/1', 'v_bat/1');
    add_line(sub, 'Battery_Dynamics/2', 'soc/1');

    %% --------------------------------------------------------------------
    % 6. DUAL LOOP VECTOR CONTROLLER
    % --------------------------------------------------------------------
    sub = [mdl, '/Dual_Loop_Vector_Controller'];
    clean_subsystem(sub);
    
    add_block('built-in/Inport', [sub, '/v_dc'], 'Position', [30, 30, 60, 50]);
    add_block('built-in/Inport', [sub, '/i_gq_target'], 'Position', [30, 70, 60, 90]);
    add_block('built-in/Inport', [sub, '/v_bat'], 'Position', [30, 110, 60, 130]);
    add_block('built-in/Inport', [sub, '/soc'], 'Position', [30, 150, 60, 170]);
    add_block('built-in/Inport', [sub, '/i_bat_target'], 'Position', [30, 190, 60, 210]);
    add_block('built-in/Inport', [sub, '/mode'], 'Position', [30, 230, 60, 250]);

    add_block('built-in/UnitDelay', [sub, '/Delay_IntVdc'], 'Position', [80, 270, 110, 300], ...
        'X0', '0.0', 'SampleTime', '1e-4');
    add_block('built-in/UnitDelay', [sub, '/Delay_IntVbat'], 'Position', [80, 320, 110, 350], ...
        'X0', '0.0', 'SampleTime', '1e-4');

    fcn_blk = add_block('simulink/User-Defined Functions/MATLAB Function', [sub, '/Control_Algorithm'], ...
        'Position', [160, 40, 340, 260]);
    chart = sf.find('Path', [sub, '/Control_Algorithm'], '-isa', 'Stateflow.EMChart');
    if ~isempty(chart)
        chart.Script = sprintf(['function [i_gd_ref, i_gq_ref, i_bat_ref, next_int_vdc, next_int_vbat] = Control_Algorithm(v_dc, i_gq_target, v_bat, soc, i_bat_target, mode, int_vdc, int_vbat)\n', ...
                                'dt = 1e-4;\n', ...
                                '%% Outer DC Bus PI Controller\n', ...
                                'err_vdc = 800.0 - v_dc;\n', ...
                                'next_int_vdc = int_vdc + err_vdc * dt;\n', ...
                                'next_int_vdc = max(min(next_int_vdc, 100.0), -100.0);\n', ...
                                'i_gd_ref = 1.45 * err_vdc + 28.0 * int_vdc;\n', ...
                                'i_gd_ref = max(min(i_gd_ref, 120.0), -120.0);\n', ...
                                'i_gq_ref = i_gq_target;\n', ...
                                '%% Battery CC-CV & V2G Control Logic\n', ...
                                'if mode == 1\n', ...
                                '    if soc >= 80.0 || v_bat >= 420.0\n', ...
                                '        err_vbat = 420.0 - v_bat;\n', ...
                                '        next_int_vbat = int_vbat + err_vbat * dt;\n', ...
                                '        i_bat_ref = 2.2 * err_vbat + 8.5 * int_vbat;\n', ...
                                '        i_bat_ref = max(min(i_bat_ref, 75.0), 0.0);\n', ...
                                '    else\n', ...
                                '        next_int_vbat = int_vbat;\n', ...
                                '        i_bat_ref = i_bat_target;\n', ...
                                '    end\n', ...
                                'else\n', ...
                                '    next_int_vbat = int_vbat;\n', ...
                                '    i_bat_ref = i_bat_target;\n', ...
                                'end\n']);
    end
    add_line(sub, 'v_dc/1', 'Control_Algorithm/1');
    add_line(sub, 'i_gq_target/1', 'Control_Algorithm/2');
    add_line(sub, 'v_bat/1', 'Control_Algorithm/3');
    add_line(sub, 'soc/1', 'Control_Algorithm/4');
    add_line(sub, 'i_bat_target/1', 'Control_Algorithm/5');
    add_line(sub, 'mode/1', 'Control_Algorithm/6');
    add_line(sub, 'Delay_IntVdc/1', 'Control_Algorithm/7');
    add_line(sub, 'Delay_IntVbat/1', 'Control_Algorithm/8');

    add_line(sub, 'Control_Algorithm/4', 'Delay_IntVdc/1');
    add_line(sub, 'Control_Algorithm/5', 'Delay_IntVbat/1');

    add_block('built-in/Outport', [sub, '/i_gd_ref'], 'Position', [400, 60, 430, 80]);
    add_block('built-in/Outport', [sub, '/i_gq_ref'], 'Position', [400, 110, 430, 130]);
    add_block('built-in/Outport', [sub, '/i_bat_ref'], 'Position', [400, 160, 430, 180]);

    add_line(sub, 'Control_Algorithm/1', 'i_gd_ref/1');
    add_line(sub, 'Control_Algorithm/2', 'i_gq_ref/1');
    add_line(sub, 'Control_Algorithm/3', 'i_bat_ref/1');

    %% --------------------------------------------------------------------
    % 7. BIDIRECTIONAL DC-DC PORT SUBSYSTEM (D=0 Strictly Causal Form)
    % --------------------------------------------------------------------
    sub = [mdl, '/Bidirectional_DCDC_Port'];
    clean_subsystem(sub);
    
    add_block('built-in/Inport', [sub, '/i_bat_ref'], 'Position', [30, 50, 60, 70]);
    add_block('built-in/Inport', [sub, '/v_bat'], 'Position', [30, 95, 60, 115]);
    add_block('built-in/Inport', [sub, '/V_dc'], 'Position', [30, 140, 60, 160]);

    add_block('built-in/UnitDelay', [sub, '/Delay_IbatState'], 'Position', [80, 180, 110, 210], ...
        'X0', '0.0', 'SampleTime', '1e-4');

    fcn_blk = add_block('simulink/User-Defined Functions/MATLAB Function', [sub, '/DCDC_Dynamics'], ...
        'Position', [160, 50, 320, 180]);
    chart = sf.find('Path', [sub, '/DCDC_Dynamics'], '-isa', 'Stateflow.EMChart');
    if ~isempty(chart)
        chart.Script = sprintf(['function [i_bat, i_dcdc_dc, next_state] = DCDC_Dynamics(i_bat_ref, v_bat, V_dc, current_state)\n', ...
                                'dt = 1e-4; tau = 2e-3;\n', ...
                                '%% D=0 formulation: output current is purely state-driven\n', ...
                                'i_bat = current_state;\n', ...
                                'next_state = current_state + ((i_bat_ref - current_state) / tau) * dt;\n', ...
                                'eta = 0.985;\n', ...
                                'if i_bat >= 0\n', ...
                                '    p_dc = (v_bat * i_bat) / eta;\n', ...
                                'else\n', ...
                                '    p_dc = (v_bat * i_bat) * eta;\n', ...
                                'end\n', ...
                                'i_dcdc_dc = p_dc / max(V_dc, 100.0);\n']);
    end
    add_line(sub, 'i_bat_ref/1', 'DCDC_Dynamics/1');
    add_line(sub, 'v_bat/1', 'DCDC_Dynamics/2');
    add_line(sub, 'V_dc/1', 'DCDC_Dynamics/3');
    add_line(sub, 'Delay_IbatState/1', 'DCDC_Dynamics/4');

    add_line(sub, 'DCDC_Dynamics/3', 'Delay_IbatState/1');

    add_block('built-in/Outport', [sub, '/i_bat'], 'Position', [370, 70, 400, 90]);
    add_block('built-in/Outport', [sub, '/i_dcdc_dc'], 'Position', [370, 120, 400, 140]);
    add_line(sub, 'DCDC_Dynamics/1', 'i_bat/1');
    add_line(sub, 'DCDC_Dynamics/2', 'i_dcdc_dc/1');

    %% --------------------------------------------------------------------
    % 8. ACTIVE FRONT END (AFE) SUBSYSTEM (D=0 Strictly Causal Form)
    % --------------------------------------------------------------------
    sub = [mdl, '/Active_Front_End_AFE'];
    clean_subsystem(sub);
    
    add_block('built-in/Inport', [sub, '/i_gd_ref'], 'Position', [30, 30, 60, 50]);
    add_block('built-in/Inport', [sub, '/i_gq_ref'], 'Position', [30, 70, 60, 90]);
    add_block('built-in/Inport', [sub, '/theta_grid'], 'Position', [30, 110, 60, 130]);
    add_block('built-in/Inport', [sub, '/v_grid_a'], 'Position', [30, 150, 60, 170]);
    add_block('built-in/Inport', [sub, '/V_dc'], 'Position', [30, 190, 60, 210]);

    add_block('built-in/UnitDelay', [sub, '/Delay_IgdState'], 'Position', [80, 230, 110, 260], ...
        'X0', '0.0', 'SampleTime', '1e-4');
    add_block('built-in/UnitDelay', [sub, '/Delay_IgqState'], 'Position', [80, 280, 110, 310], ...
        'X0', '0.0', 'SampleTime', '1e-4');

    fcn_blk = add_block('simulink/User-Defined Functions/MATLAB Function', [sub, '/AFE_Dynamics'], ...
        'Position', [160, 30, 340, 220]);
    chart = sf.find('Path', [sub, '/AFE_Dynamics'], '-isa', 'Stateflow.EMChart');
    if ~isempty(chart)
        chart.Script = sprintf(['function [i_afe_dc, ia, ib, ic, P_grid, Q_grid, next_igd, next_igq] = AFE_Dynamics(i_gd_ref, i_gq_ref, theta, va, V_dc, current_igd, current_igq)\n', ...
                                'dt = 1e-4; tau = 1.5e-3;\n', ...
                                '%% D=0 formulation: converter output currents driven by state\n', ...
                                'igd = current_igd; igq = current_igq;\n', ...
                                'next_igd = current_igd + ((i_gd_ref - current_igd) / tau) * dt;\n', ...
                                'next_igq = current_igq + ((i_gq_ref - current_igq) / tau) * dt;\n', ...
                                'ia = igd * cos(theta) - igq * sin(theta);\n', ...
                                'ib = igd * cos(theta - 2*pi/3) - igq * sin(theta - 2*pi/3);\n', ...
                                'ic = igd * cos(theta + 2*pi/3) - igq * sin(theta + 2*pi/3);\n', ...
                                'V_pk = 338.84;\n', ...
                                'P_grid = 1.5 * V_pk * igd;\n', ...
                                'Q_grid = -1.5 * V_pk * igq;\n', ...
                                'eta = 0.985;\n', ...
                                'if P_grid >= 0, P_dc = P_grid * eta; else, P_dc = P_grid / eta; end\n', ...
                                'i_afe_dc = P_dc / max(V_dc, 100.0);\n']);
    end
    add_line(sub, 'i_gd_ref/1', 'AFE_Dynamics/1');
    add_line(sub, 'i_gq_ref/1', 'AFE_Dynamics/2');
    add_line(sub, 'theta_grid/1', 'AFE_Dynamics/3');
    add_line(sub, 'v_grid_a/1', 'AFE_Dynamics/4');
    add_line(sub, 'V_dc/1', 'AFE_Dynamics/5');
    add_line(sub, 'Delay_IgdState/1', 'AFE_Dynamics/6');
    add_line(sub, 'Delay_IgqState/1', 'AFE_Dynamics/7');

    add_line(sub, 'AFE_Dynamics/7', 'Delay_IgdState/1');
    add_line(sub, 'AFE_Dynamics/8', 'Delay_IgqState/1');

    add_block('built-in/Outport', [sub, '/i_afe_dc'], 'Position', [400, 35, 430, 55]);
    add_block('built-in/Outport', [sub, '/i_grid_a'], 'Position', [400, 65, 430, 85]);
    add_block('built-in/Outport', [sub, '/i_grid_b'], 'Position', [400, 95, 430, 115]);
    add_block('built-in/Outport', [sub, '/i_grid_c'], 'Position', [400, 125, 430, 145]);
    add_block('built-in/Outport', [sub, '/P_grid'], 'Position', [400, 155, 430, 175]);
    add_block('built-in/Outport', [sub, '/Q_grid'], 'Position', [400, 185, 430, 205]);

    add_line(sub, 'AFE_Dynamics/1', 'i_afe_dc/1');
    add_line(sub, 'AFE_Dynamics/2', 'i_grid_a/1');
    add_line(sub, 'AFE_Dynamics/3', 'i_grid_b/1');
    add_line(sub, 'AFE_Dynamics/4', 'i_grid_c/1');
    add_line(sub, 'AFE_Dynamics/5', 'P_grid/1');
    add_line(sub, 'AFE_Dynamics/6', 'Q_grid/1');

    %% --------------------------------------------------------------------
    % 9. SCOPE & TELEMETRY SUBSYSTEM
    % --------------------------------------------------------------------
    sub = [mdl, '/Scopes_and_Performance_Metrics'];
    clean_subsystem(sub);
    
    add_block('built-in/Inport', [sub, '/v_grid_a'], 'Position', [30, 40, 60, 60]);
    add_block('built-in/Inport', [sub, '/i_grid_a'], 'Position', [30, 80, 60, 100]);
    add_block('built-in/Inport', [sub, '/P_grid'], 'Position', [30, 120, 60, 140]);
    add_block('built-in/Inport', [sub, '/Q_grid'], 'Position', [30, 160, 60, 180]);
    add_block('built-in/Inport', [sub, '/V_dc'], 'Position', [30, 200, 60, 220]);
    add_block('built-in/Inport', [sub, '/i_bat'], 'Position', [30, 240, 60, 260]);
    add_block('built-in/Inport', [sub, '/soc'], 'Position', [30, 280, 60, 300]);

    % Multi-channel Scope
    add_block('simulink/Sinks/Scope', [sub, '/Station_Telemetry_Scope'], ...
        'Position', [150, 40, 200, 100], ...
        'NumInputPorts', '4');
    add_line(sub, 'v_grid_a/1', 'Station_Telemetry_Scope/1');
    add_line(sub, 'i_grid_a/1', 'Station_Telemetry_Scope/2');
    add_line(sub, 'P_grid/1', 'Station_Telemetry_Scope/3');
    add_line(sub, 'V_dc/1', 'Station_Telemetry_Scope/4');

    % Log to workspace
    add_block('simulink/Sinks/To Workspace', [sub, '/Log_Vdc'], 'Position', [150, 195, 230, 225], ...
        'VariableName', 'sim_Vdc', 'SaveFormat', 'Timeseries');
    add_block('simulink/Sinks/To Workspace', [sub, '/Log_Ibat'], 'Position', [150, 235, 230, 265], ...
        'VariableName', 'sim_Ibat', 'SaveFormat', 'Timeseries');
    add_block('simulink/Sinks/To Workspace', [sub, '/Log_Pgrid'], 'Position', [150, 115, 230, 145], ...
        'VariableName', 'sim_Pgrid', 'SaveFormat', 'Timeseries');
    add_line(sub, 'V_dc/1', 'Log_Vdc/1');
    add_line(sub, 'i_bat/1', 'Log_Ibat/1');
    add_line(sub, 'P_grid/1', 'Log_Pgrid/1');

    %% --------------------------------------------------------------------
    % 10. INTERCONNECT TOP-LEVEL SUBSYSTEMS
    % --------------------------------------------------------------------
    % Grid Manager -> Grid & Controller
    add_line(mdl, 'Supervisory_Grid_Manager/1', 'Grid_and_Distribution_Transformer/1'); % v_scale
    add_line(mdl, 'Supervisory_Grid_Manager/4', 'Dual_Loop_Vector_Controller/2');      % i_gq_target
    add_line(mdl, 'Supervisory_Grid_Manager/3', 'Dual_Loop_Vector_Controller/5');      % i_bat_target
    add_line(mdl, 'Supervisory_Grid_Manager/2', 'Dual_Loop_Vector_Controller/6');      % mode

    % Grid -> AFE
    add_line(mdl, 'Grid_and_Distribution_Transformer/4', 'Active_Front_End_AFE/3');    % theta_grid
    add_line(mdl, 'Grid_and_Distribution_Transformer/1', 'Active_Front_End_AFE/4');    % v_grid_a

    % Controller -> AFE
    add_line(mdl, 'Dual_Loop_Vector_Controller/1', 'Active_Front_End_AFE/1');          % i_gd_ref
    add_line(mdl, 'Dual_Loop_Vector_Controller/2', 'Active_Front_End_AFE/2');          % i_gq_ref

    % Top-level Unit Delays for physical state causality & zero algebraic loops
    add_block('built-in/UnitDelay', [mdl, '/Delay_Ibat_Cmd'], 'Position', [500, 395, 525, 415], ...
        'X0', '0.0', 'SampleTime', '1e-4');
    add_block('built-in/UnitDelay', [mdl, '/Delay_Vbat_Feedback'], 'Position', [500, 340, 525, 360], ...
        'X0', '385.0', 'SampleTime', '1e-4');
    add_block('built-in/UnitDelay', [mdl, '/Delay_SoC_Feedback'], 'Position', [500, 365, 525, 385], ...
        'X0', '25.0', 'SampleTime', '1e-4');

    % Controller -> DC-DC Port (Delayed Command)
    add_line(mdl, 'Dual_Loop_Vector_Controller/3', 'Delay_Ibat_Cmd/1');
    add_line(mdl, 'Delay_Ibat_Cmd/1', 'Bidirectional_DCDC_Port/1');

    % AFE -> DC Bus
    add_line(mdl, 'Active_Front_End_AFE/1', 'Common_DC_Bus_800V/1');                   % i_afe_dc

    % DC-DC Port -> DC Bus
    add_line(mdl, 'Bidirectional_DCDC_Port/2', 'Common_DC_Bus_800V/2');                % i_dcdc_dc

    % DC Bus -> AFE, DC-DC Port, Controller
    add_line(mdl, 'Common_DC_Bus_800V/1', 'Active_Front_End_AFE/5');                  % V_dc -> AFE
    add_line(mdl, 'Common_DC_Bus_800V/1', 'Bidirectional_DCDC_Port/3');               % V_dc -> DCDC
    add_line(mdl, 'Common_DC_Bus_800V/1', 'Dual_Loop_Vector_Controller/1');           % V_dc -> Controller

    % DC-DC Port -> Battery
    add_line(mdl, 'Bidirectional_DCDC_Port/1', 'EV_Lithium_Ion_Battery_Pack/1');       % i_bat

    % Battery -> DC-DC Port (Delayed Feedback)
    add_block('built-in/UnitDelay', [mdl, '/Delay_Vbat_DCDC'], 'Position', [750, 360, 775, 380], ...
        'X0', '385.0', 'SampleTime', '1e-4');
    add_line(mdl, 'EV_Lithium_Ion_Battery_Pack/1', 'Delay_Vbat_DCDC/1');
    add_line(mdl, 'Delay_Vbat_DCDC/1', 'Bidirectional_DCDC_Port/2');       % v_bat -> DCDC

    % Battery -> Controller (Delayed Feedback)
    add_line(mdl, 'EV_Lithium_Ion_Battery_Pack/1', 'Delay_Vbat_Feedback/1');
    add_line(mdl, 'Delay_Vbat_Feedback/1', 'Dual_Loop_Vector_Controller/3');
    add_line(mdl, 'EV_Lithium_Ion_Battery_Pack/2', 'Delay_SoC_Feedback/1');
    add_line(mdl, 'Delay_SoC_Feedback/1', 'Dual_Loop_Vector_Controller/4');

    % Telemetry connections
    add_line(mdl, 'Grid_and_Distribution_Transformer/1', 'Scopes_and_Performance_Metrics/1'); % v_grid_a
    add_line(mdl, 'Active_Front_End_AFE/2', 'Scopes_and_Performance_Metrics/2');              % i_grid_a
    add_line(mdl, 'Active_Front_End_AFE/5', 'Scopes_and_Performance_Metrics/3');              % P_grid
    add_line(mdl, 'Active_Front_End_AFE/6', 'Scopes_and_Performance_Metrics/4');              % Q_grid
    add_line(mdl, 'Common_DC_Bus_800V/1', 'Scopes_and_Performance_Metrics/5');                % V_dc
    add_line(mdl, 'Bidirectional_DCDC_Port/1', 'Scopes_and_Performance_Metrics/6');           % i_bat
    add_line(mdl, 'EV_Lithium_Ion_Battery_Pack/2', 'Scopes_and_Performance_Metrics/7');       % soc

    % Save and close
    save_system(mdl, fullfile('simulation', [mdl, '.slx']));
    close_system(mdl);
    fprintf('Simulink model %s.slx built and saved successfully in simulation/!\n', mdl);
end

function clean_subsystem(sub_path)
    % Remove default inport/outport blocks inside newly created subsystem
    blks = find_system(sub_path, 'SearchDepth', 1, 'Type', 'Block');
    for i = 1:length(blks)
        if ~strcmp(blks{i}, sub_path)
            delete_block(blks{i});
        end
    end
end
