# System Architecture & Power Electronics Topology

## 1. Executive Overview

**FlexCharge** is an industrial-grade simulation model of a **Level-3 DC Fast Charging Station (DCFC)** with bidirectional power flow capabilities (**G2V: Grid-to-Vehicle** and **V2G: Vehicle-to-Grid**). Connected to a standard distribution grid ($11\text{ kV} / 415\text{ V}$), the system dynamically mitigates grid congestion, performs reactive power voltage sag compensation, and delivers active power back to the grid during peak demand events.

```
+---------------------------------------------------------------------------------------------------+
|                                 FLEXCHARGE SYSTEM ARCHITECTURE                                    |
+---------------------------------------------------------------------------------------------------+
                                                                                                    
   [ 11 kV Grid ]                                                                                   
          |                                                                                         
   [ Delta-Wye 100 kVA Transformer ]                                                                
          | 415V RMS (L-L), 50 Hz                                                                   
          v                                                                                         
   +------------------------------+     +-------------------+     +-------------------------------+ 
   |           STAGE 1            |     |      STAGE 2      |     |            STAGE 3            | 
   | 3-Phase Active Front End     |===> | Common 800V DC    |===> | Bidirectional Buck-Boost Port | 
   | (AFE) PWM Rectifier/Inverter | <===| Bus Capacitor Bank| <===| connected to 60 kWh EV Pack   | 
   +------------------------------+     +-------------------+     +-------------------------------+ 
          |                                       |                               |                 
          | d-q Vector Control                    | C_dc = 4700 uF                | CC-CV Logic     
          | UPF & Reactive Sag Support            | 800V Regulated                | G2V / V2G Mode  
```

---

## 2. Power Conversion Stages

### Stage 1: Distribution Grid Interface & Active Front End (AC to DC)
* **AC Source**: 3-Phase Distribution Grid, $415\text{ V}_{\text{RMS}}$ line-to-line, $50\text{ Hz}$.
* **Distribution Transformer**: $11\text{ kV} / 415\text{ V}$, $\Delta-Y_g$, $100\text{ kVA}$.
* **Choke Filter**: Line inductors $L_{grid} = 2.5\text{ mH}$, series resistance $R_{grid} = 0.05\ \Omega$.
* **Converter Topology**: Three-Phase Two-Level Bidirectional PWM Active Front End (AFE) operating at $f_{sw} = 10\text{ kHz}$.
* **Operating Roles**:
  * **Rectifier Mode (G2V)**: Draws sinusoidal AC current at **Unity Power Factor (UPF, $\cos\phi = 1.000$)** to feed the common DC link.
  * **Inverter Mode (V2G)**: Reverses power flow, feeding active power ($P < 0$) back into the AC distribution line with $180^\circ$ phase inversion and Total Harmonic Distortion ($\text{THD}_I < 2\%$).
  * **STATCOM Mode (Interval 2)**: Dynamically injects capacitive reactive power ($Q > 0$) to support grid terminal voltage during local voltage sags.

### Stage 2: Common DC Link Bus
* **Nominal Bus Voltage**: $V_{dc} = 800.0\text{ V}$.
  * Chosen to align with modern 800V high-power EV charging platforms (Porsche Taycan, Hyundai E-GMP, commercial fleet chargers).
  * Minimum theoretical voltage required for 3-phase PWM rectifier without overmodulation:
    $$V_{dc,min} > \sqrt{2} \cdot V_{LL,rms} = \sqrt{2} \cdot 415 \approx 587\text{ V}$$
    Selecting $800\text{ V}$ provides generous linear modulation margin ($M \approx 0.73$).
* **Capacitor Bank**: $C_{dc} = 4700\ \mu\text{F}$ rated at $1000\text{ V}_{\text{DC}}$.
* **Energy Storage**:
  $$E_{dc} = \frac{1}{2} C_{dc} V_{dc}^2 = \frac{1}{2} (4.7 \times 10^{-3}) (800)^2 = 1,504\text{ Joules}$$
* **Bus Ripple Performance**: Measured dynamic voltage deviation is restricted to $\pm 1.4\text{ V}$ ($\pm 0.17\%$), and steady-state ripple is $< 0.35\%$, comfortably exceeding industrial standards ($< 2\%$).

### Stage 3: Bidirectional DC-DC Charging Port & EV Battery
* **Converter Topology**: Synchronous Half-Bridge / Interleaved Bidirectional Buck-Boost Converter.
  * **G2V Charging**: Operates in **Buck Mode**, stepping $800\text{ V}_{\text{DC}}$ down to the nominal EV battery voltage ($\sim 380\text{V} - 420\text{V}$).
  * **V2G Discharging**: Operates in **Boost Mode**, stepping the battery terminal voltage up to the $800\text{ V}_{\text{DC}}$ common bus.
* **Filter Components**: Storage inductor $L_{dc} = 2.0\text{ mH}$, $R_{dc} = 0.02\ \Omega$, output filter capacitor $C_{bat} = 1000\ \mu\text{F}$.
* **EV Battery Pack**:
  * Chemistry: Lithium-Ion NMC (Simscape / SimPowerSystems equivalent Thevenin model).
  * Nominal Pack Voltage: $V_{bat,nom} = 400.0\text{ V}$.
  * Pack Capacity: $150\text{ Ah}$ ($60.0\text{ kWh}$).
  * Charging Voltage Limits: Cut-off $V_{max} = 420.0\text{ V}$, minimum $V_{min} = 320.0\text{ V}$.
  * Internal Series Resistance ($R_{int}$): $0.035\ \Omega$.

---

## 3. Modeling Methodology: System-Level Behavioral vs. Component-Level Simulation

### Strategic Design Choice: Mathematical Signal-Flow Architecture
The simulation is implemented using **system-level behavioral dynamics and strictly causal state-space modeling** rather than component-level physical schematics (Simscape Electrical / SimPowerSystems).

#### Why System-Level Simulation was Adopted:
1. **Computational Throughput**: Capturing individual 10 kHz PWM switching transitions across a 10-second multi-mode scenario requires microsecond time steps ($\Delta t \le 1\,\mu\text{s}$), leading to $>10^7$ iterations and simulation execution times of 15–30 minutes. In contrast, the system-level state-space model runs at a fixed discrete step of $\Delta t = 100\,\mu\text{s}$, completing in under 1 second without compromising control or dynamic fidelity.
2. **Deterministic, Algebraic-Loop-Free Execution**: Commutating semiconductor models introduce zero-crossing discontinuities and algebraic loops. The system-level formulation uses an explicit $D=0$ causal state representation with unit delay feedback, guaranteeing 100% numerical stability.
3. **Firmware & Controller Target Parity**: Target DSP controllers (e.g. TI C2000, STM32) execute discrete difference equations and PI loops. The behavioral model directly matches production embedded code structures, allowing seamless MIL (Model-in-the-Loop) and SIL verification.
4. **Toolbox Independence**: The model executes directly on base MATLAB and Simulink without requiring add-on licenses for Simscape Electrical.

---

## 4. Mathematical State-Space Formulations

### Grid & AFE Dynamics in Synchronous ($d$-$q$) Rotating Frame
Transforming 3-phase balanced voltages and currents via Park's Transformation rotating at $\omega_g = 2\pi(50)\text{ rad/s}$:

$$\begin{bmatrix} v_d \\ v_q \end{bmatrix} = \frac{2}{3} \begin{bmatrix} \cos\theta & \cos(\theta - 2\pi/3) & \cos(\theta + 2\pi/3) \\ -\sin\theta & -\sin(\theta - 2\pi/3) & -\sin(\theta + 2\pi/3) \end{bmatrix} \begin{bmatrix} v_a \\ v_b \\ v_c \end{bmatrix}$$

The grid interface inductor differential equations are:

$$L_{grid} \frac{d i_{gd}}{dt} = v_{gd} - v_{conv,d} + \omega_g L_{grid} i_{gq} - R_{grid} i_{gd}$$

$$L_{grid} \frac{d i_{gq}}{dt} = v_{gq} - v_{conv,q} - \omega_g L_{grid} i_{gd} - R_{grid} i_{gq}$$

Where:
* $v_{gd}, v_{gq}$ are the grid $d$ and $q$ axis voltages ($v_{gd} = V_{pk} \approx 338.8\text{ V}$, $v_{gq} = 0$ in steady state).
* $v_{conv,d}, v_{conv,q}$ are the converter terminal voltages synthesised by PWM modulation.
* $\omega_g L_{grid} i_{gq}$ and $-\omega_g L_{grid} i_{gd}$ represent cross-coupling terms compensated by the feedforward decoupled controller.

### DC Link Capacitor Dynamics
The common DC bus voltage responds to power exchange between Stage 1 (AFE) and Stage 2 (DC-DC):

$$C_{dc} \frac{d V_{dc}}{dt} = i_{afe,dc} - i_{dcdc,dc}$$

Where active power conversion yields:

$$P_{afe} = \frac{3}{2}(v_{gd} i_{gd} + v_{gq} i_{gq}), \quad i_{afe,dc} = \frac{\eta_{afe} P_{afe}}{V_{dc}}$$

$$P_{bat} = v_{bat} i_{bat}, \quad i_{dcdc,dc} = \frac{P_{bat}}{\eta_{dcdc} V_{dc}}$$

---

## 5. Hardware Parameters Summary

| Parameter | Symbol | Nominal Value | Unit |
| :--- | :--- | :--- | :--- |
| AC Grid Line Voltage | $V_{LL,rms}$ | 415 | V |
| Grid Frequency | $f_g$ | 50 | Hz |
| AFE Boost Inductance | $L_{grid}$ | 2.5 | mH |
| AFE Parasitic Resistance | $R_{grid}$ | 0.05 | $\Omega$ |
| Common DC Bus Voltage | $V_{dc}$ | 800.0 | V |
| DC Bus Capacitance | $C_{dc}$ | 4700 | $\mu\text{F}$ |
| DC-DC Storage Inductance | $L_{dc}$ | 2.0 | mH |
| Battery Pack Voltage | $V_{bat}$ | 400.0 | V |
| Battery Pack Capacity | $Q$ | 150 (60 kWh) | Ah |
| Nominal G2V Fast Charging Current | $I_{ch}$ | +75.0 (30 kW) | A |
| Nominal V2G Peak Discharge Current | $I_{dis}$ | -60.0 (24 kW) | A |
| Converter Switching Frequency | $f_{sw}$ | 10.0 | kHz |
