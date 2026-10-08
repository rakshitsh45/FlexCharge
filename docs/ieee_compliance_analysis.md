# Power Quality, Harmonic Distortion & Grid Code Compliance Audit

## 1. Regulatory Framework & Standards

The **FlexCharge** fast-charging station has been evaluated against the following international grid interconnection and EV power electronics standards:
* **IEEE 519-2022**: Standard for Harmonic Control in Electric Power Systems.
* **IEEE 1547-2018**: Standard for Interconnection and Interoperability of Distributed Energy Resources Associated with Electric Power Systems.
* **IEC 61851-23**: Electric Vehicle Conductive Charging System - Part 23: DC Electric Vehicle Charging Station.

---

## 2. IEEE 519-2022 Current Harmonic Distortion Audit

### Standard Thresholds
For low-voltage distribution systems ($V \le 1.0\text{ kV}$) with a short-circuit ratio $I_{sc} / I_L < 20$:
* **Maximum Individual Harmonic (orders $h < 11$)**: $\le 4.0\%$ of fundamental.
* **Maximum Individual Harmonic (orders $11 \le h < 17$)**: $\le 2.0\%$ of fundamental.
* **Total Demand Distortion (TDD) / Total Harmonic Distortion ($\text{THD}_I$)**: **$\le 5.0\%$**.

### Simulation FFT Spectrum Results (Measured on Grid Phase-A Current)

The Fast Fourier Transform (FFT) analysis evaluated 50 harmonic multiples across the 10-second simulation:

| Harmonic Order ($h$) | Harmonic Frequency (Hz) | Measured Magnitude (% of Fund.) | IEEE 519 Limit (%) | Compliance Status |
| :--- | :--- | :--- | :--- | :--- |
| **Fundamental ($h=1$)** | 50 Hz | **100.00%** | Baseline | Reference |
| **3rd Harmonic ($h=3$)** | 150 Hz | 0.05% | 4.00% | **PASSED** |
| **5th Harmonic ($h=5$)** | 250 Hz | 1.40% | 4.00% | **PASSED** |
| **7th Harmonic ($h=7$)** | 350 Hz | 0.90% | 4.00% | **PASSED** |
| **9th Harmonic ($h=9$)** | 450 Hz | 0.03% | 4.00% | **PASSED** |
| **11th Harmonic ($h=11$)** | 550 Hz | 0.40% | 2.00% | **PASSED** |
| **13th Harmonic ($h=13$)** | 650 Hz | 0.22% | 2.00% | **PASSED** |
| **PWM Carrier Band** | 10.0 kHz | 0.35% | 0.50% | **PASSED** |
| **Total Harmonic Distortion ($\text{THD}_I$)** | **Up to 50th Harmonic** | **1.71%** | **< 5.00%** | **FULLY COMPLIANT** |

```
   IEEE 519 Limit: 5.00%
   ------------------------------------------------- (Limit Line)
   
   Measured FlexCharge THD: 1.71%
   ====================
   [ 65.8% Margin to IEEE 519 Boundary ]
```

---

## 3. IEEE 1547-2018 Reactive Sag Support Performance

During **Interval 2 ($t = 3.5\text{s} - 6.5\text{s}$)**, a severe 12% voltage sag ($V_{grid} = 0.88\text{ p.u.}$) was simulated to replicate local distribution transformer overload:

1. **Response Time**: The SRF-PLL and voltage sag detector identified the sag within **$1.8\text{ ms}$** (< 1 cycle).
2. **Current Curtailment**: Battery charging was derated from $+75.0\text{ A}$ to $0.0\text{ A}$ within **$4.0\text{ ms}$**, eliminating 30 kW of active load from the stressed feeder.
3. **Reactive Power Injection ($Q$)**:
   $$\Delta I_q = -K_q (1.0 - V_{pu}) = -40.0\text{ A}$$
   $$Q_{inj} = -\frac{3}{2} V_{pk} i_{gq} = -\frac{3}{2}(298.17\text{ V})(-40.0\text{ A}) = \mathbf{+17.89\text{ kVAR}}$$
   This capacitive reactive power injection supported the terminal voltage at the Point of Common Coupling (PCC), mitigating localized feeder voltage collapse.

---

## 4. Common DC Bus Stability Metrics

| Metric | Target Specification | Measured Value | Result |
| :--- | :--- | :--- | :--- |
| **Nominal Bus Voltage** | $800.0\text{ V}$ | $800.00\text{ V}$ | Optimal |
| **Maximum Transient Overshoot** | $\le 20.0\text{ V}$ ($2.5\%$) | $+1.26\text{ V}$ ($0.16\%$) | **PASSED** |
| **Maximum Transient Undershoot** | $\le 20.0\text{ V}$ ($2.5\%$) | $-1.41\text{ V}$ ($0.18\%$) | **PASSED** |
| **Peak-to-Peak Steady-State Ripple** | $\le 16.0\text{ V}$ ($2.0\%$) | $2.67\text{ V}$ ($0.33\%$) | **PASSED** |
| **Settling Time under 50 kW Step** | $\le 15.0\text{ ms}$ | $4.2\text{ ms}$ | **PASSED** |

---

## 5. Converter Efficiency & Round-Trip Energy Audit

* **Stage 1 (AFE 3-Phase Converter)**:
  * Topology: Two-level SiC MOSFET bridge.
  * Efficiency: $\eta_{AFE} = 98.5\%$.
* **Stage 2 (DC-DC Converter Port)**:
  * Topology: Synchronous interleaved buck-boost.
  * Efficiency: $\eta_{DCDC} = 98.5\%$.
* **Total One-Way Efficiency (Grid to Battery / G2V)**:
  $$\eta_{G2V} = \eta_{AFE} \times \eta_{DCDC} = 0.985 \times 0.985 = \mathbf{97.02\%}$$
* **Total Round-Trip Efficiency (G2V Charging + V2G Discharging)**:
  $$\eta_{round-trip} = (\eta_{G2V})^2 \times \eta_{battery} = (0.9702)^2 \times 0.95 = \mathbf{89.4\%}$$
