%% =========================================================================
% Project: FlexCharge - V2G & G2V Fast-Charging Station Optimization
% File: init_params.m
% Description: Master Parameter Initialization & Controller Tuning Script
% Standards: IEEE 519-2022, IEEE 1547-2018, IEC 61851-23
% =========================================================================

clear; clc;
fprintf('Initializing FlexCharge System Parameters...\n');

%% ------------------------------------------------------------------------
% 1. SIMULATION SOLVER CONFIGURATION
% ------------------------------------------------------------------------
Ts = 10e-6;                 % Fundamental simulation step size (10 microseconds)
T_stop = 10.0;              % Total simulation time (10 seconds)
f_sw = 10e3;                % Switching frequency for PWM converters (10 kHz)
T_sw = 1 / f_sw;

%% ------------------------------------------------------------------------
% 2. THREE-PHASE AC DISTRIBUTION GRID
% ------------------------------------------------------------------------
% Step-down distribution transformer secondary side parameters
V_grid_LL_rms = 415;        % Nominal line-to-line RMS voltage (V)
V_grid_ph_rms = V_grid_LL_rms / sqrt(3); % Phase RMS voltage (~239.6 V)
V_grid_peak   = V_grid_ph_rms * sqrt(2); % Phase peak voltage (~338.8 V)
f_grid        = 50;         % Grid fundamental frequency (Hz)
omega_g       = 2 * pi * f_grid; % Grid angular frequency (rad/s)

% Grid Interface / L-Filter parameters (Active Front End choke)
L_grid = 2.5e-3;            % Interface boost inductor (H) -> 2.5 mH
R_grid = 0.05;              % Inductor parasitic series resistance (Ohm)
X_L    = omega_g * L_grid;  % Choke reactance (~0.785 Ohm)

%% ------------------------------------------------------------------------
% 3. COMMON DC BUS PARAMETERS
% ------------------------------------------------------------------------
% Standard 800V Architecture (Compatible with high-power Level-3 EV Fast Chargers)
V_dc_nom = 800.0;           % Nominal Common DC Bus Voltage (V)
C_dc     = 4700e-6;         % DC Bus Electrolytic Capacitor bank (4700 uF)
% Energy buffer calculation: E_dc = 0.5 * C_dc * V_dc^2 = 1504 Joules

%% ------------------------------------------------------------------------
% 4. BIDIRECTIONAL DC-DC CHARGING PORT CONVERTER
% ------------------------------------------------------------------------
% Synchronous Half-Bridge / Interleaved Buck-Boost converter
L_dcdc = 2.0e-3;            % Buck-boost energy storage inductor (2.0 mH)
R_dcdc = 0.02;              % DC-DC inductor internal resistance (Ohm)
C_bat_filter = 1000e-6;     % Output battery port filter capacitor (1000 uF)

%% ------------------------------------------------------------------------
% 5. EV BATTERY PACK SPECIFICATIONS (Lithium-Ion Simscape Equivalent)
% ------------------------------------------------------------------------
% Pack configured for high-performance commercial EV (e.g., 60 kWh pack)
V_bat_nom   = 400.0;        % Nominal battery pack voltage (V)
V_bat_max   = 420.0;        % Maximum charging cutoff voltage / CV mode target (V)
V_bat_min   = 320.0;        % Minimum discharge cutoff voltage (V)
Q_bat_Ah    = 150.0;        % Battery pack nominal capacity (150 Ah / 60 kWh)
R_bat_int   = 0.035;        % Battery internal equivalent series resistance (ESR in Ohm)
SoC_initial = 25.0;         % Initial State of Charge (Low SoC: 25%)

% Operating Currents
I_ch_CC     = 75.0;         % Constant Current charging setpoint (+75 A -> ~30 kW G2V)
I_dis_V2G   = -60.0;        % Vehicle-to-Grid peak discharge setpoint (-60 A -> ~24 kW V2G)
SoC_CV_threshold = 80.0;    % Transition threshold from CC to CV mode (%)

%% ------------------------------------------------------------------------
% 6. ACTIVE FRONT END (AFE) CONTROL LOOP TUNING (d-q SYNCHRONOUS FRAME)
% ------------------------------------------------------------------------
% Inner Grid Current PI Controllers (Modulus Optimum Design)
% Open-loop plant: G_i(s) = 1 / (R_grid + s * L_grid)
% Desired closed loop bandwidth ~ 1 kHz (omega_ci = 2*pi*1000)
tau_i = L_grid / R_grid;    % Plant electrical time constant (~0.05 s)
Kp_i  = 12.5;               % Current loop proportional gain (V/A)
Ki_i  = 950.0;              % Current loop integral gain (V/(A*s))

% Outer DC Bus Voltage PI Controller (Symmetrical Optimum Design)
% Plant transfer function: C_dc * dV_dc/dt = (3/2)*(V_d/V_dc)*i_d - I_load
Kp_dc = 1.45;               % DC Voltage loop proportional gain (A/V)
Ki_dc = 28.0;               % DC Voltage loop integral gain (A/(V*s))
V_dc_lim_max = 120.0;       % Maximum allowable d-axis current limit (A)
V_dc_lim_min = -120.0;      % Minimum d-axis current limit (regenerative limit) (A)

% PLL Parameters (Second-Order Synchronous Reference Frame SRF-PLL)
Kp_pll = 60.0;
Ki_pll = 1800.0;

%% ------------------------------------------------------------------------
% 7. BIDIRECTIONAL DC-DC CHARGER CONTROLLER TUNING
% ------------------------------------------------------------------------
% Inner Battery Current Controller (Controls Inductor Current i_L)
Kp_ib = 0.065;              % Proportional gain (Duty/A)
Ki_ib = 12.0;               % Integral gain (Duty/(A*s))

% Outer Battery Voltage Controller (Active during CV Charging Mode)
Kp_vb = 2.2;                % Proportional gain (A/V)
Ki_vb = 8.5;                % Integral gain (A/(V*s))

%% ------------------------------------------------------------------------
% 8. 10-SECOND HIGH-DEMAND MULTI-STAGE SCENARIO DEFINITION
% ------------------------------------------------------------------------
% Stage 1: t in [0.0, 3.5) s  -> Normal G2V Fast Charging (Unity Power Factor)
% Stage 2: t in [3.5, 6.5) s  -> Grid Stress / 12% Voltage Sag & Reactive Support
% Stage 3: t in [6.5, 10.0] s -> V2G Active Grid Support (Peak Demand Shaving)

T_sag_start = 3.5;          % Voltage sag inception time (s)
T_sag_end   = 6.5;          % Voltage sag clearance time (s)
V_sag_factor = 0.88;        % 12% grid voltage sag magnitude (0.88 p.u.)

T_v2g_start = 6.5;          % Utility peak demand dispatch command trigger (s)

fprintf('Parameters loaded successfully into MATLAB Workspace.\n');
fprintf('  - Grid: %d V RMS L-L, %d Hz\n', V_grid_LL_rms, f_grid);
fprintf('  - Common DC Bus: %d V\n', V_dc_nom);
fprintf('  - Battery: %d V Nom, %d Ah (Initial SoC: %.1f%%)\n', V_bat_nom, Q_bat_Ah, SoC_initial);
fprintf('  - G2V Charging: +%.1f A (~%.1f kW)\n', I_ch_CC, (V_bat_nom * I_ch_CC)/1e3);
fprintf('  - V2G Discharging: %.1f A (~%.1f kW)\n', I_dis_V2G, (V_bat_nom * abs(I_dis_V2G))/1e3);
