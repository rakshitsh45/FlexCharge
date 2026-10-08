%% =========================================================================
% Project: FlexCharge - V2G & G2V Fast-Charging Station Optimization
% File: simulate_flexcharge_dynamics.m
% Description: High-Fidelity Non-Linear Dynamic State-Space Simulation Engine
% Author: FlexCharge Engineering Team
% =========================================================================

function results = simulate_flexcharge_dynamics()
    fprintf('=================================================================\n');
    fprintf('  FLEXCHARGE: V2G/G2V FAST CHARGING STATION DYNAMIC SIMULATION   \n');
    fprintf('=================================================================\n\n');

    % Load master parameter set
    init_params;

    % Time discretization
    dt = Ts;                        % 10 microseconds step
    t_span = 0:dt:T_stop;
    N_steps = length(t_span);
    fprintf('Total simulation duration: %.2f seconds (%d calculation steps)\n', T_stop, N_steps);

    % Pre-allocate state and telemetry arrays
    log_decim = 5;                  % Log every 50 us (20 kHz sampling)
    N_log_est = ceil(N_steps / log_decim);

    t_out          = zeros(1, N_log_est);
    v_grid_a       = zeros(1, N_log_est);
    v_grid_b       = zeros(1, N_log_est);
    v_grid_c       = zeros(1, N_log_est);
    i_grid_a       = zeros(1, N_log_est);
    i_grid_b       = zeros(1, N_log_est);
    i_grid_c       = zeros(1, N_log_est);
    
    v_gd_log       = zeros(1, N_log_est);
    v_gq_log       = zeros(1, N_log_est);
    i_gd_log       = zeros(1, N_log_est);
    i_gq_log       = zeros(1, N_log_est);
    i_gd_ref_log   = zeros(1, N_log_est);
    i_gq_ref_log   = zeros(1, N_log_est);
    
    v_dc_log       = zeros(1, N_log_est);
    v_dc_ref_log   = zeros(1, N_log_est);
    
    p_grid_log     = zeros(1, N_log_est);
    q_grid_log     = zeros(1, N_log_est);
    pf_grid_log    = zeros(1, N_log_est);
    
    i_bat_log      = zeros(1, N_log_est);
    i_bat_ref_log  = zeros(1, N_log_est);
    v_bat_log      = zeros(1, N_log_est);
    soc_log        = zeros(1, N_log_est);
    p_bat_log      = zeros(1, N_log_est);
    mode_log       = zeros(1, N_log_est);

    % Initial Physical States
    v_dc       = V_dc_nom;          % Start at nominal 800V
    i_gd       = 0.0;
    i_gq       = 0.0;
    i_bat      = 0.0;
    soc        = SoC_initial;       % 25% Initial State of Charge
    
    % Controller Integrators
    int_vdc    = 0.0;
    int_igd    = 0.0;
    int_igq    = 0.0;
    int_ibat   = 0.0;
    int_vbat   = 0.0;

    fprintf('Executing dynamic simulation across 3 operational intervals...\n');
    tic;

    log_idx = 1;

    for k = 1:N_steps
        t = t_span(k);

        %% ----------------------------------------------------------------
        % 1. SCENARIO TIMELINE & SUPERVISORY DISPATCH
        % ----------------------------------------------------------------
        if t < T_sag_start
            % Interval 1 [0.0s - 3.5s]: Normal Operations (G2V Charging)
            v_grid_scale   = 1.0;
            operating_mode = 1;     % G2V Mode
            i_bat_target   = I_ch_CC; % +75 A
            i_gq_target    = 0.0;   % Unity Power Factor
            
        elseif t >= T_sag_start && t < T_sag_end
            % Interval 2 [3.5s - 6.5s]: Local Inductive Load -> 12% Voltage Sag
            v_grid_scale   = V_sag_factor; % 0.88 p.u.
            operating_mode = 2;     % Grid Sag / Reactive Support Mode
            i_bat_target   = 0.0;   % Curtail EV charging to relieve grid
            % Inject reactive current to support terminal grid voltage (IEEE 1547)
            i_gq_target    = -40.0; % Capacitive reactive current (-40 A)
            
        else
            % Interval 3 [6.5s - 10.0s]: V2G Active Grid Support (Peak Demand Shaving)
            v_grid_scale   = 1.0;
            operating_mode = 3;     % V2G Mode
            i_bat_target   = I_dis_V2G; % -60 A discharge
            i_gq_target    = 0.0;   % Unity Power Factor (Inverting)
        end

        %% ----------------------------------------------------------------
        % 2. THREE-PHASE GRID VOLTAGE GENERATION & PARK TRANSFORM
        % ----------------------------------------------------------------
        theta_grid = mod(omega_g * t, 2*pi);
        V_pk = V_grid_peak * v_grid_scale;
        
        % Balanced 3-phase grid voltages (Cosine convention for direct d-axis alignment)
        va = V_pk * cos(theta_grid);
        vb = V_pk * cos(theta_grid - 2*pi/3);
        vc = V_pk * cos(theta_grid + 2*pi/3);

        % Synchronous Reference Frame (SRF) Park Transformation:
        % In steady-state: v_gd = V_pk, v_gq = 0
        v_gd = (2/3) * (va * cos(theta_grid) + vb * cos(theta_grid - 2*pi/3) + vc * cos(theta_grid + 2*pi/3));
        v_gq = -(2/3) * (va * sin(theta_grid) + vb * sin(theta_grid - 2*pi/3) + vc * sin(theta_grid + 2*pi/3));

        %% ----------------------------------------------------------------
        % 3. EV BATTERY CC-CV & V2G CHARGING PORT CONTROLLER
        % ----------------------------------------------------------------
        % Thevenin battery model: OCV vs SoC
        V_oc = 370.0 + (V_bat_max - 370.0) * (soc / 100.0);
        v_bat = V_oc + i_bat * R_bat_int;

        % CC-CV Mode Selection logic
        if operating_mode == 1 % G2V
            if soc >= SoC_CV_threshold || v_bat >= V_bat_max
                % CV Mode: Battery Voltage Regulated to V_bat_max (420V)
                err_vbat = V_bat_max - v_bat;
                int_vbat = int_vbat + err_vbat * dt;
                int_vbat = max(min(int_vbat, 20.0), -20.0);
                i_bat_ref = Kp_vb * err_vbat + Ki_vb * int_vbat;
                i_bat_ref = max(min(i_bat_ref, I_ch_CC), 0.0);
            else
                % CC Mode: Constant Current Setpoint
                i_bat_ref = i_bat_target;
            end
        else
            % Sag Standby (0 A) or V2G (-60 A)
            i_bat_ref = i_bat_target;
        end

        % Inner Battery Inductor Current Loop
        err_ibat = i_bat_ref - i_bat;
        int_ibat = int_ibat + err_ibat * dt;
        int_ibat = max(min(int_ibat, 5.0), -5.0);
        d_cmd = (v_bat / max(v_dc, 100.0)) + Kp_ib * err_ibat + Ki_ib * int_ibat;
        d_cmd = max(min(d_cmd, 0.95), 0.05);

        % DC-DC Inductor Dynamics
        di_bat_dt = (d_cmd * v_dc - v_bat - R_dcdc * i_bat) / L_dcdc;
        i_bat = i_bat + di_bat_dt * dt;

        % Battery SoC Integration (Coulomb Counting)
        dsoc_dt = (i_bat / (Q_bat_Ah * 3600.0)) * 100.0;
        soc = soc + dsoc_dt * dt;

        % DC Bus current drawn by DC-DC Converter (with 98.5% efficiency)
        eta_dcdc = 0.985;
        if i_bat >= 0
            p_dcdc = (v_bat * i_bat) / eta_dcdc;
        else
            p_dcdc = (v_bat * i_bat) * eta_dcdc;
        end
        i_dcdc_dc = p_dcdc / max(v_dc, 100.0);

        %% ----------------------------------------------------------------
        % 4. AFE DUAL-LOOP D-Q VECTOR CONTROL
        % ----------------------------------------------------------------
        % Outer DC Bus Voltage Controller: Regulates V_dc to 800V
        % Error definition: V_dc_nom - v_dc
        err_vdc = V_dc_nom - v_dc;
        int_vdc = int_vdc + err_vdc * dt;
        int_vdc = max(min(int_vdc, V_dc_lim_max), V_dc_lim_min);
        
        % Feedforward load compensation + PI output
        % P_load = p_dcdc -> i_d_ff = (P_load / (1.5 * v_gd))
        i_d_ff = p_dcdc / (1.5 * max(v_gd, 100.0));
        i_gd_ref = i_d_ff + Kp_dc * err_vdc + Ki_dc * int_vdc;
        i_gd_ref = max(min(i_gd_ref, V_dc_lim_max), V_dc_lim_min);
        
        i_gq_ref = i_gq_target;

        % Inner Current Controllers with Decoupling Feedforward
        err_igd = i_gd_ref - i_gd;
        int_igd = int_igd + err_igd * dt;
        int_igd = max(min(int_igd, 150.0), -150.0);
        
        err_igq = i_gq_ref - i_gq;
        int_igq = int_igq + err_igq * dt;
        int_igq = max(min(int_igq, 150.0), -150.0);

        % Decoupled control law:
        u_d = Kp_i * err_igd + Ki_i * int_igd;
        u_q = Kp_i * err_igq + Ki_i * int_igq;
        
        v_conv_d = v_gd + omega_g * L_grid * i_gq - u_d;
        v_conv_q = v_gq - omega_g * L_grid * i_gd - u_q;

        % AFE Inductor Dynamics in dq Frame:
        di_gd_dt = (v_gd - v_conv_d + omega_g * L_grid * i_gq - R_grid * i_gd) / L_grid;
        di_gq_dt = (v_gq - v_conv_q - omega_g * L_grid * i_gd - R_grid * i_gq) / L_grid;
        
        i_gd = i_gd + di_gd_dt * dt;
        i_gq = i_gq + di_gq_dt * dt;

        % 3-Phase AC Current Synthesis (Inverse Park Transform)
        % Real-world AFE converters include dead-time harmonics (5th, 7th, 11th)
        % and PWM carrier ripple (f_sw = 10 kHz)
        h5_mag  = 0.014 * abs(i_gd); % 1.4% 5th harmonic (negative sequence)
        h7_mag  = 0.009 * abs(i_gd); % 0.9% 7th harmonic (positive sequence)
        h11_mag = 0.004 * abs(i_gd); % 0.4% 11th harmonic
        carrier_ripple = 0.006 * max(abs(i_gd), 15.0) * sin(2*pi*f_sw*t);

        % Fundamental current components from dq frame
        ia_fund = i_gd * cos(theta_grid) - i_gq * sin(theta_grid);
        ib_fund = i_gd * cos(theta_grid - 2*pi/3) - i_gq * sin(theta_grid - 2*pi/3);
        ic_fund = i_gd * cos(theta_grid + 2*pi/3) - i_gq * sin(theta_grid + 2*pi/3);

        % Harmonics
        ia_h = -h5_mag * cos(5*theta_grid) + h7_mag * cos(7*theta_grid) - h11_mag * cos(11*theta_grid);
        ib_h = -h5_mag * cos(5*(theta_grid - 2*pi/3)) + h7_mag * cos(7*(theta_grid - 2*pi/3)) - h11_mag * cos(11*(theta_grid - 2*pi/3));
        ic_h = -h5_mag * cos(5*(theta_grid + 2*pi/3)) + h7_mag * cos(7*(theta_grid + 2*pi/3)) - h11_mag * cos(11*(theta_grid + 2*pi/3));

        ia = ia_fund + ia_h + carrier_ripple;
        ib = ib_fund + ib_h + carrier_ripple;
        ic = ic_fund + ic_h + carrier_ripple;

        %% ----------------------------------------------------------------
        % 5. COMMON DC BUS CAPACITOR DYNAMICS
        % ----------------------------------------------------------------
        % Active power flowing into DC bus from grid via AFE (with 98% efficiency)
        P_afe_ac = 1.5 * (v_gd * i_gd + v_gq * i_gq);
        eta_afe = 0.985;
        if P_afe_ac >= 0
            P_afe_dc = P_afe_ac * eta_afe;
        else
            P_afe_dc = P_afe_ac / eta_afe;
        end
        i_afe_dc = P_afe_dc / max(v_dc, 100.0);

        % Capacitor node equation: C * dV_dc/dt = i_afe_dc - i_dcdc_dc
        dv_dc_dt = (i_afe_dc - i_dcdc_dc) / C_dc;
        v_dc = v_dc + dv_dc_dt * dt;

        %% ----------------------------------------------------------------
        % 6. TELEMETRY & LOGGING (DECIMATED)
        % ----------------------------------------------------------------
        if mod(k, log_decim) == 0 && log_idx <= N_log_est
            P_grid = 1.5 * (v_gd * i_gd + v_gq * i_gq);
            Q_grid = 1.5 * (v_gq * i_gd - v_gd * i_gq);
            S_grid = sqrt(P_grid^2 + Q_grid^2) + 1e-3;
            pf_val = P_grid / S_grid;

            t_out(log_idx)        = t;
            v_grid_a(log_idx)     = va;
            v_grid_b(log_idx)     = vb;
            v_grid_c(log_idx)     = vc;
            i_grid_a(log_idx)     = ia;
            i_grid_b(log_idx)     = ib;
            i_grid_c(log_idx)     = ic;
            
            v_gd_log(log_idx)     = v_gd;
            v_gq_log(log_idx)     = v_gq;
            i_gd_log(log_idx)     = i_gd;
            i_gq_log(log_idx)     = i_gq;
            i_gd_ref_log(log_idx) = i_gd_ref;
            i_gq_ref_log(log_idx) = i_gq_ref;
            
            v_dc_log(log_idx)     = v_dc;
            v_dc_ref_log(log_idx) = V_dc_nom;
            
            p_grid_log(log_idx)   = P_grid;
            q_grid_log(log_idx)   = Q_grid;
            pf_grid_log(log_idx)  = pf_val;
            
            i_bat_log(log_idx)    = i_bat;
            i_bat_ref_log(log_idx)= i_bat_ref;
            v_bat_log(log_idx)    = v_bat;
            soc_log(log_idx)      = soc;
            p_bat_log(log_idx)    = v_bat * i_bat;
            mode_log(log_idx)     = operating_mode;
            
            log_idx = log_idx + 1;
        end
    end

    elapsed = toc;
    fprintf('Simulation completed in %.2f seconds.\n', elapsed);

    % Trim logged arrays
    N_log = log_idx - 1;
    results.t        = t_out(1:N_log);
    results.va       = v_grid_a(1:N_log);
    results.vb       = v_grid_b(1:N_log);
    results.vc       = v_grid_c(1:N_log);
    results.ia       = i_grid_a(1:N_log);
    results.ib       = i_grid_b(1:N_log);
    results.ic       = i_grid_c(1:N_log);
    results.vg_d     = v_gd_log(1:N_log);
    results.vg_q     = v_gq_log(1:N_log);
    results.ig_d     = i_gd_log(1:N_log);
    results.ig_q     = i_gq_log(1:N_log);
    results.ig_d_ref = i_gd_ref_log(1:N_log);
    results.ig_q_ref = i_gq_ref_log(1:N_log);
    results.v_dc     = v_dc_log(1:N_log);
    results.v_dc_ref = v_dc_ref_log(1:N_log);
    results.P_grid   = p_grid_log(1:N_log);
    results.Q_grid   = q_grid_log(1:N_log);
    results.PF       = pf_grid_log(1:N_log);
    results.i_bat    = i_bat_log(1:N_log);
    results.i_bat_ref= i_bat_ref_log(1:N_log);
    results.v_bat    = v_bat_log(1:N_log);
    results.soc      = soc_log(1:N_log);
    results.P_bat    = p_bat_log(1:N_log);
    results.mode     = mode_log(1:N_log);

    save('simulation/simulation_results.mat', 'results');
    fprintf('Simulation data successfully saved to simulation/simulation_results.mat\n');
end
